// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

library RateLimitHelpers {

    function makeAssetKey(bytes32 key, address asset) internal pure returns (bytes32) {
        return keccak256(abi.encode(key, asset));
    }

}
