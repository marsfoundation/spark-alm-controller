// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import "test/base-fork/ForkTestBase.t.sol";

import { IRateLimits } from "src/interfaces/IRateLimits.sol";

import { ControllerInstance }      from "../../deploy/ControllerInstance.sol";
import { ForeignControllerDeploy } from "../../deploy/ControllerDeploy.sol";

import { ForeignControllerInit, RateLimitData } from "../../deploy/ControllerInit.sol";

// Necessary to get error message assertions to work
contract LibraryWrapper {

    function init(
        ForeignControllerInit.AddressParams     memory params,
        ControllerInstance                      memory controllerInst,
        ForeignControllerInit.InitRateLimitData memory data
    )
        external
    {
        ForeignControllerInit.init(params, controllerInst, data);
    }
}

contract ForeignControllerDeployAndInitFailureTests is ForkTestBase {

    LibraryWrapper wrapper;

    ControllerInstance public controllerInst;

    address public mismatchAddress = makeAddr("mismatchAddress");

    // Default parameters for success that are overridden for failure tests

    ForeignControllerInit.AddressParams addresses;

    RateLimitData usdcDepositData = RateLimitData({
        maxAmount : 1_000_000e6,
        slope     : uint256(1_000_000e6) / 4 hours
    });

    RateLimitData usdcWithdrawData = RateLimitData({
        maxAmount : 2_000_000e6,
        slope     : uint256(2_000_000e6) / 4 hours
    });

    RateLimitData usdcToCctpData = RateLimitData({
        maxAmount : 3_000_000e6,
        slope     : uint256(3_000_000e6) / 4 hours
    });

    RateLimitData cctpToEthereumDomainData = RateLimitData({
        maxAmount : 4_000_000e6,
        slope     : uint256(4_000_000e6) / 4 hours
    });

    ForeignControllerInit.InitRateLimitData rateLimitData = ForeignControllerInit.InitRateLimitData({
        usdcDepositData          : usdcDepositData,
        usdcWithdrawData         : usdcWithdrawData,
        usdcToCctpData           : usdcToCctpData,
        cctpToEthereumDomainData : cctpToEthereumDomainData
    });

    function setUp() public override {
        super.setUp();

        controllerInst = ForeignControllerDeploy.deployFull(
            admin,
            address(psmBase),
            USDC_BASE,
            CCTP_MESSENGER_BASE
        );

        addresses = ForeignControllerInit.AddressParams({
            admin         : admin,
            freezer       : freezer,
            relayer       : relayer,
            psm           : address(psmBase),
            cctpMessenger : CCTP_MESSENGER_BASE,
            usdc          : USDC_BASE,
            usds          : address(usdsBase),
            susds         : address(susdsBase)
        });

        // Overwrite storage for all previous deployments in setUp and assert deployment

        almProxy          = ALMProxy(controllerInst.almProxy);
        foreignController = ForeignController(controllerInst.controller);
        rateLimits        = RateLimits(controllerInst.rateLimits);

        // Admin will be calling the library from its own address
        vm.etch(admin, address(new LibraryWrapper()).code);

        wrapper = LibraryWrapper(admin);
    }

    function test_init_incorrectAdminAlmProxy() external {
        // Isolate different contracts instead of setting param so can get three different failures
        vm.startPrank(admin);
        almProxy.grantRole(DEFAULT_ADMIN_ROLE, mismatchAddress);
        almProxy.revokeRole(DEFAULT_ADMIN_ROLE, admin);
        vm.stopPrank();

        vm.expectRevert("ForeignControllerInit/incorrect-admin-almProxy");
        wrapper.init(addresses, controllerInst, rateLimitData);
    }

    function test_init_incorrectAdminRateLimits() external {
        // Isolate different contracts instead of setting param so can get three different failures
        vm.startPrank(admin);
        rateLimits.grantRole(DEFAULT_ADMIN_ROLE, mismatchAddress);
        rateLimits.revokeRole(DEFAULT_ADMIN_ROLE, admin);
        vm.stopPrank();

        vm.expectRevert("ForeignControllerInit/incorrect-admin-rateLimits");
        wrapper.init(addresses, controllerInst, rateLimitData);
    }

    function test_init_incorrectAdminController() external {
        // Isolate different contracts instead of setting param so can get three different failures
        vm.startPrank(admin);
        foreignController.grantRole(DEFAULT_ADMIN_ROLE, mismatchAddress);
        foreignController.revokeRole(DEFAULT_ADMIN_ROLE, admin);
        vm.stopPrank();

        vm.expectRevert("ForeignControllerInit/incorrect-admin-controller");
        wrapper.init(addresses, controllerInst, rateLimitData);
    }

    function test_init_incorrectAlmProxy() external {
        // Deploy new address that will not EVM revert on OZ ACL check
        controllerInst.almProxy = address(new ALMProxy(admin));

        vm.expectRevert("ForeignControllerInit/incorrect-almProxy");
        wrapper.init(addresses, controllerInst, rateLimitData);
    }

    function test_init_incorrectRateLimits() external {
        // Deploy new address that will not EVM revert on OZ ACL check
        controllerInst.rateLimits = address(new RateLimits(admin));

        vm.expectRevert("ForeignControllerInit/incorrect-rateLimits");
        wrapper.init(addresses, controllerInst, rateLimitData);
    }

    function test_init_incorrectPsm() external {
        addresses.psm = mismatchAddress;

        vm.expectRevert("ForeignControllerInit/incorrect-psm");
        wrapper.init(addresses, controllerInst, rateLimitData);
    }

    function test_init_incorrectUsdc() external {
        addresses.usdc = mismatchAddress;

        vm.expectRevert("ForeignControllerInit/incorrect-usdc");
        wrapper.init(addresses, controllerInst, rateLimitData);
    }

    function test_init_incorrectCctp() external {
        addresses.cctpMessenger = mismatchAddress;

        vm.expectRevert("ForeignControllerInit/incorrect-cctp");
        wrapper.init(addresses, controllerInst, rateLimitData);
    }

    function test_init_incorrectUsdcDepositData_unlimitedBoundary() external {
        rateLimitData.usdcDepositData.maxAmount = type(uint256).max;

        vm.expectRevert("ForeignControllerInit/invalid-rate-limit-usdcDepositData");
        wrapper.init(addresses, controllerInst, rateLimitData);

        rateLimitData.usdcDepositData.slope = 0;

        wrapper.init(addresses, controllerInst, rateLimitData);
    }

    function test_init_incorrectUsdcWithdrawData_unlimitedBoundary() external {
        rateLimitData.usdcWithdrawData.maxAmount = type(uint256).max;

        vm.expectRevert("ForeignControllerInit/invalid-rate-limit-usdcWithdrawData");
        wrapper.init(addresses, controllerInst, rateLimitData);

        rateLimitData.usdcWithdrawData.slope = 0;

        wrapper.init(addresses, controllerInst, rateLimitData);
    }

    function test_init_incorrectUsdcToCctpData_unlimitedBoundary() external {
        rateLimitData.usdcToCctpData.maxAmount = type(uint256).max;

        vm.expectRevert("ForeignControllerInit/invalid-rate-limit-usdcToCctpData");
        wrapper.init(addresses, controllerInst, rateLimitData);

        rateLimitData.usdcToCctpData.slope = 0;

        wrapper.init(addresses, controllerInst, rateLimitData);
    }

    function test_init_incorrectCctpToEthereumDomainData_unlimitedBoundary() external {
        rateLimitData.cctpToEthereumDomainData.maxAmount = type(uint256).max;

        vm.expectRevert("ForeignControllerInit/invalid-rate-limit-cctpToEthereumDomainData");
        wrapper.init(addresses, controllerInst, rateLimitData);

        rateLimitData.cctpToEthereumDomainData.slope = 0;

        wrapper.init(addresses, controllerInst, rateLimitData);
    }

    function test_init_incorrectUsdcDepositData_maxAmountPrecisionBoundary() external {
        rateLimitData.usdcDepositData.maxAmount = 1e18 + 1;  // 1 USDS, but 1 trillion USDC

        vm.expectRevert("ForeignControllerInit/invalid-max-amount-precision-usdcDepositData");
        wrapper.init(addresses, controllerInst, rateLimitData);

        rateLimitData.usdcDepositData.maxAmount = 1e18;

        wrapper.init(addresses, controllerInst, rateLimitData);
    }

    function test_init_incorrectUsdcWithdrawData_maxAmountPrecisionBoundary() external {
        rateLimitData.usdcWithdrawData.maxAmount = 1e18 + 1;  // 1 USDS, but 1 trillion USDC

        vm.expectRevert("ForeignControllerInit/invalid-max-amount-precision-usdcWithdrawData");
        wrapper.init(addresses, controllerInst, rateLimitData);

        rateLimitData.usdcWithdrawData.maxAmount = 1e18;

        wrapper.init(addresses, controllerInst, rateLimitData);
    }

    function test_init_incorrectUsdcToCctpData_maxAmountPrecisionBoundary() external {
        rateLimitData.usdcToCctpData.maxAmount = 1e18 + 1;  // 1 USDS, but 1 trillion USDC

        vm.expectRevert("ForeignControllerInit/invalid-max-amount-precision-usdcToCctpData");
        wrapper.init(addresses, controllerInst, rateLimitData);

        rateLimitData.usdcToCctpData.maxAmount = 1e18;

        wrapper.init(addresses, controllerInst, rateLimitData);
    }

    function test_init_incorrectCctpToEthereumDomainData_maxAmountPrecisionBoundary() external {
        rateLimitData.cctpToEthereumDomainData.maxAmount = 1e18 + 1;  // 1 USDS, but 1 trillion USDC

        vm.expectRevert("ForeignControllerInit/invalid-max-amount-precision-cctpToEthereumDomainData");
        wrapper.init(addresses, controllerInst, rateLimitData);

        rateLimitData.cctpToEthereumDomainData.maxAmount = 1e18;

        wrapper.init(addresses, controllerInst, rateLimitData);
    }

    function test_init_incorrectUsdcDepositData_slopePrecisionBoundary() external {
        rateLimitData.usdcDepositData.slope = uint256(1e18) / 1 hours + 1;  // 1 USDS, but 1 trillion USDC

        vm.expectRevert("ForeignControllerInit/invalid-slope-precision-usdcDepositData");
        wrapper.init(addresses, controllerInst, rateLimitData);

        rateLimitData.usdcDepositData.slope = uint256(1e18) / 1 hours;

        wrapper.init(addresses, controllerInst, rateLimitData);
    }

    function test_init_incorrectUsdcWithdrawData_slopePrecisionBoundary() external {
        rateLimitData.usdcWithdrawData.slope = uint256(1e18) / 1 hours + 1;  // 1 USDS, but 1 trillion USDC

        vm.expectRevert("ForeignControllerInit/invalid-slope-precision-usdcWithdrawData");
        wrapper.init(addresses, controllerInst, rateLimitData);

        rateLimitData.usdcWithdrawData.slope = uint256(1e18) / 1 hours;

        wrapper.init(addresses, controllerInst, rateLimitData);
    }

    function test_init_incorrectUsdcToCctpData_slopePrecisionBoundary() external {
        rateLimitData.usdcToCctpData.slope = uint256(1e18) / 1 hours + 1;  // 1 USDS, but 1 trillion USDC

        vm.expectRevert("ForeignControllerInit/invalid-slope-precision-usdcToCctpData");
        wrapper.init(addresses, controllerInst, rateLimitData);

        rateLimitData.usdcToCctpData.slope = uint256(1e18) / 1 hours;

        wrapper.init(addresses, controllerInst, rateLimitData);
    }

    function test_init_incorrectCctpToEthereumDomainData_slopePrecisionBoundary() external {
        rateLimitData.cctpToEthereumDomainData.slope = uint256(1e18) / 1 hours + 1;  // 1 USDS, but 1 trillion USDC

        vm.expectRevert("ForeignControllerInit/invalid-slope-precision-cctpToEthereumDomainData");
        wrapper.init(addresses, controllerInst, rateLimitData);

        rateLimitData.cctpToEthereumDomainData.slope = uint256(1e18) / 1 hours;

        wrapper.init(addresses, controllerInst, rateLimitData);
    }

}

contract ForeignControllerDeployAndInitSuccessTests is ForkTestBase {

    function test_deployAllAndInit() external {
        // Perform new deployments against existing fork environment

        ControllerInstance memory controllerInst = ForeignControllerDeploy.deployFull(
            admin,
            address(psmBase),
            USDC_BASE,
            CCTP_MESSENGER_BASE
        );

        // Overwrite storage for all previous deployments in setUp and assert deployment

        almProxy          = ALMProxy(controllerInst.almProxy);
        foreignController = ForeignController(controllerInst.controller);
        rateLimits        = RateLimits(controllerInst.rateLimits);

        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, admin),          true);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, admin),        true);
        assertEq(foreignController.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(address(foreignController.proxy()),      controllerInst.almProxy);
        assertEq(address(foreignController.rateLimits()), controllerInst.rateLimits);
        assertEq(address(foreignController.psm()),        address(psmBase));
        assertEq(address(foreignController.usdc()),       USDC_BASE);
        assertEq(address(foreignController.cctp()),       CCTP_MESSENGER_BASE);

        assertEq(foreignController.active(), true);

        // Perform SubDAO initialization (from governance relay during spell)
        // Setting rate limits to different values from setUp to make assertions more robust

        ForeignControllerInit.AddressParams memory addresses = ForeignControllerInit.AddressParams({
            admin         : admin,
            freezer       : freezer,
            relayer       : relayer,
            psm           : address(psmBase),
            cctpMessenger : CCTP_MESSENGER_BASE,
            usdc          : USDC_BASE,
            usds          : address(usdsBase),
            susds         : address(susdsBase)
        });

        RateLimitData memory usdcDepositData = RateLimitData({
            maxAmount : 1_000_000e6,
            slope     : uint256(1_000_000e6) / 4 hours
        });

        RateLimitData memory usdcWithdrawData = RateLimitData({
            maxAmount : 2_000_000e6,
            slope     : uint256(2_000_000e6) / 4 hours
        });

        RateLimitData memory usdcToCctpData = RateLimitData({
            maxAmount : 3_000_000e6,
            slope     : uint256(1_000_000e6) / 4 hours
        });

        RateLimitData memory cctpToEthereumDomainData = RateLimitData({
            maxAmount : 4_000_000e6,
            slope     : uint256(4_000_000e6) / 4 hours
        });

        ForeignControllerInit.InitRateLimitData memory rateLimitData
            = ForeignControllerInit.InitRateLimitData({
                usdcDepositData          : usdcDepositData,
                usdcWithdrawData         : usdcWithdrawData,
                usdcToCctpData           : usdcToCctpData,
                cctpToEthereumDomainData : cctpToEthereumDomainData
            });

        vm.startPrank(admin);
        ForeignControllerInit.init(
            addresses,
            controllerInst,
            rateLimitData
        );
        vm.stopPrank();

        // Assert SubDAO initialization

        assertEq(foreignController.hasRole(foreignController.FREEZER(), freezer), true);
        assertEq(foreignController.hasRole(foreignController.RELAYER(), relayer), true);

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), address(foreignController)), true);

        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(foreignController)), true);

        bytes32 domainKeyEthereum = RateLimitHelpers.makeDomainKey(
            foreignController.LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM
        );

        _assertDepositRateLimitData(usdcBase, usdcDepositData);

        _assertWithdrawRateLimitData(usdcBase,  usdcWithdrawData);

        _assertRateLimitData(foreignController.LIMIT_USDC_TO_CCTP(), usdcToCctpData);

        _assertRateLimitData(domainKeyEthereum, cctpToEthereumDomainData);
    }

    function _assertDepositRateLimitData(IERC20 asset, RateLimitData memory expectedData) internal {
        bytes32 assetKey = RateLimitHelpers.makeAssetKey(
            foreignController.LIMIT_PSM_DEPOSIT(),
            address(asset)
        );

        _assertRateLimitData(assetKey, expectedData);
    }

    function _assertWithdrawRateLimitData(IERC20 asset, RateLimitData memory expectedData) internal {
        bytes32 assetKey = RateLimitHelpers.makeAssetKey(
            foreignController.LIMIT_PSM_WITHDRAW(),
            address(asset)
        );

        _assertRateLimitData(assetKey, expectedData);
    }

    function _assertRateLimitData(bytes32 domainKey, RateLimitData memory expectedData) internal {
        IRateLimits.RateLimitData memory data = rateLimits.getRateLimitData(domainKey);

        assertEq(data.maxAmount,   expectedData.maxAmount);
        assertEq(data.slope,       expectedData.slope);
        assertEq(data.lastAmount,  expectedData.maxAmount);  // `lastAmount` should be `maxAmount`
        assertEq(data.lastUpdated, block.timestamp);

        assertEq(rateLimits.getCurrentRateLimit(domainKey), expectedData.maxAmount);
    }

}
