// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/mainnet-fork/ForkTestBase.t.sol";

contract SUSDSTestBase is ForkTestBase {

    uint256 SUSDS_CONVERTED_ASSETS;
    uint256 SUSDS_CONVERTED_SHARES;

    function setUp() override public {
        super.setUp();

        // Warp to accrue value over 1:1 exchange rate
        skip(10 days);

        SUSDS_CONVERTED_ASSETS = susds.convertToAssets(1e18);
        SUSDS_CONVERTED_SHARES = susds.convertToShares(1e18);

        assertEq(SUSDS_CONVERTED_ASSETS, 1.001855380694731009e18);
        assertEq(SUSDS_CONVERTED_SHARES, 0.998148055367587678e18);
    }

}

contract MainnetControllerDepositToSUSDSFailureTests is SUSDSTestBase {

    function test_depositToSUSDS_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.depositToSUSDS(1e18);
    }

    function test_depositToSUSDS_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.depositToSUSDS(1e18);
    }

}

contract MainnetControllerDepositToSUSDSTests is SUSDSTestBase {

    function test_depositToSUSDS() external {
        vm.prank(relayer);
        mainnetController.mintUSDS(1e18);

        assertEq(usds.balanceOf(address(almProxy)),          1e18);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.balanceOf(address(susds)),             0);

        assertEq(usds.allowance(address(buffer),   address(vault)),  type(uint256).max);
        assertEq(usds.allowance(address(almProxy), address(susds)),  0);

        assertEq(susds.totalSupply(),                0);
        assertEq(susds.totalAssets(),                0);
        assertEq(susds.balanceOf(address(almProxy)), 0);

        vm.prank(relayer);
        uint256 shares = mainnetController.depositToSUSDS(1e18);

        assertEq(shares, SUSDS_CONVERTED_SHARES);

        assertEq(usds.balanceOf(address(almProxy)),          0);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.balanceOf(address(susds)),             1e18);

        assertEq(usds.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(usds.allowance(address(almProxy), address(susds)),  0);

        assertEq(susds.totalSupply(),                SUSDS_CONVERTED_SHARES);
        assertEq(susds.totalAssets(),                1e18 - 1);  // Rounding
        assertEq(susds.balanceOf(address(almProxy)), SUSDS_CONVERTED_SHARES);
    }

}

contract MainnetControllerWithdrawFromSUSDSFailureTests is SUSDSTestBase {

    function test_withdrawFromSUSDS_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.withdrawFromSUSDS(1e18);
    }

    function test_withdrawFromSUSDS_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.withdrawFromSUSDS(1e18);
    }

}

contract MainnetControllerWithdrawFromSUSDSTests is SUSDSTestBase {

    function test_withdrawFromSUSDS() external {
        vm.startPrank(relayer);
        mainnetController.mintUSDS(1e18);
        mainnetController.depositToSUSDS(1e18);
        vm.stopPrank();

        assertEq(usds.balanceOf(address(almProxy)),          0);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.balanceOf(address(susds)),             1e18);

        assertEq(usds.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(usds.allowance(address(almProxy), address(susds)),  0);

        assertEq(susds.totalSupply(),                SUSDS_CONVERTED_SHARES);
        assertEq(susds.totalAssets(),                1e18 - 1);  // Rounding
        assertEq(susds.balanceOf(address(almProxy)), SUSDS_CONVERTED_SHARES);

        // Max available with rounding
        vm.prank(relayer);
        uint256 shares = mainnetController.withdrawFromSUSDS(1e18 - 1);  // Rounding

        assertEq(shares, SUSDS_CONVERTED_SHARES);

        assertEq(usds.balanceOf(address(almProxy)),          1e18 - 1);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.balanceOf(address(susds)),             1);

        assertEq(usds.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(usds.allowance(address(almProxy), address(susds)),  0);

        assertEq(susds.totalSupply(),                0);
        assertEq(susds.totalAssets(),                0);
        assertEq(susds.balanceOf(address(almProxy)), 0);
    }

}

contract MainnetControllerRedeemFromSUSDSFailureTests is SUSDSTestBase {

    function test_redeemFromSUSDS_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.redeemFromSUSDS(1e18);
    }

    function test_redeemFromSUSDS_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.redeemFromSUSDS(1e18);
    }

}


contract MainnetControllerRedeemFromSUSDSTests is SUSDSTestBase {

    function test_redeemFromSUSDS() external {
        vm.startPrank(relayer);
        mainnetController.mintUSDS(1e18);
        mainnetController.depositToSUSDS(1e18);
        vm.stopPrank();

        assertEq(usds.balanceOf(address(almProxy)),          0);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.balanceOf(address(susds)),             1e18);

        assertEq(usds.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(usds.allowance(address(almProxy), address(susds)),  0);

        assertEq(susds.totalSupply(),                SUSDS_CONVERTED_SHARES);
        assertEq(susds.totalAssets(),                1e18 - 1);  // Rounding
        assertEq(susds.balanceOf(address(almProxy)), SUSDS_CONVERTED_SHARES);

        vm.prank(relayer);
        uint256 assets = mainnetController.redeemFromSUSDS(SUSDS_CONVERTED_SHARES);

        assertEq(assets, 1e18 - 1);  // Rounding

        assertEq(usds.balanceOf(address(almProxy)),          1e18 - 1);  // Rounding
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.balanceOf(address(susds)),             1);  // Rounding

        assertEq(usds.allowance(address(buffer),   address(vault)), type(uint256).max);
        assertEq(usds.allowance(address(almProxy), address(susds)), 0);

        assertEq(susds.totalSupply(),                0);
        assertEq(susds.totalAssets(),                0);
        assertEq(susds.balanceOf(address(almProxy)), 0);
    }

}


