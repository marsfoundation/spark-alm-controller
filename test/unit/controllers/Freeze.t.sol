// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "test/unit/UnitTestBase.t.sol";

import { MainnetController } from "src/MainnetController.sol";
import { ForeignController } from "src/ForeignController.sol";

import { MockDaiNst } from "test/unit/mocks/MockDaiNst.sol";
import { MockPSM }    from "test/unit/mocks/MockPSM.sol";
import { MockPSM3 }    from "test/unit/mocks/MockPSM3.sol";
import { MockSNst }   from "test/unit/mocks/MockSNst.sol";

interface IBaseControllerLike {
    function active() external view returns (bool);
    function grantRole(bytes32 role, address account) external;
    function freeze() external;
    function reactivate() external;
}

contract ControllerTestBase is UnitTestBase {

    IBaseControllerLike controller;

    function setUp() public virtual {
        MockDaiNst daiNst = new MockDaiNst(makeAddr("dai"));
        MockPSM    psm    = new MockPSM(makeAddr("usdc"));
        MockSNst   snst   = new MockSNst(makeAddr("nst"));

        // Default to mainnet controller for tests and override with L2 controller
        controller = IBaseControllerLike(address(new MainnetController(
            admin,
            makeAddr("almProxy"),
            makeAddr("vault"),
            makeAddr("buffer"),
            address(psm),
            address(daiNst),
            makeAddr("cctp"),
            address(snst)
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
        controller.freeze();

        assertEq(controller.active(), false);
    }

}

contract ControllerReactivateTests is ControllerTestBase {

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
        controller.reactivate();

        assertEq(controller.active(), true);
    }

}

contract ForeignControllerFreezeTest is ControllerFreezeTests {

    address nst  = makeAddr("nst");
    address usdc = makeAddr("usdc");
    address snst = makeAddr("snst");

    // Override setUp to run the same tests against the L2 controller
    function setUp() public override {
        MockPSM3 psm3 = new MockPSM3(nst, usdc, snst);

        controller = IBaseControllerLike(address(new ForeignController(
            admin,
            makeAddr("almProxy"),
            address(psm3),
            nst,
            usdc,
            snst
        )));

        _setRoles();
    }

}

contract ForeignControllerReactivateTest is ControllerReactivateTests {

    address nst  = makeAddr("nst");
    address usdc = makeAddr("usdc");
    address snst = makeAddr("snst");

    // Override setUp to run the same tests against the L2 controller
    function setUp() public override {
        MockPSM3 psm3 = new MockPSM3(nst, usdc, snst);

        controller = IBaseControllerLike(address(new ForeignController(
            admin,
            makeAddr("almProxy"),
            address(psm3),
            nst,
            usdc,
            snst
        )));

        _setRoles();
    }

}
