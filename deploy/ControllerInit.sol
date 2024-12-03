
// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { CCTPForwarder } from "xchain-helpers/src/forwarders/CCTPForwarder.sol";

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

struct MintRecipient {
    uint32  domain;
    bytes32 mintRecipient;
}

library MainnetControllerInit {

    struct ConfigAddressParams {
        address admin;
        address freezer;
        address relayer;
        address oldController;
    }

    struct AddressCheckParams {
        address proxy;
        address rateLimits;
        address buffer;
        address cctp;
        address daiUsds;
        address ethenaMinter;
        address psm;
        address vault;
        address dai;
        address usds;
        address usde;
        address usdc;
        address susde;
        address susds;
    }

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    function subDaoInitController(
        ConfigAddressParams memory configAddresses,
        AddressCheckParams  memory checkAddresses,
        ControllerInstance  memory controllerInst,
        MintRecipient[]     memory mintRecipients
    )
        internal
    {
        IALMProxy   almProxy   = IALMProxy(controllerInst.almProxy);
        IRateLimits rateLimits = IRateLimits(controllerInst.rateLimits);

        MainnetController controller = MainnetController(controllerInst.controller);

        // Step 1: Perform sanity checks

        require(almProxy.hasRole(DEFAULT_ADMIN_ROLE, configAddresses.admin),   "MainnetControllerInit/incorrect-admin-almProxy");
        require(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, configAddresses.admin), "MainnetControllerInit/incorrect-admin-rateLimits");
        require(controller.hasRole(DEFAULT_ADMIN_ROLE, configAddresses.admin), "MainnetControllerInit/incorrect-admin-controller");

        // Perform requires for all checkAddresses

        require(address(controller.proxy())      == controllerInst.almProxy,   "MainnetControllerInit/incorrect-proxy");
        require(address(controller.rateLimits()) == controllerInst.rateLimits, "MainnetControllerInit/incorrect-rateLimits");

        require(address(controller.buffer())       == checkAddresses.buffer,      "MainnetControllerInit/incorrect-buffer");
        require(address(controller.vault())        == checkAddresses.vault,       "MainnetControllerInit/incorrect-vault");
        require(address(controller.psm())          == checkAddresses.psm,         "MainnetControllerInit/incorrect-psm");
        require(address(controller.daiUsds())      == checkAddresses.daiUsds,     "MainnetControllerInit/incorrect-daiUsds");
        require(address(controller.cctp())         == checkAddresses.cctp,        "MainnetControllerInit/incorrect-cctp");
        require(address(controller.ethenaMinter()) == checkAddresses.ethenaMinter, "MainnetControllerInit/incorrect-ethenaMinter");

        require(address(controller.susds()) == checkAddresses.susds, "MainnetControllerInit/incorrect-susds");
        require(address(controller.dai())   == checkAddresses.dai,   "MainnetControllerInit/incorrect-dai");
        require(address(controller.usdc())  == checkAddresses.usdc,  "MainnetControllerInit/incorrect-usdc");
        require(address(controller.usds())  == checkAddresses.usds,  "MainnetControllerInit/incorrect-usds");
        require(address(controller.usde())  == checkAddresses.usde,  "MainnetControllerInit/incorrect-usde");
        require(address(controller.susde()) == checkAddresses.susde, "MainnetControllerInit/incorrect-susde");

        require(controller.psmTo18ConversionFactor() == 1e12, "MainnetControllerInit/incorrect-psmTo18ConversionFactor");

        require(controller.active(), "MainnetControllerInit/controller-not-active");

        require(configAddresses.oldController != address(controller), "MainnetControllerInit/old-controller-is-new-controller");

        // Step 2: Configure ACL permissions for controller and almProxy

        controller.grantRole(controller.FREEZER(), configAddresses.freezer);
        controller.grantRole(controller.RELAYER(), configAddresses.relayer);

        almProxy.grantRole(almProxy.CONTROLLER(), address(controller));
        rateLimits.grantRole(rateLimits.CONTROLLER(), address(controller));

        if (configAddresses.oldController != address(0)) {
            require(almProxy.hasRole(almProxy.CONTROLLER(), configAddresses.oldController),     "MainnetControllerInit/old-controller-not-almProxy-controller");
            require(rateLimits.hasRole(rateLimits.CONTROLLER(), configAddresses.oldController), "MainnetControllerInit/old-controller-not-rateLimits-controller");

            almProxy.revokeRole(almProxy.CONTROLLER(), configAddresses.oldController);
            rateLimits.revokeRole(rateLimits.CONTROLLER(), configAddresses.oldController);
        }

        // Step 3: Configure the mint recipients on other domains

        for (uint256 i = 0; i < mintRecipients.length; i++) {
            controller.setMintRecipient(mintRecipients[i].domain, mintRecipients[i].mintRecipient);
        }
    }

    function subDaoInitFull(
        ConfigAddressParams memory configAddresses,
        AddressCheckParams  memory checkAddresses,
        ControllerInstance  memory controllerInst,
        MintRecipient[]     memory mintRecipients
    )
        internal
    {
        // Step 1: Perform controller sanity checks, configure ACL permissions for controller
        //         and almProxy and rate limits.

        subDaoInitController(
            configAddresses,
            checkAddresses,
            controllerInst,
            mintRecipients
        );

        // Step 2: Configure almProxy within the allocation system

        IVaultLike(checkAddresses.vault).rely(controllerInst.almProxy);
        IBufferLike(checkAddresses.buffer).approve(checkAddresses.usds, controllerInst.almProxy, type(uint256).max);
    }

    function pauseProxyInit(address psm, address almProxy) internal {
        IPSMLike(psm).kiss(almProxy);  // To allow using no fee functionality
    }

}

library ForeignControllerInit {

    struct ConfigAddressParams {
        address admin;
        address freezer;
        address relayer;
        address oldController;
    }

    struct AddressCheckParams {
        address psm;
        address cctpMessenger;
        address usdc;
        address usds;
        address susds;
    }

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    // TODO: Add full init script for ForeignController with base set of rate limits
    function init(
        ConfigAddressParams memory configAddresses,
        AddressCheckParams  memory checkAddresses,
        ControllerInstance  memory controllerInst,
        MintRecipient[]     memory mintRecipients
    )
        internal
    {
        IALMProxy   almProxy   = IALMProxy(controllerInst.almProxy);
        IRateLimits rateLimits = IRateLimits(controllerInst.rateLimits);

        ForeignController controller = ForeignController(controllerInst.controller);

        require(almProxy.hasRole(DEFAULT_ADMIN_ROLE, configAddresses.admin),   "ForeignControllerInit/incorrect-admin-almProxy");
        require(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, configAddresses.admin), "ForeignControllerInit/incorrect-admin-rateLimits");
        require(controller.hasRole(DEFAULT_ADMIN_ROLE, configAddresses.admin), "ForeignControllerInit/incorrect-admin-controller");

        require(address(controller.proxy())      == controllerInst.almProxy,   "ForeignControllerInit/incorrect-almProxy");
        require(address(controller.rateLimits()) == controllerInst.rateLimits, "ForeignControllerInit/incorrect-rateLimits");

        require(address(controller.psm())  == checkAddresses.psm,           "ForeignControllerInit/incorrect-psm");
        require(address(controller.usdc()) == checkAddresses.usdc,          "ForeignControllerInit/incorrect-usdc");
        require(address(controller.cctp()) == checkAddresses.cctpMessenger, "ForeignControllerInit/incorrect-cctp");

        require(controller.active(), "ForeignControllerInit/controller-not-active");

        require(configAddresses.oldController != address(controller), "ForeignControllerInit/old-controller-is-new-controller");

        IPSM3Like psm = IPSM3Like(checkAddresses.psm);

        require(psm.totalAssets() >= 1e18, "ForeignControllerInit/psm-totalAssets-not-seeded");
        require(psm.totalShares() >= 1e18, "ForeignControllerInit/psm-totalShares-not-seeded");

        require(psm.usdc()  == checkAddresses.usdc,  "ForeignControllerInit/psm-incorrect-usdc");
        require(psm.usds()  == checkAddresses.usds,  "ForeignControllerInit/psm-incorrect-usds");
        require(psm.susds() == checkAddresses.susds, "ForeignControllerInit/psm-incorrect-susds");

        // Step 1: Configure ACL permissions for controller and almProxy

        controller.grantRole(controller.FREEZER(), configAddresses.freezer);
        controller.grantRole(controller.RELAYER(), configAddresses.relayer);

        almProxy.grantRole(almProxy.CONTROLLER(), address(controller));
        rateLimits.grantRole(rateLimits.CONTROLLER(), address(controller));

        if (configAddresses.oldController != address(0)) {
            require(almProxy.hasRole(almProxy.CONTROLLER(), configAddresses.oldController)     == true, "ForeignControllerInit/old-controller-not-almProxy-controller");
            require(rateLimits.hasRole(rateLimits.CONTROLLER(), configAddresses.oldController) == true, "ForeignControllerInit/old-controller-not-rateLimits-controller");

            almProxy.revokeRole(almProxy.CONTROLLER(), configAddresses.oldController);
            rateLimits.revokeRole(rateLimits.CONTROLLER(), configAddresses.oldController);
        }

        // Step 2: Configure the mint recipients on other domains

        for (uint256 i = 0; i < mintRecipients.length; i++) {
            controller.setMintRecipient(mintRecipients[i].domain, mintRecipients[i].mintRecipient);
        }
    }

    function _makeKey(bytes32 actionKey, address asset) internal pure returns (bytes32) {
        return RateLimitHelpers.makeAssetKey(actionKey, asset);
    }

}
