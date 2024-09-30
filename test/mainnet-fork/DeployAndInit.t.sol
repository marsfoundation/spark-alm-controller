// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/mainnet-fork/ForkTestBase.t.sol";

import { IRateLimits } from "src/interfaces/IRateLimits.sol";

import { ControllerInstance }                  from "../../deploy/ControllerInstance.sol";
import { MainnetControllerDeploy }             from "../../deploy/ControllerDeploy.sol";
import { MainnetControllerInit, RateLimitData} from "../../deploy/ControllerInit.sol";

// TODO: Refactor to use live contracts
// TODO: Declare Inst structs to emulate mainnet
// NOTE: Allocation should be deployed prior to Controller

contract MainnetControllerDeployAndInit is ForkTestBase {

    function test_deployAllAndInit() external {
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
        MainnetControllerInit.makerInit(PSM, controllerInst.almProxy);
        vm.stopPrank();

        // Assert Maker initialization

        assertEq(IPSMLike(PSM).bud(controllerInst.almProxy), 1);
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
