// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { IRateLimits } from "src/interfaces/IRateLimits.sol";

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract RateLimits is IRateLimits, AccessControl {

    /**********************************************************************************************/
    /*** State variables                                                                        ***/
    /**********************************************************************************************/

    bytes32 public override constant CONTROLLER = keccak256("CONTROLLER");

    mapping(bytes32 => RateLimitData) private _data;

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
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        public override onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(lastAmount <= maxAmount,        "RateLimits/invalid-lastAmount");
        require(lastUpdated <= block.timestamp, "RateLimits/invalid-lastUpdated");

        _data[key] = RateLimitData({
            maxAmount:   maxAmount,
            slope:       slope,
            lastAmount:  lastAmount,
            lastUpdated: lastUpdated
        });

        emit RateLimitSet(key, maxAmount, slope, lastAmount, lastUpdated);
    }

    function setRateLimit(
        bytes32 key,
        uint256 maxAmount,
        uint256 slope
    )
        external override
    {
        setRateLimit(key, maxAmount, slope, maxAmount, block.timestamp);
    }

    function setUnlimitedRateLimit(
        bytes32 key
    )
        external override
    {
        setRateLimit(key, type(uint256).max, 0, type(uint256).max, block.timestamp);
    }

    /**********************************************************************************************/
    /*** Getter Functions                                                                       ***/
    /**********************************************************************************************/

    function getData(bytes32 key) external override view returns (RateLimitData memory) {
        return _data[key];
    }

    function getCurrentRateLimit(bytes32 key) public override view returns (uint256) {
        RateLimitData memory d = _data[key];

        // Unlimited rate limit case
        if (d.maxAmount == type(uint256).max) {
            return type(uint256).max;
        }

        return _min(
            d.slope * (block.timestamp - d.lastUpdated) + d.lastAmount,
            d.maxAmount
        );
    }

    /**********************************************************************************************/
    /*** Controller functions                                                                   ***/
    /**********************************************************************************************/

    function triggerRateLimit(bytes32 key, uint256 amountToDecrease)
        external override onlyRole(CONTROLLER) returns (uint256 newLimit)
    {
        RateLimitData storage d = _data[key];

        require(d.maxAmount > 0, "RateLimits/zero-maxAmount");

        uint256 currentRateLimit = getCurrentRateLimit(key);

        // Unlimited rate limit case
        if (currentRateLimit == type(uint256).max) {
            return type(uint256).max;
        }

        require(amountToDecrease <= currentRateLimit, "RateLimits/rate-limit-exceeded");

        d.lastAmount = newLimit = currentRateLimit - amountToDecrease;
        d.lastUpdated = block.timestamp;

        emit RateLimitTriggered(key, amountToDecrease, currentRateLimit, newLimit);
    }

    /**********************************************************************************************/
    /*** Internal Utility Functions                                                             ***/
    /**********************************************************************************************/

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

}

library RateLimitHelpers {

    function makeAssetKey(bytes32 key, address asset) internal pure returns (bytes32) {
        return keccak256(abi.encode(key, asset));
    }

}

