// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "test/UnitTestBase.t.sol";

contract EthereumControllerFreezeTests is UnitTestBase {

    function test_freeze_unauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            FREEZER
        ));
        ethereumController.freeze();

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            admin,
            FREEZER
        ));
        ethereumController.freeze();
    }

    function test_freeze() public {
        assertEq(ethereumController.active(), true);

        vm.prank(freezer);
        ethereumController.freeze();

        assertEq(ethereumController.active(), false);

        vm.prank(freezer);
        ethereumController.freeze();

        assertEq(ethereumController.active(), false);
    }

}

contract EthereumControllerReactivateTests is UnitTestBase {

    function test_reactivate_unauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        ethereumController.reactivate();

        vm.prank(freezer);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            freezer,
            DEFAULT_ADMIN_ROLE
        ));
        ethereumController.reactivate();
    }

    function test_reactivate() public {
        vm.prank(freezer);
        ethereumController.freeze();

        assertEq(ethereumController.active(), false);

        vm.prank(admin);
        ethereumController.reactivate();

        assertEq(ethereumController.active(), true);

        vm.prank(admin);
        ethereumController.reactivate();

        assertEq(ethereumController.active(), true);
    }

}
