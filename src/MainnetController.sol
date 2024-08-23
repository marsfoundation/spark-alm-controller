// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IERC20 }   from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import { IALMProxy } from "src/interfaces/IALMProxy.sol";

interface ICCTPLike {
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken
    ) external returns (uint64 nonce);
}

interface IDaiNstLike {
    function dai() external view returns(address);
    function daiToNst(address usr, uint256 wad) external;
    function nstToDai(address usr, uint256 wad) external;
}

interface ISNSTLike is IERC4626 {
    function nst() external view returns(address);
}

interface IVaultLike {
    function draw(uint256 nstAmount) external;
    function wipe(uint256 nstAmount) external;
}

interface IPSMLike {
    function buyGemNoFee(address usr, uint256 usdcAmount) external returns (uint256 nstAmount);
    function gem() external view returns(address);
    function sellGemNoFee(address usr, uint256 usdcAmount) external returns (uint256 nstAmount);
    function to18ConversionFactor() external view returns (uint256);
}

contract MainnetController is AccessControl {

    // TODO: Inherit and override interface

    /**********************************************************************************************/
    /*** State variables                                                                        ***/
    /**********************************************************************************************/

    bytes32 public constant FREEZER = keccak256("FREEZER");
    bytes32 public constant RELAYER = keccak256("RELAYER");

    address public immutable buffer;

    IALMProxy   public immutable proxy;
    ICCTPLike   public immutable cctp;
    IDaiNstLike public immutable daiNst;
    IPSMLike    public immutable psm;
    IVaultLike  public immutable vault;

    IERC20    public immutable dai;
    IERC20    public immutable nst;
    IERC20    public immutable usdc;
    ISNSTLike public immutable snst;

    bool public active;

    mapping(uint32 destinationDomain => bytes32 mintRecipient) public mintRecipients;

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
        address cctp_,
        address snst_
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);

        proxy  = IALMProxy(proxy_);
        vault  = IVaultLike(vault_);
        buffer = buffer_;
        psm    = IPSMLike(psm_);
        daiNst = IDaiNstLike(daiNst_);
        cctp   = ICCTPLike(cctp_);

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
        require(active, "MainnetController/not-active");
        _;
    }

    /**********************************************************************************************/
    /*** Admin functions                                                                        ***/
    /**********************************************************************************************/

    function setMintRecipient(uint32 destinationDomain, bytes32 mintRecipient)
        external onlyRole(DEFAULT_ADMIN_ROLE)
    {
        mintRecipients[destinationDomain] = mintRecipient;
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

    function depositToSNST(uint256 nstAmount)
        external onlyRole(RELAYER) isActive returns (uint256 shares)
    {
        // Approve NST to sNST from the proxy (assumes the proxy has enough NST).
        proxy.doCall(
            address(nst),
            abi.encodeCall(nst.approve, (address(snst), nstAmount))
        );

        // Deposit NST into sNST, proxy receives sNST shares, decode the resulting shares
        shares = abi.decode(
            proxy.doCall(
                address(snst),
                abi.encodeCall(snst.deposit, (nstAmount, address(proxy)))
            ),
            (uint256)
        );
    }

    function withdrawFromSNST(uint256 nstAmount)
        external onlyRole(RELAYER) isActive returns (uint256 shares)
    {
        // Withdraw NST from sNST, decode resulting shares.
        // Assumes proxy has adequate sNST shares.
        shares = abi.decode(
            proxy.doCall(
                address(snst),
                abi.encodeCall(snst.withdraw, (nstAmount, address(proxy), address(proxy)))
            ),
            (uint256)
        );
    }

    function redeemFromSNST(uint256 snstSharesAmount)
        external onlyRole(RELAYER) isActive returns (uint256 assets)
    {
        // Redeem shares for NST from sNST, decode the resulting assets.
        // Assumes proxy has adequate sNST shares.
        assets = abi.decode(
            proxy.doCall(
                address(snst),
                abi.encodeCall(snst.redeem, (snstSharesAmount, address(proxy), address(proxy)))
            ),
            (uint256)
        );
    }

    /**********************************************************************************************/
    /*** Relayer PSM functions                                                                  ***/
    /**********************************************************************************************/

    function swapNSTToUSDC(uint256 usdcAmount) external onlyRole(RELAYER) isActive {
        uint256 nstAmount = usdcAmount * psm.to18ConversionFactor();

        // Approve NST to DaiNst migrator from the proxy (assumes the proxy has enough NST)
        proxy.doCall(
            address(nst),
            abi.encodeCall(nst.approve, (address(daiNst), nstAmount))
        );

        // Swap NST to DAI 1:1
        proxy.doCall(
            address(daiNst),
            abi.encodeCall(daiNst.nstToDai, (address(proxy), nstAmount))
        );

        // Approve DAI to PSM from the proxy (assumes the proxy has enough DAI)
        proxy.doCall(
            address(dai),
            abi.encodeCall(dai.approve, (address(psm), nstAmount))
        );

        // Swap DAI to USDC through the PSM
        proxy.doCall(
            address(psm),
            abi.encodeCall(psm.buyGemNoFee, (address(proxy), usdcAmount))
        );
    }

    function swapUSDCToNST(uint256 usdcAmount) external onlyRole(RELAYER) isActive {
        uint256 nstAmount = usdcAmount * psm.to18ConversionFactor();

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

        // Approve DAI to DaiNst migrator from the proxy (assumes the proxy has enough DAI)
        proxy.doCall(
            address(dai),
            abi.encodeCall(dai.approve, (address(daiNst), nstAmount))
        );

        // Swap DAI to NST 1:1
        proxy.doCall(
            address(daiNst),
            abi.encodeCall(daiNst.daiToNst, (address(proxy), nstAmount))
        );
    }

    /**********************************************************************************************/
    /*** Relayer bridging functions                                                             ***/
    /**********************************************************************************************/

    function transferUSDCToCCTP(uint256 usdcAmount, uint32 destinationDomain)
        external onlyRole(RELAYER) isActive
    {
        bytes32 mintRecipient = mintRecipients[destinationDomain];

        require(mintRecipient != 0, "MainnetController/domain-not-configured");

        // Approve USDC to CCTP from the proxy (assumes the proxy has enough USDC)
        proxy.doCall(
            address(usdc),
            abi.encodeCall(usdc.approve, (address(cctp), usdcAmount))
        );

        // Send USDC to CCTP for bridging to destinationDomain
        proxy.doCall(
            address(cctp),
            abi.encodeCall(
                cctp.depositForBurn,
                (
                    usdcAmount,
                    destinationDomain,
                    mintRecipient,
                    address(usdc)
                )
            )
        );
    }

}

