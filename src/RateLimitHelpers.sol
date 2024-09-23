// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { console } from "forge-std/console.sol";

library RateLimitHelpers {

    function makeAssetKey(bytes32 key, address asset) internal pure returns (bytes32) {
        return keccak256(abi.encode(key, asset));
    }

    function makeDomainKey(bytes32 key, uint32 domain) internal view returns (bytes32) {
        console.log("key"   , uint256(key));
        console.log("domain", uint256(domain));
        return keccak256(abi.encode(key, domain));
    }

}
