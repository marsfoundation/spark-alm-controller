// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import { IPSM3 } from "spark-psm/src/interfaces/IPSM3.sol";

import { IALMProxy } from "src/interfaces/IALMProxy.sol";

interface ICCTPLike {
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken
    ) external returns (uint64 nonce);
}

contract ForeignController is AccessControl {

    // TODO: Inherit and override interface

    /**********************************************************************************************/
    /*** State variables                                                                        ***/
    /**********************************************************************************************/

    bytes32 public constant FREEZER = keccak256("FREEZER");
    bytes32 public constant RELAYER = keccak256("RELAYER");

    IALMProxy public immutable proxy;
    IPSM3     public immutable psm;

    IERC20 public immutable usds;
    IERC20 public immutable usdc;
    IERC20 public immutable susds;

    ICCTPLike public cctp;

    bool public active;

    mapping(uint32 destinationDomain => bytes32 mintRecipient) public mintRecipients;

    /**********************************************************************************************/
    /*** Initialization                                                                         ***/
    /**********************************************************************************************/

    constructor(
        address admin_,
        address proxy_,
        address psm_,
        address usds_,
        address usdc_,
        address susds_,
        address cctp_
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);

        proxy = IALMProxy(proxy_);
        psm   = IPSM3(psm_);

        usds  = IERC20(usds_);
        usdc  = IERC20(usdc_);
        susds = IERC20(susds_);

        cctp = ICCTPLike(cctp_);

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
    /*** Relayer bridging functions                                                             ***/
    /**********************************************************************************************/

    function transferUSDCToCCTP(uint256 usdcAmount, uint32 destinationDomain)
        external onlyRole(RELAYER) isActive
    {
        bytes32 mintRecipient = mintRecipients[destinationDomain];

        require(mintRecipient != 0, "ForeignController/domain-not-configured");

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

    /**********************************************************************************************/
    /*** Relayer PSM functions                                                                  ***/
    /**********************************************************************************************/

    function depositPSM(address asset, uint256 amount)
        external onlyRole(RELAYER) isActive returns (uint256 shares)
    {
        // Approve `asset` to PSM from the proxy (assumes the proxy has enough `asset`).
        proxy.doCall(
            asset,
            abi.encodeCall(IERC20.approve, (address(psm), amount))
        );

        // Deposit `amount` of `asset` in the PSM, decode the result to get `shares`.
        shares = abi.decode(
            proxy.doCall(
                address(psm),
                abi.encodeCall(
                    psm.deposit,
                    (asset, address(proxy), amount)
                )
            ),
            (uint256)
        );
    }

    function withdrawPSM(address asset, uint256 maxAmount)
        external onlyRole(RELAYER) isActive returns (uint256 assetsWithdrawn)
    {
        // Withdraw up to `maxAmount` of `asset` in the PSM, decode the result
        // to get `assetsWithdrawn` (assumes the proxy has enough PSM shares).
        assetsWithdrawn = abi.decode(
            proxy.doCall(
                address(psm),
                abi.encodeCall(
                    psm.withdraw,
                    (asset, address(proxy), maxAmount)
                )
            ),
            (uint256)
        );
    }

}
