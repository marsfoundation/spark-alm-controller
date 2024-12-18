// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { CCTPForwarder } from "xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { ForeignController } from "../src/ForeignController.sol";
import { MainnetController } from "../src/MainnetController.sol";
import { RateLimitHelpers }  from "../src/RateLimitHelpers.sol";

import { IALMProxy }   from "../src/interfaces/IALMProxy.sol";
import { IRateLimits } from "../src/interfaces/IRateLimits.sol";

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



// Move checks for almProxy and rateLimits to init
// Remove rate limits
// Change checks to only use constructor params

library MainnetControllerInit {

    struct CheckAddressParams {
        address proxy;
        address rateLimits;
        address vault;
        address psm;
        address daiUsds;
        address cctp;
    }

    struct ConfigAddressParams {
        address freezer;
        address relayer;
        address oldController;
    }

    struct MintRecipient {
        uint32  domain;
        bytes32 mintRecipient;
    }

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    function initController(
        ControllerInstance  memory controllerInst,
        ConfigAddressParams memory configAddresses,
        CheckAddressParams  memory checkAddresses,
        MintRecipient[]     memory mintRecipients
    )
        internal
    {
        // Step 1: Perform controller sanity checks

        MainnetController newController = MainnetController(controllerInst.controller);

        require(newController.hasRole(DEFAULT_ADMIN_ROLE, checkAddresses.admin), "MainnetControllerInit/incorrect-admin-controller");

        require(address(newController.proxy())      == controllerInst.almProxy,   "MainnetControllerInit/incorrect-almProxy");
        require(address(newController.rateLimits()) == controllerInst.rateLimits, "MainnetControllerInit/incorrect-rateLimits");

        require(address(newController.vault())   == checkAddresses.vault,         "MainnetControllerInit/incorrect-vault");
        require(address(newController.buffer())  == checkAddresses.buffer,        "MainnetControllerInit/incorrect-buffer");
        require(address(newController.psm())     == checkAddresses.psm,           "MainnetControllerInit/incorrect-psm");
        require(address(newController.daiUsds()) == checkAddresses.daiUsds,       "MainnetControllerInit/incorrect-daiUsds");
        require(address(newController.cctp())    == checkAddresses.cctpMessenger, "MainnetControllerInit/incorrect-cctpMessenger");
        require(address(newController.dai())     == checkAddresses.dai,           "MainnetControllerInit/incorrect-dai");
        require(address(newController.usdc())    == checkAddresses.usdc,          "MainnetControllerInit/incorrect-usdc");
        require(address(newController.usds())    == checkAddresses.usds,          "MainnetControllerInit/incorrect-usds");

        require(newController.psmTo18ConversionFactor() == 1e12, "MainnetControllerInit/incorrect-psmTo18ConversionFactor");

        require(newController.active(), "MainnetControllerInit/controller-not-active");

        require(configAddresses.oldController != address(newController), "MainnetControllerInit/old-controller-is-new-controller");

        // Step 2: Configure ACL permissions controller, almProxy, and rateLimits

        IALMProxy   almProxy   = IALMProxy(controllerInst.almProxy);
        IRateLimits rateLimits = IRateLimits(controllerInst.rateLimits);

        newController.grantRole(newController.FREEZER(), configAddresses.freezer);
        newController.grantRole(newController.RELAYER(), configAddresses.relayer);

        almProxy.grantRole(almProxy.CONTROLLER(), address(controller));
        rateLimits.grantRole(rateLimits.CONTROLLER(), address(controller));

        // Step 3: Configure the mint recipients on other domains

        for (uint256 i = 0; i < mintRecipients.length; i++) {
            newController.setMintRecipient(mintRecipients[i].domain, mintRecipients[i].mintRecipient);
        }
    }

    function transferControllerRoles(ControllerInstance  memory controllerInst, address oldController) internal {
        IALMProxy   almProxy   = IALMProxy(controllerInst.almProxy);
        IRateLimits rateLimits = IRateLimits(controllerInst.rateLimits);

        if (oldController == address(0)) return;

        require(almProxy.hasRole(almProxy.CONTROLLER(), oldController),     "MainnetControllerInit/old-controller-not-almProxy-controller");
        require(rateLimits.hasRole(rateLimits.CONTROLLER(), oldController), "MainnetControllerInit/old-controller-not-rateLimits-controller");

        almProxy.revokeRole(almProxy.CONTROLLER(), oldController);
        rateLimits.revokeRole(rateLimits.CONTROLLER(), oldController);
    }

    function upgradeController(
        ControllerInstance  memory controllerInst,
        ConfigAddressParams memory configAddresses,
        CheckAddressParams  memory checkAddresses,
        MintRecipient[]     memory mintRecipients
    )
        internal
    {
        initController(controllerInst, configAddresses, checkAddresses, mintRecipients);   
        transferControllerRoles(controllerInst, configAddresses);
    }

    function initAlmSystem(
        ControllerInstance  memory controllerInst,
        ConfigAddressParams memory configAddresses,
        CheckAddressParams  memory checkAddresses,
        MintRecipient[]     memory mintRecipients
    )
        internal
    {
        // Step 1: Do sanity checks outside of the controller

        require(IALMProxy(controllerInst.almProxy).hasRole(DEFAULT_ADMIN_ROLE, configAddresses.admin),     "MainnetControllerInit/incorrect-admin-almProxy");
        require(IRateLimits(controllerInst.rateLimits).hasRole(DEFAULT_ADMIN_ROLE, configAddresses.admin), "MainnetControllerInit/incorrect-admin-rateLimits");

        // Step 2: Initialize the controller

        initController(controllerInst, configAddresses, checkAddresses, mintRecipients);

        // Step 2: Configure almProxy within the allocation system

        IVaultLike(addresses.vault).rely(controllerInst.almProxy);
        IBufferLike(addresses.buffer).approve(addresses.usds, controllerInst.almProxy, type(uint256).max);
    }

    function pauseProxyInit(address psm, address almProxy) internal {
        IPSMLike(psm).kiss(almProxy);  // To allow using no fee functionality
    }

    function setRateLimitData(
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