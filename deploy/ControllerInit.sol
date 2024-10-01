// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { AllocatorIlkInstance } from "lib/dss-allocator/deploy/AllocatorInstances.sol";

import { IAccessControl } from "lib/openzeppelin-contracts/contracts/access/IAccessControl.sol";

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { ForeignController } from "src/ForeignController.sol";
import { MainnetController } from "src/MainnetController.sol";
import { RateLimitHelpers }  from "src/RateLimitHelpers.sol";

import { IALMProxy }   from "src/interfaces/IALMProxy.sol";
import { IRateLimits } from "src/interfaces/IRateLimits.sol";

import { ControllerInstance } from "./ControllerInstance.sol";

interface IBufferLike {
    function approve(address, address, uint256) external;
}

interface IForeignControllerLike is IAccessControl {
    function FREEZER() external view returns (bytes32);
    function LIMIT_PSM_DEPOSIT() external view returns (bytes32);
    function LIMIT_PSM_WITHDRAW() external view returns (bytes32);
    function RELAYER() external view returns (bytes32);
}

interface IPSMLike {
    function kiss(address) external;
}

interface IVaultLike {
    function rely(address) external;
}

struct RateLimitData {
    uint256 maxAmount;
    uint256 slope;
}

library MainnetControllerInit {

    struct AddressParams {
        address admin;
        address freezer;
        address relayer;
        address psm;
        address cctpMessenger;
        address dai;
        address daiUsds;
        address usdc;
        address usds;
        address susds;
    }

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    function subDaoInitController(
        AddressParams        memory params,
        ControllerInstance   memory controllerInst,
        AllocatorIlkInstance memory ilkInst,
        RateLimitData        memory usdsMintData,
        RateLimitData        memory usdcToUsdsData,
        RateLimitData        memory usdcToCctpData,
        RateLimitData        memory cctpToBaseDomainData
    )
        internal
    {
        IALMProxy   almProxy   = IALMProxy(controllerInst.almProxy);
        IRateLimits rateLimits = IRateLimits(controllerInst.rateLimits);

        MainnetController controller = MainnetController(controllerInst.controller);

        // Step 1: Perform sanity checks

        require(controller.hasRole(DEFAULT_ADMIN_ROLE, params.admin) == true, "MainnetControllerInit/incorrect-admin-controller");

        require(address(controller.proxy())      == controllerInst.almProxy,   "MainnetControllerInit/incorrect-almProxy");
        require(address(controller.rateLimits()) == controllerInst.rateLimits, "MainnetControllerInit/incorrect-rateLimits");
        require(address(controller.vault())      == ilkInst.vault,             "MainnetControllerInit/incorrect-vault");
        require(address(controller.buffer())     == ilkInst.buffer,            "MainnetControllerInit/incorrect-buffer");
        require(address(controller.psm())        == params.psm,                "MainnetControllerInit/incorrect-psm");
        require(address(controller.daiUsds())    == params.daiUsds,            "MainnetControllerInit/incorrect-daiUsds");
        require(address(controller.cctp())       == params.cctpMessenger,      "MainnetControllerInit/incorrect-cctpMessenger");
        require(address(controller.susds())      == params.susds,              "MainnetControllerInit/incorrect-susds");
        require(address(controller.dai())        == params.dai,                "MainnetControllerInit/incorrect-dai");
        require(address(controller.usdc())       == params.usdc,               "MainnetControllerInit/incorrect-usdc");
        require(address(controller.usds())       == params.usds,               "MainnetControllerInit/incorrect-usds");

        require(controller.psmTo18ConversionFactor() == 1e12, "MainnetControllerInit/incorrect-psmTo18ConversionFactor");
        require(controller.active()                  == true, "MainnetControllerInit/controller-not-active");

        // Step 2: Configure ACL permissions for controller and almProxy

        controller.grantRole(controller.FREEZER(), params.freezer);
        controller.grantRole(controller.RELAYER(), params.relayer);

        almProxy.grantRole(almProxy.CONTROLLER(), address(controller));

        rateLimits.grantRole(rateLimits.CONTROLLER(), address(controller));

        // Step 3: Configure all rate limits for controller, using Base as only domain

        // Sanity check all rate limit data
        _checkUnlimitedData(usdsMintData,         "usdsMintData");
        _checkUnlimitedData(usdcToUsdsData,       "usdcToUsdsData");
        _checkUnlimitedData(usdcToCctpData,       "usdcToCctpData");
        _checkUnlimitedData(cctpToBaseDomainData, "cctpToBaseDomainData");

        bytes32 domainKeyBase = RateLimitHelpers.makeDomainKey(
            controller.LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE
        );

        rateLimits.setRateLimitData(controller.LIMIT_USDS_MINT(),    usdsMintData.maxAmount,         usdsMintData.slope);
        rateLimits.setRateLimitData(controller.LIMIT_USDS_TO_USDC(), usdcToUsdsData.maxAmount,       usdcToUsdsData.slope);
        rateLimits.setRateLimitData(controller.LIMIT_USDC_TO_CCTP(), usdcToCctpData.maxAmount,       usdcToCctpData.slope);
        rateLimits.setRateLimitData(domainKeyBase,                   cctpToBaseDomainData.maxAmount, cctpToBaseDomainData.slope);
    }

    function subDaoInitFull(
        AddressParams        memory params,
        ControllerInstance   memory controllerInst,
        AllocatorIlkInstance memory ilkInst,
        RateLimitData        memory usdsMintData,
        RateLimitData        memory usdcToUsdsData,
        RateLimitData        memory usdcToCctpData,
        RateLimitData        memory cctpToBaseDomainData
    )
        internal
    {
        // Step 1: Perform initial sanity checks

        require(
            IALMProxy(controllerInst.almProxy).hasRole(DEFAULT_ADMIN_ROLE, params.admin) == true,
            "MainnetControllerInit/incorrect-admin-almProxy"
        );

        require(
            IRateLimits(controllerInst.rateLimits).hasRole(DEFAULT_ADMIN_ROLE, params.admin) == true,
            "MainnetControllerInit/incorrect-admin-rateLimits"
        );

        // Step 2: Perform controller sanity checks, configure ACL permissions for controller
        //         and almProxy and rate limits.

        subDaoInitController(
            params,
            controllerInst,
            ilkInst,
            usdsMintData,
            usdcToUsdsData,
            usdcToCctpData,
            cctpToBaseDomainData
        );

        // Step 3: Configure almProxy within the allocation system

        IVaultLike(ilkInst.vault).rely(controllerInst.almProxy);
        IBufferLike(ilkInst.buffer).approve(params.usds, controllerInst.almProxy, type(uint256).max);
    }

    function pauseProxyInit(address psm, address almProxy) internal {
        IPSMLike(psm).kiss(almProxy);  // To allow using no fee functionality
    }

    function _checkUnlimitedData(RateLimitData memory data, string memory name) internal pure {
        if (data.maxAmount == type(uint256).max) {
            require(
                data.slope == 0,
                string(abi.encodePacked("MainnetControllerInit/invalid-rate-limit-", name))
            );
        }
    }

}

library ForeignControllerInit {

    struct AddressParams {
        address admin;
        address freezer;
        address relayer;
        address psm;
        address cctpMessenger;
        address usdc;
        address usds;
        address susds;
    }

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

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
        IALMProxy   almProxy   = IALMProxy(controllerInst.almProxy);
        IRateLimits rateLimits = IRateLimits(controllerInst.rateLimits);

        ForeignController controller = ForeignController(controllerInst.controller);

        require(almProxy.hasRole(DEFAULT_ADMIN_ROLE, params.admin)   == true, "ForeignControllerInit/incorrect-admin-almProxy");
        require(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, params.admin) == true, "ForeignControllerInit/incorrect-admin-rateLimits");
        require(controller.hasRole(DEFAULT_ADMIN_ROLE, params.admin) == true, "ForeignControllerInit/incorrect-admin-controller");

        require(address(controller.proxy())      == controllerInst.almProxy,   "ForeignControllerInit/incorrect-almProxy");
        require(address(controller.rateLimits()) == controllerInst.rateLimits, "ForeignControllerInit/incorrect-rateLimits");
        require(address(controller.psm())        == params.psm,                "ForeignControllerInit/incorrect-psm");
        require(address(controller.usdc())       == params.usdc,               "ForeignControllerInit/incorrect-usdc");
        require(address(controller.cctp())       == params.cctpMessenger,      "ForeignControllerInit/incorrect-cctp");

        // Step 1: Configure ACL permissions for controller and almProxy

        controller.grantRole(controller.FREEZER(), params.freezer);
        controller.grantRole(controller.RELAYER(), params.relayer);

        almProxy.grantRole(almProxy.CONTROLLER(), address(controller));

        rateLimits.grantRole(rateLimits.CONTROLLER(), address(controller));

        // Step 2: Configure all rate limits for controller

        // Sanity check all rate limit data
        _checkUnlimitedData(data.usdcDepositData,  "usdcDepositData");
        _checkUnlimitedData(data.usdsDepositData,  "usdsDepositData");
        _checkUnlimitedData(data.susdsDepositData, "susdsDepositData");

        _checkUnlimitedData(data.usdcWithdrawData,  "usdcWithdrawData");
        _checkUnlimitedData(data.usdsWithdrawData,  "usdsWithdrawData");
        _checkUnlimitedData(data.susdsWithdrawData, "susdsWithdrawData");

        bytes32 depositKey  = controller.LIMIT_PSM_DEPOSIT();
        bytes32 withdrawKey = controller.LIMIT_PSM_WITHDRAW();

        rateLimits.setRateLimitData(_makeKey(depositKey, params.usdc),  data.usdcDepositData.maxAmount,  data.usdcDepositData.slope);
        rateLimits.setRateLimitData(_makeKey(depositKey, params.usds),  data.usdsDepositData.maxAmount,  data.usdsDepositData.slope);
        rateLimits.setRateLimitData(_makeKey(depositKey, params.susds), data.susdsDepositData.maxAmount, data.susdsDepositData.slope);

        rateLimits.setRateLimitData(_makeKey(withdrawKey, params.usdc),  data.usdcWithdrawData.maxAmount,  data.usdcWithdrawData.slope);
        rateLimits.setRateLimitData(_makeKey(withdrawKey, params.usds),  data.usdsWithdrawData.maxAmount,  data.usdsWithdrawData.slope);
        rateLimits.setRateLimitData(_makeKey(withdrawKey, params.susds), data.susdsWithdrawData.maxAmount, data.susdsWithdrawData.slope);
    }

    function _makeKey(bytes32 actionKey, address asset) internal pure returns (bytes32) {
        return RateLimitHelpers.makeAssetKey(actionKey, asset);
    }

    function _checkUnlimitedData(RateLimitData memory data, string memory name) internal pure {
        if (data.maxAmount == type(uint256).max) {
            require(
                data.slope == 0,
                string(abi.encodePacked("ForeignControllerInit/invalid-rate-limit-", name))
            );
        }
    }

}
