// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IERC20 }   from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import { IPSM3 } from "spark-psm/src/interfaces/IPSM3.sol";

import { IALMProxy } from "src/interfaces/IALMProxy.sol";

interface IPSM3Like {
    function asset0() external view returns(address);
    function asset1() external view returns(address);
    function asset2() external view returns(address);
}

interface ISNSTLike is IERC4626 {
    function nst() external view returns(address);
}

contract L2Controller is AccessControl {

    // TODO: Inherit and override interface

    /**********************************************************************************************/
    /*** State variables                                                                        ***/
    /**********************************************************************************************/

    bytes32 public constant FREEZER = keccak256("FREEZER");
    bytes32 public constant RELAYER = keccak256("RELAYER");

    IALMProxy public immutable proxy;
    IPSM3     public immutable psm;

    IERC20    public immutable nst;
    IERC20    public immutable usdc;
    ISNSTLike public immutable snst;

    bool public active;

    /**********************************************************************************************/
    /*** Initialization                                                                         ***/
    /**********************************************************************************************/

    constructor(
        address admin_,
        address proxy_,
        address psm_
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);

        proxy = IALMProxy(proxy_);
        psm   = IPSM3(psm_);

        nst  = IERC20(address(psm.asset0()));
        usdc = IERC20(address(psm.asset1()));
        snst = ISNSTLike(address(psm.asset2()));

        active = true;
    }

    /**********************************************************************************************/
    /*** Modifiers                                                                              ***/
    /**********************************************************************************************/

    modifier isActive {
        require(active, "MainnetController/not-active");
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

    /**********************************************************************************************/
    /*** Relayer PSM functions                                                                  ***/
    /**********************************************************************************************/

    function swapExactIn(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        uint256 referralCode
    )
        external onlyRole(RELAYER) isActive returns (uint256 amountOut)
    {
        // Approve `assetIn` to PSM from the proxy (assumes the proxy has enough `assetIn`).
        proxy.doCall(
            assetIn,
            abi.encodeCall(IERC20.approve, (address(psm), amountIn))
        );

        // Swap `assetIn` for `assetOut` in the PSM, decode the result to get `amountOut`.
        amountOut = abi.decode(
            proxy.doCall(
                address(psm),
                abi.encodeCall(
                    psm.swapExactIn,
                    (assetIn, assetOut, amountIn, minAmountOut, receiver, referralCode)
                )
            ),
            (uint256)
        );
    }

}
