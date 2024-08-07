// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

interface IALMProxy {

    function CONTROLLER() external view returns (bytes32);

    function doCall(address target, bytes calldata data)
        external payable returns (bytes memory result);

    function doCallWithValue(address target, bytes memory data, uint256 value)
        external payable returns (bytes memory result);

    function doDelegateCall(address target, bytes calldata data)
        external payable returns (bytes memory result);
}
