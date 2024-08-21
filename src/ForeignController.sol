// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import { IALMProxy } from "src/interfaces/IALMProxy.sol";

interface IPSM3Like {
    function asset0() external view returns(address);
    function asset1() external view returns(address);
    function asset2() external view returns(address);
}

contract ForeignController is AccessControl {

    // TODO: Inherit and override interface

    /**********************************************************************************************/
    /*** State variables                                                                        ***/
    /**********************************************************************************************/

    bytes32 public constant FREEZER = keccak256("FREEZER");
    bytes32 public constant RELAYER = keccak256("RELAYER");

    IALMProxy public immutable proxy;
    IPSM3Like public immutable psm;

    IERC20 public immutable nst;
    IERC20 public immutable usdc;
    IERC20 public immutable snst;

    bool public active;

    /**********************************************************************************************/
    /*** Initialization                                                                         ***/
    /**********************************************************************************************/

    constructor(
        address admin_,
        address proxy_,
        address psm_,
        address nst_,
        address usdc_,
        address snst_
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);

        proxy = IALMProxy(proxy_);
        psm   = IPSM3Like(psm_);

        nst  = IERC20(nst_);
        usdc = IERC20(usdc_);
        snst = IERC20(snst_);

        active = true;
    }

    /**********************************************************************************************/
    /*** Modifiers                                                                              ***/
    /**********************************************************************************************/

    modifier isActive {
        require(active, "ForeignController/not-active");
        _;
    }

    /**********************************************************************************************/
    /*** Freezer functions                                                                      ***/
    /**********************************************************************************************/

    function freeze() external onlyRole(FREEZER) {
        active = false;
    }

    function reactivate() external onlyRole(DEFAULT_ADMIN_ROLE) {
        active = true;
    }

}
