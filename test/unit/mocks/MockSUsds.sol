// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

contract MockSUsds {

    address public usds;

    constructor(address _usds) {
       usds = _usds;
    }

}
