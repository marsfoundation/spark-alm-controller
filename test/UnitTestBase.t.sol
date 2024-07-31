// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import { UpgradeableProxy } from "lib/upgradeable-proxy/src/UpgradeableProxy.sol";

import { L1Controller } from "src/L1Controller.sol";

contract RolesMock {

    function canCall(bytes32, address, address, bytes4) external pure returns (bool) {
        return true;
    }

}

contract UnitTestBase is Test {

    address admin   = makeAddr("admin");
    address freezer = makeAddr("freezer");
    address relayer = makeAddr("relayer");

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    L1Controller     l1Controller;
    L1Controller     l1ControllerImplementation;
    UpgradeableProxy l1ControllerProxy;

    address conduit;
    address vault;

    function setUp() public virtual {
        l1ControllerProxy          = new UpgradeableProxy();
        l1ControllerImplementation = new L1Controller();

        l1ControllerProxy.setImplementation(address(l1ControllerImplementation));

        l1Controller = L1Controller(address(l1ControllerProxy));

        l1Controller.initialize();

        l1Controller.grantRole(DEFAULT_ADMIN_ROLE, admin);
        l1Controller.grantRole("FREEZER",          freezer);
        l1Controller.grantRole("RELAYER",          relayer);

        UpgradeableProxy(address(l1Controller)).rely(admin);
        UpgradeableProxy(address(l1Controller)).deny(address(this));
    }

}
