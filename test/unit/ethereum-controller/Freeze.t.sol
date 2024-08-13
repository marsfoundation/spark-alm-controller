// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "test/unit/UnitTestBase.t.sol";

contract MainnetControllerFreezeTests is UnitTestBase {

    function test_freeze_unauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            FREEZER
        ));
        mainnetController.freeze();

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            admin,
            FREEZER
        ));
        mainnetController.freeze();
    }

    function test_freeze() public {
        assertEq(mainnetController.active(), true);

        vm.prank(freezer);
        mainnetController.freeze();

        assertEq(mainnetController.active(), false);

        vm.prank(freezer);
        mainnetController.freeze();

        assertEq(mainnetController.active(), false);
    }

}

contract MainnetControllerReactivateTests is UnitTestBase {

    function test_reactivate_unauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        mainnetController.reactivate();

        vm.prank(freezer);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            freezer,
            DEFAULT_ADMIN_ROLE
        ));
        mainnetController.reactivate();
    }

    function test_reactivate() public {
        vm.prank(freezer);
        mainnetController.freeze();

        assertEq(mainnetController.active(), false);

        vm.prank(admin);
        mainnetController.reactivate();

        assertEq(mainnetController.active(), true);

        vm.prank(admin);
        mainnetController.reactivate();

        assertEq(mainnetController.active(), true);
    }

}
