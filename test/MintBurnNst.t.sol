// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./UnitTestBase.t.sol";

contract L1ControllerDrawTests is UnitTestBase {

    function test_draw() external {
        l1Controller.draw(1);
    }
}
