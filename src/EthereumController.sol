// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IERC20 } from "erc20-helpers/interfaces/IERC20.sol";

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import { IALMProxy } from "src/interfaces/IALMProxy.sol";

interface IDaiNstLike {
    function dai() external view returns(address);
    function daiToNst(address usr, uint256 wad) external;
    function nstToDai(address usr, uint256 wad) external;
}

interface ISNSTLike {
    function deposit(uint256 assets, address receiver) external;
    function nst() external view returns(address);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
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

    IALMProxy   public immutable proxy;
    IDaiNstLike public immutable daiNst;
    IPSMLike    public immutable psm;
    IVaultLike  public immutable vault;

    IERC20    public immutable dai;
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
        address vault_,
        address buffer_,
        address psm_,
        address daiNst_,
        address snst_
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);

        proxy  = IALMProxy(proxy_);
        vault  = IVaultLike(vault_);
        buffer = buffer_;
        psm    = IPSMLike(psm_);
        daiNst = IDaiNstLike(daiNst_);

        snst = ISNSTLike(snst_);
        dai  = IERC20(daiNst.dai());
        usdc = IERC20(psm.gem());
        nst  = IERC20(snst.nst());

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

    function swapSNSTToNST(uint256 nstAmount) external onlyRole(RELAYER) isActive {
        // Withdraw NST from sNST, assumes proxy has adequate sNST shares
        proxy.doCall(
            address(snst),
            abi.encodeCall(snst.withdraw, (nstAmount, address(proxy), address(proxy)))
        );
    }

    /**********************************************************************************************/
    /*** Relayer PSM functions                                           s                      ***/
    /**********************************************************************************************/

    function swapNSTToUSDC(uint256 usdcAmount) external onlyRole(RELAYER) isActive {
        uint256 wadAmount = usdcAmount * psm.to18ConversionFactor();

        // Approve NST to DaiNst migrator from the proxy (assumes the proxy has enough NST)
        proxy.doCall(
            address(nst),
            abi.encodeCall(nst.approve, (address(daiNst), wadAmount))
        );

        // Swap NST to DAI 1:1
        proxy.doCall(
            address(daiNst),
            abi.encodeCall(daiNst.nstToDai, (address(proxy), wadAmount))
        );

        // Approve DAI to PSM from the proxy (assumes the proxy has enough DAI)
        proxy.doCall(
            address(dai),
            abi.encodeCall(dai.approve, (address(psm), wadAmount))
        );

        // Swap NST to USDC through the PSM
        proxy.doCall(
            address(psm),
            abi.encodeCall(psm.buyGemNoFee, (address(proxy), usdcAmount))
        );
    }

    function swapUSDCToNST(uint256 usdcAmount) external onlyRole(RELAYER) isActive {
        uint256 wadAmount = usdcAmount * psm.to18ConversionFactor();

        // Approve USDC to PSM from the proxy (assumes the proxy has enough USDC)
        proxy.doCall(
            address(usdc),
            abi.encodeCall(usdc.approve, (address(psm), usdcAmount))
        );

        // Swap USDC to DAI through the PSM
        proxy.doCall(
            address(psm),
            abi.encodeCall(psm.sellGemNoFee, (address(proxy), usdcAmount))
        );

        // Approve DAI to  DaiNst migrator from the proxy (assumes the proxy has enough DAI)
        proxy.doCall(
            address(dai),
            abi.encodeCall(dai.approve, (address(daiNst), wadAmount))
        );

        // Swap DAI to NST 1:1
        proxy.doCall(
            address(daiNst),
            abi.encodeCall(daiNst.daiToNst, (address(proxy), wadAmount))
        );
    }

}

