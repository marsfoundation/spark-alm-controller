// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

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

    bytes32 public constant FREEZER = keccak256("FREEZER");
    bytes32 public constant RELAYER = keccak256("RELAYER");

    L1Controller l1Controller;

    address conduit;
    address vault;

    function setUp() public virtual {
        l1Controller = new L1Controller();

        l1Controller.grantRole(DEFAULT_ADMIN_ROLE, admin);

        l1Controller.grantRole(FREEZER, freezer);
        l1Controller.grantRole(RELAYER, relayer);
    }

}
