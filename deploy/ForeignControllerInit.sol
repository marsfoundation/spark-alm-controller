// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { ForeignController } from "../src/ForeignController.sol";

import { IALMProxy }   from "../src/interfaces/IALMProxy.sol";
import { IRateLimits } from "../src/interfaces/IRateLimits.sol";

import { ControllerInstance } from "./ControllerInstance.sol";

interface IPSM3Like {
    function susds() external view returns (address);
    function totalAssets() external view returns (uint256);
    function totalShares() external view returns (uint256);
    function usdc() external view returns (address);
    function usds() external view returns (address);
}

library ForeignControllerInit {

    /**********************************************************************************************/
    /*** Structs and constants                                                                  ***/
    /**********************************************************************************************/

    struct CheckAddressParams {
        address admin;
        address psm;
        address cctp;
        address usdc;
        address susds;
        address usds;
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

    /**********************************************************************************************/
    /*** Internal library functions                                                             ***/
    /**********************************************************************************************/

    function initAlmSystem(
        ControllerInstance  memory controllerInst,
        ConfigAddressParams memory configAddresses,
        CheckAddressParams  memory checkAddresses,
        MintRecipient[]     memory mintRecipients
    )
        internal
    {
        // Step 1: Do sanity checks outside of the controller

        require(IALMProxy(controllerInst.almProxy).hasRole(DEFAULT_ADMIN_ROLE, checkAddresses.admin),     "ForeignControllerInit/incorrect-admin-almProxy");
        require(IRateLimits(controllerInst.rateLimits).hasRole(DEFAULT_ADMIN_ROLE, checkAddresses.admin), "ForeignControllerInit/incorrect-admin-rateLimits");

        // Step 2: Initialize the controller

        _initController(controllerInst, configAddresses, checkAddresses, mintRecipients);
    }

    function upgradeController(
        ControllerInstance  memory controllerInst,
        ConfigAddressParams memory configAddresses,
        CheckAddressParams  memory checkAddresses,
        MintRecipient[]     memory mintRecipients
    )
        internal
    {
        _initController(controllerInst, configAddresses, checkAddresses, mintRecipients);   
        
        IALMProxy   almProxy   = IALMProxy(controllerInst.almProxy);
        IRateLimits rateLimits = IRateLimits(controllerInst.rateLimits);

        require(configAddresses.oldController != address(0), "ForeignControllerInit/old-controller-zero-address"); 

        require(almProxy.hasRole(almProxy.CONTROLLER(), configAddresses.oldController),     "ForeignControllerInit/old-controller-not-almProxy-controller");
        require(rateLimits.hasRole(rateLimits.CONTROLLER(), configAddresses.oldController), "ForeignControllerInit/old-controller-not-rateLimits-controller");

        almProxy.revokeRole(almProxy.CONTROLLER(), configAddresses.oldController);
        rateLimits.revokeRole(rateLimits.CONTROLLER(), configAddresses.oldController);
    }

    /**********************************************************************************************/
    /*** Private helper functions                                                               ***/
    /**********************************************************************************************/

    function _initController(
        ControllerInstance  memory controllerInst,
        ConfigAddressParams memory configAddresses,
        CheckAddressParams  memory checkAddresses,
        MintRecipient[]     memory mintRecipients
    )
        private  
    {
        // Step 1: Perform controller sanity checks

        ForeignController newController = ForeignController(controllerInst.controller);

        require(newController.hasRole(DEFAULT_ADMIN_ROLE, checkAddresses.admin), "ForeignControllerInit/incorrect-admin-controller");

        require(address(newController.proxy())      == controllerInst.almProxy,   "ForeignControllerInit/incorrect-almProxy");
        require(address(newController.rateLimits()) == controllerInst.rateLimits, "ForeignControllerInit/incorrect-rateLimits");

        require(address(newController.psm())  == checkAddresses.psm,  "ForeignControllerInit/incorrect-psm");
        require(address(newController.usdc()) == checkAddresses.usdc, "ForeignControllerInit/incorrect-usdc");
        require(address(newController.cctp()) == checkAddresses.cctp, "ForeignControllerInit/incorrect-cctp");

        require(newController.active(), "ForeignControllerInit/controller-not-active");

        require(configAddresses.oldController != address(newController), "ForeignControllerInit/old-controller-is-new-controller");

        // Step 2: Perform PSM sanity checks

        IPSM3Like psm = IPSM3Like(checkAddresses.psm);

        require(psm.totalAssets() >= 1e18, "ForeignControllerInit/psm-totalAssets-not-seeded");
        require(psm.totalShares() >= 1e18, "ForeignControllerInit/psm-totalShares-not-seeded");

        require(psm.usdc()  == checkAddresses.usdc,  "ForeignControllerInit/psm-incorrect-usdc");
        require(psm.usds()  == checkAddresses.usds,  "ForeignControllerInit/psm-incorrect-usds");
        require(psm.susds() == checkAddresses.susds, "ForeignControllerInit/psm-incorrect-susds");

        // Step 3: Configure ACL permissions controller, almProxy, and rateLimits

        IALMProxy   almProxy   = IALMProxy(controllerInst.almProxy);
        IRateLimits rateLimits = IRateLimits(controllerInst.rateLimits);

        newController.grantRole(newController.FREEZER(), configAddresses.freezer);
        newController.grantRole(newController.RELAYER(), configAddresses.relayer);

        almProxy.grantRole(almProxy.CONTROLLER(), address(newController));
        rateLimits.grantRole(rateLimits.CONTROLLER(), address(newController));

        // Step 4: Configure the mint recipients on other domains

        for (uint256 i = 0; i < mintRecipients.length; i++) {
            newController.setMintRecipient(mintRecipients[i].domain, mintRecipients[i].mintRecipient);
        }
    }

}
