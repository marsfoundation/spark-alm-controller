// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./UnitTestBase.t.sol";

contract L1ControllerACLTests is UnitTestBase {

    function test_freeze() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            FREEZER
        ));
        l1Controller.freeze();

        vm.prank(freezer);
        l1Controller.freeze();
    }

    function test_reactivate() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        l1Controller.reactivate();

        vm.prank(admin);
        l1Controller.reactivate();
    }

}
