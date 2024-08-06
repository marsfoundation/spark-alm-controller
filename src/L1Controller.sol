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

interface IALMProxyLike {
    function doCall(address target, bytes calldata data)
        external payable returns (bytes memory result);

    function doDelegateCall(address target, bytes calldata data)
        external payable returns (bytes memory result);
}

contract L1Controller is AccessControl {

    /**********************************************************************************************/
    /*** State variables                                                                        ***/
    /**********************************************************************************************/

    bytes32 public constant FREEZER = keccak256("FREEZER");
    bytes32 public constant RELAYER = keccak256("RELAYER");

    address public immutable buffer;

    IALMProxyLike public immutable proxy;
    IVaultLike    public immutable vault;
    ISNstLike     public immutable sNst;
    IERC20        public immutable nst;

    bool public active;

    /**********************************************************************************************/
    /*** Initialization                                                                         ***/
    /**********************************************************************************************/

    constructor(
        address admin_,
        address proxy_,
        address vault_,
        address buffer_,
        address sNst_
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);

        buffer = buffer_;
        proxy  = IALMProxyLike(proxy_);
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
    /*** Freezer functions                                                                      ***/
    /**********************************************************************************************/

    function freeze() external onlyRole(FREEZER) {
        active = false;
    }

    function reactivate() external onlyRole(DEFAULT_ADMIN_ROLE) {
        active = true;
    }

    /**********************************************************************************************/
    /*** Relayer functions                                                                      ***/
    /**********************************************************************************************/

    function draw(uint256 wad) external onlyRole(RELAYER) isActive {
        // Mint NST into the buffer
        proxy.doCall(
            address(vault),
            abi.encodeWithSelector(vault.draw.selector, wad)
        );

        // Transfer NST from the buffer to the proxy
        proxy.doCall(
            address(nst),
            abi.encodeWithSelector(nst.transferFrom.selector, buffer, address(proxy), wad)
        );
    }

    function wipe(uint256 wad) external onlyRole(RELAYER) isActive {
        // Transfer NST from the proxy to the buffer
        proxy.doCall(
            address(nst),
            abi.encodeWithSelector(nst.transfer.selector, buffer, wad)
        );

        // Burn NST from the buffer
        proxy.doCall(
            address(vault),
            abi.encodeWithSelector(vault.wipe.selector, wad)
        );
    }

    function depositNstToSNst(uint256 wad) external onlyRole(RELAYER) isActive {
        // Approve NST to sNST from the proxy (assumes the proxy has enough NST)
        proxy.doCall(
            address(nst),
            abi.encodeWithSelector(nst.approve.selector, address(sNst), wad)
        );

        // Deposit NST into sNST, proxy receives sNST shares
        proxy.doCall(
            address(sNst),
            abi.encodeWithSelector(sNst.deposit.selector, wad, address(proxy))
        );
    }

}

