// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "test/unit/UnitTestBase.t.sol";

import "deploy/ControllerDeploy.sol";  // All imports needed so not importing explicitly

import { MockDaiUsds } from "test/unit/mocks/MockDaiUsds.sol";
import { MockPSM }     from "test/unit/mocks/MockPSM.sol";
import { MockSUsds }   from "test/unit/mocks/MockSUsds.sol";
import { MockVault }   from "test/unit/mocks/MockVault.sol";

contract ForeignControllerDeployTests is UnitTestBase {

    function test_deployController() public {
        address admin = makeAddr("admin");
        address psm   = makeAddr("psm");
        address usdc  = makeAddr("usdc");
        address cctp  = makeAddr("cctp");

        address almProxy   = address(new ALMProxy(admin));
        address rateLimits = address(new RateLimits(admin));

        ForeignController controller = ForeignController(
            ForeignControllerDeploy.deployController(
                admin,
                almProxy,
                rateLimits,
                psm,
                usdc,
                cctp
            )
        );

        assertEq(controller.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(address(controller.proxy()),      almProxy);
        assertEq(address(controller.rateLimits()), rateLimits);
        assertEq(address(controller.psm()),        psm);
        assertEq(address(controller.usdc()),       usdc);
        assertEq(address(controller.cctp()),       cctp);

        assertEq(controller.active(), true);
    }

    function test_deployFull() public {
        address admin = makeAddr("admin");
        address psm   = makeAddr("psm");
        address usdc  = makeAddr("usdc");
        address cctp  = makeAddr("cctp");

        ControllerInstance memory instance
            = ForeignControllerDeploy.deployFull(admin, psm, usdc, cctp);

        ALMProxy          almProxy   = ALMProxy(payable(instance.almProxy));
        ForeignController controller = ForeignController(instance.controller);
        RateLimits        rateLimits = RateLimits(instance.rateLimits);

        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, admin),   true);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, admin), true);
        assertEq(controller.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(address(controller.proxy()),      instance.almProxy);
        assertEq(address(controller.rateLimits()), instance.rateLimits);
        assertEq(address(controller.psm()),        psm);
        assertEq(address(controller.usdc()),       usdc);
        assertEq(address(controller.cctp()),       cctp);

        assertEq(controller.active(), true);
    }

}

contract MainnetControllerDeployTests is UnitTestBase {

    struct TestVars {
        address daiUsds;
        address psm;
        address susds;
        address admin;
        address vault;
        address cctp;
    }

    function test_deployController() public {
        TestVars memory vars;  // Avoid stack too deep

        vars.daiUsds = address(new MockDaiUsds(makeAddr("dai")));
        vars.psm     = address(new MockPSM(makeAddr("usdc")));
        vars.susds   = address(new MockSUsds(makeAddr("usds")));
        vars.vault   = address(new MockVault(makeAddr("buffer")));

        vars.admin = makeAddr("admin");
        vars.cctp  = makeAddr("cctp");

        address almProxy   = address(new ALMProxy(admin));
        address rateLimits = address(new RateLimits(admin));

        MainnetController controller = MainnetController(
            MainnetControllerDeploy.deployController(
                admin,
                almProxy,
                rateLimits,
                vars.vault,
                vars.psm,
                vars.daiUsds,
                vars.cctp,
                vars.susds
            )
        );

        assertEq(controller.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(address(controller.proxy()),      almProxy);
        assertEq(address(controller.rateLimits()), rateLimits);
        assertEq(address(controller.vault()),      vars.vault);
        assertEq(address(controller.buffer()),     makeAddr("buffer"));  // Buffer param in MockVault
        assertEq(address(controller.psm()),        vars.psm);
        assertEq(address(controller.daiUsds()),    vars.daiUsds);
        assertEq(address(controller.cctp()),       vars.cctp);
        assertEq(address(controller.susds()),      vars.susds);
        assertEq(address(controller.dai()),        makeAddr("dai"));   // Dai param in MockDaiUsds
        assertEq(address(controller.usdc()),       makeAddr("usdc"));  // Gem param in MockPSM
        assertEq(address(controller.usds()),       makeAddr("usds"));  // Usds param in MockSUsds

        assertEq(controller.psmTo18ConversionFactor(), 1e12);
        assertEq(controller.active(),                  true);
    }

    function test_deployFull() public {
        TestVars memory vars;  // Avoid stack too deep

        vars.daiUsds = address(new MockDaiUsds(makeAddr("dai")));
        vars.psm     = address(new MockPSM(makeAddr("usdc")));
        vars.susds   = address(new MockSUsds(makeAddr("usds")));
        vars.vault   = address(new MockVault(makeAddr("buffer")));

        vars.admin  = makeAddr("admin");
        vars.cctp   = makeAddr("cctp");

        ControllerInstance memory instance = MainnetControllerDeploy.deployFull(
            admin,
            vars.vault,
            vars.psm,
            vars.daiUsds,
            vars.cctp,
            vars.susds
        );

        ALMProxy          almProxy   = ALMProxy(payable(instance.almProxy));
        MainnetController controller = MainnetController(instance.controller);
        RateLimits        rateLimits = RateLimits(instance.rateLimits);

        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, admin),   true);
        assertEq(controller.hasRole(DEFAULT_ADMIN_ROLE, admin), true);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(address(controller.proxy()),      instance.almProxy);
        assertEq(address(controller.rateLimits()), instance.rateLimits);
        assertEq(address(controller.vault()),      vars.vault);
        assertEq(address(controller.buffer()),     makeAddr("buffer"));  // Buffer param in MockVault
        assertEq(address(controller.psm()),        vars.psm);
        assertEq(address(controller.daiUsds()),    vars.daiUsds);
        assertEq(address(controller.cctp()),       vars.cctp);
        assertEq(address(controller.susds()),      vars.susds);
        assertEq(address(controller.dai()),        makeAddr("dai"));   // Dai param in MockDaiUsds
        assertEq(address(controller.usdc()),       makeAddr("usdc"));  // Gem param in MockPSM
        assertEq(address(controller.usds()),       makeAddr("usds"));  // Usds param in MockSUsds

        assertEq(controller.psmTo18ConversionFactor(), 1e12);
        assertEq(controller.active(),                  true);
    }

}
