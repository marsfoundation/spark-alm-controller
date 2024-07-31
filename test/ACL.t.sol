// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./UnitTestBase.t.sol";

contract L1ControllerACLTests is UnitTestBase {

    function test_rely() public {
        vm.expectRevert("UpgradeableProxy/not-authorized");
        UpgradeableProxy(address(l1Controller)).rely(address(1));

        vm.prank(admin);
        UpgradeableProxy(address(l1Controller)).rely(address(1));
    }

    function test_deny() public {
        vm.expectRevert("UpgradeableProxy/not-authorized");
        UpgradeableProxy(address(l1Controller)).deny(address(1));

        vm.prank(admin);
        UpgradeableProxy(address(l1Controller)).deny(address(1));
    }

    function test_setImplementation() public {
        address newImplementation = address(new L1Controller());

        vm.expectRevert("UpgradeableProxy/not-authorized");
        UpgradeableProxy(address(l1Controller)).setImplementation(newImplementation);

        vm.prank(admin);
        UpgradeableProxy(address(l1Controller)).setImplementation(newImplementation);
    }

    function test_setActive() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            bytes32("FREEZER")
        ));
        l1Controller.setActive(true);

        vm.prank(freezer);
        l1Controller.setActive(true);
    }

}
