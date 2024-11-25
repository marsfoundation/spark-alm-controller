// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/mainnet-fork/ForkTestBase.t.sol";

import { IRateLimits } from "src/interfaces/IRateLimits.sol";

import { ControllerInstance }      from "../../deploy/ControllerInstance.sol";
import { MainnetControllerDeploy } from "../../deploy/ControllerDeploy.sol";

import {
    MainnetControllerInit,
    RateLimitData,
    MintRecipient
} from "../../deploy/ControllerInit.sol";

// Necessary to get error message assertions to work
contract LibraryWrapper {

    function subDaoInitController(
        MainnetControllerInit.AddressParams     memory params,
        ControllerInstance                      memory controllerInst,
        MainnetControllerInit.InitRateLimitData memory rateLimitData,
        MintRecipient[]                         memory mintRecipients
    )
        external
    {
        MainnetControllerInit.subDaoInitController(
            params,
            controllerInst,
            rateLimitData,
            mintRecipients
        );
    }

    function subDaoInitFull(
        MainnetControllerInit.AddressParams     memory params,
        ControllerInstance                      memory controllerInst,
        MainnetControllerInit.InitRateLimitData memory rateLimitData,
        MintRecipient[]                         memory mintRecipients
    )
        external
    {
        MainnetControllerInit.subDaoInitFull(
            params,
            controllerInst,
            rateLimitData,
            mintRecipients
        );
    }

}

contract MainnetControllerDeployInitTestBase is ForkTestBase {

    function _getDefaultParams()
        internal returns (
            MainnetControllerInit.AddressParams     memory addresses,
            MainnetControllerInit.InitRateLimitData memory rateLimitData,
            MintRecipient[]                         memory mintRecipients
        )
    {
        addresses = MainnetControllerInit.AddressParams({
            admin         : Ethereum.SPARK_PROXY,
            freezer       : freezer,
            relayer       : relayer,
            oldController : address(0),
            psm           : Ethereum.PSM,
            vault         : vault,
            buffer        : buffer,
            cctpMessenger : Ethereum.CCTP_TOKEN_MESSENGER,
            dai           : Ethereum.DAI,
            daiUsds       : Ethereum.DAI_USDS,
            usdc          : Ethereum.USDC,
            usds          : Ethereum.USDS,
            susds         : Ethereum.SUSDS
        });

        RateLimitData memory usdsMintData = RateLimitData({
            maxAmount : 1_000_000e18,
            slope     : uint256(1_000_000e18) / 4 hours
        });

        RateLimitData memory usdsToUsdcData = RateLimitData({
            maxAmount : 2_000_000e6,
            slope     : uint256(2_000_000e6) / 4 hours
        });

        RateLimitData memory usdcToCctpData = RateLimitData({
            maxAmount : 3_000_000e6,
            slope     : uint256(3_000_000e6) / 4 hours
        });

        RateLimitData memory cctpToBaseDomainData = RateLimitData({
            maxAmount : 4_000_000e6,
            slope     : uint256(4_000_000e6) / 4 hours
        });

        rateLimitData = MainnetControllerInit.InitRateLimitData({
            usdsMintData         : usdsMintData,
            usdsToUsdcData       : usdsToUsdcData,
            usdcToCctpData       : usdcToCctpData,
            cctpToBaseDomainData : cctpToBaseDomainData
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

    MainnetControllerInit.AddressParams     addresses;
    MainnetControllerInit.InitRateLimitData rateLimitData;
    MintRecipient[]                         mintRecipients;

    function setUp() public override {
        super.setUp();

        controllerInst = MainnetControllerDeploy.deployFull(
            SPARK_PROXY,
            vault,
            PSM,
            DAI_USDS,
            CCTP_MESSENGER,
            address(susds),
            address(susde),
            ETHENA_MINTER
        );

        MintRecipient[] memory mintRecipients_ = new MintRecipient[](1);

        ( addresses, rateLimitData, mintRecipients_ ) = _getDefaultParams();

        // NOTE: This would need to be refactored to a for loop if more than one recipient
        mintRecipients.push(mintRecipients_[0]);

        // Overwrite storage for all previous deployments in setUp and assert deployment

        almProxy          = ALMProxy(payable(controllerInst.almProxy));
        mainnetController = MainnetController(controllerInst.controller);
        rateLimits        = RateLimits(controllerInst.rateLimits);

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

        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-almProxy"));
    }

    function test_init_incorrectRateLimits() external {
        // Deploy new address that will not EVM revert on OZ ACL check
        controllerInst.rateLimits = address(new RateLimits(SPARK_PROXY));

        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-rateLimits"));
    }

    function test_init_incorrectVault() external {
        addresses.vault = mismatchAddress;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-vault"));
    }

    function test_init_incorrectBuffer() external {
        addresses.buffer = mismatchAddress;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-buffer"));
    }

    function test_init_incorrectPsm() external {
        addresses.psm = mismatchAddress;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-psm"));
    }

    function test_init_incorrectDaiUsds() external {
        addresses.daiUsds = mismatchAddress;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-daiUsds"));
    }

    function test_init_incorrectCctp() external {
        addresses.cctpMessenger = mismatchAddress;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-cctpMessenger"));
    }

    function test_init_incorrectSUsds() external {
        addresses.susds = mismatchAddress;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-susds"));
    }

    function test_init_incorrectDai() external {
        addresses.dai = mismatchAddress;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-dai"));
    }

    function test_init_incorrectUsdc() external {
        addresses.usdc = mismatchAddress;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-usdc"));
    }

    function test_init_incorrectUsds() external {
        addresses.usds = mismatchAddress;
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
        addresses.oldController = controllerInst.controller;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/old-controller-is-new-controller"));
    }

    // TODO: Skipping conversion factor test, can add later if needed

    /**********************************************************************************************/
    /*** Unlimited `maxAmount` rate limit boundary tests                                        ***/
    /**********************************************************************************************/

    function test_init_incorrectUsdsMintData_unlimitedBoundary() external {
        rateLimitData.usdsMintData.maxAmount = type(uint256).max;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/invalid-rate-limit-usdsMintData"));

        rateLimitData.usdsMintData.slope = 0;
        _checkBothInitsSucceed();
    }

    function test_init_incorrectUsdcToUsdsData_unlimitedBoundary() external {
        rateLimitData.usdsToUsdcData.maxAmount = type(uint256).max;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/invalid-rate-limit-usdsToUsdcData"));

        rateLimitData.usdsToUsdcData.slope = 0;
        _checkBothInitsSucceed();
    }

    function test_init_incorrectUsdcToCctpData_unlimitedBoundary() external {
        rateLimitData.usdcToCctpData.maxAmount = type(uint256).max;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/invalid-rate-limit-usdcToCctpData"));

        rateLimitData.usdcToCctpData.slope = 0;
        _checkBothInitsSucceed();
    }

    function test_init_incorrectCctpToBaseDomain_unlimitedBoundary() external {
        rateLimitData.cctpToBaseDomainData.maxAmount = type(uint256).max;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/invalid-rate-limit-cctpToBaseDomainData"));

        rateLimitData.cctpToBaseDomainData.slope = 0;
        _checkBothInitsSucceed();
    }

    /**********************************************************************************************/
    /*** `maxAmount` rate limit precision boundary tests                                        ***/
    /**********************************************************************************************/

    function test_init_incorrectUsdsMintData_maxAmountPrecisionBoundary() external {
        rateLimitData.usdsMintData.maxAmount = 1e12 * 1e18 + 1;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/invalid-max-amount-precision-usdsMintData"));

        rateLimitData.usdsMintData.maxAmount = 1e12 * 1e18;
        _checkBothInitsSucceed();
    }

    function test_init_incorrectUsdcToUsdsData_maxAmountPrecisionBoundary() external {
        rateLimitData.usdsToUsdcData.maxAmount = 1e12 * 1e6 + 1;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/invalid-max-amount-precision-usdsToUsdcData"));

        rateLimitData.usdsToUsdcData.maxAmount = 1e12 * 1e6;
        _checkBothInitsSucceed();
    }

    function test_init_incorrectUsdcToCctpData_maxAmountPrecisionBoundary() external {
        rateLimitData.usdcToCctpData.maxAmount = 1e12 * 1e6 + 1;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/invalid-max-amount-precision-usdcToCctpData"));

        rateLimitData.usdcToCctpData.maxAmount = 1e12 * 1e6;
        _checkBothInitsSucceed();
    }

    function test_init_incorrectCctpToBaseDomain_maxAmountPrecisionBoundary() external {
        rateLimitData.cctpToBaseDomainData.maxAmount = 1e12 * 1e6 + 1;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/invalid-max-amount-precision-cctpToBaseDomainData"));

        rateLimitData.cctpToBaseDomainData.maxAmount = 1e12 * 1e6;
        _checkBothInitsSucceed();
    }

    /**********************************************************************************************/
    /*** `slope` rate limit precision boundary tests                                            ***/
    /**********************************************************************************************/

    function test_init_incorrectUsdsMintData_slopePrecisionBoundary() external {
        rateLimitData.usdsMintData.slope = uint256(1e12 * 1e18) / 1 hours + 1;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/invalid-slope-precision-usdsMintData"));

        rateLimitData.usdsMintData.slope = uint256(1e12 * 1e18) / 1 hours;
        _checkBothInitsSucceed();
    }

    function test_init_incorrectUsdcToUsdsData_slopePrecisionBoundary() external {
        rateLimitData.usdsToUsdcData.slope = uint256(1e12 * 1e6) / 1 hours + 1;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/invalid-slope-precision-usdsToUsdcData"));

        rateLimitData.usdsToUsdcData.slope = uint256(1e12 * 1e6) / 1 hours;
        _checkBothInitsSucceed();
    }

    function test_init_incorrectUsdcToCctpData_slopePrecisionBoundary() external {
        rateLimitData.usdcToCctpData.slope = uint256(1e12 * 1e6) / 1 hours + 1;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/invalid-slope-precision-usdcToCctpData"));

        rateLimitData.usdcToCctpData.slope = uint256(1e12 * 1e6) / 1 hours;
        _checkBothInitsSucceed();
    }

    function test_init_incorrectCctpToBaseDomain_slopePrecisionBoundary() external {
        rateLimitData.cctpToBaseDomainData.slope = uint256(1e12 * 1e6) / 1 hours + 1;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/invalid-slope-precision-cctpToBaseDomainData"));

        rateLimitData.cctpToBaseDomainData.slope = uint256(1e12 * 1e6) / 1 hours;
        _checkBothInitsSucceed();
    }

    /**********************************************************************************************/
    /*** Old controller role check tests                                                        ***/
    /**********************************************************************************************/

    function test_init_oldControllerDoesNotHaveRoleInAlmProxy() external {
        _deployNewControllerAfterExistingControllerInit();

        // Revoke the old controller address in ALM proxy

        vm.startPrank(SPARK_PROXY);
        almProxy.revokeRole(almProxy.CONTROLLER(), addresses.oldController);
        vm.stopPrank();

        // Try to init with the old controller address that is doesn't have the CONTROLLER role

        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/old-controller-not-almProxy-controller"));
    }

    function test_init_oldControllerDoesNotHaveRoleInRateLimits() external {
        _deployNewControllerAfterExistingControllerInit();

        // Revoke the old controller address

        vm.startPrank(SPARK_PROXY);
        rateLimits.revokeRole(rateLimits.CONTROLLER(), addresses.oldController);
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
        MainnetControllerInit.subDaoInitFull(
            addresses,
            controllerInst,
            rateLimitData,
            mintRecipients
        );
        vm.stopPrank();

        // Deploy a new controller (controllerInst is used in init with new controller address)

        controllerInst.controller = MainnetControllerDeploy.deployController(
            SPARK_PROXY,
            address(almProxy),
            address(rateLimits),
            vault,
            PSM,
            DAI_USDS,
            CCTP_MESSENGER,
            address(susds),
            address(susde),
            ETHENA_MINTER
        );

        addresses.oldController = address(mainnetController);
    }

    // Added this function to ensure that all the failure modes from `subDaoInitController`
    // are also covered by `subDaoInitFull` calls
    function _checkBothInitsFail(bytes memory expectedError) internal {
        vm.expectRevert(expectedError);
        wrapper.subDaoInitController(
            addresses,
            controllerInst,
            rateLimitData,
            mintRecipients
        );

        vm.expectRevert(expectedError);
        wrapper.subDaoInitFull(
            addresses,
            controllerInst,
            rateLimitData,
            mintRecipients
        );
    }

    function _checkBothInitsSucceed() internal {
        wrapper.subDaoInitController(
            addresses,
            controllerInst,
            rateLimitData,
            mintRecipients
        );

        wrapper.subDaoInitFull(
            addresses,
            controllerInst,
            rateLimitData,
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
            address(susds),
            address(susde),
            ETHENA_MINTER
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
            MainnetControllerInit.AddressParams     memory addresses,
            MainnetControllerInit.InitRateLimitData memory rateLimitData,
            MintRecipient[]                         memory mintRecipients
        ) = _getDefaultParams();

        vm.startPrank(SPARK_PROXY);
        MainnetControllerInit.subDaoInitFull(
            addresses,
            controllerInst,
            rateLimitData,
            mintRecipients
        );
        vm.stopPrank();

        // Assert SubDAO initialization

        assertEq(mainnetController.hasRole(mainnetController.FREEZER(), freezer), true);
        assertEq(mainnetController.hasRole(mainnetController.RELAYER(), relayer), true);

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), address(mainnetController)), true);

        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(mainnetController)), true);

        bytes32 domainKeyBase = RateLimitHelpers.makeDomainKey(
            mainnetController.LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE
        );

        _assertRateLimitData(mainnetController.LIMIT_USDS_MINT(),    rateLimitData.usdsMintData);
        _assertRateLimitData(mainnetController.LIMIT_USDS_TO_USDC(), rateLimitData.usdsToUsdcData);
        _assertRateLimitData(mainnetController.LIMIT_USDC_TO_CCTP(), rateLimitData.usdcToCctpData);
        _assertRateLimitData(domainKeyBase,                          rateLimitData.cctpToBaseDomainData);

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
            address(susds),
            address(susde),
            ETHENA_MINTER
        );

        // Overwrite storage for all previous deployments in setUp and assert deployment

        almProxy          = ALMProxy(payable(controllerInst.almProxy));
        mainnetController = MainnetController(controllerInst.controller);
        rateLimits        = RateLimits(controllerInst.rateLimits);

        (
            MainnetControllerInit.AddressParams     memory addresses,
            MainnetControllerInit.InitRateLimitData memory rateLimitData,
            MintRecipient[]                         memory mintRecipients
        ) = _getDefaultParams();

        // Perform ONLY controller initialization, setting rate limits and updating ACL
        // Setting rate limits to different values from setUp to make assertions more robust

        vm.startPrank(SPARK_PROXY);
        MainnetControllerInit.subDaoInitController(
            addresses,
            controllerInst,
            rateLimitData,
            mintRecipients
        );
        vm.stopPrank();

        assertEq(mainnetController.hasRole(mainnetController.FREEZER(), freezer), true);
        assertEq(mainnetController.hasRole(mainnetController.RELAYER(), relayer), true);

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), address(mainnetController)), true);

        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(mainnetController)), true);

        bytes32 domainKeyBase = RateLimitHelpers.makeDomainKey(
            mainnetController.LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE
        );

        _assertRateLimitData(mainnetController.LIMIT_USDS_MINT(),    rateLimitData.usdsMintData);
        _assertRateLimitData(mainnetController.LIMIT_USDS_TO_USDC(), rateLimitData.usdsToUsdcData);
        _assertRateLimitData(mainnetController.LIMIT_USDC_TO_CCTP(), rateLimitData.usdcToCctpData);
        _assertRateLimitData(domainKeyBase,                          rateLimitData.cctpToBaseDomainData);

        assertEq(
            mainnetController.mintRecipients(mintRecipients[0].domain),
            mintRecipients[0].mintRecipient
        );

        assertEq(
            mainnetController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
            bytes32(uint256(uint160(makeAddr("baseAlmProxy"))))
        );
    }

    function test_init_transferAclToNewController() public {
        // Deploy and init a controller

        ControllerInstance memory controllerInst = MainnetControllerDeploy.deployFull(
            SPARK_PROXY,
            vault,
            PSM,
            DAI_USDS,
            CCTP_MESSENGER,
            address(susds),
            address(susde),
            ETHENA_MINTER
        );

        (
            MainnetControllerInit.AddressParams     memory addresses,
            MainnetControllerInit.InitRateLimitData memory rateLimitData,
            MintRecipient[]                         memory mintRecipients
        ) = _getDefaultParams();

        vm.startPrank(SPARK_PROXY);
        MainnetControllerInit.subDaoInitController(
            addresses,
            controllerInst,
            rateLimitData,
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
            address(susds),
            address(susde),
            ETHENA_MINTER
        );

        // Overwrite storage for all previous deployments in setUp and assert deployment

        almProxy          = ALMProxy(payable(controllerInst.almProxy));
        mainnetController = MainnetController(controllerInst.controller);
        rateLimits        = RateLimits(controllerInst.rateLimits);

        address oldController = address(controllerInst.controller);

        controllerInst.controller = newController;  // Overwrite struct for param

        // All other info is the same, just need to transfer ACL
        addresses.oldController = oldController;

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     oldController), true);
        assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     oldController), true);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), newController), false);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), newController), false);

        vm.startPrank(SPARK_PROXY);
        MainnetControllerInit.subDaoInitController(
            addresses,
            controllerInst,
            rateLimitData,
            mintRecipients
        );
        vm.stopPrank();

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     oldController), false);
        assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     oldController), false);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), newController), true);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), newController), true);
    }

    function _assertRateLimitData(bytes32 domainKey, RateLimitData memory expectedData) internal {
        IRateLimits.RateLimitData memory data = rateLimits.getRateLimitData(domainKey);

        assertEq(data.maxAmount,   expectedData.maxAmount);
        assertEq(data.slope,       expectedData.slope);
        assertEq(data.lastAmount,  expectedData.maxAmount);
        assertEq(data.lastUpdated, block.timestamp);

        assertEq(rateLimits.getCurrentRateLimit(domainKey), expectedData.maxAmount);
    }

}
