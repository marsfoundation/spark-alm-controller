// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/mainnet-fork/ForkTestBase.t.sol";

import { IRateLimits } from "src/interfaces/IRateLimits.sol";

import { ControllerInstance }      from "../../deploy/ControllerInstance.sol";
import { MainnetControllerDeploy } from "../../deploy/ControllerDeploy.sol";
import { MainnetControllerInit }   from "../../deploy/ControllerInit.sol";

// TODO: Refactor to use live contracts
// TODO: Declare Inst structs to emulate mainnet
// NOTE: Allocation should be deployed prior to Controller

contract MainnetControllerDeployAndInit is ForkTestBase {

    function test_deployAllAndInit() external {
        // Perform deployment

        ControllerInstance memory controllerInst = MainnetControllerDeploy.deployFull(
            SPARK_PROXY,
            ilkInst.vault,
            ilkInst.buffer,
            PSM,
            usdsInst.daiUsds,
            CCTP_MESSENGER,
            susdsInst.sUsds
        );

        // Assert deployment

        ALMProxy          almProxy   = ALMProxy(controllerInst.almProxy);
        MainnetController controller = MainnetController(controllerInst.controller);
        RateLimits        rateLimits = RateLimits(controllerInst.rateLimits);

        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY),   true);
        assertEq(controller.hasRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY), true);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, SPARK_PROXY), true);

        assertEq(address(controller.proxy()),      controllerInst.almProxy);
        assertEq(address(controller.rateLimits()), controllerInst.rateLimits);
        assertEq(address(controller.vault()),      ilkInst.vault);
        assertEq(address(controller.buffer()),     ilkInst.buffer);
        assertEq(address(controller.psm()),        PSM);
        assertEq(address(controller.daiUsds()),    usdsInst.daiUsds);
        assertEq(address(controller.cctp()),       CCTP_MESSENGER);
        assertEq(address(controller.susds()),      susdsInst.sUsds);
        assertEq(address(controller.dai()),        address(dai));
        assertEq(address(controller.usdc()),       address(usdc));
        assertEq(address(controller.usds()),       address(usds));

        assertEq(controller.psmTo18ConversionFactor(), 1e12);
        assertEq(controller.active(),                  true);

        // Perform initialization (from SPARK_PROXY during spell)

        MainnetControllerInit.RateLimitData memory usdsMintData = MainnetControllerInit.RateLimitData({
            maxAmount : 5_000_000e18,
            slope     : uint256(1_000_000e18) / 4 hours
        });

        MainnetControllerInit.RateLimitData memory usdcToUsdsData = MainnetControllerInit.RateLimitData({
            maxAmount : 5_000_000e18,
            slope     : uint256(1_000_000e18) / 4 hours
        });

        MainnetControllerInit.RateLimitData memory usdcToCctpData = MainnetControllerInit.RateLimitData({
            maxAmount : 5_000_000e18,
            slope     : uint256(1_000_000e18) / 4 hours
        });

        MainnetControllerInit.RateLimitData memory cctpToBaseDomainData = MainnetControllerInit.RateLimitData({
            maxAmount : 5_000_000e18,
            slope     : uint256(1_000_000e18) / 4 hours
        });

        vm.startPrank(SPARK_PROXY);
        MainnetControllerInit.subDaoInit(
            freezer,
            relayer,
            controllerInst,
            ilkInst,
            usdsInst,
            usdsMintData,
            usdcToUsdsData,
            usdcToCctpData,
            cctpToBaseDomainData
        );

        // Assert initialization

        assertEq(controller.hasRole(controller.FREEZER(), freezer), true);
        assertEq(controller.hasRole(controller.RELAYER(), relayer), true);

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), address(controller)), true);

        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(controller)), true);

        bytes32 domainKeyBase = RateLimitHelpers.makeDomainKey(
            controller.LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE
        );

        _assertRateLimitData(controller.LIMIT_USDS_MINT(),    usdsMintData.maxAmount,         usdsMintData.slope);
        _assertRateLimitData(controller.LIMIT_USDS_TO_USDC(), usdcToUsdsData.maxAmount,       usdcToUsdsData.slope);
        _assertRateLimitData(controller.LIMIT_USDC_TO_CCTP(), usdcToCctpData.maxAmount,       usdcToCctpData.slope);
        _assertRateLimitData(domainKeyBase,                   cctpToBaseDomainData.maxAmount, cctpToBaseDomainData.slope);

        assertEq(IVaultLike(ilkInst.vault).wards(address(controller)), 1);

        assertEq(usds.allowance(ilkInst.buffer, controllerInst.almProxy), type(uint256).max);
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
