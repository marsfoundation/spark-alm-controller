// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import { IALMProxy } from "src/interfaces/IALMProxy.sol";

interface ISNstLike {
    function deposit(uint256 assets, address receiver) external;
    function nst() external view returns(address);
}

interface IVaultLike {
    function draw(uint256 wad) external;
    function wipe(uint256 wad) external;
}

interface IPsmLike {
    function buyGemNoFee(address usr, uint256 gemAmt) external returns (uint256 daiInWad);
    function sellGemNoFee(address usr, uint256 gemAmt) external returns (uint256 daiOutWad);
}

contract L1Controller is AccessControl {

    // TODO: Inherit and override interface

    /**********************************************************************************************/
    /*** State variables                                                                        ***/
    /**********************************************************************************************/

    bytes32 public constant FREEZER = keccak256("FREEZER");
    bytes32 public constant RELAYER = keccak256("RELAYER");

    address public immutable buffer;

    IALMProxy  public immutable proxy;
    IVaultLike public immutable vault;
    ISNstLike  public immutable sNst;
    IPsmLike   public immutable psm;
    IERC20     public immutable nst;
    IERC20     public immutable usdc;

    bool public active;

    /**********************************************************************************************/
    /*** Initialization                                                                         ***/
    /**********************************************************************************************/

    constructor(
        address admin_,
        address proxy_,
        address vault_,
        address buffer_,
        address sNst_,
        address psm_,
        address usdc_
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);

        buffer = buffer_;
        proxy  = IALMProxy(proxy_);
        vault  = IVaultLike(vault_);
        sNst   = ISNstLike(sNst_);
        psm    = IPsmLike(psm_);
        usdc   = IERC20(usdc_);
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
    /*** Freezer functions                                                                      ***/
    /**********************************************************************************************/

    function freeze() external onlyRole(FREEZER) {
        active = false;
    }

    function reactivate() external onlyRole(DEFAULT_ADMIN_ROLE) {
        active = true;
    }

    /**********************************************************************************************/
    /*** Relayer vault functions                                                                ***/
    /**********************************************************************************************/

    function draw(uint256 wad) external onlyRole(RELAYER) isActive {
        // Mint NST into the buffer
        proxy.doCall(
            address(vault),
            abi.encodeCall(vault.draw, (wad))
        );

        // Transfer NST from the buffer to the proxy
        proxy.doCall(
            address(nst),
            abi.encodeCall(nst.transferFrom, (buffer, address(proxy), wad))
        );
    }

    function wipe(uint256 wad) external onlyRole(RELAYER) isActive {
        // Transfer NST from the proxy to the buffer
        proxy.doCall(
            address(nst),
            abi.encodeCall(nst.transfer, (buffer, wad))
        );

        // Burn NST from the buffer
        proxy.doCall(
            address(vault),
            abi.encodeCall(vault.wipe, (wad))
        );
    }

    /**********************************************************************************************/
    /*** Relayer sNST functions                                                                 ***/
    /**********************************************************************************************/

    function depositNstToSNst(uint256 wad) external onlyRole(RELAYER) isActive {
        // Approve NST to sNST from the proxy (assumes the proxy has enough NST)
        proxy.doCall(
            address(nst),
            abi.encodeCall(nst.approve, (address(sNst), wad))
        );

        // Deposit NST into sNST, proxy receives sNST shares
        proxy.doCall(
            address(sNst),
            abi.encodeCall(sNst.deposit, (wad, address(proxy)))
        );
    }

    /**********************************************************************************************/
    /*** Relayer PSM functions                                           s                       ***/
    /**********************************************************************************************/

    function sellGemNoFee(uint256 gemAmt) external onlyRole(RELAYER) isActive {
        // Approve USDC to PSM from the proxy (assumes the proxy has enough USDC)
        proxy.doCall(
            address(usdc),
            abi.encodeCall(usdc.approve, (address(psm), gemAmt))
        );

        // Swap USDC to NST through the PSM
        proxy.doCall(
            address(psm),
            abi.encodeCall(psm.sellGemNoFee, (address(proxy), gemAmt))
        );
    }

    function buyGemNoFee(uint256 wad) external onlyRole(RELAYER) isActive {
        // Approve NST to PSM from the proxy (assumes the proxy has enough NST)
        proxy.doCall(
            address(nst),
            abi.encodeCall(nst.approve, (address(psm), wad))
        );

        // Swap NST to USDC through the PSM
        proxy.doCall(
            address(psm),
            abi.encodeCall(psm.buyGemNoFee, (address(proxy), wad))
        );
    }

}

