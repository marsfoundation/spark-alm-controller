// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

contract MockSUsde {

    address public asset;

    constructor(address _asset) {
       asset = _asset;
    }

}
