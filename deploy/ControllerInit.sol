// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

// Multiple inits, all config is done, one for pause proxy one for spark proxy
// TODO: Add interfaces for controllers

import { AllocatorIlkInstance } from "lib/dss-allocator/deploy/AllocatorInstances.sol";

import { UsdsInstance } from "lib/usds/deploy/UsdsInstance.sol";

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { ALMProxy }          from "src/ALMProxy.sol";
import { ForeignController } from "src/ForeignController.sol";
import { MainnetController } from "src/MainnetController.sol";
import { RateLimitHelpers }  from "src/RateLimitHelpers.sol";
import { RateLimits }        from "src/RateLimits.sol";

import { ControllerInstance } from "./ControllerInstance.sol";

interface IBufferLike {
    function approve(address, address, uint256) external;
}

interface IPSMLike {
    function kiss(address) external;
}

interface IVaultLike {
    function rely(address) external;
}

library MainnetControllerInit {

    struct RateLimitData {
        uint256 maxAmount;
        uint256 slope;
    }

    function subDaoInit(
        address              freezer,
        address              relayer,
        ControllerInstance   memory controllerInst,
        AllocatorIlkInstance memory ilkInst,
        UsdsInstance         memory usdsInst,
        RateLimitData        memory usdsMintData,
        RateLimitData        memory usdcToUsdsData,
        RateLimitData        memory usdcToCctpData,
        RateLimitData        memory cctpToBaseDomainData
    )
        internal
    {
        ALMProxy          almProxy   = ALMProxy(controllerInst.almProxy);
        MainnetController controller = MainnetController(controllerInst.controller);
        RateLimits        rateLimits = RateLimits(controllerInst.rateLimits);

        // Step 1: Configure ACL permissions for controller and almProxy

        controller.grantRole(controller.FREEZER(), freezer);
        controller.grantRole(controller.RELAYER(), relayer);

        almProxy.grantRole(almProxy.CONTROLLER(), address(controller));

        rateLimits.grantRole(rateLimits.CONTROLLER(), address(controller));

        // Step 2: Configure all rate limits for controller, using Base as only domain

        bytes32 domainKeyBase = RateLimitHelpers.makeDomainKey(
            controller.LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE
        );

        rateLimits.setRateLimitData(controller.LIMIT_USDS_MINT(),    usdsMintData.maxAmount,         usdsMintData.slope);
        rateLimits.setRateLimitData(controller.LIMIT_USDS_TO_USDC(), usdcToUsdsData.maxAmount,       usdcToUsdsData.slope);
        rateLimits.setRateLimitData(controller.LIMIT_USDC_TO_CCTP(), usdcToCctpData.maxAmount,       usdcToCctpData.slope);
        rateLimits.setRateLimitData(domainKeyBase,                   cctpToBaseDomainData.maxAmount, cctpToBaseDomainData.slope);

        // Step 3: Configure almProxy within the allocation system

        IVaultLike(ilkInst.vault).rely(controllerInst.almProxy);
        IBufferLike(ilkInst.buffer).approve(usdsInst.usds, controllerInst.almProxy, type(uint256).max);
    }

    function makerInit(address psm, address almProxy) internal {
        IPSMLike(psm).kiss(almProxy);  // To allow using no fee functionality
    }

}

library ForeignControllerInit {

    // Avoid stack too deep
    struct AddressParams {
        address freezer;
        address relayer;
        address usdc;
        address usds;
        address susds;
    }

    struct RateLimitData {
        uint256 maxAmount;
        uint256 slope;
    }

    struct InitRateLimitData {
        RateLimitData usdcDepositData;
        RateLimitData usdsDepositData;
        RateLimitData susdsDepositData;
        RateLimitData usdcWithdrawData;
        RateLimitData usdsWithdrawData;
        RateLimitData susdsWithdrawData;
    }

    function init(
        AddressParams      memory params,
        ControllerInstance memory controllerInst,
        InitRateLimitData  memory data
    )
        internal
    {
        ALMProxy          almProxy   = ALMProxy(controllerInst.almProxy);
        ForeignController controller = ForeignController(controllerInst.controller);
        RateLimits        rateLimits = RateLimits(controllerInst.rateLimits);

        // Step 1: Configure ACL permissions for controller and almProxy

        controller.grantRole(controller.FREEZER(), params.freezer);
        controller.grantRole(controller.RELAYER(), params.relayer);

        almProxy.grantRole(almProxy.CONTROLLER(), address(controller));

        rateLimits.grantRole(rateLimits.CONTROLLER(), address(controller));

        // Step 2: Configure all rate limits for controller

        bytes32 depositKey  = controller.LIMIT_PSM_DEPOSIT();
        bytes32 withdrawKey = controller.LIMIT_PSM_WITHDRAW();

        rateLimits.setRateLimitData(_makeKey(depositKey, params.usdc),  data.usdcDepositData.maxAmount,  data.usdcDepositData.slope);
        rateLimits.setRateLimitData(_makeKey(depositKey, params.usds),  data.usdsDepositData.maxAmount,  data.usdsDepositData.slope);
        rateLimits.setRateLimitData(_makeKey(depositKey, params.susds), data.susdsDepositData.maxAmount, data.susdsDepositData.slope);

        rateLimits.setRateLimitData(_makeKey(withdrawKey, params.usdc),  data.usdcWithdrawData.maxAmount,  data.usdcWithdrawData.slope);
        rateLimits.setRateLimitData(_makeKey(withdrawKey, params.usds),  data.usdsWithdrawData.maxAmount,  data.usdsWithdrawData.slope);
        rateLimits.setRateLimitData(_makeKey(withdrawKey, params.susds), data.susdsWithdrawData.maxAmount, data.susdsWithdrawData.slope);
    }

    function _makeKey(bytes32 actionKey, address asset)
        internal pure returns (bytes32)
    {
        return RateLimitHelpers.makeAssetKey(actionKey, asset);
    }

}
