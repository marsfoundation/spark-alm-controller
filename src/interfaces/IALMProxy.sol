// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

interface IALMProxy {

    /**
     * @notice Returns the controller identifier
     * @dev    This function retrieves a constant `bytes32` value that represents the controller.
     * @return The `bytes32` identifier of the controller.
     */
    function CONTROLLER() external view returns (bytes32);

    /**
     * @notice Executes a low-level call to a target contract
     * @dev    Performs a standard call to the specified `target` with the given `data`.
     *         Reverts if the call fails.
     * @param  target The address of the target contract to call.
     * @param  data   The calldata that will be sent to the target contract.
     * @return result The returned data from the call.
     */
    function doCall(address target, bytes calldata data)
        external payable returns (bytes memory result);

    /**
     * @notice Executes a low-level call with value transfer to a target contract
     * @dev    This function allows for transferring `value` (ether) along with the call to the target contract.
     *         Reverts if the call fails.
     * @param  target The address of the target contract to call.
     * @param  data   The calldata that will be sent to the target contract.
     * @param  value  The amount of Ether (in wei) to send with the call.
     * @return result The returned data from the call.
     */
    function doCallWithValue(address target, bytes memory data, uint256 value)
        external payable returns (bytes memory result);

    /**
     * @notice Executes a low-level delegate call to a target contract
     * @dev    This function performs a delegate call to the specified `target`
     *         with the given `data`. Reverts if the call fails.
     * @param  target The address of the target contract to delegate call.
     * @param  data   The calldata that will be sent to the target contract.
     * @return result The returned data from the delegate call.
     */
    function doDelegateCall(address target, bytes calldata data)
        external payable returns (bytes memory result);

}
