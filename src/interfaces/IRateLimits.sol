// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

interface IRateLimits {

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    /**
     * @dev Struct representing a rate limit.
     *      The amount is calculated using the formula: `currentRateLimit = slope * (block.timestamp - lastUpdated) + amount`.
     * @param maxAmount Maximum allowed amount.
     * @param slope The slope of the rate limit, used to calculate the new limit based on time passed.
     * @param amount The current amount available based on the rate limit.
     * @param lastUpdated The timestamp when the rate limit was last updated.
     */
    struct RateLimit {
        uint256 maxAmount;
        uint256 slope;
        uint256 amount;
        uint256 lastUpdated;
    }

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev Emitted when a rate limit is set.
     * @param key The identifier for the rate limit.
     * @param maxAmount The maximum allowed amount for the rate limit.
     * @param slope The slope value used in the rate limit calculation.
     * @param amount The current amount available under the rate limit.
     * @param lastUpdated The timestamp when the rate limit was last updated.
     */
    event RateLimitSet(
        bytes32 indexed key,
        uint256 maxAmount,
        uint256 slope,
        uint256 amount,
        uint256 lastUpdated
    );

    /**
     * @dev Emitted when a rate limit is triggered.
     * @param key The identifier for the rate limit.
     * @param amount The amount that triggered the rate limit.
     * @param oldLimit The previous rate limit value before triggering.
     * @param newLimit The new rate limit value after triggering.
     */
    event RateLimitTriggered(
        bytes32 indexed key,
        uint256 amount,
        uint256 oldLimit,
        uint256 newLimit
    );

    /**********************************************************************************************/
    /*** State variables                                                                        ***/
    /**********************************************************************************************/

    /**
     * @dev Returns the controller identifier as a bytes32 value.
     * @return bytes32 The controller identifier.
     */
    function CONTROLLER() external view returns (bytes32);

    /**
     * @dev Retrieves the RateLimit struct associated with a specific key.
     * @param key The identifier for the rate limit.
     * @return maxAmount Maximum allowed amount.
     * @return slope The slope of the rate limit, used to calculate the new limit based on time passed.
     * @return amount The current amount available based on the rate limit.
     * @return lastUpdated The timestamp when the rate limit was last updated.
     */
    function limits(bytes32 key) external view returns (
        uint256 maxAmount,
        uint256 slope,
        uint256 amount,
        uint256 lastUpdated
    );

    /**********************************************************************************************/
    /*** Admin functions                                                                        ***/
    /**********************************************************************************************/

    /**
     * @dev Sets a rate limit for a specific key with the provided parameters, including the current amount and last update time.
     * @param key The identifier for the rate limit.
     * @param maxAmount The maximum allowed amount for the rate limit.
     * @param slope The slope value used in the rate limit calculation.
     * @param amount The current amount available under the rate limit.
     * @param lastUpdated The timestamp when the rate limit was last updated.
     */
    function setRateLimit(
        bytes32 key,
        uint256 maxAmount,
        uint256 slope,
        uint256 amount,
        uint256 lastUpdated
    ) external;

    /**
     * @dev Sets a rate limit for a specific key with the provided parameters.
     * @param key The identifier for the rate limit.
     * @param maxAmount The maximum allowed amount for the rate limit.
     * @param slope The slope value used in the rate limit calculation.
     */
    function setRateLimit(
        bytes32 key,
        uint256 maxAmount,
        uint256 slope
    ) external;

    /**
     * @dev Sets a rate limit for a specific key with the provided parameters.
     * @param key The identifier for the rate limit.
     * @param asset The address of the asset to set the rate limit for.
     * @param maxAmount The maximum allowed amount for the rate limit.
     * @param slope The slope value used in the rate limit calculation.
     */
    function setRateLimit(
        bytes32 key,
        address asset,
        uint256 maxAmount,
        uint256 slope
    ) external;

    /**
     * @dev Sets an unlimited rate limit.
     * @param key The identifier for the rate limit.
     */
    function setUnlimitedRateLimit(
        bytes32 key
    ) external;

    /**
     * @dev Sets an unlimited rate limit.
     * @param key The identifier for the rate limit.
     * @param asset The address of the asset to set the rate limit for.
     */
    function setUnlimitedRateLimit(
        bytes32 key,
        address asset
    ) external;

    /**********************************************************************************************/
    /*** Getter Functions                                                                       ***/
    /**********************************************************************************************/

    /**
     * @dev Retrieves the current rate limit for a specific key.
     * @param key The identifier for the rate limit.
     * @return uint256 The current rate limit value for the given key.
     */
    function getCurrentRateLimit(bytes32 key) external view returns (uint256);

    /**
     * @dev Retrieves the current rate limit for a specific key and asset.
     * @param key The identifier for the rate limit.
     * @param asset The address of the asset to retrieve the rate limit for.
     * @return uint256 The current rate limit value for the given key and asset.
     */
    function getCurrentRateLimit(bytes32 key, address asset) external view returns (uint256);

    /**********************************************************************************************/
    /*** Controller functions                                                                   ***/
    /**********************************************************************************************/

    /**
     * @dev Triggers the rate limit for a specific key and reduces the available amount by the provided value.
     * @param key The identifier for the rate limit.
     * @param amount The amount to deduct from the available rate limit.
     * @return newLimit The updated rate limit after the deduction.
     */
    function triggerRateLimit(bytes32 key, uint256 amount) external returns (uint256 newLimit);

    /**
     * @dev Triggers the rate limit for a specific key and asset, reducing the available amount by the provided value.
     * @param key The identifier for the rate limit.
     * @param asset The address of the asset to trigger the rate limit for.
     * @param amount The amount to deduct from the available rate limit.
     * @return newLimit The updated rate limit after the deduction.
     */
    function triggerRateLimit(bytes32 key, address asset, uint256 amount) external returns (uint256 newLimit);

}
