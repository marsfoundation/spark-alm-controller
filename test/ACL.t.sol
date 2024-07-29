// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "./UnitTestBase.t.sol";

contract L1ControllerACLTests is UnitTestBase {

    address admin   = makeAddr("admin");
    address freezer = makeAddr("freezer");
    address relayer = makeAddr("relayer");

    function setUp() public override {
        super.setUp();

        l1Controller.setFreezer(freezer);
        l1Controller.setRelayer(relayer);

        // TODO: Move this into base
        UpgradeableProxy(address(l1Controller)).rely(admin);
        UpgradeableProxy(address(l1Controller)).deny(address(this));
    }

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

    function test_setRoles() public {
        vm.expectRevert("L1Controller/not-authorized");
        l1Controller.setRoles(address(1));

        vm.prank(admin);
        l1Controller.setRoles(address(1));
    }

    function test_setRelayer() public {
        vm.expectRevert("L1Controller/not-authorized");
        l1Controller.setRelayer(address(1));

        vm.prank(admin);
        l1Controller.setRelayer(address(1));
    }

    function test_setFreezer() public {
        vm.expectRevert("L1Controller/not-authorized");
        l1Controller.setFreezer(address(1));

        vm.prank(admin);
        l1Controller.setFreezer(address(1));
    }

    function test_setActive() public {
        vm.expectRevert("L1Controller/not-freezer");
        l1Controller.setActive(true);

        vm.prank(freezer);
        l1Controller.setActive(true);
    }

}
