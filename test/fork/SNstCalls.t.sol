// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/fork/ForkTestBase.t.sol";

contract MainnetControllerDepositToSNSTFailureTests is ForkTestBase {

    function test_depositToSNST_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.depositToSNST(1e18);
    }

    function test_depositToSNST_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.depositToSNST(1e18);
    }

}

contract MainnetControllerDepositToSNSTTests is ForkTestBase {

    function test_depositToSNST() external {
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
        uint256 shares = mainnetController.depositToSNST(1e18);

        assertEq(shares, 1e18);

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

contract MainnetControllerWithdrawFromSNSTFailureTests is ForkTestBase {

    function test_withdrawFromSNST_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.withdrawFromSNST(1e18);
    }

    function test_withdrawFromSNST_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.withdrawFromSNST(1e18);
    }

}

contract MainnetControllerWithdrawFromSNSTTests is ForkTestBase {

    function test_withdrawFromSNST() external {
        vm.startPrank(relayer);
        mainnetController.mintNST(1e18);
        mainnetController.depositToSNST(1e18);
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
        uint256 shares = mainnetController.withdrawFromSNST(1e18);

        assertEq(shares, 1e18);

        assertEq(nst.balanceOf(address(almProxy)),           1e18);
        assertEq(nst.balanceOf(address(mainnetController)), 0);
        assertEq(nst.balanceOf(address(snst)),               0);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(snst)),  0);

        assertEq(snst.totalSupply(),                0);
        assertEq(snst.totalAssets(),                0);
        assertEq(snst.balanceOf(address(almProxy)), 0);
    }

}

contract MainnetControllerRedeemFromSNSTFailureTests is ForkTestBase {

    function test_redeemFromSNST_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.redeemFromSNST(1e18);
    }

    function test_redeemFromSNST_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.redeemFromSNST(1e18);
    }

}


contract MainnetControllerRedeemFromSNSTTests is ForkTestBase {

    function test_redeemFromSNST() external {
        vm.startPrank(relayer);
        mainnetController.mintNST(1e18);
        mainnetController.depositToSNST(1e18);
        vm.stopPrank();

        assertEq(nst.balanceOf(address(almProxy)),           0);
        assertEq(nst.balanceOf(address(mainnetController)), 0);
        assertEq(nst.balanceOf(address(snst)),               1e18);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(snst)),  0);

        // NOTE: 1:1 exchange rate
        assertEq(snst.totalSupply(),                1e18);
        assertEq(snst.totalAssets(),                1e18);
        assertEq(snst.balanceOf(address(almProxy)), 1e18);

        vm.prank(relayer);
        uint256 assets = mainnetController.redeemFromSNST(1e18);

        assertEq(assets, 1e18);

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


