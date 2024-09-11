// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/mainnet-fork/ForkTestBase.t.sol";

import { IERC20 } from "lib/forge-std/src/interfaces/IERC20.sol";

import { ERC20Mock } from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

import { PSM3Deploy }       from "spark-psm/deploy/PSM3Deploy.sol";
import { IPSM3 }            from "spark-psm/src/PSM3.sol";
import { MockRateProvider } from "spark-psm/test/mocks/MockRateProvider.sol";

import { CCTPBridgeTesting } from "xchain-helpers/src/testing/bridges/CCTPBridgeTesting.sol";
import { CCTPForwarder }     from "xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { ALMProxy }          from "src/ALMProxy.sol";
import { ForeignController } from "src/ForeignController.sol";
import { RateLimitHelpers }  from "src/RateLimits.sol";

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

    function test_transferUSDCToCCTP_invalidMintRecipient() external {
        vm.prank(relayer);
        vm.expectRevert("MainnetController/domain-not-configured");
        mainnetController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ARBITRUM_ONE);
    }

}

// TODO: Figure out finalized structure for this repo/testing structure wise
contract BaseChainUSDCToCCTPTestBase is ForkTestBase {

    using DomainHelpers     for *;
    using CCTPBridgeTesting for Bridge;

    address admin = makeAddr("admin");

    /**********************************************************************************************/
    /*** Base addresses                                                                         ***/
    /**********************************************************************************************/

    address CCTP_MESSENGER_BASE = 0x1682Ae6375C4E4A97e4B583BC394c861A46D8962;
    address USDC_BASE           = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

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

        destination = getChain("base").createSelectFork(18181500);  // August 8, 2024

        usdsBase  = IERC20(address(new ERC20Mock()));
        susdsBase = IERC20(address(new ERC20Mock()));
        usdcBase  = IERC20(USDC_BASE);

        rateProvider = new MockRateProvider();

        rateProvider.__setConversionRate(1.25e27);

        deal(address(usdsBase), address(this), 1e18);  // For seeding PSM during deployment

        psmBase = IPSM3(PSM3Deploy.deploy(
            address(usdsBase), USDC_BASE, address(susdsBase), address(rateProvider)
        ));

        foreignAlmProxy = new ALMProxy(admin);

        foreignRateLimits = new RateLimits(admin);

        foreignController = new ForeignController({
            admin_      : admin,
            proxy_      : address(foreignAlmProxy),
            rateLimits_ : address(foreignRateLimits),
            psm_        : address(psmBase),
            usds_       : address(usdsBase),
            usdc_       : USDC_BASE,
            susds_      : address(susdsBase),
            cctp_       : CCTP_MESSENGER_BASE
        });

        // NOTE: FREEZER, RELAYER, and CONTROLLER are taken from super.setUp()

        vm.startPrank(admin);

        foreignController.grantRole(FREEZER, freezer);
        foreignController.grantRole(RELAYER, relayer);

        foreignController.setMintRecipient(
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            bytes32(uint256(uint160(address(almProxy))))
        );

        foreignAlmProxy.grantRole(CONTROLLER, address(foreignController));

        foreignRateLimits.grantRole(CONTROLLER, address(foreignController));

        // Setup unlimited rate limits
        foreignRateLimits.setUnlimitedRateLimit(foreignController.LIMIT_USDC_TO_CCTP());
        foreignRateLimits.setUnlimitedRateLimit(RateLimitHelpers.makeAssetKey(foreignController.LIMIT_PSM_DEPOSIT(),  address(usdcBase)));
        foreignRateLimits.setUnlimitedRateLimit(RateLimitHelpers.makeAssetKey(foreignController.LIMIT_PSM_DEPOSIT(),  address(usdsBase)));
        foreignRateLimits.setUnlimitedRateLimit(RateLimitHelpers.makeAssetKey(foreignController.LIMIT_PSM_DEPOSIT(),  address(susdsBase)));
        foreignRateLimits.setUnlimitedRateLimit(RateLimitHelpers.makeAssetKey(foreignController.LIMIT_PSM_WITHDRAW(), address(usdcBase)));
        foreignRateLimits.setUnlimitedRateLimit(RateLimitHelpers.makeAssetKey(foreignController.LIMIT_PSM_WITHDRAW(), address(usdsBase)));
        foreignRateLimits.setUnlimitedRateLimit(RateLimitHelpers.makeAssetKey(foreignController.LIMIT_PSM_WITHDRAW(), address(susdsBase)));

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

    function test_transferUSDCToCCTP_invalidMintRecipient() external {
        vm.prank(relayer);
        vm.expectRevert("ForeignController/domain-not-configured");
        foreignController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ARBITRUM_ONE);
    }

}

contract USDCToCCTPIntegrationTests is BaseChainUSDCToCCTPTestBase {

    using DomainHelpers     for *;
    using CCTPBridgeTesting for Bridge;

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

        // NOTE: Focusing on burnToken, amount, depositor, mintRecipient, and destinationDomain
        //       for assertions
        vm.expectEmit(CCTP_MESSENGER);
        emit DepositForBurn(
            94773,
            address(usdc),
            1e6,
            address(almProxy),
            mainnetController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            bytes32(0x0000000000000000000000001682ae6375c4e4a97e4b583bc394c861a46d8962),
            bytes32(0x0000000000000000000000000000000000000000000000000000000000000000)
        );

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
        deal(address(usdc), address(almProxy), 1_900_000e6);

        assertEq(usdc.balanceOf(address(almProxy)),          1_900_000e6);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.totalSupply(),                         USDC_SUPPLY);

        assertEq(usds.allowance(address(almProxy), CCTP_MESSENGER),  0);

        // Will split into two separate transactions at max 1m each
        vm.expectEmit(CCTP_MESSENGER);
        emit DepositForBurn(
            94773,
            address(usdc),
            1_000_000e6,
            address(almProxy),
            mainnetController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            bytes32(0x0000000000000000000000001682ae6375c4e4a97e4b583bc394c861a46d8962),
            bytes32(0x0000000000000000000000000000000000000000000000000000000000000000)
        );
        vm.expectEmit(CCTP_MESSENGER);
        emit DepositForBurn(
            94774,
            address(usdc),
            900_000e6,
            address(almProxy),
            mainnetController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            bytes32(0x0000000000000000000000001682ae6375c4e4a97e4b583bc394c861a46d8962),
            bytes32(0x0000000000000000000000000000000000000000000000000000000000000000)
        );

        vm.prank(relayer);
        mainnetController.transferUSDCToCCTP(1_900_000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);

        assertEq(usdc.balanceOf(address(almProxy)),          0);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.totalSupply(),                         USDC_SUPPLY - 1_900_000e6);

        assertEq(usds.allowance(address(almProxy), CCTP_MESSENGER),  0);

        destination.selectFork();

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   0);
        assertEq(usdcBase.balanceOf(address(foreignController)), 0);
        assertEq(usdcBase.totalSupply(),                         USDC_BASE_SUPPLY);

        bridge.relayMessagesToDestination(true);

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   1_900_000e6);
        assertEq(usdcBase.balanceOf(address(foreignController)), 0);
        assertEq(usdcBase.totalSupply(),                         USDC_BASE_SUPPLY + 1_900_000e6);
    }

    function test_transferUSDCToCCTP_destinationToSource() external {
        destination.selectFork();

        deal(address(usdcBase), address(foreignAlmProxy), 1e6);

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   1e6);
        assertEq(usdcBase.balanceOf(address(foreignController)), 0);
        assertEq(usdcBase.totalSupply(),                         USDC_BASE_SUPPLY);

        assertEq(usdsBase.allowance(address(foreignAlmProxy), CCTP_MESSENGER_BASE),  0);

        // NOTE: Focusing on burnToken, amount, depositor, mintRecipient, and destinationDomain
        //       for assertions
        vm.expectEmit(CCTP_MESSENGER_BASE);
        emit DepositForBurn(
            255141,
            address(usdcBase),
            1e6,
            address(foreignAlmProxy),
            foreignController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            bytes32(0x000000000000000000000000bd3fa81b58ba92a82136038b25adec7066af3155),
            bytes32(0x0000000000000000000000000000000000000000000000000000000000000000)
        );

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
        vm.expectEmit(CCTP_MESSENGER_BASE);
        emit DepositForBurn(
            255141,
            address(usdcBase),
            1_000_000e6,
            address(foreignAlmProxy),
            foreignController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            bytes32(0x000000000000000000000000bd3fa81b58ba92a82136038b25adec7066af3155),
            bytes32(0x0000000000000000000000000000000000000000000000000000000000000000)
        );
        vm.expectEmit(CCTP_MESSENGER_BASE);
        emit DepositForBurn(
            255142,
            address(usdcBase),
            1_000_000e6,
            address(foreignAlmProxy),
            foreignController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            bytes32(0x000000000000000000000000bd3fa81b58ba92a82136038b25adec7066af3155),
            bytes32(0x0000000000000000000000000000000000000000000000000000000000000000)
        );
        vm.expectEmit(CCTP_MESSENGER_BASE);
        emit DepositForBurn(
            255143,
            address(usdcBase),
            600_000e6,
            address(foreignAlmProxy),
            foreignController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            bytes32(0x000000000000000000000000bd3fa81b58ba92a82136038b25adec7066af3155),
            bytes32(0x0000000000000000000000000000000000000000000000000000000000000000)
        );

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

}
