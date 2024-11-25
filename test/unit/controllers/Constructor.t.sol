// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "test/unit/UnitTestBase.t.sol";

import { ForeignController } from "src/ForeignController.sol";
import { MainnetController } from "src/MainnetController.sol";

import { MockDaiUsds } from "test/unit/mocks/MockDaiUsds.sol";
import { MockPSM }     from "test/unit/mocks/MockPSM.sol";
import { MockPSM3 }    from "test/unit/mocks/MockPSM3.sol";
import { MockSUsde }   from "test/unit/mocks/MockSUsde.sol";
import { MockSUsds }   from "test/unit/mocks/MockSUsds.sol";
import { MockVault }   from "test/unit/mocks/MockVault.sol";

contract MainnetControllerConstructorTests is UnitTestBase {

    function test_constructor() public {
        MockDaiUsds daiUsds = new MockDaiUsds(makeAddr("dai"));
        MockPSM     psm     = new MockPSM(makeAddr("usdc"));
        MockSUsde   susde   = new MockSUsde(makeAddr("usde"));
        MockSUsds   susds   = new MockSUsds(makeAddr("usds"));
        MockVault   vault   = new MockVault(makeAddr("buffer"));

        MainnetController mainnetController = new MainnetController(
            admin,
            makeAddr("almProxy"),
            makeAddr("rateLimits"),
            address(vault),
            address(psm),
            address(daiUsds),
            makeAddr("cctp"),
            address(susds),
            address(susde),
            makeAddr("ethenaMinter")
        );

        assertEq(mainnetController.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(address(mainnetController.proxy()),        makeAddr("almProxy"));
        assertEq(address(mainnetController.rateLimits()),   makeAddr("rateLimits"));
        assertEq(address(mainnetController.vault()),        address(vault));
        assertEq(address(mainnetController.buffer()),       makeAddr("buffer"));  // Buffer param in MockVault
        assertEq(address(mainnetController.psm()),          address(psm));
        assertEq(address(mainnetController.daiUsds()),      address(daiUsds));
        assertEq(address(mainnetController.cctp()),         makeAddr("cctp"));
        assertEq(address(mainnetController.ethenaMinter()), makeAddr("ethenaMinter"));
        assertEq(address(mainnetController.susde()),        address(susde));
        assertEq(address(mainnetController.susds()),        address(susds));
        assertEq(address(mainnetController.dai()),          makeAddr("dai"));   // Dai param in MockDaiUsds
        assertEq(address(mainnetController.usdc()),         makeAddr("usdc"));  // Gem param in MockPSM
        assertEq(address(mainnetController.usds()),         makeAddr("usds"));  // Usds param in MockSUsds
        assertEq(address(mainnetController.usde()),         makeAddr("usde"));  // Usde param in MockSUsde

        assertEq(mainnetController.psmTo18ConversionFactor(), psm.to18ConversionFactor());
        assertEq(mainnetController.psmTo18ConversionFactor(), 1e12);

        assertEq(mainnetController.active(), true);
    }

}

contract ForeignControllerConstructorTests is UnitTestBase {

    address almProxy   = makeAddr("almProxy");
    address rateLimits = makeAddr("rateLimits");
    address cctp       = makeAddr("cctp");
    address psm        = makeAddr("psm");
    address usdc       = makeAddr("usdc");

    function test_constructor() public {
        ForeignController foreignController = new ForeignController(
            admin,
            almProxy,
            rateLimits,
            psm,
            usdc,
            cctp
        );

        assertEq(foreignController.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(address(foreignController.proxy()),      almProxy);
        assertEq(address(foreignController.rateLimits()), rateLimits);
        assertEq(address(foreignController.psm()),        psm);
        assertEq(address(foreignController.usdc()),       usdc);   // asset1 param in MockPSM3
        assertEq(address(foreignController.cctp()),       cctp);

        assertEq(foreignController.active(), true);
    }

}
