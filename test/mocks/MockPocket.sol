// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { MockERC20 } from "lib/erc20-helpers/src/MockERC20.sol";

contract MockPocket {

    function approve(address gem, address psm) public {
        MockERC20(gem).approve(psm, type(uint256).max);
    }

}
