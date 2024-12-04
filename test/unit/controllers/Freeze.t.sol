// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { MainnetController } from "../../../src/MainnetController.sol";
import { ForeignController } from "../../../src/ForeignController.sol";

import { MockDaiUsds } from "../mocks/MockDaiUsds.sol";
import { MockPSM }     from "../mocks/MockPSM.sol";
import { MockPSM3 }    from "../mocks/MockPSM3.sol";
import { MockSUsds }   from "../mocks/MockSUsds.sol";
import { MockVault }   from "../mocks/MockVault.sol";

import "../UnitTestBase.t.sol";

interface IBaseControllerLike {
    function active() external view returns (bool);
    function grantRole(bytes32 role, address account) external;
    function freeze() external;
    function reactivate() external;
}

contract ControllerTestBase is UnitTestBase {

    IBaseControllerLike controller;

    function setUp() public virtual {
        MockDaiUsds daiUsds = new MockDaiUsds(makeAddr("dai"));
        MockPSM     psm     = new MockPSM(makeAddr("usdc"));
        MockSUsds   susds   = new MockSUsds(makeAddr("susds"));
        MockVault   vault   = new MockVault(makeAddr("buffer"));

        // Default to mainnet controller for tests and override with foreign controller
        controller = IBaseControllerLike(address(new MainnetController(
            admin,
            makeAddr("almProxy"),
            makeAddr("rateLimits"),
            address(vault),
            address(psm),
            address(daiUsds),
            makeAddr("cctp"),
            address(susds)
        )));

        _setRoles();
    }

    function _setRoles() internal {
        // Done with spell by pause proxy
        vm.startPrank(admin);

        controller.grantRole(FREEZER, freezer);
        controller.grantRole(RELAYER, relayer);

        vm.stopPrank();
    }

}

contract ControllerFreezeTests is ControllerTestBase {

    event Frozen();

    function test_freeze_unauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            FREEZER
        ));
        controller.freeze();

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            admin,
            FREEZER
        ));
        controller.freeze();
    }

    function test_freeze() public {
        assertEq(controller.active(), true);

        vm.prank(freezer);
        controller.freeze();

        assertEq(controller.active(), false);

        vm.prank(freezer);
        vm.expectEmit(address(controller));
        emit Frozen();
        controller.freeze();

        assertEq(controller.active(), false);
    }

}

contract ControllerReactivateTests is ControllerTestBase {

    event Reactivated();

    function test_reactivate_unauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        controller.reactivate();

        vm.prank(freezer);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            freezer,
            DEFAULT_ADMIN_ROLE
        ));
        controller.reactivate();
    }

    function test_reactivate() public {
        vm.prank(freezer);
        controller.freeze();

        assertEq(controller.active(), false);

        vm.prank(admin);
        controller.reactivate();

        assertEq(controller.active(), true);

        vm.prank(admin);
        vm.expectEmit(address(controller));
        emit Reactivated();
        controller.reactivate();

        assertEq(controller.active(), true);
    }

}

contract ForeignControllerFreezeTest is ControllerFreezeTests {

    address usds  = makeAddr("usds");
    address usdc  = makeAddr("usdc");
    address susds = makeAddr("susds");

    // Override setUp to run the same tests against the foreign controller
    function setUp() public override {
        MockPSM3 psm3 = new MockPSM3(usds, usdc, susds);

        controller = IBaseControllerLike(address(new ForeignController(
            admin,
            makeAddr("almProxy"),
            makeAddr("rateLimits"),
            address(psm3),
            usdc,
            makeAddr("cctp")
        )));

        _setRoles();
    }

}

contract ForeignControllerReactivateTest is ControllerReactivateTests {

    address usds  = makeAddr("usds");
    address usdc  = makeAddr("usdc");
    address susds = makeAddr("susds");

    // Override setUp to run the same tests against the foreign controller
    function setUp() public override {
        MockPSM3 psm3 = new MockPSM3(usds, usdc, susds);

        controller = IBaseControllerLike(address(new ForeignController(
            admin,
            makeAddr("almProxy"),
            makeAddr("rateLimits"),
            address(psm3),
            usdc,
            makeAddr("cctp")
        )));

        _setRoles();
    }

}
