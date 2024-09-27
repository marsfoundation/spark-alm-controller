// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "test/unit/UnitTestBase.t.sol";

import "deploy/ControllerDeploy.sol";  // All imports needed so not importing explicitly

import { MockDaiUsds } from "test/unit/mocks/MockDaiUsds.sol";
import { MockPSM }     from "test/unit/mocks/MockPSM.sol";
import { MockSUsds }   from "test/unit/mocks/MockSUsds.sol";

contract ForeignControllerDeployTests is UnitTestBase {

    function test_deployController() public {
        address admin = makeAddr("admin");
        address psm   = makeAddr("psm");
        address usdc  = makeAddr("usdc");
        address cctp  = makeAddr("cctp");

        ALMProxy   almProxy   = new ALMProxy(admin);
        RateLimits rateLimits = new RateLimits(admin);

        ForeignController controller = ForeignController(
            ForeignControllerDeploy.deployController(
                admin,
                address(almProxy),
                address(rateLimits),
                psm,
                usdc,
                cctp
            )
        );

        assertEq(controller.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(address(controller.proxy()),      address(almProxy));
        assertEq(address(controller.rateLimits()), address(rateLimits));
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

        ALMProxy          almProxy   = ALMProxy(instance.almProxy);
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

    function test_deployController() public {
        address admin = makeAddr("admin");
        address psm   = makeAddr("psm");
        address usdc  = makeAddr("usdc");
        address cctp  = makeAddr("cctp");

        ALMProxy   almProxy   = new ALMProxy(admin);
        RateLimits rateLimits = new RateLimits(admin);

        ForeignController controller = ForeignController(
            ForeignControllerDeploy.deployController(
                admin,
                address(almProxy),
                address(rateLimits),
                psm,
                usdc,
                cctp
            )
        );

        assertEq(controller.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(address(controller.proxy()),      address(almProxy));
        assertEq(address(controller.rateLimits()), address(rateLimits));
        assertEq(address(controller.psm()),        psm);
        assertEq(address(controller.usdc()),       usdc);
        assertEq(address(controller.cctp()),       cctp);

        assertEq(controller.active(), true);
    }

    function test_deployFull() public {
        MockDaiUsds daiUsds = new MockDaiUsds(makeAddr("dai"));
        MockPSM     psm     = new MockPSM(makeAddr("usdc"));
        MockSUsds   susds   = new MockSUsds(makeAddr("usds"));

        address admin   = makeAddr("admin");
        address vault   = makeAddr("vault");
        address buffer  = makeAddr("buffer");
        address cctp    = makeAddr("cctp");

        ControllerInstance memory instance = MainnetControllerDeploy.deployFull(
            admin,
            vault,
            buffer,
            address(psm),
            address(daiUsds),
            cctp,
            address(susds)
        );

        ALMProxy          almProxy   = ALMProxy(instance.almProxy);
        MainnetController controller = MainnetController(instance.controller);
        RateLimits        rateLimits = RateLimits(instance.rateLimits);

        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, admin),   true);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, admin), true);
        assertEq(controller.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(address(controller.proxy()),      almProxy);
        assertEq(address(controller.rateLimits()), rateLimits);
        assertEq(address(controller.vault()),      vault);
        assertEq(address(controller.buffer()),     buffer);
        assertEq(address(controller.psm()),        address(psm));
        assertEq(address(controller.daiUsds()),    address(daiUsds));
        assertEq(address(controller.cctp()),       cctp);
        assertEq(address(controller.susds()),      address(susds));
        assertEq(address(controller.dai()),        makeAddr("dai"));   // Dai param in MockDaiUsds
        assertEq(address(controller.usdc()),       makeAddr("usdc"));  // Gem param in MockPSM
        assertEq(address(controller.usds()),       makeAddr("usds"));  // Usds param in MockSUsds

        assertEq(controller.psmTo18ConversionFactor(), 1e12);
        assertEq(controller.active(),                  true);
    }

}



    // function test_MainnetControllerDeploy() public {
    //     MockDaiUsds daiUsds = new MockDaiUsds(makeAddr("dai"));
    //     MockPSM     psm     = new MockPSM(makeAddr("usdc"));
    //     MockSUsds   susds   = new MockSUsds(makeAddr("usds"));

    //     address admin   = makeAddr("admin");
    //     address vault   = makeAddr("vault");
    //     address buffer  = makeAddr("buffer");
    //     address cctp    = makeAddr("cctp");

    //     ( address almProxy, address mainnetController, address rateLimits )
    //         = MainnetControllerDeploy.deploy(
    //             admin,
    //             vault,
    //             buffer,
    //             address(psm),
    //             address(daiUsds),
    //             cctp,
    //             address(susds)
    //         );

    //     assertEq(ALMProxy(almProxy).hasRole(DEFAULT_ADMIN_ROLE, admin), true);

    //     assertEq(RateLimits(rateLimits).hasRole(DEFAULT_ADMIN_ROLE, admin), true);

    //     MainnetController controller = MainnetController(mainnetController);

    //     assertEq(controller.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

    //     assertEq(address(controller.proxy()),      almProxy);
    //     assertEq(address(controller.rateLimits()), rateLimits);
    //     assertEq(address(controller.vault()),      vault);
    //     assertEq(address(controller.buffer()),     buffer);
    //     assertEq(address(controller.psm()),        address(psm));
    //     assertEq(address(controller.daiUsds()),    address(daiUsds));
    //     assertEq(address(controller.cctp()),       cctp);
    //     assertEq(address(controller.susds()),      address(susds));
    //     assertEq(address(controller.dai()),        makeAddr("dai"));   // Dai param in MockDaiUsds
    //     assertEq(address(controller.usdc()),       makeAddr("usdc"));  // Gem param in MockPSM
    //     assertEq(address(controller.usds()),       makeAddr("usds"));  // Usds param in MockSUsds

    //     assertEq(controller.psmTo18ConversionFactor(), 1e12);
    //     assertEq(controller.active(),                  true);
    // }

    // function test_RateLimitsDeploy() public {
    //     address admin = makeAddr("admin");

    //     address rateLimits = RateLimitsDeploy.deploy(admin);

    //     assertEq(RateLimits(rateLimits).hasRole(DEFAULT_ADMIN_ROLE, admin), true);
    // }
// }
