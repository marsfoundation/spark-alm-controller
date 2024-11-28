// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/mainnet-fork/ForkTestBase.t.sol";

import { IAToken } from "aave-v3-origin/src/core/contracts/interfaces/IAToken.sol";

contract AaveV3MainMarketBaseTest is ForkTestBase {

    address constant ATOKEN_USDS = 0x32a6268f9Ba3642Dda7892aDd74f1D34469A4259;
    address constant ATOKEN_USDC = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;
    address constant POOL        = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    IAToken ausds = IAToken(ATOKEN_USDS);
    IAToken ausdc = IAToken(ATOKEN_USDC);

    function setUp() public override {
        super.setUp();

        vm.startPrank(Ethereum.SPARK_PROXY);

        rateLimits.setRateLimitData(
            RateLimitHelpers.makeAssetKey(
                mainnetController.LIMIT_AAVE_DEPOSIT(),
                ATOKEN_USDS
            ),
            25_000_000e18,
            uint256(5_000_000e18) / 1 days
        );
        rateLimits.setRateLimitData(
            RateLimitHelpers.makeAssetKey(
                mainnetController.LIMIT_AAVE_DEPOSIT(),
                ATOKEN_USDC
            ),
            25_000_000e6,
            uint256(5_000_000e6) / 1 days
        );

        vm.stopPrank();
    }

}

// NOTE: Only testing USDS for non-rate limit failures as it doesn't matter which asset is used

contract AaveV3MainMarketDepositFailureTests is AaveV3MainMarketBaseTest {

    function test_aave_deposit_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.depositAave(ATOKEN_USDS, 1_000_000e18);
    }

    function test_aave_deposit_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.depositAave(ATOKEN_USDS, 1_000_000e18);
    }

    function test_aave_usds_deposit_rateLimitedBoundary() external {
        deal(Ethereum.USDS, address(almProxy), 25_000_000e18 + 1);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.startPrank(relayer);
        mainnetController.depositAave(ATOKEN_USDS, 25_000_000e18 + 1);

        mainnetController.depositAave(ATOKEN_USDS, 25_000_000e18);
    }

    function test_aave_usdc_deposit_rateLimitedBoundary() external {
        deal(Ethereum.USDC, address(almProxy), 25_000_000e6 + 1);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.startPrank(relayer);
        mainnetController.depositAave(ATOKEN_USDC, 25_000_000e6 + 1);

        mainnetController.depositAave(ATOKEN_USDC, 25_000_000e6);
    }

}

contract AaveV3MainMarketDepositSuccessTests is AaveV3MainMarketBaseTest {

    function test_aave_usds_deposit() public {
        deal(Ethereum.USDS, address(almProxy), 1_000_000e18);

        assertEq(ausds.balanceOf(address(almProxy)),                       0);
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(almProxy)),       1_000_000e18);
        assertEq(IERC20(Ethereum.USDS).allowance(address(almProxy), POOL), 0);

        vm.prank(relayer);
        mainnetController.depositAave(ATOKEN_USDS, 1_000_000e18);

        assertEq(ausds.balanceOf(address(almProxy)),                       1_000_000e18);
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(almProxy)),       0);
        assertEq(IERC20(Ethereum.USDS).allowance(address(almProxy), POOL), 0);
    }

    function test_aave_usdc_deposit() public {
        deal(Ethereum.USDC, address(almProxy), 1_000_000e6);

        assertEq(ausdc.balanceOf(address(almProxy)),                       0);
        assertEq(IERC20(Ethereum.USDC).balanceOf(address(almProxy)),       1_000_000e6);
        assertEq(IERC20(Ethereum.USDC).allowance(address(almProxy), POOL), 0);

        vm.prank(relayer);
        mainnetController.depositAave(ATOKEN_USDC, 1_000_000e6);

        assertEq(ausdc.balanceOf(address(almProxy)),                       1_000_000e6);
        assertEq(IERC20(Ethereum.USDC).balanceOf(address(almProxy)),       0);
        assertEq(IERC20(Ethereum.USDC).allowance(address(almProxy), POOL), 0);
    }

}

contract AaveV3MainMarketWithdrawFailureTests is AaveV3MainMarketBaseTest {

    function test_aave_withdraw_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.withdrawAave(ATOKEN_USDS, 1_000_000e18);
    }

    function test_aave_withdraw_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.withdrawAave(ATOKEN_USDS, 1_000_000e18);
    }

}

contract AaveV3MainMarketWithdrawSuccessTests is AaveV3MainMarketBaseTest {

    function test_aave_usds_withdraw() public {
        deal(Ethereum.USDS, address(almProxy), 1_000_000e18);
        vm.prank(relayer);
        mainnetController.depositAave(ATOKEN_USDS, 1_000_000e18);

        assertEq(ausds.balanceOf(address(almProxy)),                 1_000_000e18);
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(almProxy)), 0);

        // Partial withdraw
        vm.prank(relayer);
        assertEq(mainnetController.withdrawAave(ATOKEN_USDS, 400_000e18), 400_000e18);

        assertEq(ausds.balanceOf(address(almProxy)),                 600_000e18);
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(almProxy)), 400_000e18);

        // Withdraw all
        vm.prank(relayer);
        assertEq(mainnetController.withdrawAave(ATOKEN_USDS, type(uint256).max), 600_000e18);

        assertEq(ausds.balanceOf(address(almProxy)),                 0);
        assertEq(IERC20(Ethereum.USDS).balanceOf(address(almProxy)), 1_000_000e18);
    }

    function test_aave_usdc_withdraw() public {
        deal(Ethereum.USDC, address(almProxy), 1_000_000e6);
        vm.prank(relayer);
        mainnetController.depositAave(ATOKEN_USDC, 1_000_000e6);

        assertEq(ausdc.balanceOf(address(almProxy)),                 1_000_000e6);
        assertEq(IERC20(Ethereum.USDC).balanceOf(address(almProxy)), 0);

        // Partial withdraw
        vm.prank(relayer);
        assertEq(mainnetController.withdrawAave(ATOKEN_USDC, 400_000e6), 400_000e6);

        assertEq(ausdc.balanceOf(address(almProxy)),                 600_000e6 + 1);  // Rounding error
        assertEq(IERC20(Ethereum.USDC).balanceOf(address(almProxy)), 400_000e6);

        // Withdraw all
        vm.prank(relayer);
        assertEq(mainnetController.withdrawAave(ATOKEN_USDC, type(uint256).max), 600_000e6 + 1);

        assertEq(ausdc.balanceOf(address(almProxy)),                 0);
        assertEq(IERC20(Ethereum.USDC).balanceOf(address(almProxy)), 1_000_000e6 + 1);
    }

}
