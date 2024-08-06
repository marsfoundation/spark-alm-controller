// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./UnitTestBase.t.sol";

contract L1ControllerConstructorTests is UnitTestBase {

    function test_constructor() public {
        // From setUp
        assertEq(l1Controller.hasRole(DEFAULT_ADMIN_ROLE, address(this)), true);

        // Overwrite L1Controller with a new instance
        vm.prank(admin);
        l1Controller = new L1Controller();

        assertEq(l1Controller.hasRole(DEFAULT_ADMIN_ROLE, address(this)), false);
        assertEq(l1Controller.hasRole(DEFAULT_ADMIN_ROLE, admin),         true);
    }
}
