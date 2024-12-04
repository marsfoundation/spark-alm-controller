// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/mainnet-fork/ForkTestBase.t.sol";

import { IRateLimits } from "src/interfaces/IRateLimits.sol";

import { ControllerInstance }      from "../../deploy/ControllerInstance.sol";
import { MainnetControllerDeploy } from "../../deploy/ControllerDeploy.sol";

import { MainnetControllerInit, MintRecipient } from "../../deploy/ControllerInit.sol";

// Necessary to get error message assertions to work
contract LibraryWrapper {

    function subDaoInitController(
        MainnetControllerInit.ConfigAddressParams memory configAddresses,
        MainnetControllerInit.AddressCheckParams  memory checkAddresses,
        ControllerInstance                        memory controllerInst,
        MintRecipient[]                           memory mintRecipients
    )
        external
    {
        MainnetControllerInit.subDaoInitController(
            configAddresses,
            checkAddresses,
            controllerInst,
            mintRecipients
        );
    }

    function subDaoInitFull(
        MainnetControllerInit.ConfigAddressParams memory configAddresses,
        MainnetControllerInit.AddressCheckParams  memory checkAddresses,
        ControllerInstance                        memory controllerInst,
        MintRecipient[]                           memory mintRecipients
    )
        external
    {
        MainnetControllerInit.subDaoInitFull(
            configAddresses,
            checkAddresses,
            controllerInst,
            mintRecipients
        );
    }

}

contract MainnetControllerDeployInitTestBase is ForkTestBase {

    function _getDefaultParams()
        internal returns (
            MainnetControllerInit.ConfigAddressParams memory configAddresses,
            MainnetControllerInit.AddressCheckParams  memory checkAddresses,
            MintRecipient[]                           memory mintRecipients
        )
    {
        configAddresses = MainnetControllerInit.ConfigAddressParams({
            admin         : Ethereum.SPARK_PROXY,
            freezer       : freezer,
            relayer       : relayer,
            oldController : address(0)
        });

        checkAddresses = MainnetControllerInit.AddressCheckParams({
            proxy        : Ethereum.ALM_PROXY,
            rateLimits   : Ethereum.ALM_RATE_LIMITS,
            buffer       : Ethereum.ALLOCATOR_BUFFER,
            cctp         : Ethereum.CCTP_TOKEN_MESSENGER,
            daiUsds      : Ethereum.DAI_USDS,
            ethenaMinter : Ethereum.ETHENA_MINTER,
            psm          : Ethereum.PSM,
            vault        : Ethereum.ALLOCATOR_VAULT,
            dai          : Ethereum.DAI,
            usds         : Ethereum.USDS,
            usde         : Ethereum.USDE,
            usdc         : Ethereum.USDC,
            susde        : Ethereum.SUSDE,
            susds        : Ethereum.SUSDS
        });

        mintRecipients = new MintRecipient[](1);

        mintRecipients[0] = MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            mintRecipient : bytes32(uint256(uint160(makeAddr("baseAlmProxy"))))
        });
    }

}

contract MainnetControllerDeployAndInitFailureTests is MainnetControllerDeployInitTestBase {

    LibraryWrapper wrapper;

    ControllerInstance public controllerInst;

    address public mismatchAddress = makeAddr("mismatchAddress");

    MainnetControllerInit.ConfigAddressParams configAddresses;
    MainnetControllerInit.AddressCheckParams  checkAddresses;
    MintRecipient[]                           mintRecipients;

    function setUp() public override {
        super.setUp();

        mainnetController = MainnetController(MainnetControllerDeploy.deployController({
            admin      : Ethereum.SPARK_PROXY,
            almProxy   : Ethereum.ALM_PROXY,
            rateLimits : Ethereum.ALM_RATE_LIMITS,
            vault      : Ethereum.ALLOCATOR_VAULT,
            psm        : Ethereum.PSM,
            daiUsds    : Ethereum.DAI_USDS,
            cctp       : Ethereum.CCTP_TOKEN_MESSENGER,
            susds      : Ethereum.SUSDS
        }));

        almProxy   = ALMProxy(payable(Ethereum.ALM_PROXY));
        rateLimits = RateLimits(Ethereum.ALM_RATE_LIMITS);

        MintRecipient[] memory mintRecipients_ = new MintRecipient[](1);

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

    /**********************************************************************************************/
    /*** ACL tests                                                                              ***/
    /**********************************************************************************************/

    function test_init_incorrectAdminAlmProxy() external {
        // Isolate different contracts instead of setting param so can get three different failures
        vm.startPrank(SPARK_PROXY);
        almProxy.grantRole(DEFAULT_ADMIN_ROLE, mismatchAddress);
        almProxy.revokeRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY);
        vm.stopPrank();

        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-admin-almProxy"));
    }

    function test_init_incorrectAdminRateLimits() external {
        // Isolate different contracts instead of setting param so can get three different failures
        vm.startPrank(SPARK_PROXY);
        rateLimits.grantRole(DEFAULT_ADMIN_ROLE, mismatchAddress);
        rateLimits.revokeRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY);
        vm.stopPrank();

        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-admin-rateLimits"));
    }

    function test_init_incorrectAdminController() external {
        // Isolate different contracts instead of setting param so can get three different failures
        vm.startPrank(SPARK_PROXY);
        mainnetController.grantRole(DEFAULT_ADMIN_ROLE, mismatchAddress);
        mainnetController.revokeRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY);
        vm.stopPrank();

        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-admin-controller"));
    }

    /**********************************************************************************************/
    /*** Constructor tests                                                                      ***/
    /**********************************************************************************************/

    function test_init_incorrectAlmProxy() external {
        // Deploy new address that will not EVM revert on OZ ACL check
        controllerInst.almProxy = address(new ALMProxy(SPARK_PROXY));

        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-proxy"));
    }

    function test_init_incorrectRateLimits() external {
        // Deploy new address that will not EVM revert on OZ ACL check
        controllerInst.rateLimits = address(new RateLimits(SPARK_PROXY));

        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-rateLimits"));
    }

    function test_init_incorrectVault() external {
        checkAddresses.vault = mismatchAddress;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-vault"));
    }

    function test_init_incorrectBuffer() external {
        checkAddresses.buffer = mismatchAddress;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-buffer"));
    }

    function test_init_incorrectPsm() external {
        checkAddresses.psm = mismatchAddress;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-psm"));
    }

    function test_init_incorrectDaiUsds() external {
        checkAddresses.daiUsds = mismatchAddress;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-daiUsds"));
    }

    function test_init_incorrectCctp() external {
        checkAddresses.cctp = mismatchAddress;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-cctp"));
    }

    function test_init_incorrectSUsds() external {
        checkAddresses.susds = mismatchAddress;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-susds"));
    }

    function test_init_incorrectDai() external {
        checkAddresses.dai = mismatchAddress;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-dai"));
    }

    function test_init_incorrectUsdc() external {
        checkAddresses.usdc = mismatchAddress;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-usdc"));
    }

    function test_init_incorrectUsds() external {
        checkAddresses.usds = mismatchAddress;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-usds"));
    }

    function test_init_controllerInactive() external {
        // Cheating to set this outside of init scripts so that the controller can be frozen
        vm.startPrank(SPARK_PROXY);
        mainnetController.grantRole(FREEZER, freezer);

        vm.startPrank(freezer);
        mainnetController.freeze();
        vm.stopPrank();

        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/controller-not-active"));
    }

    function test_init_oldControllerIsNewController() external {
        configAddresses.oldController = controllerInst.controller;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/old-controller-is-new-controller"));
    }

    // TODO: Skipping conversion factor test, can add later if needed

    /**********************************************************************************************/
    /*** Old controller role check tests                                                        ***/
    /**********************************************************************************************/

    function test_init_oldControllerDoesNotHaveRoleInAlmProxy() external {
        _deployNewControllerAfterExistingControllerInit();

        // Revoke the old controller address in ALM proxy

        vm.startPrank(SPARK_PROXY);
        almProxy.revokeRole(almProxy.CONTROLLER(), configAddresses.oldController);
        vm.stopPrank();

        // Try to init with the old controller address that is doesn't have the CONTROLLER role

        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/old-controller-not-almProxy-controller"));
    }

    function test_init_oldControllerDoesNotHaveRoleInRateLimits() external {
        _deployNewControllerAfterExistingControllerInit();

        // Revoke the old controller address

        vm.startPrank(SPARK_PROXY);
        rateLimits.revokeRole(rateLimits.CONTROLLER(), configAddresses.oldController);
        vm.stopPrank();

        // Try to init with the old controller address that is doesn't have the CONTROLLER role

        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/old-controller-not-rateLimits-controller"));
    }

    /**********************************************************************************************/
    /*** Helper functions                                                                       ***/
    /**********************************************************************************************/

    function _deployNewControllerAfterExistingControllerInit() internal {
        // Successfully init first controller

        vm.startPrank(SPARK_PROXY);
        MainnetControllerInit.subDaoInitController(
            configAddresses,
            checkAddresses,
            controllerInst,
            mintRecipients
        );
        vm.stopPrank();

        // Deploy a new controller (controllerInst is used in init with new controller address)

        controllerInst.controller = MainnetControllerDeploy.deployController({
            admin      : Ethereum.SPARK_PROXY,
            almProxy   : Ethereum.ALM_PROXY,
            rateLimits : Ethereum.ALM_RATE_LIMITS,
            vault      : Ethereum.ALLOCATOR_VAULT,
            psm        : Ethereum.PSM,
            daiUsds    : Ethereum.DAI_USDS,
            cctp       : Ethereum.CCTP_TOKEN_MESSENGER,
            susds      : Ethereum.SUSDS
        });

        configAddresses.oldController = address(mainnetController);
    }

    // Added this function to ensure that all the failure modes from `subDaoInitController`
    // are also covered by `subDaoInitFull` calls
    function _checkBothInitsFail(bytes memory expectedError) internal {
        vm.expectRevert(expectedError);
        wrapper.subDaoInitController(
            configAddresses,
            checkAddresses,
            controllerInst,
            mintRecipients
        );

        vm.expectRevert(expectedError);
        wrapper.subDaoInitFull(
            configAddresses,
            checkAddresses,
            controllerInst,
            mintRecipients
        );
    }

    function _checkBothInitsSucceed() internal {
        wrapper.subDaoInitController(
            configAddresses,
            checkAddresses,
            controllerInst,
            mintRecipients
        );

        wrapper.subDaoInitFull(
            configAddresses,
            checkAddresses,
            controllerInst,
            mintRecipients
        );
    }
}

contract MainnetControllerDeployAndInitSuccessTests is MainnetControllerDeployInitTestBase {

    function test_deployAllAndInitFull() external {
        // Perform new deployments against existing fork environment

        ControllerInstance memory controllerInst = MainnetControllerDeploy.deployFull(
            SPARK_PROXY,
            vault,
            PSM,
            DAI_USDS,
            CCTP_MESSENGER,
            address(susds)
        );

        // Overwrite storage for all previous deployments in setUp and assert deployment

        almProxy          = ALMProxy(payable(controllerInst.almProxy));
        mainnetController = MainnetController(controllerInst.controller);
        rateLimits        = RateLimits(controllerInst.rateLimits);

        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY),          true);
        assertEq(mainnetController.hasRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY), true);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY),        true);

        assertEq(address(mainnetController.proxy()),      controllerInst.almProxy);
        assertEq(address(mainnetController.rateLimits()), controllerInst.rateLimits);
        assertEq(address(mainnetController.vault()),      vault);
        assertEq(address(mainnetController.buffer()),     buffer);
        assertEq(address(mainnetController.psm()),        PSM);
        assertEq(address(mainnetController.daiUsds()),    DAI_USDS);
        assertEq(address(mainnetController.cctp()),       CCTP_MESSENGER);
        assertEq(address(mainnetController.susds()),      address(susds));
        assertEq(address(mainnetController.dai()),        address(dai));
        assertEq(address(mainnetController.usdc()),       address(usdc));
        assertEq(address(mainnetController.usds()),       address(usds));

        assertEq(mainnetController.psmTo18ConversionFactor(), 1e12);
        assertEq(mainnetController.active(),                  true);

        // Perform SubDAO initialization (from SPARK_PROXY during spell)
        // Setting rate limits to different values from setUp to make assertions more robust

        (
            MainnetControllerInit.ConfigAddressParams memory configAddresses,
            MainnetControllerInit.AddressCheckParams  memory checkAddresses,
            MintRecipient[]                           memory mintRecipients
        ) = _getDefaultParams();

        vm.startPrank(SPARK_PROXY);
        MainnetControllerInit.subDaoInitFull(
            configAddresses,
            checkAddresses,
            controllerInst,
            mintRecipients
        );
        vm.stopPrank();

        // Assert SubDAO initialization

        assertEq(mainnetController.hasRole(mainnetController.FREEZER(), freezer), true);
        assertEq(mainnetController.hasRole(mainnetController.RELAYER(), relayer), true);

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), address(mainnetController)), true);

        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(mainnetController)), true);

        assertEq(
            mainnetController.mintRecipients(mintRecipients[0].domain),
            mintRecipients[0].mintRecipient
        );

        assertEq(
            mainnetController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
            bytes32(uint256(uint160(makeAddr("baseAlmProxy"))))
        );

        assertEq(IVaultLike(vault).wards(controllerInst.almProxy), 1);

        assertEq(usds.allowance(buffer, controllerInst.almProxy), type(uint256).max);

        // Perform Maker initialization (from PAUSE_PROXY during spell)

        vm.startPrank(PAUSE_PROXY);
        MainnetControllerInit.pauseProxyInit(PSM, controllerInst.almProxy);
        vm.stopPrank();

        // Assert Maker initialization

        assertEq(IPSMLike(PSM).bud(controllerInst.almProxy), 1);
    }

    function test_deployAllAndInitController() external {
        // Perform new deployments against existing fork environment

        ControllerInstance memory controllerInst = MainnetControllerDeploy.deployFull(
            SPARK_PROXY,
            vault,
            PSM,
            DAI_USDS,
            CCTP_MESSENGER,
            address(susds)
        );

        // Overwrite storage for all previous deployments in setUp and assert deployment

        almProxy          = ALMProxy(payable(controllerInst.almProxy));
        mainnetController = MainnetController(controllerInst.controller);
        rateLimits        = RateLimits(controllerInst.rateLimits);

        (
            MainnetControllerInit.ConfigAddressParams memory configAddresses,
            MainnetControllerInit.AddressCheckParams  memory checkAddresses,
            MintRecipient[]                           memory mintRecipients
        ) = _getDefaultParams();

        // Perform ONLY controller initialization, setting rate limits and updating ACL
        // Setting rate limits to different values from setUp to make assertions more robust

        vm.startPrank(SPARK_PROXY);
        MainnetControllerInit.subDaoInitController(
            configAddresses,
            checkAddresses,
            controllerInst,
            mintRecipients
        );
        vm.stopPrank();

        assertEq(mainnetController.hasRole(mainnetController.FREEZER(), freezer), true);
        assertEq(mainnetController.hasRole(mainnetController.RELAYER(), relayer), true);

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), address(mainnetController)), true);

        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(mainnetController)), true);

        assertEq(
            mainnetController.mintRecipients(mintRecipients[0].domain),
            mintRecipients[0].mintRecipient
        );

        assertEq(
            mainnetController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
            bytes32(uint256(uint160(makeAddr("baseAlmProxy"))))
        );
    }

    function test_init_transferAclToNewController_Test() public {
        // Deploy and init a controller

        ControllerInstance memory controllerInst = MainnetControllerDeploy.deployFull(
            SPARK_PROXY,
            vault,
            PSM,
            DAI_USDS,
            CCTP_MESSENGER,
            address(susds)
        );

        (
            MainnetControllerInit.ConfigAddressParams memory configAddresses,
            MainnetControllerInit.AddressCheckParams  memory checkAddresses,
            MintRecipient[]                           memory mintRecipients
        ) = _getDefaultParams();

        vm.startPrank(SPARK_PROXY);
        MainnetControllerInit.subDaoInitController(
            configAddresses,
            checkAddresses,
            controllerInst,
            mintRecipients
        );
        vm.stopPrank();

        // Deploy a new controller (example of how an upgrade would work)

        address newController = MainnetControllerDeploy.deployController(
            SPARK_PROXY,
            controllerInst.almProxy,
            controllerInst.rateLimits,
            vault,
            PSM,
            DAI_USDS,
            CCTP_MESSENGER,
            address(susds)
        );

        // Overwrite storage for all previous deployments in setUp and assert deployment

        almProxy          = ALMProxy(payable(controllerInst.almProxy));
        mainnetController = MainnetController(controllerInst.controller);
        rateLimits        = RateLimits(controllerInst.rateLimits);

        address oldController = address(controllerInst.controller);

        controllerInst.controller = newController;  // Overwrite struct for param

        // All other info is the same, just need to transfer ACL
        configAddresses.oldController = oldController;

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     oldController), true);
        assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     oldController), true);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), newController), false);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), newController), false);

        vm.startPrank(SPARK_PROXY);
        MainnetControllerInit.subDaoInitController(
            configAddresses,
            checkAddresses,
            controllerInst,
            mintRecipients
        );
        vm.stopPrank();

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     oldController), false);
        assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     oldController), false);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), newController), true);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), newController), true);
    }

}
