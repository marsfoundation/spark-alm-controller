// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

contract MockDaiNst {

    address public dai;

    constructor(address _dai) {
        dai = _dai;
    }

}