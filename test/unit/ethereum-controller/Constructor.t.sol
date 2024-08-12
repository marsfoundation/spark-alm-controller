// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "test/unit/UnitTestBase.t.sol";

contract EthereumControllerConstructorTests is UnitTestBase {

    function test_constructor() public {
        // Deploy another ethereumController to test the constructor
        EthereumController newEthereumController = new EthereumController(
            admin,
            address(almProxy),
            makeAddr("vault"),
            makeAddr("buffer"),
            address(psm),
            address(daiNst),
            address(snst)
        );

        assertEq(newEthereumController.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(address(newEthereumController.proxy()),  address(almProxy));
        assertEq(address(newEthereumController.vault()),  makeAddr("vault"));
        assertEq(address(newEthereumController.buffer()), makeAddr("buffer"));
        assertEq(address(newEthereumController.psm()),    address(psm));
        assertEq(address(newEthereumController.daiNst()), address(daiNst));
        assertEq(address(newEthereumController.snst()),   address(snst));
        assertEq(address(newEthereumController.dai()),    makeAddr("dai"));   // Dai param in MockDaiNst
        assertEq(address(newEthereumController.usdc()),   makeAddr("usdc"));  // Gem param in MockPsm
        assertEq(address(newEthereumController.nst()),    makeAddr("nst"));   // Nst param in MockSNst

        assertEq(newEthereumController.active(), true);
    }

}
