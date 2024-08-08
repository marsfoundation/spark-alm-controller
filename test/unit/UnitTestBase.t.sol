// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import { ALMProxy }           from "src/ALMProxy.sol";
import { EthereumController } from "src/EthereumController.sol";

import { MockPsm }  from "test/unit/mocks/MockPsm.sol";
import { MockSNst } from "test/unit/mocks/MockSNst.sol";

contract UnitTestBase is Test {

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    bytes32 constant CONTROLLER = keccak256("CONTROLLER");
    bytes32 constant FREEZER    = keccak256("FREEZER");
    bytes32 constant RELAYER    = keccak256("RELAYER");

    address admin   = makeAddr("admin");
    address freezer = makeAddr("freezer");
    address relayer = makeAddr("relayer");

    MockPsm  psm;
    MockSNst snst;

    ALMProxy           almProxy;
    EthereumController ethereumController;

    function setUp() public virtual {
        psm  = new MockPsm(makeAddr("usdc"));
        snst = new MockSNst(makeAddr("nst"));

        almProxy = new ALMProxy(admin);

        ethereumController = new EthereumController(
            admin,
            address(almProxy),
            makeAddr("vault"),
            makeAddr("buffer"),
            address(snst),
            address(psm)
        );

        // Done with spell by pause proxy
        vm.startPrank(admin);

        ethereumController.grantRole(FREEZER, freezer);
        ethereumController.grantRole(RELAYER, relayer);

        almProxy.grantRole(FREEZER,    freezer);
        almProxy.grantRole(CONTROLLER, address(ethereumController));

        vm.stopPrank();
    }

}
