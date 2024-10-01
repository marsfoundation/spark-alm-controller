// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/mainnet-fork/ForkTestBase.t.sol";

import { IRateLimits } from "src/interfaces/IRateLimits.sol";

import { ControllerInstance }      from "../../deploy/ControllerInstance.sol";
import { MainnetControllerDeploy } from "../../deploy/ControllerDeploy.sol";

import { MainnetControllerInit, RateLimitData } from "../../deploy/ControllerInit.sol";

// TODO: Refactor to use live contracts
// TODO: Declare Inst structs to emulate mainnet
// NOTE: Allocation should be deployed prior to Controller

// Necessary to get error message assertions to work
contract LibraryWrapper {

    function subDaoInitController(
        MainnetControllerInit.AddressParams memory params,
        ControllerInstance                  memory controllerInst,
        AllocatorIlkInstance                memory ilkInst,
        RateLimitData                       memory usdsMintData,
        RateLimitData                       memory usdcToUsdsData,
        RateLimitData                       memory usdcToCctpData,
        RateLimitData                       memory cctpToBaseDomainData
    )
        external
    {
        MainnetControllerInit.subDaoInitController(
            params,
            controllerInst,
            ilkInst,
            usdsMintData,
            usdcToUsdsData,
            usdcToCctpData,
            cctpToBaseDomainData
        );
    }

    function subDaoInitFull(
        MainnetControllerInit.AddressParams memory params,
        ControllerInstance                  memory controllerInst,
        AllocatorIlkInstance                memory ilkInst,
        RateLimitData                       memory usdsMintData,
        RateLimitData                       memory usdcToUsdsData,
        RateLimitData                       memory usdcToCctpData,
        RateLimitData                       memory cctpToBaseDomainData
    )
        external
    {
        MainnetControllerInit.subDaoInitFull(
            params,
            controllerInst,
            ilkInst,
            usdsMintData,
            usdcToUsdsData,
            usdcToCctpData,
            cctpToBaseDomainData
        );
    }

}

contract MainnetControllerDeployAndInitFailureTests is ForkTestBase {

    LibraryWrapper wrapper;

    ControllerInstance public controllerInst;

    address public mismatchAddress = makeAddr("mismatchAddress");

    MainnetControllerInit.AddressParams addresses;

    RateLimitData usdsMintData = RateLimitData({
        maxAmount : 1_000_000e18,
        slope     : uint256(1_000_000e18) / 4 hours
    });

    RateLimitData usdcToUsdsData = RateLimitData({
        maxAmount : 2_000_000e6,
        slope     : uint256(2_000_000e6) / 4 hours
    });

    RateLimitData usdcToCctpData = RateLimitData({
        maxAmount : 3_000_000e6,
        slope     : uint256(3_000_000e6) / 4 hours
    });

    RateLimitData cctpToBaseDomainData = RateLimitData({
        maxAmount : 4_000_000e6,
        slope     : uint256(4_000_000e6) / 4 hours
    });

    function setUp() public override {
        super.setUp();

        controllerInst = MainnetControllerDeploy.deployFull(
            SPARK_PROXY,
            ilkInst.vault,
            ilkInst.buffer,
            PSM,
            usdsInst.daiUsds,
            CCTP_MESSENGER,
            susdsInst.sUsds
        );

        addresses = MainnetControllerInit.AddressParams({
            admin         : SPARK_PROXY,
            freezer       : freezer,
            relayer       : relayer,
            psm           : PSM,
            cctpMessenger : CCTP_MESSENGER,
            dai           : address(dai),
            daiUsds       : address(daiUsds),
            usdc          : USDC,
            usds          : address(usds),
            susds         : address(susds)
        });

        // Overwrite storage for all previous deployments in setUp and assert deployment

        almProxy          = ALMProxy(controllerInst.almProxy);
        mainnetController = MainnetController(controllerInst.controller);
        rateLimits        = RateLimits(controllerInst.rateLimits);

        // Admin will be calling the library from its own address
        vm.etch(SPARK_PROXY, address(new LibraryWrapper()).code);

        wrapper = LibraryWrapper(SPARK_PROXY);
    }

    function test_init_incorrectAdminAlmProxy() external {
        // Isolate different contracts instead of setting param so can get three different failures
        vm.startPrank(SPARK_PROXY);
        almProxy.grantRole(DEFAULT_ADMIN_ROLE, mismatchAddress);
        almProxy.revokeRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY);
        vm.stopPrank();

        // Check is not in both functions
        vm.expectRevert("MainnetControllerInit/incorrect-admin-almProxy");
        wrapper.subDaoInitFull(
            addresses,
            controllerInst,
            ilkInst,
            usdsMintData,
            usdcToUsdsData,
            usdcToCctpData,
            cctpToBaseDomainData
        );
    }

    function test_init_incorrectAdminRateLimits() external {
        // Isolate different contracts instead of setting param so can get three different failures
        vm.startPrank(SPARK_PROXY);
        rateLimits.grantRole(DEFAULT_ADMIN_ROLE, mismatchAddress);
        rateLimits.revokeRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY);
        vm.stopPrank();

        vm.expectRevert("MainnetControllerInit/incorrect-admin-rateLimits");
        wrapper.subDaoInitFull(
            addresses,
            controllerInst,
            ilkInst,
            usdsMintData,
            usdcToUsdsData,
            usdcToCctpData,
            cctpToBaseDomainData
        );
    }

    function test_init_incorrectAdminController() external {
        // Isolate different contracts instead of setting param so can get three different failures
        vm.startPrank(SPARK_PROXY);
        mainnetController.grantRole(DEFAULT_ADMIN_ROLE, mismatchAddress);
        mainnetController.revokeRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY);
        vm.stopPrank();

        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-admin-controller"));
    }

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
        ilkInst.vault = mismatchAddress;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/incorrect-vault"));
    }

    function test_init_incorrectBuffer() external {
        ilkInst.buffer = mismatchAddress;
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

    // TODO: Skipping conversion factor test and active test, can add later if needed

    function test_init_unlimitedData_incorrectUsdsMintDataBoundary() external {
        usdsMintData.maxAmount = type(uint256).max;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/invalid-rate-limit-usdsMintData"));

        usdsMintData.slope = 0;
        _checkBothInitsSucceed();
    }

    function test_init_unlimitedData_incorrectUsdcToUsdsDataBoundary() external {
        usdcToUsdsData.maxAmount = type(uint256).max;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/invalid-rate-limit-usdcToUsdsData"));

        usdcToUsdsData.slope = 0;
        _checkBothInitsSucceed();
    }

    function test_init_unlimitedData_incorrectUsdcToCctpDataBoundary() external {
        usdcToCctpData.maxAmount = type(uint256).max;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/invalid-rate-limit-usdcToCctpData"));

        usdcToCctpData.slope = 0;
        _checkBothInitsSucceed();
    }

    function test_init_unlimitedData_incorrectCctpToBaseDomainBoundary() external {
        cctpToBaseDomainData.maxAmount = type(uint256).max;
        _checkBothInitsFail(abi.encodePacked("MainnetControllerInit/invalid-rate-limit-cctpToBaseDomainData"));

        cctpToBaseDomainData.slope = 0;
        _checkBothInitsSucceed();
    }

    // Added this function to ensure that all the failure modes from `subDaoInitController`
    // are also covered by `subDaoInitFull` calls
    function _checkBothInitsFail(bytes memory expectedError) internal {
        vm.expectRevert(expectedError);
        wrapper.subDaoInitController(
            addresses,
            controllerInst,
            ilkInst,
            usdsMintData,
            usdcToUsdsData,
            usdcToCctpData,
            cctpToBaseDomainData
        );

        vm.expectRevert(expectedError);
        wrapper.subDaoInitFull(
            addresses,
            controllerInst,
            ilkInst,
            usdsMintData,
            usdcToUsdsData,
            usdcToCctpData,
            cctpToBaseDomainData
        );
    }

    function _checkBothInitsSucceed() internal {
        wrapper.subDaoInitController(
            addresses,
            controllerInst,
            ilkInst,
            usdsMintData,
            usdcToUsdsData,
            usdcToCctpData,
            cctpToBaseDomainData
        );

        wrapper.subDaoInitFull(
            addresses,
            controllerInst,
            ilkInst,
            usdsMintData,
            usdcToUsdsData,
            usdcToCctpData,
            cctpToBaseDomainData
        );
    }
}

contract MainnetControllerDeployAndInitSuccessTests is ForkTestBase {

    function test_deployAllAndInitFull() external {
        // Perform new deployments against existing fork environment

        ControllerInstance memory controllerInst = MainnetControllerDeploy.deployFull(
            SPARK_PROXY,
            ilkInst.vault,
            ilkInst.buffer,
            PSM,
            usdsInst.daiUsds,
            CCTP_MESSENGER,
            susdsInst.sUsds
        );

        // Overwrite storage for all previous deployments in setUp and assert deployment

        almProxy          = ALMProxy(controllerInst.almProxy);
        mainnetController = MainnetController(controllerInst.controller);
        rateLimits        = RateLimits(controllerInst.rateLimits);

        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY),          true);
        assertEq(mainnetController.hasRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY), true);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY),        true);

        assertEq(address(mainnetController.proxy()),      controllerInst.almProxy);
        assertEq(address(mainnetController.rateLimits()), controllerInst.rateLimits);
        assertEq(address(mainnetController.vault()),      ilkInst.vault);
        assertEq(address(mainnetController.buffer()),     ilkInst.buffer);
        assertEq(address(mainnetController.psm()),        PSM);
        assertEq(address(mainnetController.daiUsds()),    usdsInst.daiUsds);
        assertEq(address(mainnetController.cctp()),       CCTP_MESSENGER);
        assertEq(address(mainnetController.susds()),      susdsInst.sUsds);
        assertEq(address(mainnetController.dai()),        address(dai));
        assertEq(address(mainnetController.usdc()),       address(usdc));
        assertEq(address(mainnetController.usds()),       address(usds));

        assertEq(mainnetController.psmTo18ConversionFactor(), 1e12);
        assertEq(mainnetController.active(),                  true);

        // Perform SubDAO initialization (from SPARK_PROXY during spell)
        // Setting rate limits to different values from setUp to make assertions more robust

        MainnetControllerInit.AddressParams memory addresses = MainnetControllerInit.AddressParams({
            admin         : SPARK_PROXY,
            freezer       : freezer,
            relayer       : relayer,
            psm           : PSM,
            cctpMessenger : CCTP_MESSENGER,
            dai           : address(dai),
            daiUsds       : address(daiUsds),
            usdc          : USDC,
            usds          : address(usds),
            susds         : address(susds)
        });

        RateLimitData memory usdsMintData = RateLimitData({
            maxAmount : 1_000_000e18,
            slope     : uint256(1_000_000e18) / 4 hours
        });

        RateLimitData memory usdcToUsdsData = RateLimitData({
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

        vm.startPrank(SPARK_PROXY);
        MainnetControllerInit.subDaoInitFull(
            addresses,
            controllerInst,
            ilkInst,
            usdsMintData,
            usdcToUsdsData,
            usdcToCctpData,
            cctpToBaseDomainData
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

        _assertRateLimitData(mainnetController.LIMIT_USDS_MINT(),    usdsMintData.maxAmount,         usdsMintData.slope);
        _assertRateLimitData(mainnetController.LIMIT_USDS_TO_USDC(), usdcToUsdsData.maxAmount,       usdcToUsdsData.slope);
        _assertRateLimitData(mainnetController.LIMIT_USDC_TO_CCTP(), usdcToCctpData.maxAmount,       usdcToCctpData.slope);
        _assertRateLimitData(domainKeyBase,                          cctpToBaseDomainData.maxAmount, cctpToBaseDomainData.slope);

        assertEq(IVaultLike(ilkInst.vault).wards(controllerInst.almProxy), 1);

        assertEq(usds.allowance(ilkInst.buffer, controllerInst.almProxy), type(uint256).max);

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
            ilkInst.vault,
            ilkInst.buffer,
            PSM,
            usdsInst.daiUsds,
            CCTP_MESSENGER,
            susdsInst.sUsds
        );

        // Overwrite storage for all previous deployments in setUp and assert deployment

        almProxy          = ALMProxy(controllerInst.almProxy);
        mainnetController = MainnetController(controllerInst.controller);
        rateLimits        = RateLimits(controllerInst.rateLimits);

        // Perform ONLY controller initialization, setting rate limits and updating ACL
        // Setting rate limits to different values from setUp to make assertions more robust

        MainnetControllerInit.AddressParams memory addresses = MainnetControllerInit.AddressParams({
            admin         : SPARK_PROXY,
            freezer       : freezer,
            relayer       : relayer,
            psm           : PSM,
            cctpMessenger : CCTP_MESSENGER,
            dai           : address(dai),
            daiUsds       : address(daiUsds),
            usdc          : USDC,
            usds          : address(usds),
            susds         : address(susds)
        });

        RateLimitData memory usdsMintData = RateLimitData({
            maxAmount : 1_000_000e18,
            slope     : uint256(1_000_000e18) / 4 hours
        });

        RateLimitData memory usdcToUsdsData = RateLimitData({
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

        vm.startPrank(SPARK_PROXY);
        MainnetControllerInit.subDaoInitController(
            addresses,
            controllerInst,
            ilkInst,
            usdsMintData,
            usdcToUsdsData,
            usdcToCctpData,
            cctpToBaseDomainData
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

        _assertRateLimitData(mainnetController.LIMIT_USDS_MINT(),    usdsMintData.maxAmount,         usdsMintData.slope);
        _assertRateLimitData(mainnetController.LIMIT_USDS_TO_USDC(), usdcToUsdsData.maxAmount,       usdcToUsdsData.slope);
        _assertRateLimitData(mainnetController.LIMIT_USDC_TO_CCTP(), usdcToCctpData.maxAmount,       usdcToCctpData.slope);
        _assertRateLimitData(domainKeyBase,                          cctpToBaseDomainData.maxAmount, cctpToBaseDomainData.slope);
    }

    function _assertRateLimitData(bytes32 domainKey, uint256 maxAmount, uint256 slope) internal {
        IRateLimits.RateLimitData memory data = rateLimits.getRateLimitData(domainKey);

        assertEq(data.maxAmount,   maxAmount);
        assertEq(data.slope,       slope);
        assertEq(data.lastAmount,  maxAmount);
        assertEq(data.lastUpdated, block.timestamp);

        assertEq(rateLimits.getCurrentRateLimit(domainKey), maxAmount);
    }

}
