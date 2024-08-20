// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "test/unit/UnitTestBase.t.sol";

contract MainnetControllerConstructorTests is UnitTestBase {

    function test_constructor() public {
        // Deploy another mainnetController to test the constructor
        MainnetController newMainnetController = new MainnetController(
            admin,
            address(almProxy),
            makeAddr("vault"),
            makeAddr("buffer"),
            address(psm),
            address(daiNst),
            makeAddr("cctp"),
            address(snst)
        );

        assertEq(newMainnetController.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(address(newMainnetController.proxy()),  address(almProxy));
        assertEq(address(newMainnetController.vault()),  makeAddr("vault"));
        assertEq(address(newMainnetController.buffer()), makeAddr("buffer"));
        assertEq(address(newMainnetController.psm()),    address(psm));
        assertEq(address(newMainnetController.daiNst()), address(daiNst));
        assertEq(address(newMainnetController.cctp()),   makeAddr("cctp"));
        assertEq(address(newMainnetController.snst()),   address(snst));
        assertEq(address(newMainnetController.dai()),    makeAddr("dai"));   // Dai param in MockDaiNst
        assertEq(address(newMainnetController.usdc()),   makeAddr("usdc"));  // Gem param in MockPsm
        assertEq(address(newMainnetController.nst()),    makeAddr("nst"));   // Nst param in MockSNst

        assertEq(newMainnetController.active(), true);
    }

}
