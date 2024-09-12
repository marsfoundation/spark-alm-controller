// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

import { IPSM3 } from "spark-psm/src/interfaces/IPSM3.sol";

import { IALMProxy }   from "src/interfaces/IALMProxy.sol";
import { IRateLimits } from "src/interfaces/IRateLimits.sol";

import { RateLimitHelpers } from "src/RateLimits.sol";

import { ICCTPLike } from "src/interfaces/CCTPInterfaces.sol";

contract ForeignController is AccessControl {

    /**********************************************************************************************/
    /*** State variables                                                                        ***/
    /**********************************************************************************************/

    bytes32 public constant FREEZER = keccak256("FREEZER");
    bytes32 public constant RELAYER = keccak256("RELAYER");

    bytes32 public constant LIMIT_USDC_TO_CCTP = keccak256("LIMIT_USDC_TO_CCTP");
    bytes32 public constant LIMIT_PSM_DEPOSIT  = keccak256("LIMIT_PSM_DEPOSIT");
    bytes32 public constant LIMIT_PSM_WITHDRAW = keccak256("LIMIT_PSM_WITHDRAW");

    IALMProxy   public immutable proxy;
    IRateLimits public immutable rateLimits;
    IPSM3       public immutable psm;

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
        address rateLimits_,
        address psm_,
        address usds_,
        address usdc_,
        address susds_,
        address cctp_
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);

        proxy      = IALMProxy(proxy_);
        rateLimits = IRateLimits(rateLimits_);
        psm        = IPSM3(psm_);

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

    modifier rateLimited(bytes32 key, uint256 amount) {
        rateLimits.triggerRateLimitDecrease(key, amount);
        _;
    }

    modifier rateLimitedAsset(bytes32 key, address asset, uint256 amount) {
        rateLimits.triggerRateLimitDecrease(RateLimitHelpers.makeAssetKey(key, asset), amount);
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
        external onlyRole(RELAYER) isActive rateLimited(LIMIT_USDC_TO_CCTP, usdcAmount)
    {
        bytes32 mintRecipient = mintRecipients[destinationDomain];

        require(mintRecipient != 0, "ForeignController/domain-not-configured");

        // Approve USDC to CCTP from the proxy (assumes the proxy has enough USDC)
        proxy.doCall(
            address(usdc),
            abi.encodeCall(usdc.approve, (address(cctp), usdcAmount))
        );

        // If amount is larger than limit we must break it up
        uint256 burnLimit = cctp.localMinter().burnLimitsPerMessage(address(usdc));
        while (usdcAmount > burnLimit) {
            proxy.doCall(
                address(cctp),
                abi.encodeCall(
                    cctp.depositForBurn,
                    (
                        burnLimit,
                        destinationDomain,
                        mintRecipient,
                        address(usdc)
                    )
                )
            );

            usdcAmount -= burnLimit;
        }

        // Send remainder if any
        if (usdcAmount > 0) {
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

    /**********************************************************************************************/
    /*** Relayer PSM functions                                                                  ***/
    /**********************************************************************************************/

    function depositPSM(address asset, uint256 amount)
        external onlyRole(RELAYER) isActive rateLimitedAsset(LIMIT_PSM_DEPOSIT, asset, amount) returns (uint256 shares)
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

    // NOTE: !!! Rate limited at end of function !!!
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

        rateLimits.triggerRateLimitDecrease(RateLimitHelpers.makeAssetKey(LIMIT_PSM_WITHDRAW, asset), assetsWithdrawn);
    }

}
