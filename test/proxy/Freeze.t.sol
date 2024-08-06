// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "test/UnitTestBase.t.sol";

contract ALMProxyFreezeTests is UnitTestBase {

    function test_freeze_unauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            FREEZER
        ));
        almProxy.freeze();

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            admin,
            FREEZER
        ));
        almProxy.freeze();
    }

    function test_freeze() public {
        assertEq(almProxy.active(), true);

        vm.prank(freezer);
        almProxy.freeze();

        assertEq(almProxy.active(), false);

        vm.prank(freezer);
        almProxy.freeze();

        assertEq(almProxy.active(), false);
    }

}

contract ALMProxyReactivateTests is UnitTestBase {

    function test_reactivate_unauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        almProxy.reactivate();

        vm.prank(freezer);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            freezer,
            DEFAULT_ADMIN_ROLE
        ));
        almProxy.reactivate();
    }

    function test_reactivate() public {
        vm.prank(freezer);
        almProxy.freeze();

        assertEq(almProxy.active(), false);

        vm.prank(admin);
        almProxy.reactivate();

        assertEq(almProxy.active(), true);

        vm.prank(admin);
        almProxy.reactivate();

        assertEq(almProxy.active(), true);
    }

}
