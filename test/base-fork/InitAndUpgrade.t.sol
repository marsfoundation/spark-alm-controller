// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "../../test/base-fork/ForkTestBase.t.sol";

import { IRateLimits } from "../../src/interfaces/IRateLimits.sol";

import { ControllerInstance }      from "../../deploy/ControllerInstance.sol";
import { ForeignControllerDeploy } from "../../deploy/ControllerDeploy.sol";

import { ForeignControllerInit as Init } from "../../deploy/ForeignControllerInit.sol";

// Necessary to get error message assertions to work
contract LibraryWrapper {

    function initAlmSystem(
        ControllerInstance       memory controllerInst,
        Init.ConfigAddressParams memory configAddresses,
        Init.CheckAddressParams  memory checkAddresses,
        Init.MintRecipient[]     memory mintRecipients
    )
        external
    {
        Init.initAlmSystem(controllerInst, configAddresses, checkAddresses, mintRecipients);
    }

    function upgradeController(
        ControllerInstance       memory controllerInst,
        Init.ConfigAddressParams memory configAddresses,
        Init.CheckAddressParams  memory checkAddresses,
        Init.MintRecipient[]     memory mintRecipients
    )
        external
    {
        Init.upgradeController(controllerInst, configAddresses, checkAddresses, mintRecipients);
    }

}

contract ForeignControllerInitAndUpgradeTestBase is ForkTestBase {

    function _getDefaultParams()
        internal returns (
            Init.ConfigAddressParams memory configAddresses,
            Init.CheckAddressParams  memory checkAddresses,
            Init.MintRecipient[]     memory mintRecipients
        )
    {
        configAddresses = Init.ConfigAddressParams({
            freezer       : freezer,
            relayer       : relayer,
            oldController : address(0)
        });

        checkAddresses = Init.CheckAddressParams({
            admin : Base.SPARK_EXECUTOR,
            psm   : address(psmBase),
            cctp  : Base.CCTP_TOKEN_MESSENGER,
            usdc  : address(usdcBase),
            susds : address(susdsBase),
            usds  : address(usdsBase)
        });

        mintRecipients = new Init.MintRecipient[](1);

        mintRecipients[0] = Init.MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            mintRecipient : bytes32(uint256(uint160(makeAddr("mainnetAlmProxy"))))
        });
    }

}

contract ForeignControllerInitFailureTests is ForeignControllerInitAndUpgradeTestBase {

    LibraryWrapper wrapper;

    ControllerInstance public controllerInst;

    address public mismatchAddress = makeAddr("mismatchAddress");

    Init.ConfigAddressParams configAddresses;
    Init.CheckAddressParams  checkAddresses;
    Init.MintRecipient[]     mintRecipients;

    function setUp() public override {
        super.setUp();

        // Deploy new controller against live mainnet system
        // NOTE: initAlmSystem will redundantly call rely and approve on already inited 
        //       almProxy and rateLimits, this setup was chosen to easily test upgrade and init failures
        foreignController = ForeignController(ForeignControllerDeploy.deployController({
            admin      : Base.SPARK_EXECUTOR,
            almProxy   : address(almProxy),
            rateLimits : address(rateLimits),
            psm        : address(psmBase),
            usdc       : address(usdcBase),
            cctp       : Base.CCTP_TOKEN_MESSENGER
        }));

        Init.MintRecipient[] memory mintRecipients_ = new Init.MintRecipient[](1);

        ( configAddresses, checkAddresses, mintRecipients_ ) = _getDefaultParams();

        // NOTE: This would need to be refactored to a for loop if more than one recipient
        mintRecipients.push(mintRecipients_[0]);

        controllerInst = ControllerInstance({
            almProxy   : address(almProxy),
            controller : address(foreignController),
            rateLimits : address(rateLimits)
        });

        // Admin will be calling the library from its own address
        vm.etch(Base.SPARK_EXECUTOR, address(new LibraryWrapper()).code);

        wrapper = LibraryWrapper(Base.SPARK_EXECUTOR);
    }

    function _getBlock() internal pure override returns (uint256) {
        return 23900000;  // Dec 19, 2024
    }

    /**********************************************************************************************/
    /*** ACL tests                                                                              ***/
    /**********************************************************************************************/

    function test_init_incorrectAdminAlmProxy() external {
        // Isolate different contracts instead of setting param so can get three different failures
        vm.startPrank(Base.SPARK_EXECUTOR);
        almProxy.grantRole(DEFAULT_ADMIN_ROLE, mismatchAddress);
        almProxy.revokeRole(DEFAULT_ADMIN_ROLE, Base.SPARK_EXECUTOR);
        vm.stopPrank();

        vm.expectRevert("ForeignControllerInit/incorrect-admin-almProxy");
        wrapper.initAlmSystem(
            controllerInst,
            configAddresses,
            checkAddresses,
            mintRecipients
        );
    }

    function test_init_incorrectAdminRateLimits() external {
        // Isolate different contracts instead of setting param so can get three different failures
        vm.startPrank(Base.SPARK_EXECUTOR);
        rateLimits.grantRole(DEFAULT_ADMIN_ROLE, mismatchAddress);
        rateLimits.revokeRole(DEFAULT_ADMIN_ROLE, Base.SPARK_EXECUTOR);
        vm.stopPrank();

        vm.expectRevert("ForeignControllerInit/incorrect-admin-rateLimits");
        wrapper.initAlmSystem(
            controllerInst,
            configAddresses,
            checkAddresses,
            mintRecipients
        );
    }

    function test_init_incorrectAdminController() external {
        // Isolate different contracts instead of setting param so can get three different failures
        vm.startPrank(Base.SPARK_EXECUTOR);
        foreignController.grantRole(DEFAULT_ADMIN_ROLE, mismatchAddress);
        foreignController.revokeRole(DEFAULT_ADMIN_ROLE, Base.SPARK_EXECUTOR);
        vm.stopPrank();

        _checkInitAndUpgradeFail(abi.encodePacked("ForeignControllerInit/incorrect-admin-controller"));
    }

    /**********************************************************************************************/
    /*** Constructor tests                                                                      ***/
    /**********************************************************************************************/

    function test_init_incorrectAlmProxy() external {
        // Deploy new address that will not EVM revert on OZ ACL check
        controllerInst.almProxy = address(new ALMProxy(Base.SPARK_EXECUTOR));

        _checkInitAndUpgradeFail(abi.encodePacked("ForeignControllerInit/incorrect-almProxy"));
    }

    function test_init_incorrectRateLimits() external {
        // Deploy new address that will not EVM revert on OZ ACL check
        controllerInst.rateLimits = address(new RateLimits(Base.SPARK_EXECUTOR));

        _checkInitAndUpgradeFail(abi.encodePacked("ForeignControllerInit/incorrect-rateLimits"));
    }

    function test_init_incorrectPsm() external {
        checkAddresses.psm = mismatchAddress;
        _checkInitAndUpgradeFail(abi.encodePacked("ForeignControllerInit/incorrect-psm"));
    }

    function test_init_incorrectUsdc() external {
        checkAddresses.usdc = mismatchAddress;
        _checkInitAndUpgradeFail(abi.encodePacked("ForeignControllerInit/incorrect-usdc"));
    }

    function test_init_incorrectCctp() external {
        checkAddresses.cctp = mismatchAddress;
        _checkInitAndUpgradeFail(abi.encodePacked("ForeignControllerInit/incorrect-cctp"));
    }

    function test_init_controllerInactive() external {
        // Cheating to set this outside of init scripts so that the controller can be frozen
        vm.startPrank(Base.SPARK_EXECUTOR);
        foreignController.grantRole(FREEZER, freezer);

        vm.startPrank(freezer);
        foreignController.freeze();
        vm.stopPrank();

        _checkInitAndUpgradeFail(abi.encodePacked("ForeignControllerInit/controller-not-active"));
    }

    function test_init_oldControllerIsNewController() external {
        configAddresses.oldController = controllerInst.controller;
        _checkInitAndUpgradeFail(abi.encodePacked("ForeignControllerInit/old-controller-is-new-controller"));
    }

    /**********************************************************************************************/
    /*** PSM tests                                                                              ***/
    /**********************************************************************************************/

    function test_init_totalAssetsNotSeededBoundary() external {
        // Remove one wei from PSM to make seeded condition not met
        vm.prank(address(0));
        psmBase.withdraw(address(usdsBase), address(this), 1);  // Withdraw one wei from PSM

        assertEq(psmBase.totalAssets(), 1e18 - 1);

        // vm.expectRevert("ForeignControllerInit/psm-totalAssets-not-seeded");
        // wrapper.initAlmSystem(
        //     controllerInst,
        //     configAddresses,
        //     checkAddresses,
        //     mintRecipients
        // );

        _checkInitAndUpgradeFail(abi.encodePacked("ForeignControllerInit/psm-totalAssets-not-seeded"));

        // Approve from address(this) cause it received the one wei
        // Redo the seeding
        usdsBase.approve(address(psmBase), 1);
        psmBase.deposit(address(usdsBase), address(0), 1);

        assertEq(psmBase.totalAssets(), 1e18);

        wrapper.initAlmSystem(
            controllerInst,
            configAddresses,
            checkAddresses,
            mintRecipients
        );
    }

    function test_init_totalSharesNotSeededBoundary() external {
        // Remove one wei from PSM to make seeded condition not met
        vm.prank(address(0));
        psmBase.withdraw(address(usdsBase), address(this), 1);  // Withdraw one wei from PSM

        usdsBase.transfer(address(psmBase), 1);  // Transfer one wei to PSM to update totalAssets

        assertEq(psmBase.totalAssets(), 1e18);
        assertEq(psmBase.totalShares(), 1e18 - 1);

        vm.expectRevert("ForeignControllerInit/psm-totalShares-not-seeded");
        wrapper.initAlmSystem(
            controllerInst,
            configAddresses,
            checkAddresses,
            mintRecipients
        );

        // Do deposit to update shares, need to do 2 wei to get back to 1e18 because of rounding
        deal(address(usdsBase), address(this), 2);
        usdsBase.approve(address(psmBase), 2);
        psmBase.deposit(address(usdsBase), address(0), 2);

        assertEq(psmBase.totalAssets(), 1e18 + 2);
        assertEq(psmBase.totalShares(), 1e18);

        wrapper.initAlmSystem(
            controllerInst,
            configAddresses,
            checkAddresses,
            mintRecipients
        );
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
        wrapper.initAlmSystem(
            controllerInst,
            configAddresses,
            checkAddresses,
            mintRecipients
        );
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
        wrapper.initAlmSystem(
            controllerInst,
            configAddresses,
            checkAddresses,
            mintRecipients
        );
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
        wrapper.initAlmSystem(
            controllerInst,
            configAddresses,
            checkAddresses,
            mintRecipients
        );
    }

    /**********************************************************************************************/
    /*** Helper functions                                                                       ***/
    /**********************************************************************************************/

    function _checkInitAndUpgradeFail(bytes memory expectedError) internal {
        vm.expectRevert(expectedError);
        wrapper.initAlmSystem(
            controllerInst,
            configAddresses,
            checkAddresses,
            mintRecipients
        );

        vm.expectRevert(expectedError);
        wrapper.upgradeController(
            controllerInst,
            configAddresses,
            checkAddresses,
            mintRecipients
        );
    }

}

// contract ForeignControllerUpgradeFailureTests is ForeignControllerInitAndUpgradeTestBase {

//     LibraryWrapper wrapper;

//     ControllerInstance public controllerInst;

//     address public mismatchAddress = makeAddr("mismatchAddress");

//     Init.ConfigAddressParams configAddresses;
//     Init.CheckAddressParams  checkAddresses;
//     Init.MintRecipient[]     mintRecipients;

//     function setUp() public override {
//         super.setUp();

//         // Deploy new controller against live mainnet system
//         controllerInst.controller = ForeignControllerDeploy.deployController({
//             admin      : Base.Base.SPARK_EXECUTOR,
//             almProxy   : almProxy,
//             rateLimits : rateLimits,
//             vault      : Base.ALLOCATOR_VAULT,
//             psm        : Base.PSM,
//             daiUsds    : Base.DAI_USDS,
//             cctp       : Base.CCTP_TOKEN_MESSENGER
//         });

//         // Overwrite storage for all previous deployments in setUp and assert deployment
//         almProxy   = ALMProxy(payable(almProxy));
//         rateLimits = RateLimits(rateLimits);

//         controllerInst.almProxy   = address(almProxy);
//         controllerInst.rateLimits = address(rateLimits);

//         Init.MintRecipient[] memory mintRecipients_ = new Init.MintRecipient[](1);

//         ( configAddresses, checkAddresses, mintRecipients_ ) = _getDefaultParams();

//         mintRecipients.push(mintRecipients_[0]);

//         configAddresses.oldController = Base.ALM_CONTROLLER;

//         // Admin will be calling the library from its own address
//         vm.etch(Base.SPARK_EXECUTOR, address(new LibraryWrapper()).code);

//         wrapper = LibraryWrapper(Base.SPARK_EXECUTOR);
//     }

//     function _getBlock() internal pure override returns (uint256) {
//         return 21430000;  // Dec 18, 2024
//     }

//     function test_upgrade_oldControllerZeroAddress() external {
//         configAddresses.oldController = address(0);

//         vm.expectRevert("ForeignControllerInit/old-controller-zero-address");
//         wrapper.upgradeController(
//             controllerInst,
//             configAddresses,
//             checkAddresses,
//             mintRecipients
//         );
//     }

//     function test_upgrade_oldControllerDoesNotHaveRoleInAlmProxy() external {
//         // Revoke the old controller address in ALM proxy
//         vm.startPrank(Base.SPARK_EXECUTOR);
//         almProxy.revokeRole(almProxy.CONTROLLER(), configAddresses.oldController);
//         vm.stopPrank(); 

//         // Try to upgrade with the old controller address that is doesn't have the CONTROLLER role
//         vm.expectRevert("ForeignControllerInit/old-controller-not-almProxy-controller");
//         wrapper.upgradeController(
//             controllerInst,
//             configAddresses,
//             checkAddresses,
//             mintRecipients
//         );
//     }

//     function test_upgrade_oldControllerDoesNotHaveRoleInRateLimits() external {
//         // Revoke the old controller address in rate limits
//         vm.startPrank(Base.SPARK_EXECUTOR);
//         rateLimits.revokeRole(rateLimits.CONTROLLER(), configAddresses.oldController);
//         vm.stopPrank();

//         // Try to upgrade with the old controller address that is doesn't have the CONTROLLER role
//         vm.expectRevert("ForeignControllerInit/old-controller-not-rateLimits-controller");
//         wrapper.upgradeController(
//             controllerInst,
//             configAddresses,
//             checkAddresses,
//             mintRecipients
//         );
//     }

// }

// contract ForeignControllerInitAlmSystemSuccessTests is ForeignControllerInitAndUpgradeTestBase {

//     LibraryWrapper wrapper;

//     ControllerInstance public controllerInst;

//     address public mismatchAddress = makeAddr("mismatchAddress");

//     Init.ConfigAddressParams configAddresses;
//     Init.CheckAddressParams  checkAddresses;
//     Init.MintRecipient[]     mintRecipients;

//     function setUp() public override {
//         super.setUp();

//         controllerInst = ForeignControllerDeploy.deployFull(
//             Base.Base.SPARK_EXECUTOR,
//             Base.ALLOCATOR_VAULT,
//             Base.PSM,
//             Base.DAI_USDS,
//             Base.CCTP_TOKEN_MESSENGER
//         );

//         // Overwrite storage for all previous deployments in setUp and assert brand new deployment
//         foreignController = ForeignController(controllerInst.controller);
//         almProxy          = ALMProxy(payable(controllerInst.almProxy));
//         rateLimits        = RateLimits(controllerInst.rateLimits);
//         vault             = Base.ALLOCATOR_VAULT;  // Use mainnet vault
//         buffer            = Base.ALLOCATOR_BUFFER; // Use mainnet buffer

//         Init.MintRecipient[] memory mintRecipients_ = new Init.MintRecipient[](1);

//         ( configAddresses, checkAddresses, mintRecipients_ ) = _getDefaultParams();

//         mintRecipients.push(mintRecipients_[0]);

//         // Admin will be calling the library from its own address
//         vm.etch(Base.SPARK_EXECUTOR, address(new LibraryWrapper()).code);

//         wrapper = LibraryWrapper(Base.SPARK_EXECUTOR);
//     }

//     function _getBlock() internal pure override returns (uint256) {
//         return 21430000;  // Dec 18, 2024
//     }

//     function test_initAlmSystem() public {
//         assertEq(foreignController.hasRole(foreignController.FREEZER(), freezer), false);
//         assertEq(foreignController.hasRole(foreignController.RELAYER(), relayer), false);

//         assertEq(almProxy.hasRole(almProxy.CONTROLLER(), address(foreignController)),     false);
//         assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(foreignController)), false);

//         assertEq(foreignController.mintRecipients(mintRecipients[0].domain),            bytes32(0));
//         assertEq(foreignController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE), bytes32(0));

//         assertEq(IVaultLike(vault).wards(controllerInst.almProxy), 0);
//         assertEq(usds.allowance(buffer, controllerInst.almProxy),  0);

//         vm.startPrank(Base.SPARK_EXECUTOR);
//         wrapper.initAlmSystem(
//             Base.ALLOCATOR_VAULT,
//             usdsBase,
//             controllerInst,
//             configAddresses,
//             checkAddresses,
//             mintRecipients
//         );

//         assertEq(foreignController.hasRole(foreignController.FREEZER(), freezer), true);
//         assertEq(foreignController.hasRole(foreignController.RELAYER(), relayer), true);

//         assertEq(almProxy.hasRole(almProxy.CONTROLLER(), address(foreignController)),     true);
//         assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(foreignController)), true);

//         assertEq(
//             foreignController.mintRecipients(mintRecipients[0].domain),
//             mintRecipients[0].mintRecipient
//         );

//         assertEq(
//             foreignController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
//             bytes32(uint256(uint160(makeAddr("baseAlmProxy"))))
//         );

//         assertEq(IVaultLike(vault).wards(controllerInst.almProxy), 1);
//         assertEq(usds.allowance(buffer, controllerInst.almProxy),  type(uint256).max);
//     }

//     function test_pauseProxyInitAlmSystem() public {
//         // Update to call the library from the pause proxy
//         vm.etch(PAUSE_PROXY, address(new LibraryWrapper()).code);
//         wrapper = LibraryWrapper(PAUSE_PROXY);

//         assertEq(IPSMLike(Base.PSM).bud(controllerInst.almProxy), 0);

//         vm.startPrank(PAUSE_PROXY);
//         wrapper.pauseProxyInitAlmSystem(Base.PSM, controllerInst.almProxy);
//         vm.stopPrank();

//         assertEq(IPSMLike(Base.PSM).bud(controllerInst.almProxy), 1);
//     }

// }

// contract ForeignControllerUpgradeControllerSuccessTests is ForeignControllerInitAndUpgradeTestBase {

//     LibraryWrapper wrapper;

//     ControllerInstance public controllerInst;

//     address public mismatchAddress = makeAddr("mismatchAddress");

//     Init.ConfigAddressParams configAddresses;
//     Init.CheckAddressParams  checkAddresses;
//     Init.MintRecipient[]     mintRecipients;

//     ForeignController newController;

//     function setUp() public override {
//         super.setUp();

//         // Upgrade against mainnet contracts
//         controllerInst = ControllerInstance({
//             almProxy   : almProxy,
//             controller : Base.ALM_CONTROLLER,
//             rateLimits : rateLimits
//         });

//         // Overwrite storage for all previous deployments in setUp and assert brand new deployment
//         foreignController = ForeignController(controllerInst.controller);
//         almProxy          = ALMProxy(payable(controllerInst.almProxy));
//         rateLimits        = RateLimits(controllerInst.rateLimits);
//         vault             = Base.ALLOCATOR_VAULT;  // Use mainnet vault
//         buffer            = Base.ALLOCATOR_BUFFER; // Use mainnet buffer

//         Init.MintRecipient[] memory mintRecipients_ = new Init.MintRecipient[](1);

//         ( configAddresses, checkAddresses, mintRecipients_ ) = _getDefaultParams();

//         mintRecipients.push(mintRecipients_[0]);

//         newController = ForeignController(ForeignControllerDeploy.deployController({
//             admin      : Base.Base.SPARK_EXECUTOR,
//             almProxy   : almProxy,
//             rateLimits : rateLimits,
//             vault      : Base.ALLOCATOR_VAULT,
//             psm        : Base.PSM,
//             daiUsds    : Base.DAI_USDS,
//             cctp       : Base.CCTP_TOKEN_MESSENGER
//         }));

//         controllerInst.controller     = address(newController);   // Upgrade to new controller
//         configAddresses.oldController = Base.ALM_CONTROLLER;  // Revoke from old controller

//         // Admin will be calling the library from its own address
//         vm.etch(Base.SPARK_EXECUTOR, address(new LibraryWrapper()).code);

//         wrapper = LibraryWrapper(Base.SPARK_EXECUTOR);
//     }

//     function _getBlock() internal pure override returns (uint256) {
//         return 21430000;  // Dec 18, 2024
//     }

//     function test_upgradeController() public {
//         assertEq(newController.hasRole(newController.FREEZER(), freezer), false);
//         assertEq(newController.hasRole(newController.RELAYER(), relayer), false);

//         assertEq(almProxy.hasRole(almProxy.CONTROLLER(), address(foreignController)),     true);
//         assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(foreignController)), true);

//         assertEq(almProxy.hasRole(almProxy.CONTROLLER(), address(newController)),     false);
//         assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(newController)), false);

//         assertEq(newController.mintRecipients(mintRecipients[0].domain),            bytes32(0));
//         assertEq(newController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE), bytes32(0));

//         vm.startPrank(Base.SPARK_EXECUTOR);
//         wrapper.upgradeController(
//             controllerInst,
//             configAddresses,
//             checkAddresses,
//             mintRecipients
//         );

//         assertEq(newController.hasRole(newController.FREEZER(), freezer), true);
//         assertEq(newController.hasRole(newController.RELAYER(), relayer), true);

//         assertEq(almProxy.hasRole(almProxy.CONTROLLER(), address(foreignController)),     false);
//         assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(foreignController)), false);

//         assertEq(almProxy.hasRole(almProxy.CONTROLLER(), address(newController)),     true);
//         assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(newController)), true);

//         assertEq(
//             newController.mintRecipients(mintRecipients[0].domain),
//             mintRecipients[0].mintRecipient
//         );

//         assertEq(
//             newController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
//             bytes32(uint256(uint160(makeAddr("baseAlmProxy"))))
//         );
//     }

// }