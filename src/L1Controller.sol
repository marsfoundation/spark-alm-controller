// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

interface ISNstLike {
    function deposit(uint256 assets, address receiver) external;
    function nst() external view returns(address);
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

    IVaultLike public immutable vault;
    ISNstLike  public immutable sNst;
    IERC20     public immutable nst;

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

        buffer = buffer_;
        vault  = IVaultLike(vault_);
        sNst   = ISNstLike(sNst_);
        nst    = IERC20(ISNstLike(sNst_).nst());

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
        // TODO: Refactor to use ALM Proxy
        vault.draw(wad);
    }

    function wipe(uint256 wad) external onlyRole(RELAYER) isActive {
        // TODO: Refactor to use ALM Proxy
        vault.wipe(wad);
    }

    // TODO: Use referral?
    function depositNstToSNst(uint256 assets) external onlyRole(RELAYER) isActive {
        // TODO: Refactor to use ALM Proxy
        nst.transferFrom(buffer, address(this), assets);
        nst.approve(address(sNst), assets);
        sNst.deposit(assets, address(buffer));
    }

    // function
    // call sNst.withdraw using the proxy
    // Call proxy with exec to run specified calldata (target + calldata, call and delegatecall)

}

