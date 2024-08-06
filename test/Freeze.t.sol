// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "./UnitTestBase.t.sol";

contract L1ControllerFreezeTests is UnitTestBase {

    function test_freeze_unauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            FREEZER
        ));
        l1Controller.freeze();

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            admin,
            FREEZER
        ));
        l1Controller.freeze();
    }

    function test_freeze() public {
        assertEq(l1Controller.active(), true);

        vm.prank(freezer);
        l1Controller.freeze();

        assertEq(l1Controller.active(), false);

        vm.prank(freezer);
        l1Controller.freeze();

        assertEq(l1Controller.active(), false);
    }

}

contract L1ControllerReactivateTests is UnitTestBase {

    function test_reactivate_unauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        l1Controller.reactivate();

        vm.prank(freezer);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            freezer,
            DEFAULT_ADMIN_ROLE
        ));
        l1Controller.reactivate();
    }

    function test_reactivate() public {
        vm.prank(freezer);
        l1Controller.freeze();

        assertEq(l1Controller.active(), false);

        vm.prank(admin);
        l1Controller.reactivate();

        assertEq(l1Controller.active(), true);

        vm.prank(admin);
        l1Controller.reactivate();

        assertEq(l1Controller.active(), true);
    }

}
