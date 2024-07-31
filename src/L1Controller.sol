// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import { UpgradeableProxied } from "upgradeable-proxy/UpgradeableProxied.sol";

contract L1Controller is UpgradeableProxied, AccessControl {

    bool public active;

    bool initialized;

    /**********************************************************************************************/
    /*** Initialization                                                                         ***/
    /**********************************************************************************************/

    // TODO: Verify this and test if necessary
    function initialize() public {
        require(!initialized, "L1Controller/already-initialized");
        initialized = true;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**********************************************************************************************/
    /*** Freezer Functions                                                                      ***/
    /**********************************************************************************************/

    function setActive(bool active_) external onlyRole("FREEZER") {
        active = active_;
    }

    /**********************************************************************************************/
    /*** Relayer Functions                                                                      ***/
    /**********************************************************************************************/

    // TODO: Placeholder for relayer functions
    function doAction() external onlyRole("RELAYER") {
        // Do something
    }

}

