// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { ERC20Mock } from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

import { CCTPForwarder } from "xchain-helpers/src/forwarders/CCTPForwarder.sol";

import "test/base-fork/ForkTestBase.t.sol";

import { IRateLimits } from "src/interfaces/IRateLimits.sol";

import { ControllerInstance }      from "deploy/ControllerInstance.sol";
import { ForeignControllerDeploy } from "deploy/ControllerDeploy.sol";

import { ForeignControllerInit, MintRecipient } from "deploy/ControllerInit.sol";

import { RateLimitHelpers } from "src/RateLimitHelpers.sol";

// Necessary to get error message assertions to work
contract LibraryWrapper {

    function init(
        ForeignControllerInit.ConfigAddressParams memory configAddresses,
        ForeignControllerInit.AddressCheckParams  memory checkAddresses,
        ControllerInstance                        memory controllerInst,
        MintRecipient[]                           memory mintRecipients
    )
        external
    {
        ForeignControllerInit.init(configAddresses, checkAddresses, controllerInst, mintRecipients);
    }

}

contract ForeignControllerDeployAndInitTestBase is ForkTestBase {

    // Default params used for all testing, can be overridden where needed.
    function _getDefaultParams()
        internal returns (
            ForeignControllerInit.ConfigAddressParams memory configAddresses,
            ForeignControllerInit.AddressCheckParams  memory checkAddresses,
            MintRecipient[]                           memory mintRecipients
        )
    {
        configAddresses = ForeignControllerInit.ConfigAddressParams({
            admin         : Base.SPARK_EXECUTOR,
            freezer       : freezer,  // TODO: Use real freezer addresses
            relayer       : relayer,
            oldController : Base.ALM_CONTROLLER
        });

        checkAddresses = ForeignControllerInit.AddressCheckParams({
            psm           : Base.PSM3,
            cctpMessenger : Base.CCTP_TOKEN_MESSENGER,
            usdc          : Base.USDC,
            usds          : Base.USDS,
            susds         : Base.SUSDS
        });

        mintRecipients = new MintRecipient[](1);

        mintRecipients[0] = MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            mintRecipient : bytes32(uint256(uint160(Ethereum.ALM_PROXY)))
        });
    }

}

contract ForeignControllerDeployAndInitFailureTests is ForeignControllerDeployAndInitTestBase {

    LibraryWrapper wrapper;

    ControllerInstance public controllerInst;

    address public mismatchAddress = makeAddr("mismatchAddress");

    // Default parameters for success that are overridden for failure tests

    ForeignControllerInit.ConfigAddressParams configAddresses;
    ForeignControllerInit.AddressCheckParams  checkAddresses;
    MintRecipient[]                           mintRecipients;

    function setUp() public override {
        super.setUp();

        foreignController = ForeignController(ForeignControllerDeploy.deployController({
            admin      : Base.SPARK_EXECUTOR,
            almProxy   : Base.ALM_PROXY,
            rateLimits : Base.ALM_RATE_LIMITS,
            psm        : Base.PSM3,
            usdc       : Base.USDC,
            cctp       : Base.CCTP_TOKEN_MESSENGER
        }));

        almProxy   = ALMProxy(payable(Base.ALM_PROXY));
        rateLimits = RateLimits(Base.ALM_RATE_LIMITS);

        MintRecipient[] memory mintRecipients_ = new MintRecipient[](1);

        ( configAddresses, checkAddresses, mintRecipients_ ) = _getDefaultParams();

        // NOTE: This would need to be refactored to a for loop if more than one recipient
        mintRecipients.push(mintRecipients_[0]);

        controllerInst = ControllerInstance({
            almProxy   : Base.ALM_PROXY,
            controller : address(foreignController),
            rateLimits : Base.ALM_RATE_LIMITS
        });

        // Admin will be calling the library from its own address
        vm.etch(SPARK_EXECUTOR, address(new LibraryWrapper()).code);

        wrapper = LibraryWrapper(SPARK_EXECUTOR);
    }

    /**********************************************************************************************/
    /*** ACL failure modes                                                                      ***/
    /**********************************************************************************************/

    function test_init_incorrectAdminAlmProxy() external {
        // Isolate different contracts instead of setting param so can get three different failures
        vm.startPrank(SPARK_EXECUTOR);
        almProxy.grantRole(DEFAULT_ADMIN_ROLE, mismatchAddress);
        almProxy.revokeRole(DEFAULT_ADMIN_ROLE, SPARK_EXECUTOR);
        vm.stopPrank();

        vm.expectRevert("ForeignControllerInit/incorrect-admin-almProxy");
        wrapper.init(configAddresses, checkAddresses, controllerInst, mintRecipients);
    }

    function test_init_incorrectAdminRateLimits() external {
        // Isolate different contracts instead of setting param so can get three different failures
        vm.startPrank(SPARK_EXECUTOR);
        rateLimits.grantRole(DEFAULT_ADMIN_ROLE, mismatchAddress);
        rateLimits.revokeRole(DEFAULT_ADMIN_ROLE, SPARK_EXECUTOR);
        vm.stopPrank();

        vm.expectRevert("ForeignControllerInit/incorrect-admin-rateLimits");
        wrapper.init(configAddresses, checkAddresses, controllerInst, mintRecipients);
    }

    function test_init_incorrectAdminController() external {
        // Isolate different contracts instead of setting param so can get three different failures
        vm.startPrank(SPARK_EXECUTOR);
        foreignController.grantRole(DEFAULT_ADMIN_ROLE, mismatchAddress);
        foreignController.revokeRole(DEFAULT_ADMIN_ROLE, SPARK_EXECUTOR);
        vm.stopPrank();

        vm.expectRevert("ForeignControllerInit/incorrect-admin-controller");
        wrapper.init(configAddresses, checkAddresses, controllerInst, mintRecipients);
    }

    /**********************************************************************************************/
    /*** Controller constructor failure modes                                                   ***/
    /**********************************************************************************************/

    function test_init_incorrectAlmProxy() external {
        // Deploy new address that will not EVM revert on OZ ACL check
        controllerInst.almProxy = address(new ALMProxy(SPARK_EXECUTOR));

        vm.expectRevert("ForeignControllerInit/incorrect-almProxy");
        wrapper.init(configAddresses, checkAddresses, controllerInst, mintRecipients);
    }

    function test_init_incorrectRateLimits() external {
        // Deploy new address that will not EVM revert on OZ ACL check
        controllerInst.rateLimits = address(new RateLimits(SPARK_EXECUTOR));

        vm.expectRevert("ForeignControllerInit/incorrect-rateLimits");
        wrapper.init(configAddresses, checkAddresses, controllerInst, mintRecipients);
    }

    function test_init_incorrectPsm() external {
        checkAddresses.psm = mismatchAddress;

        vm.expectRevert("ForeignControllerInit/incorrect-psm");
        wrapper.init(configAddresses, checkAddresses, controllerInst, mintRecipients);
    }

    function test_init_incorrectUsdc() external {
        checkAddresses.usdc = mismatchAddress;

        vm.expectRevert("ForeignControllerInit/incorrect-usdc");
        wrapper.init(configAddresses, checkAddresses, controllerInst, mintRecipients);
    }

    function test_init_incorrectCctp() external {
        checkAddresses.cctpMessenger = mismatchAddress;

        vm.expectRevert("ForeignControllerInit/incorrect-cctp");
        wrapper.init(configAddresses, checkAddresses, controllerInst, mintRecipients);
    }

    function test_init_controllerInactive() external {
        // Cheating to set this outside of init scripts so that the controller can be frozen
        vm.prank(SPARK_EXECUTOR);
        foreignController.grantRole(FREEZER, freezer);

        vm.startPrank(freezer);
        foreignController.freeze();
        vm.stopPrank();

        vm.expectRevert("ForeignControllerInit/controller-not-active");
        wrapper.init(configAddresses, checkAddresses, controllerInst, mintRecipients);
    }

    /**********************************************************************************************/
    /*** Sanity check failure modes                                                             ***/
    /**********************************************************************************************/

    function test_init_oldControllerIsNewController() external {
        configAddresses.oldController = controllerInst.controller;

        vm.expectRevert("ForeignControllerInit/old-controller-is-new-controller");
        wrapper.init(configAddresses, checkAddresses, controllerInst, mintRecipients);
    }

    // TODO: Refactor this test, totalShares goes to zero after deposit
    // function test_init_totalAssetsNotSeededBoundary() external {
    //     _withdrawAllFunds(address(almProxy));
    //     _withdrawAllFunds(0x6F3066538A648b9CFad0679DF0a7e40882A23AA4);
    //     _withdrawAllFunds(address(0));

    //     assertEq(psmBase.totalAssets(), 1);  // Dust from withdrawals

    //     // address(this) holds funds
    //     usdsBase.approve(address(psmBase), 1e18);
    //     psmBase.deposit(address(usdsBase), address(this), 1e18 - 2);

    //     assertEq(psmBase.totalAssets(), 1e18 - 1);
    //     assertEq(psmBase.totalShares(), 1e18);

    //     vm.expectRevert("ForeignControllerInit/psm-totalAssets-not-seeded");
    //     wrapper.init(configAddresses, checkAddresses, controllerInst, mintRecipients);

    //     // Approve from address(this) cause it received the one wei
    //     // Redo the seeding
    //     usdsBase.approve(address(psmBase), 1);
    //     psmBase.deposit(address(usdsBase), address(0), 1);

    //     assertEq(psmBase.totalAssets(), 1e18);

    //     wrapper.init(configAddresses, checkAddresses, controllerInst, mintRecipients);
    // }

    function test_init_totalSharesNotSeededBoundary() external {
        // Remove one wei from PSM to make seeded condition not met
        vm.prank(address(0));
        psmBase.withdraw(address(usdsBase), address(this), 1);  // Withdraw one wei from PSM

        usdsBase.transfer(address(psmBase), 1);  // Transfer one wei to PSM to update totalAssets

        assertEq(psmBase.totalAssets(), 1e18);
        assertEq(psmBase.totalShares(), 1e18 - 1);

        vm.expectRevert("ForeignControllerInit/psm-totalShares-not-seeded");
        wrapper.init(configAddresses, checkAddresses, controllerInst, mintRecipients);

        // Do deposit to update shares, need to do 2 wei to get back to 1e18 because of rounding
        deal(address(usdsBase), address(this), 2);
        usdsBase.approve(address(psmBase), 2);
        psmBase.deposit(address(usdsBase), address(0), 2);

        assertEq(psmBase.totalAssets(), 1e18 + 2);
        assertEq(psmBase.totalShares(), 1e18);

        wrapper.init(configAddresses, checkAddresses, controllerInst, mintRecipients);
    }

    function test_init_incorrectPsmUsdc() external {
        ERC20Mock wrongUsdc = new ERC20Mock();

        deal(address(usdsBase), address(this), 1e18);  // For seeding PSM during deployment

        // Deploy a new PSM with the wrong USDC
        psmBase = IPSM3(PSM3Deploy.deploy(
            SPARK_EXECUTOR, address(wrongUsdc), address(usdsBase), address(susdsBase), SSR_ORACLE
        ));

        // Deploy a new controller pointing to misconfigured PSM
        controllerInst = ForeignControllerDeploy.deployFull(
            SPARK_EXECUTOR,
            address(psmBase),
            USDC_BASE,
            CCTP_MESSENGER_BASE
        );

        checkAddresses.psm = address(psmBase);  // Overwrite to point to misconfigured PSM

        vm.expectRevert("ForeignControllerInit/psm-incorrect-usdc");
        wrapper.init(configAddresses, checkAddresses, controllerInst, mintRecipients);
    }

    function test_init_incorrectPsmUsds() external {
        ERC20Mock wrongUsds = new ERC20Mock();

        deal(address(wrongUsds), address(this), 1e18);  // For seeding PSM during deployment

        // Deploy a new PSM with the wrong USDC
        psmBase = IPSM3(PSM3Deploy.deploy(
            SPARK_EXECUTOR, USDC_BASE, address(wrongUsds), address(susdsBase), SSR_ORACLE
        ));

        // Deploy a new controller pointing to misconfigured PSM
        controllerInst = ForeignControllerDeploy.deployFull(
            SPARK_EXECUTOR,
            address(psmBase),
            USDC_BASE,
            CCTP_MESSENGER_BASE
        );

        checkAddresses.psm = address(psmBase);  // Overwrite to point to misconfigured PSM

        vm.expectRevert("ForeignControllerInit/psm-incorrect-usds");
        wrapper.init(configAddresses, checkAddresses, controllerInst, mintRecipients);
    }

    function test_init_incorrectPsmSUsds() external {
        ERC20Mock wrongSUsds = new ERC20Mock();

        deal(address(usdsBase), address(this), 1e18);  // For seeding PSM during deployment

        // Deploy a new PSM with the wrong USDC
        psmBase = IPSM3(PSM3Deploy.deploy(
            SPARK_EXECUTOR, USDC_BASE, address(usdsBase), address(wrongSUsds), SSR_ORACLE
        ));

        // Deploy a new controller pointing to misconfigured PSM
        controllerInst = ForeignControllerDeploy.deployFull(
            SPARK_EXECUTOR,
            address(psmBase),
            USDC_BASE,
            CCTP_MESSENGER_BASE
        );

        checkAddresses.psm = address(psmBase);  // Overwrite to point to misconfigured PSM

        vm.expectRevert("ForeignControllerInit/psm-incorrect-susds");
        wrapper.init(configAddresses, checkAddresses, controllerInst, mintRecipients);
    }

    /**********************************************************************************************/
    /*** Old controller role check tests                                                        ***/
    /**********************************************************************************************/

    function test_init_oldControllerDoesNotHaveRoleInAlmProxy() external {
        _deployNewControllerAfterExistingControllerInit();

        // Revoke the old controller address in ALM proxy

        vm.startPrank(SPARK_EXECUTOR);
        almProxy.revokeRole(almProxy.CONTROLLER(), configAddresses.oldController);
        vm.stopPrank();

        // Try to init with the old controller address that is doesn't have the CONTROLLER role

        vm.expectRevert("ForeignControllerInit/old-controller-not-almProxy-controller");
        wrapper.init(configAddresses, checkAddresses, controllerInst, mintRecipients);
    }

    function test_init_oldControllerDoesNotHaveRoleInRateLimits() external {
        _deployNewControllerAfterExistingControllerInit();

        // Revoke the old controller address

        vm.startPrank(SPARK_EXECUTOR);
        rateLimits.revokeRole(rateLimits.CONTROLLER(), configAddresses.oldController);
        vm.stopPrank();

        // Try to init with the old controller address that is doesn't have the CONTROLLER role

        vm.expectRevert("ForeignControllerInit/old-controller-not-rateLimits-controller");
        wrapper.init(configAddresses, checkAddresses, controllerInst, mintRecipients);
    }

    /**********************************************************************************************/
    /*** Helper functions                                                                       ***/
    /**********************************************************************************************/

    function _deployNewControllerAfterExistingControllerInit() internal {
        // Successfully init first controller

        vm.startPrank(SPARK_EXECUTOR);
        ForeignControllerInit.init(
            configAddresses,
            checkAddresses,
            controllerInst,
            mintRecipients
        );
        vm.stopPrank();

        // Deploy a new controller (controllerInst is used in init with new controller address)

        controllerInst.controller = ForeignControllerDeploy.deployController(
            SPARK_EXECUTOR,
            controllerInst.almProxy,
            controllerInst.rateLimits,
            address(psmBase),
            USDC_BASE,
            CCTP_MESSENGER_BASE
        );

        configAddresses.oldController = address(foreignController);
    }

    function _withdrawAllFunds(address owner) internal {
        vm.startPrank(owner);
        psmBase.withdraw(address(usdcBase),  address(this), type(uint256).max);
        psmBase.withdraw(address(usdsBase),  address(this), type(uint256).max);
        psmBase.withdraw(address(susdsBase), address(this), type(uint256).max);
        vm.stopPrank();
    }

}

// contract ForeignControllerDeployAndInitSuccessTests is ForeignControllerDeployAndInitTestBase {

//     function test_deployAllAndInit() external {
//         // Perform new deployments against existing fork environment

//         ControllerInstance memory controllerInst = ForeignControllerDeploy.deployFull(
//             SPARK_EXECUTOR,
//             address(psmBase),
//             USDC_BASE,
//             CCTP_MESSENGER_BASE
//         );

//         // Overwrite storage for all previous deployments in setUp and assert deployment

//         almProxy          = ALMProxy(payable(controllerInst.almProxy));
//         foreignController = ForeignController(controllerInst.controller);
//         rateLimits        = RateLimits(controllerInst.rateLimits);

//         assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, SPARK_EXECUTOR),          true);
//         assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, SPARK_EXECUTOR),        true);
//         assertEq(foreignController.hasRole(DEFAULT_ADMIN_ROLE, SPARK_EXECUTOR), true);

//         assertEq(address(foreignController.proxy()),      controllerInst.almProxy);
//         assertEq(address(foreignController.rateLimits()), controllerInst.rateLimits);
//         assertEq(address(foreignController.psm()),        address(psmBase));
//         assertEq(address(foreignController.usdc()),       USDC_BASE);
//         assertEq(address(foreignController.cctp()),       CCTP_MESSENGER_BASE);

//         assertEq(foreignController.active(), true);

//         // Perform SubDAO initialization (from governance relay during spell)
//         // Setting rate limits to different values from setUp to make assertions more robust

//         (
//             ForeignControllerInit.AddressParams     memory addresses,
//             ForeignControllerInit.InitRateLimitData memory rateLimitData,
//             MintRecipient[]                         memory mintRecipients
//         ) = _getDefaultParams();

//         vm.startPrank(SPARK_EXECUTOR);
//         ForeignControllerInit.init(
//             addresses,
//             controllerInst,
//             rateLimitData,
//             mintRecipients
//         );
//         vm.stopPrank();

//         // Assert SubDAO initialization

//         assertEq(foreignController.hasRole(foreignController.FREEZER(), freezer), true);
//         assertEq(foreignController.hasRole(foreignController.RELAYER(), relayer), true);

//         assertEq(almProxy.hasRole(almProxy.CONTROLLER(), address(foreignController)), true);

//         assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(foreignController)), true);

//         bytes32 domainKeyEthereum = RateLimitHelpers.makeDomainKey(
//             foreignController.LIMIT_USDC_TO_DOMAIN(),
//             CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM
//         );

//         _assertDepositRateLimitData(usdcBase,  rateLimitData.usdcDepositData);
//         _assertDepositRateLimitData(usdsBase,  rateLimitData.usdsDepositData);
//         _assertDepositRateLimitData(susdsBase, rateLimitData.susdsDepositData);

//         _assertWithdrawRateLimitData(usdcBase,  rateLimitData.usdcWithdrawData);
//         _assertWithdrawRateLimitData(usdsBase,  rateLimitData.usdsWithdrawData);
//         _assertWithdrawRateLimitData(susdsBase, rateLimitData.susdsWithdrawData);

//         _assertRateLimitData(foreignController.LIMIT_USDC_TO_CCTP(), rateLimitData.usdcToCctpData);

//         _assertRateLimitData(domainKeyEthereum, rateLimitData.cctpToEthereumDomainData);

//         assertEq(
//             foreignController.mintRecipients(mintRecipients[0].domain),
//             mintRecipients[0].mintRecipient
//         );

//         assertEq(
//             foreignController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
//             bytes32(uint256(uint160(makeAddr("ethereumAlmProxy"))))
//         );
//     }

//     function test_init_transferAclToNewController() public {
//         ControllerInstance memory controllerInst = ForeignControllerDeploy.deployFull(
//             SPARK_EXECUTOR,
//             address(psmBase),
//             USDC_BASE,
//             CCTP_MESSENGER_BASE
//         );

//         (
//             ForeignControllerInit.AddressParams     memory addresses,
//             ForeignControllerInit.InitRateLimitData memory rateLimitData,
//             MintRecipient[]                         memory mintRecipients
//         ) = _getDefaultParams();

//         vm.startPrank(SPARK_EXECUTOR);
//         ForeignControllerInit.init(
//             addresses,
//             controllerInst,
//             rateLimitData,
//             mintRecipients
//         );
//         vm.stopPrank();

//         // Example of how an upgrade would work
//         address newController = ForeignControllerDeploy.deployController(
//             SPARK_EXECUTOR,
//             controllerInst.almProxy,
//             controllerInst.rateLimits,
//             address(psmBase),
//             USDC_BASE,
//             CCTP_MESSENGER_BASE
//         );

//         // Overwrite storage of previous deployments in setUp

//         almProxy   = ALMProxy(payable(controllerInst.almProxy));
//         rateLimits = RateLimits(controllerInst.rateLimits);

//         address oldController = address(controllerInst.controller);

//         controllerInst.controller = newController;  // Overwrite struct for param

//         // All other info is the same, just need to transfer ACL
//         addresses.oldController = oldController;

//         assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     oldController), true);
//         assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     oldController), true);
//         assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), newController), false);
//         assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), newController), false);

//         vm.startPrank(SPARK_EXECUTOR);
//         ForeignControllerInit.init(
//             addresses,
//             controllerInst,
//             rateLimitData,
//             mintRecipients
//         );
//         vm.stopPrank();

//         assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     oldController), false);
//         assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     oldController), false);
//         assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), newController), true);
//         assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), newController), true);
//     }

//     function _assertDepositRateLimitData(IERC20 asset, RateLimitData memory expectedData) internal {
//         bytes32 assetKey = RateLimitHelpers.makeAssetKey(
//             foreignController.LIMIT_PSM_DEPOSIT(),
//             address(asset)
//         );

//         _assertRateLimitData(assetKey, expectedData);
//     }

//     function _assertWithdrawRateLimitData(IERC20 asset, RateLimitData memory expectedData) internal {
//         bytes32 assetKey = RateLimitHelpers.makeAssetKey(
//             foreignController.LIMIT_PSM_WITHDRAW(),
//             address(asset)
//         );

//         _assertRateLimitData(assetKey, expectedData);
//     }

//     function _assertRateLimitData(bytes32 domainKey, RateLimitData memory expectedData) internal {
//         IRateLimits.RateLimitData memory data = rateLimits.getRateLimitData(domainKey);

//         assertEq(data.maxAmount,   expectedData.maxAmount);
//         assertEq(data.slope,       expectedData.slope);
//         assertEq(data.lastAmount,  expectedData.maxAmount);  // `lastAmount` should be `maxAmount`
//         assertEq(data.lastUpdated, block.timestamp);

//         assertEq(rateLimits.getCurrentRateLimit(domainKey), expectedData.maxAmount);
//     }

// }
