// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { UpgradeableProxied } from "lib/upgradeable-proxy/src/UpgradeableProxied.sol";

interface ISNstLike {
    function deposit(uint256 assets, address receiver) external;
}

interface IVaultLike {
    function draw(uint256 wad) external;
    function wipe(uint256 wad) external;
}

contract L1Controller is UpgradeableProxied {

    /**********************************************************************************************/
    /*** State Variables                                                                        ***/
    /**********************************************************************************************/

    address public buffer;
    address public freezer;
    address public relayer;
    address public roles;

    ISNstLike  public sNst;
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

    function setBuffer(address buffer_) external auth {
        buffer = buffer_;
    }

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

    function setSNst(address sNst_) external auth {
        sNst = ISNstLike(sNst_);
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

    // TODO: Use referral?
    function depositNstToSNst(uint256 assets, address receiver) external isRelayer {
        nst.transferFrom(buffer, address(this), assets);
        sNst.deposit(assets, receiver);
    }

}

