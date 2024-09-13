// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

interface IRateLimits {

    /**********************************************************************************************/
    /*** Structs                                                                                ***/
    /**********************************************************************************************/

    /**
     * @dev Struct representing a rate limit.
     *      The current rate limit is calculated using the formula:
     *      `currentRateLimit = min(slope * (block.timestamp - lastUpdated) + lastAmount, maxAmount)`.
     * @param maxAmount Maximum allowed amount at any time.
     * @param slope The slope of the rate limit, used to calculate the new limit based on time passed. [tokens / second]
     * @param lastAmount The amount left available at the last update.
     * @param lastUpdated The timestamp when the rate limit was last updated.
     */
    struct RateLimitData {
        uint256 maxAmount;
        uint256 slope;
        uint256 lastAmount;
        uint256 lastUpdated;
    }

    /**********************************************************************************************/
    /*** Events                                                                                 ***/
    /**********************************************************************************************/

    /**
     * @dev Emitted when the rate limit data is set.
     * @param key The identifier for the rate limit.
     * @param maxAmount The maximum allowed amount for the rate limit.
     * @param slope The slope value used in the rate limit calculation.
     * @param lastAmount The amount left available at the last update.
     * @param lastUpdated The timestamp when the rate limit was last updated.
     */
    event RateLimitDataSet(
        bytes32 indexed key,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    );

    /**
     * @dev Emitted when a rate limit decrease is triggered.
     * @param key The identifier for the rate limit.
     * @param amountToDecrease The amount to decrease from the current rate limit.
     * @param oldRateLimit The previous rate limit value before triggering.
     * @param newRateLimit The new rate limit value after triggering.
     */
    event RateLimitDecreaseTriggered(
        bytes32 indexed key,
        uint256 amountToDecrease,
        uint256 oldRateLimit,
        uint256 newRateLimit
    );

    /**
     * @dev Emitted when a rate limit increase is triggered.
     * @param key The identifier for the rate limit.
     * @param amountToIncrease The amount to increase from the current rate limit.
     * @param oldRateLimit The previous rate limit value before triggering.
     * @param newRateLimit The new rate limit value after triggering.
     */
    event RateLimitIncreaseTriggered(
        bytes32 indexed key,
        uint256 amountToIncrease,
        uint256 oldRateLimit,
        uint256 newRateLimit
    );

    /**********************************************************************************************/
    /*** State variables                                                                        ***/
    /**********************************************************************************************/

    /**
     * @dev Returns the controller identifier as a bytes32 value.
     * @return bytes32 The controller identifier.
     */
    function CONTROLLER() external view returns (bytes32);

    /**********************************************************************************************/
    /*** Admin functions                                                                        ***/
    /**********************************************************************************************/

    /**
     * @dev Sets a rate limit for a specific key with the provided parameters, including the current amount and last update time.
     * @param key The identifier for the rate limit.
     * @param maxAmount The maximum allowed amount for the rate limit.
     * @param slope The slope value used in the rate limit calculation.
     * @param lastAmount The amount left available at the last update.
     * @param lastUpdated The timestamp when the rate limit was last updated.
     */
    function setRateLimit(
        bytes32 key,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
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
     * @dev Sets an unlimited rate limit.
     * @param key The identifier for the rate limit.
     */
    function setUnlimitedRateLimit(
        bytes32 key
    ) external;

    /**********************************************************************************************/
    /*** Getter Functions                                                                       ***/
    /**********************************************************************************************/

    /**
     * @dev Retrieves the RateLimitData struct associated with a specific key.
     * @param key The identifier for the rate limit.
     * @return The data associated with the rate limit.
     */
    function getRateLimitData(bytes32 key) external view returns (RateLimitData memory);

    /**
     * @dev Retrieves the current rate limit for a specific key.
     * @param key The identifier for the rate limit.
     * @return The current rate limit value for the given key.
     */
    function getCurrentRateLimit(bytes32 key) external view returns (uint256);

    /**********************************************************************************************/
    /*** Controller functions                                                                   ***/
    /**********************************************************************************************/

    /**
     * @dev Triggers the rate limit for a specific key and reduces the available amount by the provided value.
     * @param key The identifier for the rate limit.
     * @param amountToDecrease The amount to decrease from the current rate limit.
     * @return newLimit The updated rate limit after the deduction.
     */
    function triggerRateLimitDecrease(bytes32 key, uint256 amountToDecrease) external returns (uint256 newLimit);

    /**
     * @dev Increases the rate limit for a given key up to the maxAmount.
     * @param key The identifier for the rate limit.
     * @param amountToIncrease The amount to increase from the current rate limit.
     * @return newLimit The updated rate limit after the addition.
     */
    function triggerRateLimitIncrease(bytes32 key, uint256 amountToIncrease) external returns (uint256 newLimit);

}
