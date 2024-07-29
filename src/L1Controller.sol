// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { UpgradeableProxied } from "lib/upgradeable-proxy/src/UpgradeableProxied.sol";

contract L1Controller is UpgradeableProxied {

    /**********************************************************************************************/
    /*** State Variables                                                                        ***/
    /**********************************************************************************************/

    address public relayer;
    address public freezer;
    address public roles;

    bool public active;

    /**********************************************************************************************/
    /*** Modifiers                                                                              ***/
    /**********************************************************************************************/

    modifier auth {
        require(wards[msg.sender] == 1, "L1Controller/not-authorized");
        _;
    }

    modifier isRelayer {
        require(msg.sender == relayer, "L1Controller/not-relayer");
        _;
    }

    modifier isFreezer {
        require(msg.sender == freezer, "L1Controller/not-freezer");
        _;
    }

    /**********************************************************************************************/
    /*** Admin Functions                                                                        ***/
    /**********************************************************************************************/

    function setRoles(address roles_) external auth {
        roles = roles_;
    }

    function setRelayer(address relayer_) external auth {
        relayer = relayer_;
    }

    function setFreezer(address freezer_) external auth {
        freezer = freezer_;
    }

    /**********************************************************************************************/
    /*** Freezer Functions                                                                      ***/
    /**********************************************************************************************/

    function setActive(bool active_) external isFreezer {
        active = active_;
    }

}

