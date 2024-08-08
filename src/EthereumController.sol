// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import { IALMProxy } from "src/interfaces/IALMProxy.sol";

interface ICCTPLike {
    function depositForBurnWithCaller(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller
    ) external returns (uint64 nonce);
}

interface ISNSTLike {
    function deposit(uint256 assets, address receiver) external;
    function nst() external view returns(address);
}

interface IVaultLike {
    function draw(uint256 nstAmount) external;
    function wipe(uint256 nstAmount) external;
}

interface IPSMLike {
    function buyGemNoFee(address usr, uint256 usdcAmount) external returns (uint256 daiInnstAmount);
    function gem() external view returns(address);
    function sellGemNoFee(address usr, uint256 usdcAmount) external returns (uint256 daiOutnstAmount);
    function to18ConversionFactor() external view returns (uint256);
}

contract EthereumController is AccessControl {

    // TODO: Inherit and override interface

    /**********************************************************************************************/
    /*** State variables                                                                        ***/
    /**********************************************************************************************/

    bytes32 public constant FREEZER = keccak256("FREEZER");
    bytes32 public constant RELAYER = keccak256("RELAYER");

    address public immutable buffer;

    IALMProxy  public immutable proxy;
    IVaultLike public immutable vault;
    ISNSTLike  public immutable snst;
    IPSMLike   public immutable psm;
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
        address snst_,
        address psm_
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);

        buffer = buffer_;
        proxy  = IALMProxy(proxy_);
        vault  = IVaultLike(vault_);
        snst   = ISNSTLike(snst_);
        psm    = IPSMLike(psm_);
        usdc   = IERC20(psm.gem());
        nst    = IERC20(snst.nst());

        active = true;
    }

    /**********************************************************************************************/
    /*** Modifiers                                                                              ***/
    /**********************************************************************************************/

    modifier isActive {
        require(active, "EthereumController/not-active");
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

    function mintNST(uint256 nstAmount) external onlyRole(RELAYER) isActive {
        // Mint NST into the buffer
        proxy.doCall(
            address(vault),
            abi.encodeCall(vault.draw, (nstAmount))
        );

        // Transfer NST from the buffer to the proxy
        proxy.doCall(
            address(nst),
            abi.encodeCall(nst.transferFrom, (buffer, address(proxy), nstAmount))
        );
    }

    function burnNST(uint256 nstAmount) external onlyRole(RELAYER) isActive {
        // Transfer NST from the proxy to the buffer
        proxy.doCall(
            address(nst),
            abi.encodeCall(nst.transfer, (buffer, nstAmount))
        );

        // Burn NST from the buffer
        proxy.doCall(
            address(vault),
            abi.encodeCall(vault.wipe, (nstAmount))
        );
    }

    /**********************************************************************************************/
    /*** Relayer sNST functions                                                                 ***/
    /**********************************************************************************************/

    function swapNSTToSNST(uint256 nstAmount) external onlyRole(RELAYER) isActive {
        // Approve NST to sNST from the proxy (assumes the proxy has enough NST)
        proxy.doCall(
            address(nst),
            abi.encodeCall(nst.approve, (address(snst), nstAmount))
        );

        // Deposit NST into sNST, proxy receives sNST shares
        proxy.doCall(
            address(snst),
            abi.encodeCall(snst.deposit, (nstAmount, address(proxy)))
        );
    }

    /**********************************************************************************************/
    /*** Relayer PSM functions                                           s                      ***/
    /**********************************************************************************************/

    function swapNSTToUSDC(uint256 usdcAmount) external onlyRole(RELAYER) isActive {
        uint256 conversionFactor = psm.to18ConversionFactor();

        // Approve NST to PSM from the proxy (assumes the proxy has enough NST)
        proxy.doCall(
            address(nst),
            abi.encodeCall(nst.approve, (address(psm), usdcAmount * conversionFactor))
        );

        // Swap NST to USDC through the PSM
        proxy.doCall(
            address(psm),
            abi.encodeCall(psm.buyGemNoFee, (address(proxy), usdcAmount))
        );
    }

    function swapUSDCToNST(uint256 usdcAmount) external onlyRole(RELAYER) isActive {
        // Approve USDC to PSM from the proxy (assumes the proxy has enough USDC)
        proxy.doCall(
            address(usdc),
            abi.encodeCall(usdc.approve, (address(psm), usdcAmount))
        );

        // Swap USDC to NST through the PSM
        proxy.doCall(
            address(psm),
            abi.encodeCall(psm.sellGemNoFee, (address(proxy), usdcAmount))
        );
    }

}

