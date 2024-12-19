// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/mainnet-fork/ForkTestBase.t.sol";

import { IRateLimits } from "src/interfaces/IRateLimits.sol";

import { ControllerInstance }      from "../../deploy/ControllerInstance.sol";
import { MainnetControllerDeploy } from "../../deploy/ControllerDeploy.sol";

import { MainnetControllerInit as Init } from "../../deploy/MainnetControllerInit.sol";

// Necessary to get error message assertions to work
contract LibraryWrapper {

    function initAlmSystem(
        address vault, 
        address usds,
        ControllerInstance       memory controllerInst,
        Init.ConfigAddressParams memory configAddresses,
        Init.CheckAddressParams  memory checkAddresses,
        Init.MintRecipient[]     memory mintRecipients
    )
        external
    {
        Init.initAlmSystem(vault, usds, controllerInst, configAddresses, checkAddresses, mintRecipients);
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

contract MainnetControllerInitAndUpgradeTestBase is ForkTestBase {

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
            admin      : Ethereum.SPARK_PROXY,
            proxy      : Ethereum.ALM_PROXY,
            rateLimits : Ethereum.ALM_RATE_LIMITS,
            vault      : Ethereum.ALLOCATOR_VAULT,
            psm        : Ethereum.PSM,
            daiUsds    : Ethereum.DAI_USDS,
            cctp       : Ethereum.CCTP_TOKEN_MESSENGER
        });

        mintRecipients = new Init.MintRecipient[](1);

        mintRecipients[0] = Init.MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            mintRecipient : bytes32(uint256(uint160(makeAddr("baseAlmProxy"))))
        });
    }

}

contract MainnetControllerInitFailureTests is MainnetControllerInitAndUpgradeTestBase {

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
        mainnetController = MainnetController(MainnetControllerDeploy.deployController({
            admin      : Ethereum.SPARK_PROXY,
            almProxy   : Ethereum.ALM_PROXY,
            rateLimits : Ethereum.ALM_RATE_LIMITS,
            vault      : Ethereum.ALLOCATOR_VAULT,
            psm        : Ethereum.PSM,
            daiUsds    : Ethereum.DAI_USDS,
            cctp       : Ethereum.CCTP_TOKEN_MESSENGER
        }));

        almProxy   = ALMProxy(payable(Ethereum.ALM_PROXY));
        rateLimits = RateLimits(Ethereum.ALM_RATE_LIMITS);

        Init.MintRecipient[] memory mintRecipients_ = new Init.MintRecipient[](1);

        ( configAddresses, checkAddresses, mintRecipients_ ) = _getDefaultParams();

        // NOTE: This would need to be refactored to a for loop if more than one recipient
        mintRecipients.push(mintRecipients_[0]);

        controllerInst = ControllerInstance({
            almProxy   : Ethereum.ALM_PROXY,
            controller : address(mainnetController),
            rateLimits : Ethereum.ALM_RATE_LIMITS
        });

        // Admin will be calling the library from its own address
        vm.etch(SPARK_PROXY, address(new LibraryWrapper()).code);

        wrapper = LibraryWrapper(SPARK_PROXY);
    }

    function _getBlock() internal pure override returns (uint256) {
        return 21430000;  // Dec 18, 2024
    }

    /**********************************************************************************************/
    /*** ACL tests                                                                              ***/
    /**********************************************************************************************/

    function test_init_incorrectAdminAlmProxy() external {
        // Isolate different contracts instead of setting param so can get three different failures
        vm.startPrank(SPARK_PROXY);
        almProxy.grantRole(DEFAULT_ADMIN_ROLE, mismatchAddress);
        almProxy.revokeRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY);
        vm.stopPrank();

        vm.expectRevert("MainnetControllerInit/incorrect-admin-almProxy");
        wrapper.initAlmSystem(
            vault,
            address(usds),
            controllerInst,
            configAddresses,
            checkAddresses,
            mintRecipients
        );
    }

    function test_init_incorrectAdminRateLimits() external {
        // Isolate different contracts instead of setting param so can get three different failures
        vm.startPrank(SPARK_PROXY);
        rateLimits.grantRole(DEFAULT_ADMIN_ROLE, mismatchAddress);
        rateLimits.revokeRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY);
        vm.stopPrank();

        vm.expectRevert("MainnetControllerInit/incorrect-admin-rateLimits");
        wrapper.initAlmSystem(
            vault,
            address(usds),
            controllerInst,
            configAddresses,
            checkAddresses,
            mintRecipients
        );
    }

    function test_init_incorrectAdminController() external {
        // Isolate different contracts instead of setting param so can get three different failures
        vm.startPrank(SPARK_PROXY);
        mainnetController.grantRole(DEFAULT_ADMIN_ROLE, mismatchAddress);
        mainnetController.revokeRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY);
        vm.stopPrank();

        _checkInitAndUpgradeFail(abi.encodePacked("MainnetControllerInit/incorrect-admin-controller"));
    }

    /**********************************************************************************************/
    /*** Constructor tests                                                                      ***/
    /**********************************************************************************************/

    function test_init_incorrectAlmProxy() external {
        // Deploy new address that will not EVM revert on OZ ACL check
        controllerInst.almProxy = address(new ALMProxy(SPARK_PROXY));

        _checkInitAndUpgradeFail(abi.encodePacked("MainnetControllerInit/incorrect-almProxy"));
    }

    function test_init_incorrectRateLimits() external {
        // Deploy new address that will not EVM revert on OZ ACL check
        controllerInst.rateLimits = address(new RateLimits(SPARK_PROXY));

        _checkInitAndUpgradeFail(abi.encodePacked("MainnetControllerInit/incorrect-rateLimits"));
    }

    function test_init_incorrectVault() external {
        checkAddresses.vault = mismatchAddress;
        _checkInitAndUpgradeFail(abi.encodePacked("MainnetControllerInit/incorrect-vault"));
    }

    function test_init_incorrectPsm() external {
        checkAddresses.psm = mismatchAddress;
        _checkInitAndUpgradeFail(abi.encodePacked("MainnetControllerInit/incorrect-psm"));
    }

    function test_init_incorrectDaiUsds() external {
        checkAddresses.daiUsds = mismatchAddress;
        _checkInitAndUpgradeFail(abi.encodePacked("MainnetControllerInit/incorrect-daiUsds"));
    }

    function test_init_incorrectCctp() external {
        checkAddresses.cctp = mismatchAddress;
        _checkInitAndUpgradeFail(abi.encodePacked("MainnetControllerInit/incorrect-cctp"));
    }

    function test_init_controllerInactive() external {
        // Cheating to set this outside of init scripts so that the controller can be frozen
        vm.startPrank(SPARK_PROXY);
        mainnetController.grantRole(FREEZER, freezer);

        vm.startPrank(freezer);
        mainnetController.freeze();
        vm.stopPrank();

        _checkInitAndUpgradeFail(abi.encodePacked("MainnetControllerInit/controller-not-active"));
    }

    function test_init_oldControllerIsNewController() external {
        configAddresses.oldController = controllerInst.controller;
        _checkInitAndUpgradeFail(abi.encodePacked("MainnetControllerInit/old-controller-is-new-controller"));
    }

    function test_init_vaultMismatch() external {
        vault = mismatchAddress;
        
        vm.expectRevert("MainnetControllerInit/incorrect-vault");
        wrapper.initAlmSystem(
            vault,
            address(usds),
            controllerInst,
            configAddresses,
            checkAddresses,
            mintRecipients
        );
    }

    function _checkInitAndUpgradeFail(bytes memory expectedError) internal {
        vm.expectRevert(expectedError);
        wrapper.initAlmSystem(
            vault,
            address(usds),
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

contract MainnetControllerUpgradeFailureTests is MainnetControllerInitAndUpgradeTestBase {

    LibraryWrapper wrapper;

    ControllerInstance public controllerInst;

    address public mismatchAddress = makeAddr("mismatchAddress");

    Init.ConfigAddressParams configAddresses;
    Init.CheckAddressParams  checkAddresses;
    Init.MintRecipient[]     mintRecipients;

    function setUp() public override {
        super.setUp();

        // Deploy new controller against live mainnet system
        controllerInst.controller = MainnetControllerDeploy.deployController({
            admin      : Ethereum.SPARK_PROXY,
            almProxy   : Ethereum.ALM_PROXY,
            rateLimits : Ethereum.ALM_RATE_LIMITS,
            vault      : Ethereum.ALLOCATOR_VAULT,
            psm        : Ethereum.PSM,
            daiUsds    : Ethereum.DAI_USDS,
            cctp       : Ethereum.CCTP_TOKEN_MESSENGER
        });

        // Overwrite storage for all previous deployments in setUp and assert deployment
        almProxy   = ALMProxy(payable(Ethereum.ALM_PROXY));
        rateLimits = RateLimits(Ethereum.ALM_RATE_LIMITS);

        controllerInst.almProxy   = address(almProxy);
        controllerInst.rateLimits = address(rateLimits);

        Init.MintRecipient[] memory mintRecipients_ = new Init.MintRecipient[](1);

        ( configAddresses, checkAddresses, mintRecipients_ ) = _getDefaultParams();

        mintRecipients.push(mintRecipients_[0]);

        configAddresses.oldController = Ethereum.ALM_CONTROLLER;

        // Admin will be calling the library from its own address
        vm.etch(SPARK_PROXY, address(new LibraryWrapper()).code);

        wrapper = LibraryWrapper(SPARK_PROXY);
    }

    function _getBlock() internal pure override returns (uint256) {
        return 21430000;  // Dec 18, 2024
    }

    /**********************************************************************************************/
    /*** Old controller role check tests                                                        ***/
    /**********************************************************************************************/

    function test_upgrade_oldControllerZeroAddress() external {
        configAddresses.oldController = address(0);

        vm.expectRevert("MainnetControllerInit/old-controller-zero-address");
        wrapper.upgradeController(
            controllerInst,
            configAddresses,
            checkAddresses,
            mintRecipients
        );
    }

    function test_upgrade_oldControllerDoesNotHaveRoleInAlmProxy() external {
        // Revoke the old controller address in ALM proxy
        vm.startPrank(SPARK_PROXY);
        almProxy.revokeRole(almProxy.CONTROLLER(), configAddresses.oldController);
        vm.stopPrank(); 

        // Try to upgrade with the old controller address that is doesn't have the CONTROLLER role
        vm.expectRevert("MainnetControllerInit/old-controller-not-almProxy-controller");
        wrapper.upgradeController(
            controllerInst,
            configAddresses,
            checkAddresses,
            mintRecipients
        );
    }

    function test_upgrade_oldControllerDoesNotHaveRoleInRateLimits() external {
        // Revoke the old controller address in rate limits
        vm.startPrank(SPARK_PROXY);
        rateLimits.revokeRole(rateLimits.CONTROLLER(), configAddresses.oldController);
        vm.stopPrank();

        // Try to upgrade with the old controller address that is doesn't have the CONTROLLER role
        vm.expectRevert("MainnetControllerInit/old-controller-not-rateLimits-controller");
        wrapper.upgradeController(
            controllerInst,
            configAddresses,
            checkAddresses,
            mintRecipients
        );
    }

}

//     // Added this function to ensure that all the failure modes from `subDaoInitController`
//     // are also covered by `subDaoInitFull` calls
//     function _checkInitAndUpgradeFail(bytes memory expectedError) internal {
//         vm.expectRevert(expectedError);
//         wrapper.initAlmSystem(
//             vault,
//             address(usds),
//             controllerInst,
//             configAddresses,
//             checkAddresses,
//             mintRecipients
//         );

//         vm.expectRevert(expectedError);
//         wrapper.upgradeController(
//             controllerInst,
//             configAddresses,
//             checkAddresses,
//             mintRecipients
//         );
//     }

//     // function _checkInitAndUpgradeSucceed() internal {
//     //     wrapper.subDaoInitController(
//     //         configAddresses,
//     //         checkAddresses,
//     //         controllerInst,
//     //         mintRecipients
//     //     );

//     //     wrapper.subDaoInitFull(
//     //         configAddresses,
//     //         checkAddresses,
//     //         controllerInst,
//     //         mintRecipients
//     //     );
//     // }
// }

// contract MainnetControllerDeployAndInitSuccessTests is MainnetControllerDeployInitTestBase {

//     function test_deployAllAndInitFull() external {
//         // Perform new deployments against existing fork environment

//         ControllerInstance memory controllerInst = MainnetControllerDeploy.deployFull(
//             SPARK_PROXY,
//             vault,
//             PSM,
//             DAI_USDS,
//             CCTP_MESSENGER,
//             address(susds)
//         );

//         // Overwrite storage for all previous deployments in setUp and assert deployment

//         almProxy          = ALMProxy(payable(controllerInst.almProxy));
//         mainnetController = MainnetController(controllerInst.controller);
//         rateLimits        = RateLimits(controllerInst.rateLimits);

//         assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY),          true);
//         assertEq(mainnetController.hasRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY), true);
//         assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY),        true);

//         assertEq(address(mainnetController.proxy()),      controllerInst.almProxy);
//         assertEq(address(mainnetController.rateLimits()), controllerInst.rateLimits);
//         assertEq(address(mainnetController.vault()),      vault);
//         assertEq(address(mainnetController.buffer()),     buffer);
//         assertEq(address(mainnetController.psm()),        PSM);
//         assertEq(address(mainnetController.daiUsds()),    DAI_USDS);
//         assertEq(address(mainnetController.cctp()),       CCTP_MESSENGER);
//         assertEq(address(mainnetController.susds()),      address(susds));
//         assertEq(address(mainnetController.dai()),        address(dai));
//         assertEq(address(mainnetController.usdc()),       address(usdc));
//         assertEq(address(mainnetController.usds()),       address(usds));

//         assertEq(mainnetController.psmTo18ConversionFactor(), 1e12);
//         assertEq(mainnetController.active(),                  true);

//         // Perform SubDAO initialization (from SPARK_PROXY during spell)
//         // Setting rate limits to different values from setUp to make assertions more robust

//         (
//             Init.ConfigAddressParams memory configAddresses,
//             Init.CheckAddressParams  memory checkAddresses,
//             MintRecipient[]                           memory mintRecipients
//         ) = _getDefaultParams();

//         vm.startPrank(SPARK_PROXY);
//         Init.subDaoInitFull(
//             configAddresses,
//             checkAddresses,
//             controllerInst,
//             mintRecipients
//         );
//         vm.stopPrank();

//         // Assert SubDAO initialization

//         assertEq(mainnetController.hasRole(mainnetController.FREEZER(), freezer), true);
//         assertEq(mainnetController.hasRole(mainnetController.RELAYER(), relayer), true);

//         assertEq(almProxy.hasRole(almProxy.CONTROLLER(), address(mainnetController)), true);

//         assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(mainnetController)), true);

//         assertEq(
//             mainnetController.mintRecipients(mintRecipients[0].domain),
//             mintRecipients[0].mintRecipient
//         );

//         assertEq(
//             mainnetController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
//             bytes32(uint256(uint160(makeAddr("baseAlmProxy"))))
//         );

//         assertEq(IVaultLike(vault).wards(controllerInst.almProxy), 1);

//         assertEq(usds.allowance(buffer, controllerInst.almProxy), type(uint256).max);

//         // Perform Maker initialization (from PAUSE_PROXY during spell)

//         vm.startPrank(PAUSE_PROXY);
//         Init.pauseProxyInit(PSM, controllerInst.almProxy);
//         vm.stopPrank();

//         // Assert Maker initialization

//         assertEq(IPSMLike(PSM).bud(controllerInst.almProxy), 1);
//     }

//     function test_deployAllAndInitController() external {
//         // Perform new deployments against existing fork environment

//         ControllerInstance memory controllerInst = MainnetControllerDeploy.deployFull(
//             SPARK_PROXY,
//             vault,
//             PSM,
//             DAI_USDS,
//             CCTP_MESSENGER,
//             address(susds)
//         );

//         // Overwrite storage for all previous deployments in setUp and assert deployment

//         almProxy          = ALMProxy(payable(controllerInst.almProxy));
//         mainnetController = MainnetController(controllerInst.controller);
//         rateLimits        = RateLimits(controllerInst.rateLimits);

//         (
//             Init.ConfigAddressParams memory configAddresses,
//             Init.CheckAddressParams  memory checkAddresses,
//             MintRecipient[]                           memory mintRecipients
//         ) = _getDefaultParams();

//         // Perform ONLY controller initialization, setting rate limits and updating ACL
//         // Setting rate limits to different values from setUp to make assertions more robust

//         vm.startPrank(SPARK_PROXY);
//         Init.subDaoInitController(
//             configAddresses,
//             checkAddresses,
//             controllerInst,
//             mintRecipients
//         );
//         vm.stopPrank();

//         assertEq(mainnetController.hasRole(mainnetController.FREEZER(), freezer), true);
//         assertEq(mainnetController.hasRole(mainnetController.RELAYER(), relayer), true);

//         assertEq(almProxy.hasRole(almProxy.CONTROLLER(), address(mainnetController)), true);

//         assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(mainnetController)), true);

//         assertEq(
//             mainnetController.mintRecipients(mintRecipients[0].domain),
//             mintRecipients[0].mintRecipient
//         );

//         assertEq(
//             mainnetController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
//             bytes32(uint256(uint160(makeAddr("baseAlmProxy"))))
//         );
//     }

//     function test_init_transferAclToNewController_Test() public {
//         // Deploy and init a controller

//         ControllerInstance memory controllerInst = MainnetControllerDeploy.deployFull(
//             SPARK_PROXY,
//             vault,
//             PSM,
//             DAI_USDS,
//             CCTP_MESSENGER,
//             address(susds)
//         );

//         (
//             Init.ConfigAddressParams memory configAddresses,
//             Init.CheckAddressParams  memory checkAddresses,
//             MintRecipient[]                           memory mintRecipients
//         ) = _getDefaultParams();

//         vm.startPrank(SPARK_PROXY);
//         Init.subDaoInitController(
//             configAddresses,
//             checkAddresses,
//             controllerInst,
//             mintRecipients
//         );
//         vm.stopPrank();

//         // Deploy a new controller (example of how an upgrade would work)

//         address newController = MainnetControllerDeploy.deployController(
//             SPARK_PROXY,
//             controllerInst.almProxy,
//             controllerInst.rateLimits,
//             vault,
//             PSM,
//             DAI_USDS,
//             CCTP_MESSENGER,
//             address(susds)
//         );

//         // Overwrite storage for all previous deployments in setUp and assert deployment

//         almProxy          = ALMProxy(payable(controllerInst.almProxy));
//         mainnetController = MainnetController(controllerInst.controller);
//         rateLimits        = RateLimits(controllerInst.rateLimits);

//         address oldController = address(controllerInst.controller);

//         controllerInst.controller = newController;  // Overwrite struct for param

//         // All other info is the same, just need to transfer ACL
//         configAddresses.oldController = oldController;

//         assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     oldController), true);
//         assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     oldController), true);
//         assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), newController), false);
//         assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), newController), false);

//         vm.startPrank(SPARK_PROXY);
//         Init.subDaoInitController(
//             configAddresses,
//             checkAddresses,
//             controllerInst,
//             mintRecipients
//         );
//         vm.stopPrank();

//         assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     oldController), false);
//         assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     oldController), false);
//         assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), newController), true);
//         assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), newController), true);
//     }

// }