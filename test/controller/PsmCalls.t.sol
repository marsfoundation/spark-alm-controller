// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/UnitTestBase.t.sol";

contract L1ControllerBuyGemNoFeeFailureTests is UnitTestBase {

    function test_sellGemNoFee_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        l1Controller.sellGemNoFee(1e18);
    }

    function test_sellGemNoFee_frozen() external {
        vm.prank(freezer);
        l1Controller.freeze();

        vm.prank(relayer);
        vm.expectRevert("L1Controller/not-active");
        l1Controller.buyGemNoFee(1e18);
    }

}

contract L1ControllerBuyGemNoFeeTests is UnitTestBase {

    function test_buyGemNoFee() external {
        vm.prank(relayer);
        l1Controller.draw(1e18);

        assertEq(nst.balanceOf(address(almProxy)),     1e18);
        assertEq(nst.balanceOf(address(l1Controller)), 0);
        assertEq(nst.balanceOf(address(psm)),          100e18);

        assertEq(gem.balanceOf(address(almProxy)),     0);
        assertEq(gem.balanceOf(address(l1Controller)), 0);
        assertEq(gem.balanceOf(address(pocket)),       100e6);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(psm)),   0);

        vm.prank(relayer);
        l1Controller.buyGemNoFee(1e6);

        assertEq(nst.balanceOf(address(almProxy)),     0);
        assertEq(nst.balanceOf(address(l1Controller)), 0);
        assertEq(nst.balanceOf(address(psm)),          101e18);

        assertEq(gem.balanceOf(address(almProxy)),     1e6);
        assertEq(gem.balanceOf(address(l1Controller)), 0);
        assertEq(gem.balanceOf(address(pocket)),       99e6);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(psm)),   0);
    }

}

contract L1ControllerSellGemNoFeeFailureTests is UnitTestBase {

    function test_sellGemNoFee_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        l1Controller.sellGemNoFee(1e18);
    }

    function test_sellGemNoFee_frozen() external {
        vm.prank(freezer);
        l1Controller.freeze();

        vm.prank(relayer);
        vm.expectRevert("L1Controller/not-active");
        l1Controller.sellGemNoFee(1e18);
    }

}

contract L1ControllerSellGemNoFeeTests is UnitTestBase {

    function test_sellGemNoFee() external {
        deal(address(gem), address(almProxy), 1e6);

        assertEq(nst.balanceOf(address(almProxy)),     0);
        assertEq(nst.balanceOf(address(l1Controller)), 0);
        assertEq(nst.balanceOf(address(psm)),          100e18);

        assertEq(gem.balanceOf(address(almProxy)),     1e6);
        assertEq(gem.balanceOf(address(l1Controller)), 0);
        assertEq(gem.balanceOf(address(pocket)),       100e6);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(psm)),   0);

        vm.prank(relayer);
        l1Controller.sellGemNoFee(1e6);

        assertEq(nst.balanceOf(address(almProxy)),     1e18);
        assertEq(nst.balanceOf(address(l1Controller)), 0);
        assertEq(nst.balanceOf(address(psm)),          99e18);

        assertEq(gem.balanceOf(address(almProxy)),     0);
        assertEq(gem.balanceOf(address(l1Controller)), 0);
        assertEq(gem.balanceOf(address(pocket)),       101e6);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(psm)),   0);
    }

}

