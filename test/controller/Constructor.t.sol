// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "test/UnitTestBase.t.sol";

contract L1ControllerConstructorTests is UnitTestBase {

    function test_constructor() public {
        // Deploy another l1Controller to test the constructor
        L1Controller newL1Controller = new L1Controller(
            admin,
            address(almProxy),
            address(vault),
            address(buffer),
            address(sNst)
        );

        assertEq(newL1Controller.hasRole(DEFAULT_ADMIN_ROLE, admin), true);
        assertEq(newL1Controller.active(),                           true);

        assertEq(address(newL1Controller.buffer()), address(buffer));
        assertEq(address(newL1Controller.proxy()),  address(almProxy));
        assertEq(address(newL1Controller.vault()),  address(vault));
        assertEq(address(newL1Controller.sNst()),   address(sNst));
        assertEq(address(newL1Controller.nst()),    address(nst));
    }
}
