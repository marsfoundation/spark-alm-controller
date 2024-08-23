// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "test/unit/UnitTestBase.t.sol";

import { ForeignController } from "src/ForeignController.sol";
import { MainnetController } from "src/MainnetController.sol";

import { MockDaiNst } from "test/unit/mocks/MockDaiNst.sol";
import { MockPSM }    from "test/unit/mocks/MockPSM.sol";
import { MockSNst }   from "test/unit/mocks/MockSNst.sol";

contract MainnetControllerAdminTests is UnitTestBase {

    bytes32 mintRecipient1 = bytes32(uint256(uint160(makeAddr("mintRecipient1"))));
    bytes32 mintRecipient2 = bytes32(uint256(uint160(makeAddr("mintRecipient2"))));

    MainnetController mainnetController;

    function setUp() public {
        MockDaiNst daiNst = new MockDaiNst(makeAddr("dai"));
        MockPSM    psm    = new MockPSM(makeAddr("usdc"));
        MockSNst   snst   = new MockSNst(makeAddr("nst"));

        mainnetController = new MainnetController(
            admin,
            makeAddr("almProxy"),
            makeAddr("vault"),
            makeAddr("buffer"),
            address(psm),
            address(daiNst),
            makeAddr("cctp"),
            address(snst)
        );
    }

    function test_setMintRecipient_unauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        mainnetController.setMintRecipient(1, mintRecipient1);

        vm.prank(freezer);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            freezer,
            DEFAULT_ADMIN_ROLE
        ));
        mainnetController.setMintRecipient(1, mintRecipient1);
    }

    function test_setMintRecipient() public {
        assertEq(mainnetController.mintRecipients(1), bytes32(0));
        assertEq(mainnetController.mintRecipients(2), bytes32(0));

        vm.prank(admin);
        mainnetController.setMintRecipient(1, mintRecipient1);

        assertEq(mainnetController.mintRecipients(1), mintRecipient1);

        vm.prank(admin);
        mainnetController.setMintRecipient(2, mintRecipient2);

        assertEq(mainnetController.mintRecipients(2), mintRecipient2);

        vm.prank(admin);
        mainnetController.setMintRecipient(1, mintRecipient2);

        assertEq(mainnetController.mintRecipients(1), mintRecipient2);
    }

}

contract ForeignControllerAdminTests is UnitTestBase {

    ForeignController foreignController;

    bytes32 mintRecipient1 = bytes32(uint256(uint160(makeAddr("mintRecipient1"))));
    bytes32 mintRecipient2 = bytes32(uint256(uint160(makeAddr("mintRecipient2"))));

    function setUp() public {
        foreignController = new ForeignController(
            admin,
            makeAddr("almProxy"),
            makeAddr("psm"),
            makeAddr("nst"),
            makeAddr("usdc"),
            makeAddr("snst"),
            makeAddr("cctp")
        );
    }

    function test_setMintRecipient_unauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        foreignController.setMintRecipient(1, mintRecipient1);

        vm.prank(freezer);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            freezer,
            DEFAULT_ADMIN_ROLE
        ));
        foreignController.setMintRecipient(1, mintRecipient1);
    }

    function test_setMintRecipient() public {
        assertEq(foreignController.mintRecipients(1), bytes32(0));
        assertEq(foreignController.mintRecipients(2), bytes32(0));

        vm.prank(admin);
        foreignController.setMintRecipient(1, mintRecipient1);

        assertEq(foreignController.mintRecipients(1), mintRecipient1);

        vm.prank(admin);
        foreignController.setMintRecipient(2, mintRecipient2);

        assertEq(foreignController.mintRecipients(2), mintRecipient2);

        vm.prank(admin);
        foreignController.setMintRecipient(1, mintRecipient2);

        assertEq(foreignController.mintRecipients(1), mintRecipient2);
    }

}

