// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/UnitTestBase.t.sol";

contract L1ControllerSwapNSTToUSDCFailureTests is UnitTestBase {

    function test_swapUSDCToNST_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        l1Controller.swapUSDCToNST(1e6);
    }

    function test_swapUSDCToNST_frozen() external {
        vm.prank(freezer);
        l1Controller.freeze();

        vm.prank(relayer);
        vm.expectRevert("L1Controller/not-active");
        l1Controller.swapNSTToUSDC(1e6);
    }

}

contract L1ControllerSwapNSTToUSDCTests is UnitTestBase {

    function test_swapNSTToUSDC() external {
        vm.prank(relayer);
        l1Controller.mintNST(1e18);

        assertEq(nst.balanceOf(address(almProxy)),     1e18);
        assertEq(nst.balanceOf(address(l1Controller)), 0);
        assertEq(nst.balanceOf(address(psm)),          100e18);

        assertEq(usdc.balanceOf(address(almProxy)),     0);
        assertEq(usdc.balanceOf(address(l1Controller)), 0);
        assertEq(usdc.balanceOf(address(pocket)),       100e6);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(psm)),   0);

        vm.prank(relayer);
        l1Controller.swapNSTToUSDC(1e6);

        assertEq(nst.balanceOf(address(almProxy)),     0);
        assertEq(nst.balanceOf(address(l1Controller)), 0);
        assertEq(nst.balanceOf(address(psm)),          101e18);

        assertEq(usdc.balanceOf(address(almProxy)),     1e6);
        assertEq(usdc.balanceOf(address(l1Controller)), 0);
        assertEq(usdc.balanceOf(address(pocket)),       99e6);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(psm)),   0);
    }

}

contract L1ControllerSwapUSDCToNSTFailureTests is UnitTestBase {

    function test_swapUSDCToNST_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        l1Controller.swapUSDCToNST(1e6);
    }

    function test_swapUSDCToNST_frozen() external {
        vm.prank(freezer);
        l1Controller.freeze();

        vm.prank(relayer);
        vm.expectRevert("L1Controller/not-active");
        l1Controller.swapUSDCToNST(1e6);
    }

}

contract L1ControllerSwapUSDCToNSTTests is UnitTestBase {

    function test_swapUSDCToNST() external {
        deal(address(usdc), address(almProxy), 1e6);

        assertEq(nst.balanceOf(address(almProxy)),     0);
        assertEq(nst.balanceOf(address(l1Controller)), 0);
        assertEq(nst.balanceOf(address(psm)),          100e18);

        assertEq(usdc.balanceOf(address(almProxy)),     1e6);
        assertEq(usdc.balanceOf(address(l1Controller)), 0);
        assertEq(usdc.balanceOf(address(pocket)),       100e6);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(psm)),   0);

        vm.prank(relayer);
        l1Controller.swapUSDCToNST(1e6);

        assertEq(nst.balanceOf(address(almProxy)),     1e18);
        assertEq(nst.balanceOf(address(l1Controller)), 0);
        assertEq(nst.balanceOf(address(psm)),          99e18);

        assertEq(usdc.balanceOf(address(almProxy)),     0);
        assertEq(usdc.balanceOf(address(l1Controller)), 0);
        assertEq(usdc.balanceOf(address(pocket)),       101e6);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(psm)),   0);
    }

}

