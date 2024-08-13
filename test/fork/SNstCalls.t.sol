// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/fork/ForkTestBase.t.sol";

contract SNSTTestBase is ForkTestBase {

    uint256 SNST_CONVERTED_ASSETS;
    uint256 SNST_CONVERTED_SHARES;

    function setUp() override public {
        super.setUp();

        // Warp to accrue value over 1:1 exchange rate
        skip(10 days);

        SNST_CONVERTED_ASSETS = snst.convertToAssets(1e18);
        SNST_CONVERTED_SHARES = snst.convertToShares(1e18);

        assertEq(SNST_CONVERTED_ASSETS, 1.001855380694731009e18);
        assertEq(SNST_CONVERTED_SHARES, 0.998148055367587678e18);
    }

}

contract MainnetControllerDepositToSNSTFailureTests is SNSTTestBase {

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

contract MainnetControllerDepositToSNSTTests is SNSTTestBase {

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

        assertEq(shares, SNST_CONVERTED_SHARES);

        assertEq(nst.balanceOf(address(almProxy)),          0);
        assertEq(nst.balanceOf(address(mainnetController)), 0);
        assertEq(nst.balanceOf(address(snst)),              1e18);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(snst)),  0);

        assertEq(snst.totalSupply(),                SNST_CONVERTED_SHARES);
        assertEq(snst.totalAssets(),                1e18 - 1);  // Rounding
        assertEq(snst.balanceOf(address(almProxy)), SNST_CONVERTED_SHARES);
    }

}

contract MainnetControllerWithdrawFromSNSTFailureTests is SNSTTestBase {

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

contract MainnetControllerWithdrawFromSNSTTests is SNSTTestBase {

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

        assertEq(snst.totalSupply(),                SNST_CONVERTED_SHARES);
        assertEq(snst.totalAssets(),                1e18 - 1);  // Rounding
        assertEq(snst.balanceOf(address(almProxy)), SNST_CONVERTED_SHARES);

        // Max available with rounding
        vm.prank(relayer);
        uint256 shares = mainnetController.withdrawFromSNST(1e18 - 1);  // Rounding

        assertEq(shares, SNST_CONVERTED_SHARES);

        assertEq(nst.balanceOf(address(almProxy)),          1e18 - 1);
        assertEq(nst.balanceOf(address(mainnetController)), 0);
        assertEq(nst.balanceOf(address(snst)),              1);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(snst)),  0);

        assertEq(snst.totalSupply(),                0);
        assertEq(snst.totalAssets(),                0);
        assertEq(snst.balanceOf(address(almProxy)), 0);
    }

}

contract MainnetControllerRedeemFromSNSTFailureTests is SNSTTestBase {

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


contract MainnetControllerRedeemFromSNSTTests is SNSTTestBase {

    function test_redeemFromSNST() external {
        vm.startPrank(relayer);
        mainnetController.mintNST(1e18);
        mainnetController.depositToSNST(1e18);
        vm.stopPrank();

        assertEq(nst.balanceOf(address(almProxy)),          0);
        assertEq(nst.balanceOf(address(mainnetController)), 0);
        assertEq(nst.balanceOf(address(snst)),              1e18);

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(snst)),  0);

        assertEq(snst.totalSupply(),                SNST_CONVERTED_SHARES);
        assertEq(snst.totalAssets(),                1e18 - 1);  // Rounding
        assertEq(snst.balanceOf(address(almProxy)), SNST_CONVERTED_SHARES);

        vm.prank(relayer);
        uint256 assets = mainnetController.redeemFromSNST(SNST_CONVERTED_SHARES);

        assertEq(assets, 1e18 - 1);  // Rounding

        assertEq(nst.balanceOf(address(almProxy)),          1e18 - 1);  // Rounding
        assertEq(nst.balanceOf(address(mainnetController)), 0);
        assertEq(nst.balanceOf(address(snst)),              1);  // Rounding

        assertEq(nst.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(snst)),  0);

        assertEq(snst.totalSupply(),                0);
        assertEq(snst.totalAssets(),                0);
        assertEq(snst.balanceOf(address(almProxy)), 0);
    }

}


