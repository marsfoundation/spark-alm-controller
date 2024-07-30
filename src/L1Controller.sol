// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { UpgradeableProxied } from "lib/upgradeable-proxy/src/UpgradeableProxied.sol";

interface IVaultLike {
    function draw(uint256 wad) external;
    function wipe(uint256 wad) external;
}

contract L1Controller is UpgradeableProxied {

    /**********************************************************************************************/
    /*** State Variables                                                                        ***/
    /**********************************************************************************************/

    address public relayer;
    address public freezer;
    address public roles;

    IVaultLike public vault;

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

    function setFreezer(address freezer_) external auth {
        freezer = freezer_;
    }

    function setRelayer(address relayer_) external auth {
        relayer = relayer_;
    }

    function setRoles(address roles_) external auth {
        roles = roles_;
    }

    function setVault(address vault_) external auth {
        vault = IVaultLike(vault_);
    }

    /**********************************************************************************************/
    /*** Freezer Functions                                                                      ***/
    /**********************************************************************************************/

    function setActive(bool active_) external isFreezer {
        active = active_;
    }

    /**********************************************************************************************/
    /*** Relayer Functions                                                                      ***/
    /**********************************************************************************************/

    function draw(uint256 wad) external isRelayer {
        vault.draw(wad);
    }

    function wipe(uint256 wad) external isRelayer {
        vault.wipe(wad);
    }

}

