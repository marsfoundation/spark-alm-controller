// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

contract RateProvider {

    function getConversionRate() external pure returns (uint256) {
        return 1.2e27;
    }

}
