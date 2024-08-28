// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "test/unit/UnitTestBase.t.sol";

import { ForeignController } from "src/ForeignController.sol";
import { MainnetController } from "src/MainnetController.sol";

import { MockDaiUsds } from "test/unit/mocks/MockDaiUsds.sol";
import { MockPSM }     from "test/unit/mocks/MockPSM.sol";
import { MockPSM3 }    from "test/unit/mocks/MockPSM3.sol";
import { MockSUsds }   from "test/unit/mocks/MockSUsds.sol";

contract MainnetControllerConstructorTests is UnitTestBase {

    function test_constructor() public {
        MockDaiUsds daiUsds = new MockDaiUsds(makeAddr("dai"));
        MockPSM     psm     = new MockPSM(makeAddr("usdc"));
        MockSUsds   susds   = new MockSUsds(makeAddr("usds"));

        MainnetController mainnetController = new MainnetController(
            admin,
            makeAddr("almProxy"),
            makeAddr("vault"),
            makeAddr("buffer"),
            address(psm),
            address(daiUsds),
            makeAddr("cctp"),
            address(susds)
        );

        assertEq(mainnetController.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(address(mainnetController.proxy()),   makeAddr("almProxy"));
        assertEq(address(mainnetController.vault()),   makeAddr("vault"));
        assertEq(address(mainnetController.buffer()),  makeAddr("buffer"));
        assertEq(address(mainnetController.psm()),     address(psm));
        assertEq(address(mainnetController.daiUsds()), address(daiUsds));
        assertEq(address(mainnetController.cctp()),    makeAddr("cctp"));
        assertEq(address(mainnetController.susds()),   address(susds));
        assertEq(address(mainnetController.dai()),     makeAddr("dai"));   // Dai param in MockDaiUsds
        assertEq(address(mainnetController.usdc()),    makeAddr("usdc"));  // Gem param in MockPSM
        assertEq(address(mainnetController.usds()),    makeAddr("usds"));  // Usds param in MockSUsds

        assertEq(mainnetController.active(), true);
    }

}

contract ForeignControllerConstructorTests is UnitTestBase {

    address almProxy = makeAddr("almProxy");
    address cctp     = makeAddr("cctp");
    address usds     = makeAddr("usds");
    address psm      = makeAddr("psm");
    address susds    = makeAddr("susds");
    address usdc     = makeAddr("usdc");

    function test_constructor() public {
        ForeignController foreignController = new ForeignController(
            admin,
            almProxy,
            psm,
            usds,
            usdc,
            susds,
            cctp
        );

        assertEq(foreignController.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(address(foreignController.proxy()), almProxy);
        assertEq(address(foreignController.psm()),   psm);
        assertEq(address(foreignController.usds()),  usds);   // asset0 param in MockPSM3
        assertEq(address(foreignController.usdc()),  usdc);   // asset1 param in MockPSM3
        assertEq(address(foreignController.susds()), susds);  // asset2 param in MockPSM3
        assertEq(address(foreignController.cctp()),  cctp);

        assertEq(foreignController.active(), true);
    }

}
