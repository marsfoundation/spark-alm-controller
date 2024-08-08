// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/UnitTestBase.t.sol";

contract EthereumControllerSwapNSTToSNSTFailureTests is UnitTestBase {

    function test_swapNSTToSNST_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        ethereumController.swapNSTToSNST(1e18);
    }

    function test_swapNSTToSNST_frozen() external {
        vm.prank(freezer);
        ethereumController.freeze();

        vm.prank(relayer);
        vm.expectRevert("EthereumController/not-active");
        ethereumController.swapNSTToSNST(1e18);
    }

}

contract EthereumControllerSwapNSTToSNSTTests is UnitTestBase {

    function test_swapNSTToSNST() external {
        vm.prank(relayer);
        ethereumController.mintNST(1e18);

        assertEq(nst.balanceOf(address(almProxy)),           1e18);
        assertEq(nst.balanceOf(address(ethereumController)), 0);
        assertEq(nst.balanceOf(address(snst)),               0);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(snst)),  0);

        assertEq(snst.totalSupply(),                0);
        assertEq(snst.totalAssets(),                0);
        assertEq(snst.balanceOf(address(almProxy)), 0);

        vm.prank(relayer);
        ethereumController.swapNSTToSNST(1e18);

        assertEq(nst.balanceOf(address(almProxy)),           0);
        assertEq(nst.balanceOf(address(ethereumController)), 0);
        assertEq(nst.balanceOf(address(snst)),               1e18);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(snst)),  0);

        // NOTE: 1:1 exchange rate
        assertEq(snst.totalSupply(),                1e18);
        assertEq(snst.totalAssets(),                1e18);
        assertEq(snst.balanceOf(address(almProxy)), 1e18);
    }

}

contract EthereumControllerSwapSNSTToNSTFailureTests is UnitTestBase {

    function test_swapSNSTToNST_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        ethereumController.swapSNSTToNST(1e18);
    }

    function test_swapSNSTToNST_frozen() external {
        vm.prank(freezer);
        ethereumController.freeze();

        vm.prank(relayer);
        vm.expectRevert("EthereumController/not-active");
        ethereumController.swapSNSTToNST(1e18);
    }

}

contract EthereumControllerSwapSNSTToNSTTests is UnitTestBase {

    function test_swapSNSTToNST() external {
        vm.startPrank(relayer);
        ethereumController.mintNST(1e18);
        ethereumController.swapNSTToSNST(1e18);
        vm.stopPrank();

        assertEq(nst.balanceOf(address(almProxy)),           0);
        assertEq(nst.balanceOf(address(ethereumController)), 0);
        assertEq(nst.balanceOf(address(snst)),               1e18);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(snst)),  0);

        // NOTE: 1:1 exchange rate
        assertEq(snst.totalSupply(),                1e18);
        assertEq(snst.totalAssets(),                1e18);
        assertEq(snst.balanceOf(address(almProxy)), 1e18);

        vm.prank(relayer);
        ethereumController.swapSNSTToNST(1e18);

        assertEq(nst.balanceOf(address(almProxy)),           1e18);
        assertEq(nst.balanceOf(address(ethereumController)), 0);
        assertEq(nst.balanceOf(address(snst)),               0);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(snst)),  0);

        assertEq(snst.totalSupply(),                0);
        assertEq(snst.totalAssets(),                0);
        assertEq(snst.balanceOf(address(almProxy)), 0);
    }

}


