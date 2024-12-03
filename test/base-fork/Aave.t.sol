// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/base-fork/ForkTestBase.t.sol";

import { IAToken } from "aave-v3-origin/src/core/contracts/interfaces/IAToken.sol";

import { RateLimitHelpers } from "src/RateLimitHelpers.sol";

contract AaveV3BaseMarketTestBase is ForkTestBase {

    uint256 startingAUSDCBalance;

    function setUp() public override {
        super.setUp();

        vm.startPrank(Base.SPARK_EXECUTOR);

        // NOTE: Hit SUPPLY_CAP_EXCEEDED when using 25m
        rateLimits.setRateLimitData(
            RateLimitHelpers.makeAssetKey(
                foreignController.LIMIT_AAVE_DEPOSIT(),
                ATOKEN_USDC
            ),
            1_000_000e6,
            uint256(1_000_000e6) / 1 days
        );

        vm.stopPrank();

        startingAUSDCBalance = usdcBase.balanceOf(address(ausdc));
    }

}

contract AaveV3BaseMarketDepositFailureTests is AaveV3BaseMarketTestBase {

    function test_depositAave_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        foreignController.depositAave(ATOKEN_USDC, 1_000_000e18);
    }

    function test_depositAave_frozen() external {
        vm.prank(freezer);
        foreignController.freeze();

        vm.prank(relayer);
        vm.expectRevert("ForeignController/not-active");
        foreignController.depositAave(ATOKEN_USDC, 1_000_000e18);
    }

    function test_depositAave_usdcRateLimitedBoundary() external {
        deal(Base.USDC, address(almProxy), 1_000_000e6 + 1);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.startPrank(relayer);
        foreignController.depositAave(ATOKEN_USDC, 1_000_000e6 + 1);

        foreignController.depositAave(ATOKEN_USDC, 1_000_000e6);
    }

}

contract AaveV3BaseMarketDepositSuccessTests is AaveV3BaseMarketTestBase {

    function test_depositAave_usdc() public {
        deal(Base.USDC, address(almProxy), 1_000_000e6);

        assertEq(usdcBase.allowance(address(almProxy), AAVE_POOL), 0);

        assertEq(ausdc.balanceOf(address(almProxy)),    0);
        assertEq(usdcBase.balanceOf(address(almProxy)), 1_000_000e6);
        assertEq(usdcBase.balanceOf(address(ausdc)),    startingAUSDCBalance);

        vm.prank(relayer);
        foreignController.depositAave(ATOKEN_USDC, 1_000_000e6);

        assertEq(usdcBase.allowance(address(almProxy), AAVE_POOL), 0);

        assertEq(ausdc.balanceOf(address(almProxy)),    1_000_000e6);
        assertEq(usdcBase.balanceOf(address(almProxy)), 0);
        assertEq(usdcBase.balanceOf(address(ausdc)),    startingAUSDCBalance + 1_000_000e6);
    }

}

contract AaveV3BaseMarketWithdrawFailureTests is AaveV3BaseMarketTestBase {

    function test_withdrawAave_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        foreignController.withdrawAave(ATOKEN_USDC, 1_000_000e18);
    }

    function test_withdrawAave_frozen() external {
        vm.prank(freezer);
        foreignController.freeze();

        vm.prank(relayer);
        vm.expectRevert("ForeignController/not-active");
        foreignController.withdrawAave(ATOKEN_USDC, 1_000_000e18);
    }

}

contract AaveV3BaseMarketWithdrawSuccessTests is AaveV3BaseMarketTestBase {

    function test_withdrawAave_usdc() public {
        deal(Base.USDC, address(almProxy), 1_000_000e6);
        vm.prank(relayer);
        foreignController.depositAave(ATOKEN_USDC, 1_000_000e6);

        skip(1 days);

        uint256 fullBalance = ausdc.balanceOf(address(almProxy));

        assertGe(fullBalance, 1_000_000e6);

        assertEq(ausdc.balanceOf(address(almProxy)),    fullBalance);
        assertEq(usdcBase.balanceOf(address(almProxy)), 0);
        assertEq(usdcBase.balanceOf(address(ausdc)),    startingAUSDCBalance + 1_000_000e6);

        // Partial withdraw
        vm.prank(relayer);
        assertEq(foreignController.withdrawAave(ATOKEN_USDC, 400_000e6), 400_000e6);

        assertEq(ausdc.balanceOf(address(almProxy)),    fullBalance - 400_000e6);
        assertEq(usdcBase.balanceOf(address(almProxy)), 400_000e6);
        assertEq(usdcBase.balanceOf(address(ausdc)),    startingAUSDCBalance + 600_000e6);  // 1m - 400k

        // Withdraw all
        vm.prank(relayer);
        assertEq(foreignController.withdrawAave(ATOKEN_USDC, type(uint256).max), fullBalance - 400_000e6);

        assertEq(ausdc.balanceOf(address(almProxy)),    0);
        assertEq(usdcBase.balanceOf(address(almProxy)), fullBalance);
        assertEq(usdcBase.balanceOf(address(ausdc)),    startingAUSDCBalance + 1_000_000e6 - fullBalance);

        // Interest accrued was withdrawn, reducing cash balance
        assertLe(usdcBase.balanceOf(address(ausdc)), startingAUSDCBalance);
    }

}