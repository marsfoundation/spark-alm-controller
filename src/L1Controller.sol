// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

interface ISNstLike {
    function deposit(uint256 assets, address receiver) external;
}

interface IVaultLike {
    function draw(uint256 wad) external;
    function wipe(uint256 wad) external;
}

contract L1Controller is AccessControl {

    /**********************************************************************************************/
    /*** State Variables                                                                        ***/
    /**********************************************************************************************/

    bytes32 public constant FREEZER = keccak256("FREEZER");
    bytes32 public constant RELAYER = keccak256("RELAYER");

    address public buffer;
    address public freezer;
    address public relayer;
    address public roles;

    ISNstLike  public sNst;
    IVaultLike public vault;

    bool public active;

    /**********************************************************************************************/
    /*** Initialization                                                                         ***/
    /**********************************************************************************************/

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**********************************************************************************************/
    /*** Admin Functions                                                                      ***/
    /**********************************************************************************************/

    function setBuffer(address buffer_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        buffer = buffer_;
    }

    function setFreezer(address freezer_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        freezer = freezer_;
    }

    function setRelayer(address relayer_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        relayer = relayer_;
    }

    function setRoles(address roles_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        roles = roles_;
    }

    function setVault(address vault_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        vault = IVaultLike(vault_);
    }

    function setSNst(address sNst_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        sNst = ISNstLike(sNst_);
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
        // TODO: ALM Proxy instead of buffer
        vault.draw(wad);
        // nst.transferFrom(almProxy);
    }

    function wipe(uint256 wad) external onlyRole(RELAYER) {
        // TODO: ALM Proxy instead of buffer
        vault.wipe(wad);
    }

    // TODO: Use referral?
    function depositNstToSNst(uint256 assets) external onlyRole(RELAYER) {
        // TODO: ALM Proxy
        // nst.transferFrom(buffer, address(this), assets);
        // sNst.deposit(assets, receiver);
    }

    // function
    // call sNst.withdraw using the proxy
    // Call proxy with exec to run specified calldata (target + calldata, call and delegatecall)

}

