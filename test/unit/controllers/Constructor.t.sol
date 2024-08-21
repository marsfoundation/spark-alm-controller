// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "test/unit/UnitTestBase.t.sol";

import { ForeignController } from "src/ForeignController.sol";
import { MainnetController } from "src/MainnetController.sol";

import { MockDaiNst } from "test/unit/mocks/MockDaiNst.sol";
import { MockPSM }    from "test/unit/mocks/MockPSM.sol";
import { MockPSM3 }   from "test/unit/mocks/MockPSM3.sol";
import { MockSNst }   from "test/unit/mocks/MockSNst.sol";

contract MainnetControllerConstructorTests is UnitTestBase {

    function test_constructor() public {
        MockDaiNst daiNst = new MockDaiNst(makeAddr("dai"));
        MockPSM    psm    = new MockPSM(makeAddr("usdc"));
        MockSNst   snst   = new MockSNst(makeAddr("nst"));

        MainnetController mainnetController = new MainnetController(
            admin,
            makeAddr("almProxy"),
            makeAddr("vault"),
            makeAddr("buffer"),
            address(psm),
            address(daiNst),
            makeAddr("cctp"),
            address(snst)
        );

        assertEq(mainnetController.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(address(mainnetController.proxy()),  makeAddr("almProxy"));
        assertEq(address(mainnetController.vault()),  makeAddr("vault"));
        assertEq(address(mainnetController.buffer()), makeAddr("buffer"));
        assertEq(address(mainnetController.psm()),    address(psm));
        assertEq(address(mainnetController.daiNst()), address(daiNst));
        assertEq(address(mainnetController.cctp()),   makeAddr("cctp"));
        assertEq(address(mainnetController.snst()),   address(snst));
        assertEq(address(mainnetController.dai()),    makeAddr("dai"));   // Dai param in MockDaiNst
        assertEq(address(mainnetController.usdc()),   makeAddr("usdc"));  // Gem param in MockPSM
        assertEq(address(mainnetController.nst()),    makeAddr("nst"));   // Nst param in MockSNst

        assertEq(mainnetController.active(), true);
    }

}

contract ForeignControllerConstructorTests is UnitTestBase {

    address nst  = makeAddr("nst");
    address usdc = makeAddr("usdc");
    address snst = makeAddr("snst");

    function test_constructor() public {
        MockPSM3 psm3 = new MockPSM3(nst, usdc, snst);

        ForeignController foreignController = new ForeignController(
            admin,
            makeAddr("almProxy"),
            address(psm3),
            nst,
            usdc,
            snst
        );

        assertEq(foreignController.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(address(foreignController.proxy()), makeAddr("almProxy"));
        assertEq(address(foreignController.psm()),   address(psm3));
        assertEq(address(foreignController.nst()),   nst);   // asset0 param in MockPSM3
        assertEq(address(foreignController.usdc()),  usdc);  // asset1 param in MockPSM3
        assertEq(address(foreignController.snst()),  snst);  // asset2 param in MockPSM3

        assertEq(foreignController.active(), true);
    }

}
