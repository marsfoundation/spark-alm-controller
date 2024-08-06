// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

interface IVaultLike {
    function draw(uint256 wad) external;
    function wipe(uint256 wad) external;
}

contract L1Controller is AccessControl {

    bytes32 public constant FREEZER = keccak256("FREEZER");
    bytes32 public constant RELAYER = keccak256("RELAYER");

    IVaultLike public immutable vault;

    bool public active;

    /**********************************************************************************************/
    /*** Initialization                                                                         ***/
    /**********************************************************************************************/

    constructor( address admin_, address vault_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);

        vault = IVaultLike(vault_);
    }

    /**********************************************************************************************/
    /*** Freezer Functions                                                                      ***/
    /**********************************************************************************************/

    function setActive(bool active_) external onlyRole(FREEZER) {
        active = active_;
    }

    /**********************************************************************************************/
    /*** Relayer Functions                                                                      ***/
    /**********************************************************************************************/

    function draw(uint256 wad) external onlyRole(RELAYER) {
        vault.draw(wad);
    }

    function wipe(uint256 wad) external onlyRole(RELAYER) {
        vault.wipe(wad);
    }

}

