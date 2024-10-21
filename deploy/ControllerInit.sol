// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

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

interface IPSMLike {
    function kiss(address) external;
}

interface IPSM3Like {
    function totalAssets() external view returns (uint256);
    function totalShares() external view returns (uint256);
    function usdc() external view returns (address);
    function usds() external view returns (address);
    function susds() external view returns (address);
}

interface IVaultLike {
    function rely(address) external;
}

struct RateLimitData {
    uint256 maxAmount;
    uint256 slope;
}

struct MintRecipient {
    uint32  domain;
    bytes32 mintRecipient;
}

library MainnetControllerInit {

    struct AddressParams {
        address admin;
        address freezer;
        address relayer;
        address oldController;
        address psm;
        address vault;
        address buffer;
        address cctpMessenger;
        address dai;
        address daiUsds;
        address usdc;
        address usds;
        address susds;
    }

    struct InitRateLimitData {
        RateLimitData usdsMintData;
        RateLimitData usdsToUsdcData;
        RateLimitData usdcToCctpData;
        RateLimitData cctpToBaseDomainData;
    }

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    function subDaoInitController(
        AddressParams      memory addresses,
        ControllerInstance memory controllerInst,
        InitRateLimitData  memory data,
        MintRecipient[]    memory mintRecipients
    )
        internal
    {
        IALMProxy   almProxy   = IALMProxy(controllerInst.almProxy);
        IRateLimits rateLimits = IRateLimits(controllerInst.rateLimits);

        MainnetController controller = MainnetController(controllerInst.controller);

        // Step 1: Perform sanity checks

        require(almProxy.hasRole(DEFAULT_ADMIN_ROLE, addresses.admin)   == true,"MainnetControllerInit/incorrect-admin-almProxy");
        require(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, addresses.admin) == true,"MainnetControllerInit/incorrect-admin-rateLimits");
        require(controller.hasRole(DEFAULT_ADMIN_ROLE, addresses.admin) == true, "MainnetControllerInit/incorrect-admin-controller");

        require(address(controller.proxy())      == controllerInst.almProxy,   "MainnetControllerInit/incorrect-almProxy");
        require(address(controller.rateLimits()) == controllerInst.rateLimits, "MainnetControllerInit/incorrect-rateLimits");
        require(address(controller.vault())      == addresses.vault,           "MainnetControllerInit/incorrect-vault");
        require(address(controller.buffer())     == addresses.buffer,          "MainnetControllerInit/incorrect-buffer");
        require(address(controller.psm())        == addresses.psm,             "MainnetControllerInit/incorrect-psm");
        require(address(controller.daiUsds())    == addresses.daiUsds,         "MainnetControllerInit/incorrect-daiUsds");
        require(address(controller.cctp())       == addresses.cctpMessenger,   "MainnetControllerInit/incorrect-cctpMessenger");
        require(address(controller.susds())      == addresses.susds,           "MainnetControllerInit/incorrect-susds");
        require(address(controller.dai())        == addresses.dai,             "MainnetControllerInit/incorrect-dai");
        require(address(controller.usdc())       == addresses.usdc,            "MainnetControllerInit/incorrect-usdc");
        require(address(controller.usds())       == addresses.usds,            "MainnetControllerInit/incorrect-usds");

        require(controller.psmTo18ConversionFactor() == 1e12, "MainnetControllerInit/incorrect-psmTo18ConversionFactor");
        require(controller.active()                  == true, "MainnetControllerInit/controller-not-active");

        require(addresses.oldController != address(controller), "MainnetControllerInit/old-controller-is-new-controller");

        // Step 2: Configure ACL permissions for controller and almProxy

        controller.grantRole(controller.FREEZER(), addresses.freezer);
        controller.grantRole(controller.RELAYER(), addresses.relayer);

        almProxy.grantRole(almProxy.CONTROLLER(), address(controller));
        rateLimits.grantRole(rateLimits.CONTROLLER(), address(controller));

        if (addresses.oldController != address(0)) {
            almProxy.revokeRole(almProxy.CONTROLLER(), addresses.oldController);
            rateLimits.revokeRole(rateLimits.CONTROLLER(), addresses.oldController);
        }

        // Step 3: Configure all rate limits for controller, using Base as only domain

        bytes32 domainKeyBase = RateLimitHelpers.makeDomainKey(
            controller.LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE
        );

        _setRateLimitData(controller.LIMIT_USDS_MINT(),    rateLimits, data.usdsMintData,         "usdsMintData",         18);
        _setRateLimitData(controller.LIMIT_USDS_TO_USDC(), rateLimits, data.usdsToUsdcData,       "usdsToUsdcData",       6);
        _setRateLimitData(controller.LIMIT_USDC_TO_CCTP(), rateLimits, data.usdcToCctpData,       "usdcToCctpData",       6);
        _setRateLimitData(domainKeyBase,                   rateLimits, data.cctpToBaseDomainData, "cctpToBaseDomainData", 6);

        // Step 4: Configure the mint recipients on other domains

        for (uint256 i = 0; i < mintRecipients.length; i++) {
            controller.setMintRecipient(mintRecipients[i].domain, mintRecipients[i].mintRecipient);
        }
    }

    function subDaoInitFull(
        AddressParams      memory addresses,
        ControllerInstance memory controllerInst,
        InitRateLimitData  memory data,
        MintRecipient[]    memory mintRecipients
    )
        internal
    {
        // Step 1: Perform controller sanity checks, configure ACL permissions for controller
        //         and almProxy and rate limits.

        subDaoInitController(
            addresses,
            controllerInst,
            data,
            mintRecipients
        );

        // Step 2: Configure almProxy within the allocation system

        IVaultLike(addresses.vault).rely(controllerInst.almProxy);
        IBufferLike(addresses.buffer).approve(addresses.usds, controllerInst.almProxy, type(uint256).max);
    }

    function pauseProxyInit(address psm, address almProxy) internal {
        IPSMLike(psm).kiss(almProxy);  // To allow using no fee functionality
    }

    function _setRateLimitData(
        bytes32       key,
        IRateLimits   rateLimits,
        RateLimitData memory data,
        string        memory name,
        uint256       decimals
    )
        internal
    {
        // Handle setting an unlimited rate limit
        if (data.maxAmount == type(uint256).max) {
            require(
                data.slope == 0,
                string(abi.encodePacked("MainnetControllerInit/invalid-rate-limit-", name))
            );
        }
        else {
            require(
                data.maxAmount <= 1e12 * (10 ** decimals),
                string(abi.encodePacked("MainnetControllerInit/invalid-max-amount-precision-", name))
            );
            require(
                data.slope <= 1e12 * (10 ** decimals) / 1 hours,
                string(abi.encodePacked("MainnetControllerInit/invalid-slope-precision-", name))
            );
        }
        rateLimits.setRateLimitData(key, data.maxAmount, data.slope);
    }

}

library ForeignControllerInit {

    struct AddressParams {
        address admin;
        address freezer;
        address relayer;
        address oldController;
        address psm;
        address cctpMessenger;
        address usdc;
        address usds;
        address susds;
    }

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    struct InitRateLimitData {
        RateLimitData usdcDepositData;
        RateLimitData usdcWithdrawData;
        RateLimitData usdsDepositData;
        RateLimitData usdsWithdrawData;
        RateLimitData susdsDepositData;
        RateLimitData susdsWithdrawData;
        RateLimitData usdcToCctpData;
        RateLimitData cctpToEthereumDomainData;
    }

    function init(
        AddressParams      memory addresses,
        ControllerInstance memory controllerInst,
        InitRateLimitData  memory data,
        MintRecipient[]    memory mintRecipients
    )
        internal
    {
        IALMProxy   almProxy   = IALMProxy(controllerInst.almProxy);
        IRateLimits rateLimits = IRateLimits(controllerInst.rateLimits);

        ForeignController controller = ForeignController(controllerInst.controller);

        require(almProxy.hasRole(DEFAULT_ADMIN_ROLE, addresses.admin)   == true, "ForeignControllerInit/incorrect-admin-almProxy");
        require(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, addresses.admin) == true, "ForeignControllerInit/incorrect-admin-rateLimits");
        require(controller.hasRole(DEFAULT_ADMIN_ROLE, addresses.admin) == true, "ForeignControllerInit/incorrect-admin-controller");

        require(address(controller.proxy())      == controllerInst.almProxy,   "ForeignControllerInit/incorrect-almProxy");
        require(address(controller.rateLimits()) == controllerInst.rateLimits, "ForeignControllerInit/incorrect-rateLimits");
        require(address(controller.psm())        == addresses.psm,             "ForeignControllerInit/incorrect-psm");
        require(address(controller.usdc())       == addresses.usdc,            "ForeignControllerInit/incorrect-usdc");
        require(address(controller.cctp())       == addresses.cctpMessenger,   "ForeignControllerInit/incorrect-cctp");

        require(controller.active() == true, "ForeignControllerInit/controller-not-active");

        require(addresses.oldController != address(controller), "ForeignControllerInit/old-controller-is-new-controller");

        IPSM3Like psm = IPSM3Like(addresses.psm);

        require(psm.totalAssets() >= 1e18, "ForeignControllerInit/psm-totalAssets-not-seeded");
        require(psm.totalShares() >= 1e18, "ForeignControllerInit/psm-totalShares-not-seeded");

        require(psm.usdc()  == addresses.usdc,  "ForeignControllerInit/psm-incorrect-usdc");
        require(psm.usds()  == addresses.usds,  "ForeignControllerInit/psm-incorrect-usds");
        require(psm.susds() == addresses.susds, "ForeignControllerInit/psm-incorrect-susds");

        // Step 1: Configure ACL permissions for controller and almProxy

        controller.grantRole(controller.FREEZER(), addresses.freezer);
        controller.grantRole(controller.RELAYER(), addresses.relayer);

        almProxy.grantRole(almProxy.CONTROLLER(), address(controller));
        rateLimits.grantRole(rateLimits.CONTROLLER(), address(controller));

        if (addresses.oldController != address(0)) {
            almProxy.revokeRole(almProxy.CONTROLLER(), addresses.oldController);
            rateLimits.revokeRole(rateLimits.CONTROLLER(), addresses.oldController);
        }

        // Step 2: Configure all rate limits for controller

        bytes32 depositKey  = controller.LIMIT_PSM_DEPOSIT();
        bytes32 withdrawKey = controller.LIMIT_PSM_WITHDRAW();

        bytes32 domainKeyEthereum = RateLimitHelpers.makeDomainKey(
            controller.LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM
        );

        _setRateLimitData(_makeKey(depositKey,  addresses.usdc),  rateLimits, data.usdcDepositData,          "usdcDepositData",          6);
        _setRateLimitData(_makeKey(withdrawKey, addresses.usdc),  rateLimits, data.usdcWithdrawData,         "usdcWithdrawData",         6);
        _setRateLimitData(_makeKey(depositKey,  addresses.usds),  rateLimits, data.usdsDepositData,          "usdsDepositData",          18);
        _setRateLimitData(_makeKey(withdrawKey, addresses.usds),  rateLimits, data.usdsWithdrawData,         "usdsWithdrawData",         18);
        _setRateLimitData(_makeKey(depositKey,  addresses.susds), rateLimits, data.susdsDepositData,         "susdsDepositData",         18);
        _setRateLimitData(_makeKey(withdrawKey, addresses.susds), rateLimits, data.susdsWithdrawData,        "susdsWithdrawData",        18);
        _setRateLimitData(controller.LIMIT_USDC_TO_CCTP(),        rateLimits, data.usdcToCctpData,           "usdcToCctpData",           6);
        _setRateLimitData(domainKeyEthereum,                      rateLimits, data.cctpToEthereumDomainData, "cctpToEthereumDomainData", 6);

        // Step 3: Configure the mint recipients on other domains

        for (uint256 i = 0; i < mintRecipients.length; i++) {
            controller.setMintRecipient(mintRecipients[i].domain, mintRecipients[i].mintRecipient);
        }
    }

    function _makeKey(bytes32 actionKey, address asset) internal pure returns (bytes32) {
        return RateLimitHelpers.makeAssetKey(actionKey, asset);
    }

    function _setRateLimitData(
        bytes32       key,
        IRateLimits   rateLimits,
        RateLimitData memory data,
        string        memory name,
        uint256       decimals
    )
        internal
    {
        // Handle setting an unlimited rate limit
        if (data.maxAmount == type(uint256).max) {
            require(
                data.slope == 0,
                string(abi.encodePacked("ForeignControllerInit/invalid-rate-limit-", name))
            );
        }
        else {
            require(
                data.maxAmount <= 1e12 * (10 ** decimals),
                string(abi.encodePacked("ForeignControllerInit/invalid-max-amount-precision-", name))
            );
            require(
                data.slope <= 1e12 * (10 ** decimals) / 1 hours,
                string(abi.encodePacked("ForeignControllerInit/invalid-slope-precision-", name))
            );
        }
        rateLimits.setRateLimitData(key, data.maxAmount, data.slope);
    }

}
