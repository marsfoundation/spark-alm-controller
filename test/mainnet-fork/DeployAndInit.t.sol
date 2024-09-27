// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/mainnet-fork/ForkTestBase.t.sol";

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
        MainnetControllerInit.init(
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
    }

}
