// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import "deploy/Deploy.sol";  // All imports needed so not importing explicitly

import { MockDaiUsds } from "test/unit/mocks/MockDaiUsds.sol";
import { MockPSM }     from "test/unit/mocks/MockPSM.sol";
import { MockPSM3 }    from "test/unit/mocks/MockPSM3.sol";
import { MockSUsds }   from "test/unit/mocks/MockSUsds.sol";

contract DeployTests is Test {

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    function test_ALMProxyDeploy() public {
        address admin = makeAddr("admin");

        address almProxy = ALMProxyDeploy.deploy(admin);

        assertEq(ALMProxy(almProxy).hasRole(DEFAULT_ADMIN_ROLE, admin), true);
    }

    function test_ForeignControllerDeploy() public {
        address admin = makeAddr("admin");
        address psm   = makeAddr("psm");
        address usdc  = makeAddr("usdc");
        address cctp  = makeAddr("cctp");

        ( address almProxy, address foreignController, address rateLimits )
            = ForeignControllerDeploy.deploy(admin, psm, usdc, cctp);

        assertEq(ALMProxy(almProxy).hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(RateLimits(rateLimits).hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        ForeignController controller = ForeignController(foreignController);

        assertEq(controller.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(address(controller.proxy()),      almProxy);
        assertEq(address(controller.rateLimits()), rateLimits);
        assertEq(address(controller.psm()),        psm);
        assertEq(address(controller.usdc()),       usdc);
        assertEq(address(controller.cctp()),       cctp);

        assertEq(controller.active(), true);
    }

    function test_MainnetControllerDeploy() public {
        MockDaiUsds daiUsds = new MockDaiUsds(makeAddr("dai"));
        MockPSM     psm     = new MockPSM(makeAddr("usdc"));
        MockSUsds   susds   = new MockSUsds(makeAddr("usds"));

        address admin   = makeAddr("admin");
        address vault   = makeAddr("vault");
        address buffer  = makeAddr("buffer");
        address cctp    = makeAddr("cctp");

        ( address almProxy, address mainnetController, address rateLimits )
            = MainnetControllerDeploy.deploy(
                admin,
                vault,
                buffer,
                address(psm),
                address(daiUsds),
                cctp,
                address(susds)
            );

        assertEq(ALMProxy(almProxy).hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(RateLimits(rateLimits).hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        MainnetController controller = MainnetController(mainnetController);

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

    function test_RateLimitsDeploy() public {
        address admin = makeAddr("admin");

        address rateLimits = RateLimitsDeploy.deploy(admin);

        assertEq(RateLimits(rateLimits).hasRole(DEFAULT_ADMIN_ROLE, admin), true);
    }
}
