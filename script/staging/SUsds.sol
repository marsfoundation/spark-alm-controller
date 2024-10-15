// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

contract SUsds is MockERC20 {

    address public usds;

    constructor(address usds_) MockERC20("sUSDS", "sUSDS", 18) {
        usds = usds_;
    }

}
