// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { ERC20Mock } from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

import { CCTPForwarder } from "xchain-helpers/src/forwarders/CCTPForwarder.sol";

import "test/base-fork/ForkTestBase.t.sol";

import { IRateLimits } from "src/interfaces/IRateLimits.sol";

import { ControllerInstance }      from "deploy/ControllerInstance.sol";
import { ForeignControllerDeploy } from "deploy/ControllerDeploy.sol";

import { ForeignControllerInit, RateLimitData, MintRecipient } from "deploy/ControllerInit.sol";

import { RateLimitHelpers } from "src/RateLimitHelpers.sol";

// Necessary to get error message assertions to work
contract LibraryWrapper {

    function init(
        ForeignControllerInit.AddressParams     memory params,
        ControllerInstance                      memory controllerInst,
        ForeignControllerInit.InitRateLimitData memory data,
        MintRecipient[]                         memory mintRecipients
    )
        external
    {
        ForeignControllerInit.init(params, controllerInst, data, mintRecipients);
    }

}

contract ForeignControllerDeployAndInitTestBase is ForkTestBase {

    // Default params used for all testing, can be overridden where needed.
    function _getDefaultParams()
        internal returns (
            ForeignControllerInit.AddressParams     memory addresses,
            ForeignControllerInit.InitRateLimitData memory rateLimitData,
            MintRecipient[]                         memory mintRecipients
        )
    {
        addresses = ForeignControllerInit.AddressParams({
            admin         : SPARK_EXECUTOR,
            freezer       : freezer,
            relayer       : relayer,
            oldController : address(0),  // Empty
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

        RateLimitData memory usdsDepositData = RateLimitData({
            maxAmount : 3_000_000e6,
            slope     : uint256(3_000_000e6) / 4 hours
        });

        RateLimitData memory usdsWithdrawData = RateLimitData({
            maxAmount : 4_000_000e6,
            slope     : uint256(4_000_000e6) / 4 hours
        });

        RateLimitData memory susdsDepositData = RateLimitData({
            maxAmount : 5_000_000e6,
            slope     : uint256(5_000_000e6) / 4 hours
        });

        RateLimitData memory susdsWithdrawData = RateLimitData({
            maxAmount : 6_000_000e6,
            slope     : uint256(6_000_000e6) / 4 hours
        });

        RateLimitData memory usdcToCctpData = RateLimitData({
            maxAmount : 7_000_000e6,
            slope     : uint256(7_000_000e6) / 4 hours
        });

        RateLimitData memory cctpToEthereumDomainData = RateLimitData({
            maxAmount : 8_000_000e6,
            slope     : uint256(8_000_000e6) / 4 hours
        });

        rateLimitData = ForeignControllerInit.InitRateLimitData({
            usdcDepositData          : usdcDepositData,
            usdcWithdrawData         : usdcWithdrawData,
            usdsDepositData          : usdsDepositData,
            usdsWithdrawData         : usdsWithdrawData,
            susdsDepositData         : susdsDepositData,
            susdsWithdrawData        : susdsWithdrawData,
            usdcToCctpData           : usdcToCctpData,
            cctpToEthereumDomainData : cctpToEthereumDomainData
        });

        mintRecipients = new MintRecipient[](1);

        mintRecipients[0] = MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            mintRecipient : bytes32(uint256(uint160(makeAddr("ethereumAlmProxy"))))
        });
    }

}

contract ForeignControllerDeployAndInitFailureTests is ForeignControllerDeployAndInitTestBase {

    LibraryWrapper wrapper;

    ControllerInstance public controllerInst;

    address public mismatchAddress = makeAddr("mismatchAddress");

    // Default parameters for success that are overridden for failure tests

    ForeignControllerInit.AddressParams     addresses;
    ForeignControllerInit.InitRateLimitData rateLimitData;
    MintRecipient[]                         mintRecipients;

    function setUp() public override {
        super.setUp();

        controllerInst = ForeignControllerDeploy.deployFull(
            SPARK_EXECUTOR,
            address(psmBase),
            USDC_BASE,
            CCTP_MESSENGER_BASE
        );

        MintRecipient[] memory mintRecipients_ = new MintRecipient[](1);

        ( addresses, rateLimitData, mintRecipients_ ) = _getDefaultParams();

        // NOTE: This would need to be refactored to a for loop if more than one recipient
        mintRecipients.push(mintRecipients_[0]);

        // Overwrite storage for all previous deployments in setUp and assert deployment

        almProxy          = ALMProxy(payable(controllerInst.almProxy));
        foreignController = ForeignController(controllerInst.controller);
        rateLimits        = RateLimits(controllerInst.rateLimits);

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
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectAdminRateLimits() external {
        // Isolate different contracts instead of setting param so can get three different failures
        vm.startPrank(SPARK_EXECUTOR);
        rateLimits.grantRole(DEFAULT_ADMIN_ROLE, mismatchAddress);
        rateLimits.revokeRole(DEFAULT_ADMIN_ROLE, SPARK_EXECUTOR);
        vm.stopPrank();

        vm.expectRevert("ForeignControllerInit/incorrect-admin-rateLimits");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectAdminController() external {
        // Isolate different contracts instead of setting param so can get three different failures
        vm.startPrank(SPARK_EXECUTOR);
        foreignController.grantRole(DEFAULT_ADMIN_ROLE, mismatchAddress);
        foreignController.revokeRole(DEFAULT_ADMIN_ROLE, SPARK_EXECUTOR);
        vm.stopPrank();

        vm.expectRevert("ForeignControllerInit/incorrect-admin-controller");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    /**********************************************************************************************/
    /*** Controller constructor failure modes                                                   ***/
    /**********************************************************************************************/

    function test_init_incorrectAlmProxy() external {
        // Deploy new address that will not EVM revert on OZ ACL check
        controllerInst.almProxy = address(new ALMProxy(SPARK_EXECUTOR));

        vm.expectRevert("ForeignControllerInit/incorrect-almProxy");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectRateLimits() external {
        // Deploy new address that will not EVM revert on OZ ACL check
        controllerInst.rateLimits = address(new RateLimits(SPARK_EXECUTOR));

        vm.expectRevert("ForeignControllerInit/incorrect-rateLimits");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectPsm() external {
        addresses.psm = mismatchAddress;

        vm.expectRevert("ForeignControllerInit/incorrect-psm");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectUsdc() external {
        addresses.usdc = mismatchAddress;

        vm.expectRevert("ForeignControllerInit/incorrect-usdc");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectCctp() external {
        addresses.cctpMessenger = mismatchAddress;

        vm.expectRevert("ForeignControllerInit/incorrect-cctp");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_controllerInactive() external {
        // Cheating to set this outside of init scripts so that the controller can be frozen
        vm.prank(SPARK_EXECUTOR);
        foreignController.grantRole(FREEZER, freezer);

        vm.startPrank(freezer);
        foreignController.freeze();
        vm.stopPrank();

        vm.expectRevert("ForeignControllerInit/controller-not-active");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    /**********************************************************************************************/
    /*** Sanity check failure modes                                                             ***/
    /**********************************************************************************************/

    function test_init_oldControllerIsNewController() external {
        addresses.oldController = controllerInst.controller;

        vm.expectRevert("ForeignControllerInit/old-controller-is-new-controller");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_totalAssetsNotSeededBoundary() external {
        // Remove one wei from PSM to make seeded condition not met
        vm.prank(address(0));
        psmBase.withdraw(address(usdsBase), address(this), 1);  // Withdraw one wei from PSM

        assertEq(psmBase.totalAssets(), 1e18 - 1);

        vm.expectRevert("ForeignControllerInit/psm-totalAssets-not-seeded");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        // Approve from address(this) cause it received the one wei
        // Redo the seeding
        usdsBase.approve(address(psmBase), 1);
        psmBase.deposit(address(usdsBase), address(0), 1);

        assertEq(psmBase.totalAssets(), 1e18);

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_totalSharesNotSeededBoundary() external {
        // Remove one wei from PSM to make seeded condition not met
        vm.prank(address(0));
        psmBase.withdraw(address(usdsBase), address(this), 1);  // Withdraw one wei from PSM

        usdsBase.transfer(address(psmBase), 1);  // Transfer one wei to PSM to update totalAssets

        assertEq(psmBase.totalAssets(), 1e18);
        assertEq(psmBase.totalShares(), 1e18 - 1);

        vm.expectRevert("ForeignControllerInit/psm-totalShares-not-seeded");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        // Do deposit to update shares, need to do 2 wei to get back to 1e18 because of rounding
        deal(address(usdsBase), address(this), 2);
        usdsBase.approve(address(psmBase), 2);
        psmBase.deposit(address(usdsBase), address(0), 2);

        assertEq(psmBase.totalAssets(), 1e18 + 2);
        assertEq(psmBase.totalShares(), 1e18);

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
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

        addresses.psm = address(psmBase);  // Overwrite to point to misconfigured PSM

        vm.expectRevert("ForeignControllerInit/psm-incorrect-usdc");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
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

        addresses.psm = address(psmBase);  // Overwrite to point to misconfigured PSM

        vm.expectRevert("ForeignControllerInit/psm-incorrect-usds");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
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

        addresses.psm = address(psmBase);  // Overwrite to point to misconfigured PSM

        vm.expectRevert("ForeignControllerInit/psm-incorrect-susds");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    /**********************************************************************************************/
    /*** Rate limit unlimited boundary failure modes                                            ***/
    /**********************************************************************************************/

    function test_init_incorrectUsdcDepositData_unlimitedBoundary() external {
        rateLimitData.usdcDepositData.maxAmount = type(uint256).max;

        vm.expectRevert("ForeignControllerInit/invalid-rate-limit-usdcDepositData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.usdcDepositData.slope = 0;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectUsdcWithdrawData_unlimitedBoundary() external {
        rateLimitData.usdcWithdrawData.maxAmount = type(uint256).max;

        vm.expectRevert("ForeignControllerInit/invalid-rate-limit-usdcWithdrawData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.usdcWithdrawData.slope = 0;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectUsdsDepositData_unlimitedBoundary() external {
        rateLimitData.usdsDepositData.maxAmount = type(uint256).max;

        vm.expectRevert("ForeignControllerInit/invalid-rate-limit-usdsDepositData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.usdsDepositData.slope = 0;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectUsdsWithdrawData_unlimitedBoundary() external {
        rateLimitData.usdsWithdrawData.maxAmount = type(uint256).max;

        vm.expectRevert("ForeignControllerInit/invalid-rate-limit-usdsWithdrawData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.usdsWithdrawData.slope = 0;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectSUsdsDepositData_unlimitedBoundary() external {
        rateLimitData.susdsDepositData.maxAmount = type(uint256).max;

        vm.expectRevert("ForeignControllerInit/invalid-rate-limit-susdsDepositData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.susdsDepositData.slope = 0;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectSUsdsWithdrawData_unlimitedBoundary() external {
        rateLimitData.susdsWithdrawData.maxAmount = type(uint256).max;

        vm.expectRevert("ForeignControllerInit/invalid-rate-limit-susdsWithdrawData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.susdsWithdrawData.slope = 0;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectUsdcToCctpData_unlimitedBoundary() external {
        rateLimitData.usdcToCctpData.maxAmount = type(uint256).max;

        vm.expectRevert("ForeignControllerInit/invalid-rate-limit-usdcToCctpData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.usdcToCctpData.slope = 0;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectCctpToEthereumDomainData_unlimitedBoundary() external {
        rateLimitData.cctpToEthereumDomainData.maxAmount = type(uint256).max;

        vm.expectRevert("ForeignControllerInit/invalid-rate-limit-cctpToEthereumDomainData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.cctpToEthereumDomainData.slope = 0;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    /**********************************************************************************************/
    /*** Rate limit max amount precision boundary failure modes                                 ***/
    /**********************************************************************************************/

    function test_init_incorrectUsdcDepositData_maxAmountPrecisionBoundary() external {
        rateLimitData.usdcDepositData.maxAmount = 1e18 + 1;  // 1 USDS, but 1 trillion USDC

        vm.expectRevert("ForeignControllerInit/invalid-max-amount-precision-usdcDepositData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.usdcDepositData.maxAmount = 1e18;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectUsdcWithdrawData_maxAmountPrecisionBoundary() external {
        rateLimitData.usdcWithdrawData.maxAmount = 1e18 + 1;  // 1 USDS, but 1 trillion USDC

        vm.expectRevert("ForeignControllerInit/invalid-max-amount-precision-usdcWithdrawData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.usdcWithdrawData.maxAmount = 1e18;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectUsdsDepositData_maxAmountPrecisionBoundary() external {
        rateLimitData.usdsDepositData.maxAmount = 1e30 + 1;

        vm.expectRevert("ForeignControllerInit/invalid-max-amount-precision-usdsDepositData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.usdsDepositData.maxAmount = 1e30;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectUsdsWithdrawData_maxAmountPrecisionBoundary() external {
        rateLimitData.usdsWithdrawData.maxAmount = 1e30 + 1;

        vm.expectRevert("ForeignControllerInit/invalid-max-amount-precision-usdsWithdrawData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.usdsWithdrawData.maxAmount = 1e30;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectSUsdsDepositData_maxAmountPrecisionBoundary() external {
        rateLimitData.susdsDepositData.maxAmount = 1e30 + 1;

        vm.expectRevert("ForeignControllerInit/invalid-max-amount-precision-susdsDepositData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.susdsDepositData.maxAmount = 1e30;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectSUsdsWithdrawData_maxAmountPrecisionBoundary() external {
        rateLimitData.susdsWithdrawData.maxAmount = 1e30 + 1;

        vm.expectRevert("ForeignControllerInit/invalid-max-amount-precision-susdsWithdrawData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.susdsWithdrawData.maxAmount = 1e30;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectUsdcToCctpData_maxAmountPrecisionBoundary() external {
        rateLimitData.usdcToCctpData.maxAmount = 1e18 + 1;  // 1 USDS, but 1 trillion USDC

        vm.expectRevert("ForeignControllerInit/invalid-max-amount-precision-usdcToCctpData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.usdcToCctpData.maxAmount = 1e18;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectCctpToEthereumDomainData_maxAmountPrecisionBoundary() external {
        rateLimitData.cctpToEthereumDomainData.maxAmount = 1e18 + 1;  // 1 USDS, but 1 trillion USDC

        vm.expectRevert("ForeignControllerInit/invalid-max-amount-precision-cctpToEthereumDomainData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.cctpToEthereumDomainData.maxAmount = 1e18;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    /**********************************************************************************************/
    /*** Rate limit slope precision boundary failure modes                                      ***/
    /**********************************************************************************************/

    function test_init_incorrectUsdcDepositData_slopePrecisionBoundary() external {
        rateLimitData.usdcDepositData.slope = uint256(1e18) / 1 hours + 1;  // 1 USDS, but 1 trillion USDC

        vm.expectRevert("ForeignControllerInit/invalid-slope-precision-usdcDepositData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.usdcDepositData.slope = uint256(1e18) / 1 hours;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectUsdcWithdrawData_slopePrecisionBoundary() external {
        rateLimitData.usdcWithdrawData.slope = uint256(1e18) / 1 hours + 1;  // 1 USDS, but 1 trillion USDC

        vm.expectRevert("ForeignControllerInit/invalid-slope-precision-usdcWithdrawData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.usdcWithdrawData.slope = uint256(1e18) / 1 hours;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectUsdsDepositData_slopePrecisionBoundary() external {
        rateLimitData.usdsDepositData.slope = uint256(1e30) / 1 hours + 1;

        vm.expectRevert("ForeignControllerInit/invalid-slope-precision-usdsDepositData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.usdsDepositData.slope = uint256(1e30) / 1 hours;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectUsdsWithdrawData_slopePrecisionBoundary() external {
        rateLimitData.usdsWithdrawData.slope = uint256(1e30) / 1 hours + 1;

        vm.expectRevert("ForeignControllerInit/invalid-slope-precision-usdsWithdrawData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.usdsWithdrawData.slope = uint256(1e30) / 1 hours;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectSUsdsDepositData_slopePrecisionBoundary() external {
        rateLimitData.susdsDepositData.slope = uint256(1e30) / 1 hours + 1;

        vm.expectRevert("ForeignControllerInit/invalid-slope-precision-susdsDepositData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.susdsDepositData.slope = uint256(1e30) / 1 hours;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectSUsdsWithdrawData_slopePrecisionBoundary() external {
        rateLimitData.susdsWithdrawData.slope = uint256(1e30) / 1 hours + 1;

        vm.expectRevert("ForeignControllerInit/invalid-slope-precision-susdsWithdrawData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.susdsWithdrawData.slope = uint256(1e30) / 1 hours;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectUsdcToCctpData_slopePrecisionBoundary() external {
        rateLimitData.usdcToCctpData.slope = uint256(1e18) / 1 hours + 1;  // 1 USDS, but 1 trillion USDC

        vm.expectRevert("ForeignControllerInit/invalid-slope-precision-usdcToCctpData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.usdcToCctpData.slope = uint256(1e18) / 1 hours;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_incorrectCctpToEthereumDomainData_slopePrecisionBoundary() external {
        rateLimitData.cctpToEthereumDomainData.slope = uint256(1e18) / 1 hours + 1;  // 1 USDS, but 1 trillion USDC

        vm.expectRevert("ForeignControllerInit/invalid-slope-precision-cctpToEthereumDomainData");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);

        rateLimitData.cctpToEthereumDomainData.slope = uint256(1e18) / 1 hours;

        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    /**********************************************************************************************/
    /*** Old controller role check tests                                                        ***/
    /**********************************************************************************************/

    function test_init_oldControllerDoesNotHaveRoleInAlmProxy() external {
        _deployNewControllerAfterExistingControllerInit();

        // Revoke the old controller address in ALM proxy

        vm.startPrank(SPARK_EXECUTOR);
        almProxy.revokeRole(almProxy.CONTROLLER(), addresses.oldController);
        vm.stopPrank();

        // Try to init with the old controller address that is doesn't have the CONTROLLER role

        vm.expectRevert("ForeignControllerInit/old-controller-not-almProxy-controller");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    function test_init_oldControllerDoesNotHaveRoleInRateLimits() external {
        _deployNewControllerAfterExistingControllerInit();

        // Revoke the old controller address

        vm.startPrank(SPARK_EXECUTOR);
        rateLimits.revokeRole(rateLimits.CONTROLLER(), addresses.oldController);
        vm.stopPrank();

        // Try to init with the old controller address that is doesn't have the CONTROLLER role

        vm.expectRevert("ForeignControllerInit/old-controller-not-rateLimits-controller");
        wrapper.init(addresses, controllerInst, rateLimitData, mintRecipients);
    }

    /**********************************************************************************************/
    /*** Helper functions                                                                       ***/
    /**********************************************************************************************/

    function _deployNewControllerAfterExistingControllerInit() internal {
        // Successfully init first controller

        vm.startPrank(SPARK_EXECUTOR);
        ForeignControllerInit.init(
            addresses,
            controllerInst,
            rateLimitData,
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

        addresses.oldController = address(foreignController);
    }

}

contract ForeignControllerDeployAndInitSuccessTests is ForeignControllerDeployAndInitTestBase {

    function test_deployAllAndInit() external {
        // Perform new deployments against existing fork environment

        ControllerInstance memory controllerInst = ForeignControllerDeploy.deployFull(
            SPARK_EXECUTOR,
            address(psmBase),
            USDC_BASE,
            CCTP_MESSENGER_BASE
        );

        // Overwrite storage for all previous deployments in setUp and assert deployment

        almProxy          = ALMProxy(payable(controllerInst.almProxy));
        foreignController = ForeignController(controllerInst.controller);
        rateLimits        = RateLimits(controllerInst.rateLimits);

        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, SPARK_EXECUTOR),          true);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, SPARK_EXECUTOR),        true);
        assertEq(foreignController.hasRole(DEFAULT_ADMIN_ROLE, SPARK_EXECUTOR), true);

        assertEq(address(foreignController.proxy()),      controllerInst.almProxy);
        assertEq(address(foreignController.rateLimits()), controllerInst.rateLimits);
        assertEq(address(foreignController.psm()),        address(psmBase));
        assertEq(address(foreignController.usdc()),       USDC_BASE);
        assertEq(address(foreignController.cctp()),       CCTP_MESSENGER_BASE);

        assertEq(foreignController.active(), true);

        // Perform SubDAO initialization (from governance relay during spell)
        // Setting rate limits to different values from setUp to make assertions more robust

        (
            ForeignControllerInit.AddressParams     memory addresses,
            ForeignControllerInit.InitRateLimitData memory rateLimitData,
            MintRecipient[]                         memory mintRecipients
        ) = _getDefaultParams();

        vm.startPrank(SPARK_EXECUTOR);
        ForeignControllerInit.init(
            addresses,
            controllerInst,
            rateLimitData,
            mintRecipients
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

        _assertDepositRateLimitData(usdcBase,  rateLimitData.usdcDepositData);
        _assertDepositRateLimitData(usdsBase,  rateLimitData.usdsDepositData);
        _assertDepositRateLimitData(susdsBase, rateLimitData.susdsDepositData);

        _assertWithdrawRateLimitData(usdcBase,  rateLimitData.usdcWithdrawData);
        _assertWithdrawRateLimitData(usdsBase,  rateLimitData.usdsWithdrawData);
        _assertWithdrawRateLimitData(susdsBase, rateLimitData.susdsWithdrawData);

        _assertRateLimitData(foreignController.LIMIT_USDC_TO_CCTP(), rateLimitData.usdcToCctpData);

        _assertRateLimitData(domainKeyEthereum, rateLimitData.cctpToEthereumDomainData);

        assertEq(
            foreignController.mintRecipients(mintRecipients[0].domain),
            mintRecipients[0].mintRecipient
        );

        assertEq(
            foreignController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
            bytes32(uint256(uint160(makeAddr("ethereumAlmProxy"))))
        );
    }

    function test_init_transferAclToNewController() public {
        ControllerInstance memory controllerInst = ForeignControllerDeploy.deployFull(
            SPARK_EXECUTOR,
            address(psmBase),
            USDC_BASE,
            CCTP_MESSENGER_BASE
        );

        (
            ForeignControllerInit.AddressParams     memory addresses,
            ForeignControllerInit.InitRateLimitData memory rateLimitData,
            MintRecipient[]                         memory mintRecipients
        ) = _getDefaultParams();

        vm.startPrank(SPARK_EXECUTOR);
        ForeignControllerInit.init(
            addresses,
            controllerInst,
            rateLimitData,
            mintRecipients
        );
        vm.stopPrank();

        // Example of how an upgrade would work
        address newController = ForeignControllerDeploy.deployController(
            SPARK_EXECUTOR,
            controllerInst.almProxy,
            controllerInst.rateLimits,
            address(psmBase),
            USDC_BASE,
            CCTP_MESSENGER_BASE
        );

        // Overwrite storage of previous deployments in setUp

        almProxy   = ALMProxy(payable(controllerInst.almProxy));
        rateLimits = RateLimits(controllerInst.rateLimits);

        address oldController = address(controllerInst.controller);

        controllerInst.controller = newController;  // Overwrite struct for param

        // All other info is the same, just need to transfer ACL
        addresses.oldController = oldController;

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     oldController), true);
        assertEq(almProxy.hasRole(almProxy.CONTROLLER(),     oldController), true);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), newController), false);
        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), newController), false);

        vm.startPrank(SPARK_EXECUTOR);
        ForeignControllerInit.init(
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
