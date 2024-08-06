// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "./UnitTestBase.t.sol";

contract L1ControllerACLTests is UnitTestBase {

    function test_setActive() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            FREEZER
        ));
        l1Controller.setActive(true);

        vm.prank(freezer);
        l1Controller.setActive(true);
    }

}
