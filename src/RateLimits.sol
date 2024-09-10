// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IRateLimits } from "src/interfaces/IRateLimits.sol";

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract RateLimits is IRateLimits, AccessControl {

    /**********************************************************************************************/
    /*** State variables                                                                        ***/
    /**********************************************************************************************/

    bytes32 public override constant CONTROLLER = keccak256("CONTROLLER");

    mapping(bytes32 => RateLimit) public override limits;

    /**********************************************************************************************/
    /*** Initialization                                                                         ***/
    /**********************************************************************************************/

    constructor(
        address admin_
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
    }

    /**********************************************************************************************/
    /*** Admin functions                                                                        ***/
    /**********************************************************************************************/

    function setRateLimit(
        bytes32 key,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 slope,
        uint256 amount,
        uint256 lastUpdated
    )
        public override onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(minAmount <= maxAmount,                     "RateLimits/invalid-minAmount-maxAmount");
        require(lastUpdated <= block.timestamp,             "RateLimits/invalid-lastUpdated");
        require(amount >= minAmount && amount <= maxAmount, "RateLimits/invalid-amount");

        limits[key] = RateLimit({
            minAmount:   minAmount,
            maxAmount:   maxAmount,
            slope:       slope,
            amount:      amount,
            lastUpdated: lastUpdated
        });

        emit RateLimitSet(key, minAmount, maxAmount, slope, amount, lastUpdated);
    }

    function setRateLimit(
        bytes32 key,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 slope
    )
        public override
    {
        setRateLimit(key, minAmount, maxAmount, slope, minAmount, block.timestamp);
    }

    function setRateLimit(
        bytes32 key,
        address asset,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 slope
    )
        external override
    {
        setRateLimit(keccak256(abi.encode(key, asset)), minAmount, maxAmount, slope);
    }

    function setUnlimitedRateLimit(
        bytes32 key
    )
        public override
    {
        setRateLimit(key, type(uint256).max, type(uint256).max, 0, type(uint256).max, block.timestamp);
    }

    function setUnlimitedRateLimit(
        bytes32 key,
        address asset
    )
        external override
    {
        setUnlimitedRateLimit(keccak256(abi.encode(key, asset)));
    }

    /**********************************************************************************************/
    /*** Getter Functions                                                                       ***/
    /**********************************************************************************************/

    function getCurrentRateLimit(bytes32 key) public override view returns (uint256) {
        RateLimit memory limit = limits[key];

        // Unlimited rate limit case
        if (limit.minAmount == type(uint256).max) {
            return type(uint256).max;
        }

        return _min(
            limit.slope * (block.timestamp - limit.lastUpdated) + limit.amount,
            limit.maxAmount
        );
    }

    function getCurrentRateLimit(bytes32 key, address asset) external override view returns (uint256) {
        return getCurrentRateLimit(keccak256(abi.encode(key, asset)));
    }

    /**********************************************************************************************/
    /*** Controller functions                                                                   ***/
    /**********************************************************************************************/

    function triggerRateLimit(bytes32 key, uint256 amount)
        public override onlyRole(CONTROLLER) returns (uint256 newLimit)
    {
        require(amount > 0, "RateLimits/invalid-amount");

        uint256 currentRateLimit = getCurrentRateLimit(key);

        // Unlimited rate limit case
        if (currentRateLimit == type(uint256).max) {
            return type(uint256).max;
        }

        require(amount <= currentRateLimit, "RateLimits/rate-limit-exceeded");

        RateLimit storage limit = limits[key];

        limit.amount = newLimit = _max(currentRateLimit - amount, limit.minAmount);
        limit.lastUpdated = block.timestamp;

        emit RateLimitTriggered(key, amount, currentRateLimit, newLimit);
    }

    function triggerRateLimit(bytes32 key, address asset, uint256 amount)
        external override returns (uint256 newLimit)
    {
        return triggerRateLimit(keccak256(abi.encode(key, asset)), amount);
    }

    /**********************************************************************************************/
    /*** Internal Utility Functions                                                             ***/
    /**********************************************************************************************/

    function _max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

}

