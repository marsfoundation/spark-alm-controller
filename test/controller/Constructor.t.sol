// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "test/UnitTestBase.t.sol";

contract EthereumControllerConstructorTests is UnitTestBase {

    function test_constructor() public {
        // Deploy another ethereumController to test the constructor
        EthereumController newEthereumController = new EthereumController(
            admin,
            address(almProxy),
            address(vault),
            address(buffer),
            address(snst),
            address(psm)
        );

        assertEq(newEthereumController.hasRole(DEFAULT_ADMIN_ROLE, admin), true);
        assertEq(newEthereumController.active(),                           true);

        assertEq(address(newEthereumController.buffer()), address(buffer));
        assertEq(address(newEthereumController.proxy()),  address(almProxy));
        assertEq(address(newEthereumController.vault()),  address(vault));
        assertEq(address(newEthereumController.snst()),   address(snst));
        assertEq(address(newEthereumController.psm()),    address(psm));
        assertEq(address(newEthereumController.usdc()),   address(usdc));
        assertEq(address(newEthereumController.nst()),    address(nst));
    }

}
