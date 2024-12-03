// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/mainnet-fork/ForkTestBase.t.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { ERC20Mock } from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

import { Base } from "spark-address-registry/src/Base.sol";

import { PSM3Deploy }       from "spark-psm/deploy/PSM3Deploy.sol";
import { IPSM3 }            from "spark-psm/src/PSM3.sol";
import { MockRateProvider } from "spark-psm/test/mocks/MockRateProvider.sol";

import { CCTPBridgeTesting } from "xchain-helpers/src/testing/bridges/CCTPBridgeTesting.sol";
import { CCTPForwarder }     from "xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { ForeignControllerDeploy } from "deploy/ControllerDeploy.sol";
import { ControllerInstance }      from "deploy/ControllerInstance.sol";

import { ForeignControllerInit, MintRecipient } from "deploy/ControllerInit.sol";

import { ALMProxy }          from "src/ALMProxy.sol";
import { ForeignController } from "src/ForeignController.sol";
import { RateLimits }        from "src/RateLimits.sol";
import { RateLimitHelpers }  from "src/RateLimitHelpers.sol";

contract MainnetControllerTransferUSDCToCCTPFailureTests is ForkTestBase {

    function test_transferUSDCToCCTP_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
    }

    function test_transferUSDCToCCTP_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
    }

    function test_transferUSDCToCCTP_cctpRateLimitedBoundary() external {
        vm.startPrank(SPARK_PROXY);

        // Set this so second modifier will be passed in success case
        rateLimits.setUnlimitedRateLimitData(
            RateLimitHelpers.makeDomainKey(
                mainnetController.LIMIT_USDC_TO_DOMAIN(),
                CCTPForwarder.DOMAIN_ID_CIRCLE_BASE
            )
        );

        // Rate limit will be constant 10m (higher than setup)
        rateLimits.setRateLimitData(mainnetController.LIMIT_USDC_TO_CCTP(), 10_000_000e6, 0);

        // Set this for success case
        mainnetController.setMintRecipient(
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            bytes32(uint256(uint160(makeAddr("mintRecipient"))))
        );

        vm.stopPrank();

        deal(address(usdc), address(almProxy), 10_000_000e6 + 1);

        vm.startPrank(relayer);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.transferUSDCToCCTP(10_000_000e6 + 1, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);

        mainnetController.transferUSDCToCCTP(10_000_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
    }

    function test_transferUSDCToCCTP_domainRateLimitedBoundary() external {
        vm.startPrank(SPARK_PROXY);

        // Set this so first modifier will be passed in success case
        rateLimits.setUnlimitedRateLimitData(mainnetController.LIMIT_USDC_TO_CCTP());

        // Rate limit will be constant 10m (higher than setup)
        rateLimits.setRateLimitData(
            RateLimitHelpers.makeDomainKey(
                mainnetController.LIMIT_USDC_TO_DOMAIN(),
                CCTPForwarder.DOMAIN_ID_CIRCLE_BASE
            ),
            10_000_000e6,
            0
        );

        // Set this for success case
        mainnetController.setMintRecipient(
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            bytes32(uint256(uint160(makeAddr("mintRecipient"))))
        );

        vm.stopPrank();

        deal(address(usdc), address(almProxy), 10_000_000e6 + 1);

        vm.startPrank(relayer);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.transferUSDCToCCTP(10_000_000e6 + 1, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);

        mainnetController.transferUSDCToCCTP(10_000_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
    }

    function test_transferUSDCToCCTP_invalidMintRecipient() external {
        // Configure to pass modifiers
        vm.startPrank(SPARK_PROXY);

        rateLimits.setUnlimitedRateLimitData(
            RateLimitHelpers.makeDomainKey(
                mainnetController.LIMIT_USDC_TO_DOMAIN(),
                CCTPForwarder.DOMAIN_ID_CIRCLE_ARBITRUM_ONE
            )
        );

        rateLimits.setUnlimitedRateLimitData(mainnetController.LIMIT_USDC_TO_CCTP());

        vm.stopPrank();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/domain-not-configured");
        mainnetController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ARBITRUM_ONE);
    }

}

// TODO: Figure out finalized structure for this repo/testing structure wise
contract BaseChainUSDCToCCTPTestBase is ForkTestBase {

    using DomainHelpers     for *;
    using CCTPBridgeTesting for Bridge;

    /**********************************************************************************************/
    /*** Constants/state variables                                                              ***/
    /**********************************************************************************************/

    address pocket = makeAddr("pocket");

    /**********************************************************************************************/
    /*** Base addresses                                                                         ***/
    /**********************************************************************************************/

    address constant CCTP_MESSENGER_BASE = Base.CCTP_TOKEN_MESSENGER;
    address constant SPARK_EXECUTOR      = Base.SPARK_EXECUTOR;
    address constant SSR_ORACLE          = Base.SSR_AUTH_ORACLE;
    address constant USDC_BASE           = Base.USDC;

    /**********************************************************************************************/
    /*** ALM system deployments                                                                 ***/
    /**********************************************************************************************/

    ALMProxy          foreignAlmProxy;
    RateLimits        foreignRateLimits;
    ForeignController foreignController;

    /**********************************************************************************************/
    /*** Casted addresses for testing                                                           ***/
    /**********************************************************************************************/

    IERC20 usdsBase;
    IERC20 susdsBase;
    IERC20 usdcBase;

    MockRateProvider rateProvider;

    IPSM3 psmBase;

    uint256 USDC_BASE_SUPPLY;

    function setUp() public override virtual {
        super.setUp();

        /*** Step 1: Set up environment and deploy mocks ***/

        destination = getChain("base").createSelectFork(23190000);  // Dec 2, 2024

        susdsBase = IERC20(Base.SUSDS);
        usdcBase  = IERC20(Base.USDC);
        usdsBase  = IERC20(Base.USDS);

        /*** Step 2: Deploy and configure PSM with a pocket ***/

        deal(address(usdsBase), address(this), 1e18);  // For seeding PSM during deployment

        psmBase = IPSM3(Base.PSM3);

        vm.prank(SPARK_EXECUTOR);
        psmBase.setPocket(pocket);

        vm.prank(pocket);
        usdcBase.approve(address(psmBase), type(uint256).max);

        /*** Step 3: Deploy and configure ALM system ***/

        foreignController = ForeignController(ForeignControllerDeploy.deployController({
            admin      : Base.SPARK_EXECUTOR,
            almProxy   : Base.ALM_PROXY,
            rateLimits : Base.ALM_RATE_LIMITS,
            psm        : Base.PSM3,
            usdc       : Base.USDC,
            cctp       : Base.CCTP_TOKEN_MESSENGER
        }));

        foreignAlmProxy   = ALMProxy(payable(Base.ALM_PROXY));
        foreignRateLimits = RateLimits(Base.ALM_RATE_LIMITS);

        ForeignControllerInit.ConfigAddressParams memory configAddresses
            = ForeignControllerInit.ConfigAddressParams({
                admin         : SPARK_EXECUTOR,
                freezer       : freezer,  // TODO: Use real freezer addresses
                relayer       : relayer,
                oldController : Base.ALM_CONTROLLER
            });

        ForeignControllerInit.AddressCheckParams memory checkAddresses
            = ForeignControllerInit.AddressCheckParams({
                psm           : address(psmBase),
                cctpMessenger : CCTP_MESSENGER_BASE,
                usdc          : Base.USDC,
                usds          : Base.USDS,
                susds         : Base.SUSDS
            });

        ControllerInstance memory controllerInst = ControllerInstance({
            almProxy   : Base.ALM_PROXY,
            controller : address(foreignController),
            rateLimits : Base.ALM_RATE_LIMITS
        });

        MintRecipient[] memory mintRecipients = new MintRecipient[](1);

        mintRecipients[0] = MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            mintRecipient : bytes32(uint256(uint160(address(almProxy))))
        });

        vm.startPrank(SPARK_EXECUTOR);
        // NOTE: Intentionally not setting new rate limits because they are not relevant for this
        //       testing. Existing rate limits can be used.
        ForeignControllerInit.init(
            configAddresses,
            checkAddresses,
            controllerInst,
            mintRecipients
        );
        vm.stopPrank();

        USDC_BASE_SUPPLY = usdcBase.totalSupply();

        source.selectFork();

        bridge = CCTPBridgeTesting.createCircleBridge(source, destination);

        vm.prank(SPARK_PROXY);
        mainnetController.setMintRecipient(
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            bytes32(uint256(uint160(address(foreignAlmProxy))))
        );
    }

}

contract ForeignControllerTransferUSDCToCCTPFailureTests is BaseChainUSDCToCCTPTestBase {

    using DomainHelpers for *;

    function setUp( ) public override {
        super.setUp();
        destination.selectFork();
    }

    function test_transferUSDCToCCTP_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        foreignController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);
    }

    function test_transferUSDCToCCTP_frozen() external {
        vm.prank(freezer);
        foreignController.freeze();

        vm.prank(relayer);
        vm.expectRevert("ForeignController/not-active");
        foreignController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);
    }

    function test_transferUSDCToCCTP_cctpRateLimitedBoundary() external {
        vm.startPrank(SPARK_EXECUTOR);

        // Set this so second modifier will be passed in success case
        foreignRateLimits.setUnlimitedRateLimitData(
            RateLimitHelpers.makeDomainKey(
                foreignController.LIMIT_USDC_TO_DOMAIN(),
                CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM
            )
        );

        // Rate limit will be constant 10m (higher than setup)
        foreignRateLimits.setRateLimitData(foreignController.LIMIT_USDC_TO_CCTP(), 10_000_000e6, 0);

        // Set this for success case
        foreignController.setMintRecipient(
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            bytes32(uint256(uint160(makeAddr("mintRecipient"))))
        );

        vm.stopPrank();

        deal(address(usdcBase), address(foreignAlmProxy), 10_000_000e6 + 1);

        vm.startPrank(relayer);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        foreignController.transferUSDCToCCTP(10_000_000e6 + 1, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);

        foreignController.transferUSDCToCCTP(10_000_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);
    }

    function test_transferUSDCToCCTP_domainRateLimitedBoundary() external {
        vm.startPrank(SPARK_EXECUTOR);

        // Set this so first modifier will be passed in success case
        foreignRateLimits.setUnlimitedRateLimitData(foreignController.LIMIT_USDC_TO_CCTP());

        // Rate limit will be constant 10m (higher than setup)
        foreignRateLimits.setRateLimitData(
            RateLimitHelpers.makeDomainKey(
                foreignController.LIMIT_USDC_TO_DOMAIN(),
                CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM
            ),
            10_000_000e6,
            0
        );

        // Set this for success case
        foreignController.setMintRecipient(
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            bytes32(uint256(uint160(makeAddr("mintRecipient"))))
        );

        vm.stopPrank();

        deal(address(usdcBase), address(foreignAlmProxy), 10_000_000e6 + 1);

        vm.startPrank(relayer);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        foreignController.transferUSDCToCCTP(10_000_000e6 + 1, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);

        foreignController.transferUSDCToCCTP(10_000_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);
    }

    function test_transferUSDCToCCTP_invalidMintRecipient() external {
        // Configure to pass modifiers
        vm.startPrank(SPARK_EXECUTOR);

        foreignRateLimits.setUnlimitedRateLimitData(
            RateLimitHelpers.makeDomainKey(
                foreignController.LIMIT_USDC_TO_DOMAIN(),
                CCTPForwarder.DOMAIN_ID_CIRCLE_ARBITRUM_ONE
            )
        );

        foreignRateLimits.setUnlimitedRateLimitData(foreignController.LIMIT_USDC_TO_CCTP());

        vm.stopPrank();

        vm.prank(relayer);
        vm.expectRevert("ForeignController/domain-not-configured");
        foreignController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ARBITRUM_ONE);
    }

}

contract USDCToCCTPIntegrationTests is BaseChainUSDCToCCTPTestBase {

    using DomainHelpers     for *;
    using CCTPBridgeTesting for Bridge;

    event CCTPTransferInitiated(
        uint64  indexed nonce,
        uint32  indexed destinationDomain,
        bytes32 indexed mintRecipient,
        uint256 usdcAmount
    );

    event DepositForBurn(
        uint64  indexed nonce,
        address indexed burnToken,
        uint256 amount,
        address indexed depositor,
        bytes32 mintRecipient,
        uint32  destinationDomain,
        bytes32 destinationTokenMessenger,
        bytes32 destinationCaller
    );

    function test_transferUSDCToCCTP_sourceToDestination() external {
        deal(address(usdc), address(almProxy), 1e6);

        assertEq(usdc.balanceOf(address(almProxy)),          1e6);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.totalSupply(),                         USDC_SUPPLY);

        assertEq(usds.allowance(address(almProxy), CCTP_MESSENGER),  0);

        _expectEthereumCCTPEmit(146_783, 1e6);

        vm.prank(relayer);
        mainnetController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);

        assertEq(usdc.balanceOf(address(almProxy)),          0);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.totalSupply(),                         USDC_SUPPLY - 1e6);

        assertEq(usds.allowance(address(almProxy), CCTP_MESSENGER),  0);

        destination.selectFork();

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   0);
        assertEq(usdcBase.balanceOf(address(foreignController)), 0);
        assertEq(usdcBase.totalSupply(),                         USDC_BASE_SUPPLY);

        bridge.relayMessagesToDestination(true);

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   1e6);
        assertEq(usdcBase.balanceOf(address(foreignController)), 0);
        assertEq(usdcBase.totalSupply(),                         USDC_BASE_SUPPLY + 1e6);
    }

    function test_transferUSDCToCCTP_sourceToDestination_bigTransfer() external {
        deal(address(usdc), address(almProxy), 2_900_000e6);

        assertEq(usdc.balanceOf(address(almProxy)),          2_900_000e6);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.totalSupply(),                         USDC_SUPPLY);

        assertEq(usds.allowance(address(almProxy), CCTP_MESSENGER),  0);

        // Will split into 3 separate transactions at max 1m each
        _expectEthereumCCTPEmit(146_783, 1_000_000e6);
        _expectEthereumCCTPEmit(146_784, 1_000_000e6);
        _expectEthereumCCTPEmit(146_785, 900_000e6);

        vm.prank(relayer);
        mainnetController.transferUSDCToCCTP(2_900_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);

        assertEq(usdc.balanceOf(address(almProxy)),          0);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.totalSupply(),                         USDC_SUPPLY - 2_900_000e6);

        assertEq(usds.allowance(address(almProxy), CCTP_MESSENGER),  0);

        destination.selectFork();

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   0);
        assertEq(usdcBase.balanceOf(address(foreignController)), 0);
        assertEq(usdcBase.totalSupply(),                         USDC_BASE_SUPPLY);

        bridge.relayMessagesToDestination(true);

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   2_900_000e6);
        assertEq(usdcBase.balanceOf(address(foreignController)), 0);
        assertEq(usdcBase.totalSupply(),                         USDC_BASE_SUPPLY + 2_900_000e6);
    }

    function test_transferUSDCToCCTP_sourceToDestination_rateLimited() external {
        bytes32 cctpKey = mainnetController.LIMIT_USDC_TO_CCTP();

        bytes32 domainKey = RateLimitHelpers.makeDomainKey(
            mainnetController.LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE
        );

        deal(address(usdc), address(almProxy), 9_000_000e6);

        vm.startPrank(relayer);

        assertEq(usdc.balanceOf(address(almProxy)),         9_000_000e6);
        assertEq(rateLimits.getCurrentRateLimit(domainKey), 4_000_000e6);
        assertEq(rateLimits.getCurrentRateLimit(cctpKey),   type(uint256).max);

        mainnetController.transferUSDCToCCTP(2_000_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);

        assertEq(usdc.balanceOf(address(almProxy)),         7_000_000e6);
        assertEq(rateLimits.getCurrentRateLimit(domainKey), 2_000_000e6);
        assertEq(rateLimits.getCurrentRateLimit(cctpKey),   type(uint256).max);  // No change

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.transferUSDCToCCTP(2_000_000e6 + 1, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);

        mainnetController.transferUSDCToCCTP(2_000_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);

        assertEq(usdc.balanceOf(address(almProxy)),         5_000_000e6);
        assertEq(rateLimits.getCurrentRateLimit(domainKey), 0);
        assertEq(rateLimits.getCurrentRateLimit(cctpKey),   type(uint256).max);

        skip(4 hours);

        assertEq(usdc.balanceOf(address(almProxy)),         5_000_000e6);
        assertEq(rateLimits.getCurrentRateLimit(domainKey), 333_333.3312e6);
        assertEq(rateLimits.getCurrentRateLimit(cctpKey),   type(uint256).max);

        mainnetController.transferUSDCToCCTP(333_333.3312e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);

        assertEq(usdc.balanceOf(address(almProxy)),         4_666_666.6688e6);
        assertEq(rateLimits.getCurrentRateLimit(domainKey), 0);
        assertEq(rateLimits.getCurrentRateLimit(cctpKey),   type(uint256).max);

        vm.stopPrank();
    }

    function test_transferUSDCToCCTP_destinationToSource() external {
        destination.selectFork();

        deal(address(usdcBase), address(foreignAlmProxy), 1e6);

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   1e6);
        assertEq(usdcBase.balanceOf(address(foreignController)), 0);
        assertEq(usdcBase.totalSupply(),                         USDC_BASE_SUPPLY);

        assertEq(usdsBase.allowance(address(foreignAlmProxy), CCTP_MESSENGER_BASE),  0);

        _expectBaseCCTPEmit(354_554, 1e6);

        vm.prank(relayer);
        foreignController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   0);
        assertEq(usdcBase.balanceOf(address(foreignController)), 0);
        assertEq(usdcBase.totalSupply(),                         USDC_BASE_SUPPLY - 1e6);

        assertEq(usdsBase.allowance(address(foreignAlmProxy), CCTP_MESSENGER_BASE),  0);

        source.selectFork();

        assertEq(usdc.balanceOf(address(almProxy)),          0);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.totalSupply(),                         USDC_SUPPLY);

        bridge.relayMessagesToSource(true);

        assertEq(usdc.balanceOf(address(almProxy)),          1e6);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.totalSupply(),                         USDC_SUPPLY + 1e6);
    }

    function test_transferUSDCToCCTP_destinationToSource_bigTransfer() external {
        destination.selectFork();

        deal(address(usdcBase), address(foreignAlmProxy), 2_600_000e6);

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   2_600_000e6);
        assertEq(usdcBase.balanceOf(address(foreignController)), 0);
        assertEq(usdcBase.totalSupply(),                         USDC_BASE_SUPPLY);

        assertEq(usdsBase.allowance(address(foreignAlmProxy), CCTP_MESSENGER_BASE),  0);

        // Will split into three separate transactions at max 1m each
        _expectBaseCCTPEmit(354_554, 1_000_000e6);
        _expectBaseCCTPEmit(354_555, 1_000_000e6);
        _expectBaseCCTPEmit(354_556, 600_000e6);

        vm.prank(relayer);
        foreignController.transferUSDCToCCTP(2_600_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   0);
        assertEq(usdcBase.balanceOf(address(foreignController)), 0);
        assertEq(usdcBase.totalSupply(),                         USDC_BASE_SUPPLY - 2_600_000e6);

        assertEq(usdsBase.allowance(address(foreignAlmProxy), CCTP_MESSENGER_BASE),  0);

        source.selectFork();

        assertEq(usdc.balanceOf(address(almProxy)),          0);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.totalSupply(),                         USDC_SUPPLY);

        bridge.relayMessagesToSource(true);

        assertEq(usdc.balanceOf(address(almProxy)),          2_600_000e6);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.totalSupply(),                         USDC_SUPPLY + 2_600_000e6);
    }

    function test_transferUSDCToCCTP_destinationToSource_rateLimited() external {
        destination.selectFork();

        bytes32 cctpKey = foreignController.LIMIT_USDC_TO_CCTP();

        bytes32 domainKey = RateLimitHelpers.makeDomainKey(
            foreignController.LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM
        );

        deal(address(usdcBase), address(foreignAlmProxy), 9_000_000e6);

        vm.startPrank(relayer);

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),     9_000_000e6);
        assertEq(foreignRateLimits.getCurrentRateLimit(domainKey), 4_000_000e6);
        assertEq(foreignRateLimits.getCurrentRateLimit(cctpKey),   type(uint256).max);

        foreignController.transferUSDCToCCTP(2_000_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),     7_000_000e6);
        assertEq(foreignRateLimits.getCurrentRateLimit(domainKey), 2_000_000e6);
        assertEq(foreignRateLimits.getCurrentRateLimit(cctpKey),   type(uint256).max);  // No change

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        foreignController.transferUSDCToCCTP(2_000_000e6 + 1, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);

        foreignController.transferUSDCToCCTP(2_000_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),     5_000_000e6);
        assertEq(foreignRateLimits.getCurrentRateLimit(domainKey), 0);
        assertEq(foreignRateLimits.getCurrentRateLimit(cctpKey),   type(uint256).max);

        skip(4 hours);

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),     5_000_000e6);
        assertEq(foreignRateLimits.getCurrentRateLimit(domainKey), 333_333.3312e6);
        assertEq(foreignRateLimits.getCurrentRateLimit(cctpKey),   type(uint256).max);

        foreignController.transferUSDCToCCTP(333_333.3312e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),     4_666_666.6688e6);
        assertEq(foreignRateLimits.getCurrentRateLimit(domainKey), 0);
        assertEq(foreignRateLimits.getCurrentRateLimit(cctpKey),   type(uint256).max);

        vm.stopPrank();
    }

    function _expectEthereumCCTPEmit(uint64 nonce, uint256 amount) internal {
        // NOTE: Focusing on burnToken, amount, depositor, mintRecipient, and destinationDomain
        //       for assertions
        vm.expectEmit(CCTP_MESSENGER);
        emit DepositForBurn(
            nonce,
            address(usdc),
            amount,
            address(almProxy),
            mainnetController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            bytes32(0x0000000000000000000000001682ae6375c4e4a97e4b583bc394c861a46d8962),
            bytes32(0x0000000000000000000000000000000000000000000000000000000000000000)
        );

        vm.expectEmit(address(mainnetController));
        emit CCTPTransferInitiated(
            nonce,
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            mainnetController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
            amount
        );
    }

    function _expectBaseCCTPEmit(uint64 nonce, uint256 amount) internal {
        // NOTE: Focusing on burnToken, amount, depositor, mintRecipient, and destinationDomain
        //       for assertions
        vm.expectEmit(CCTP_MESSENGER_BASE);
        emit DepositForBurn(
            nonce,
            address(usdcBase),
            amount,
            address(foreignAlmProxy),
            foreignController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            bytes32(0x000000000000000000000000bd3fa81b58ba92a82136038b25adec7066af3155),
            bytes32(0x0000000000000000000000000000000000000000000000000000000000000000)
        );

        vm.expectEmit(address(foreignController));
        emit CCTPTransferInitiated(
            nonce,
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            foreignController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
            amount
        );
    }

}
