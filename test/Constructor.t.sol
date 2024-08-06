// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import { L1Controller } from "src/L1Controller.sol";

contract L1ControllerConstructorTests is Test {

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    function test_constructor() public {
        address admin = makeAddr("admin");
        address vault = makeAddr("vault");

        L1Controller l1Controller = new L1Controller(admin, address(vault));

        assertEq(l1Controller.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(address(l1Controller.vault()), vault);
    }
}
