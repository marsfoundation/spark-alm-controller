// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

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

    address public immutable buffer;

    ISNstLike  public immutable sNst;
    IVaultLike public immutable vault;

    bool public active;

    /**********************************************************************************************/
    /*** Initialization                                                                         ***/
    /**********************************************************************************************/

    constructor(
        address admin_,
        address vault_,
        address buffer_,
        address sNst_
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);

        vault  = IVaultLike(vault_);
        buffer = buffer_;
        sNst   = ISNstLike(sNst_);

        active = true;
    }

    /**********************************************************************************************/
    /*** Modifiers                                                                              ***/
    /**********************************************************************************************/

    modifier isActive {
        require(active, "L1Controller/not-active");
        _;
    }

    /**********************************************************************************************/
    /*** Freezer Functions                                                                      ***/
    /**********************************************************************************************/

    function freeze() external onlyRole(FREEZER) {
        active = false;
    }

    function reactivate() external onlyRole(DEFAULT_ADMIN_ROLE) {
        active = true;
    }

    /**********************************************************************************************/
    /*** Relayer Functions                                                                      ***/
    /**********************************************************************************************/

    function draw(uint256 wad) external onlyRole(RELAYER) isActive {
        // TODO: ALM Proxy instead of buffer
        vault.draw(wad);
        // nst.transferFrom(almProxy);
    }

    function wipe(uint256 wad) external onlyRole(RELAYER) isActive {
        // TODO: ALM Proxy instead of buffer
        vault.wipe(wad);
    }

    // TODO: Use referral?
    function depositNstToSNst(uint256 assets) external onlyRole(RELAYER) isActive {
        // TODO: ALM Proxy
        // nst.transferFrom(buffer, address(this), assets);
        // sNst.deposit(assets, receiver);
    }

    // function
    // call sNst.withdraw using the proxy
    // Call proxy with exec to run specified calldata (target + calldata, call and delegatecall)

}

