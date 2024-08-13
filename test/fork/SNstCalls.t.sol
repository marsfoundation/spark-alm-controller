// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/fork/ForkTestBase.t.sol";

contract MainnetControllerSwapNSTToSNSTFailureTests is ForkTestBase {

    function test_swapNSTToSNST_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.swapNSTToSNST(1e18);
    }

    function test_swapNSTToSNST_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.swapNSTToSNST(1e18);
    }

}

contract MainnetControllerSwapNSTToSNSTTests is ForkTestBase {

    function test_swapNSTToSNST() external {
        vm.prank(relayer);
        mainnetController.mintNST(1e18);

        assertEq(nst.balanceOf(address(almProxy)),          1e18);
        assertEq(nst.balanceOf(address(mainnetController)), 0);
        assertEq(nst.balanceOf(address(snst)),              0);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(snst)),  0);

        assertEq(snst.totalSupply(),                0);
        assertEq(snst.totalAssets(),                0);
        assertEq(snst.balanceOf(address(almProxy)), 0);

        vm.prank(relayer);
        mainnetController.swapNSTToSNST(1e18);

        assertEq(nst.balanceOf(address(almProxy)),          0);
        assertEq(nst.balanceOf(address(mainnetController)), 0);
        assertEq(nst.balanceOf(address(snst)),              1e18);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(snst)),  0);

        // NOTE: 1:1 exchange rate
        assertEq(snst.totalSupply(),                1e18);
        assertEq(snst.totalAssets(),                1e18);
        assertEq(snst.balanceOf(address(almProxy)), 1e18);
    }

}

contract MainnetControllerSwapSNSTToNSTFailureTests is ForkTestBase {

    function test_swapSNSTToNST_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.swapSNSTToNST(1e18);
    }

    function test_swapSNSTToNST_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.swapSNSTToNST(1e18);
    }

}

contract MainnetControllerSwapSNSTToNSTTests is ForkTestBase {

    function test_swapSNSTToNST() external {
        vm.startPrank(relayer);
        mainnetController.mintNST(1e18);
        mainnetController.swapNSTToSNST(1e18);
        vm.stopPrank();

        assertEq(nst.balanceOf(address(almProxy)),          0);
        assertEq(nst.balanceOf(address(mainnetController)), 0);
        assertEq(nst.balanceOf(address(snst)),              1e18);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(snst)),  0);

        // NOTE: 1:1 exchange rate
        assertEq(snst.totalSupply(),                1e18);
        assertEq(snst.totalAssets(),                1e18);
        assertEq(snst.balanceOf(address(almProxy)), 1e18);

        vm.prank(relayer);
        mainnetController.swapSNSTToNST(1e18);

        assertEq(nst.balanceOf(address(almProxy)),          1e18);
        assertEq(nst.balanceOf(address(mainnetController)), 0);
        assertEq(nst.balanceOf(address(snst)),              0);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(snst)),  0);

        assertEq(snst.totalSupply(),                0);
        assertEq(snst.totalAssets(),                0);
        assertEq(snst.balanceOf(address(almProxy)), 0);
    }

}


