// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "test/unit/UnitTestBase.t.sol";

import { ALMProxy } from "src/ALMProxy.sol";

contract ALMProxyConstructorTests is UnitTestBase {

    function test_constructor() public {
        // Deploy another almProxy to test the constructor
        ALMProxy newAlmProxy = new ALMProxy(admin);

        assertEq(newAlmProxy.hasRole(DEFAULT_ADMIN_ROLE, admin), true);
    }
}
