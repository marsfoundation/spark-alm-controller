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

    uint256 startingAUSDSBalance;
    uint256 startingAUSDCBalance;

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

        startingAUSDCBalance = usdc.balanceOf(address(ausdc));
        startingAUSDSBalance = usds.balanceOf(address(ausds));
    }

}

// NOTE: Only testing USDS for non-rate limit failures as it doesn't matter which asset is used

contract AaveV3MainMarketDepositFailureTests is AaveV3MainMarketBaseTest {

    function test_depositAave_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.depositAave(ATOKEN_USDS, 1_000_000e18);
    }

    function test_depositAave_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.depositAave(ATOKEN_USDS, 1_000_000e18);
    }

    function test_depositAave_usdsRateLimitedBoundary() external {
        deal(Ethereum.USDS, address(almProxy), 25_000_000e18 + 1);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.startPrank(relayer);
        mainnetController.depositAave(ATOKEN_USDS, 25_000_000e18 + 1);

        mainnetController.depositAave(ATOKEN_USDS, 25_000_000e18);
    }

    function test_depositAave_usdcRateLimitedBoundary() external {
        deal(Ethereum.USDC, address(almProxy), 25_000_000e6 + 1);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.startPrank(relayer);
        mainnetController.depositAave(ATOKEN_USDC, 25_000_000e6 + 1);

        mainnetController.depositAave(ATOKEN_USDC, 25_000_000e6);
    }

}

contract AaveV3MainMarketDepositSuccessTests is AaveV3MainMarketBaseTest {

    function test_depositAave_usds() public {
        deal(Ethereum.USDS, address(almProxy), 1_000_000e18);

        assertEq(usds.allowance(address(almProxy), POOL), 0);

        assertEq(ausds.balanceOf(address(almProxy)), 0);
        assertEq(usds.balanceOf(address(almProxy)),  1_000_000e18);
        assertEq(usds.balanceOf(address(ausds)),     startingAUSDSBalance);

        vm.prank(relayer);
        mainnetController.depositAave(ATOKEN_USDS, 1_000_000e18);

        assertEq(usds.allowance(address(almProxy), POOL), 0);

        assertEq(ausds.balanceOf(address(almProxy)), 1_000_000e18);
        assertEq(usds.balanceOf(address(almProxy)),  0);
        assertEq(usds.balanceOf(address(ausds)),     startingAUSDSBalance + 1_000_000e18);
    }

    function test_depositAave_usdc() public {
        deal(Ethereum.USDC, address(almProxy), 1_000_000e6);

        assertEq(usdc.allowance(address(almProxy), POOL), 0);

        assertEq(ausdc.balanceOf(address(almProxy)), 0);
        assertEq(usdc.balanceOf(address(almProxy)),  1_000_000e6);
        assertEq(usdc.balanceOf(address(ausdc)),     startingAUSDCBalance);

        vm.prank(relayer);
        mainnetController.depositAave(ATOKEN_USDC, 1_000_000e6);

        assertEq(usdc.allowance(address(almProxy), POOL), 0);

        assertEq(ausdc.balanceOf(address(almProxy)), 1_000_000e6 - 1);
        assertEq(usdc.balanceOf(address(almProxy)),  0);
        assertEq(usdc.balanceOf(address(ausdc)),     startingAUSDCBalance + 1_000_000e6);
    }

}

contract AaveV3MainMarketWithdrawFailureTests is AaveV3MainMarketBaseTest {

    function test_withdrawAave_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.withdrawAave(ATOKEN_USDS, 1_000_000e18);
    }

    function test_withdrawAave_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.withdrawAave(ATOKEN_USDS, 1_000_000e18);
    }

}

contract AaveV3MainMarketWithdrawSuccessTests is AaveV3MainMarketBaseTest {

    function test_withdrawAave_usds() public {
        deal(Ethereum.USDS, address(almProxy), 1_000_000e18);
        vm.prank(relayer);
        mainnetController.depositAave(ATOKEN_USDS, 1_000_000e18);

        skip(1 days);

        uint256 fullBalance = ausds.balanceOf(address(almProxy));

        assertGe(fullBalance, 1_000_000e18);

        assertEq(ausds.balanceOf(address(almProxy)), fullBalance);
        assertEq(usds.balanceOf(address(almProxy)),  0);
        assertEq(usds.balanceOf(address(ausds)),     startingAUSDSBalance + 1_000_000e18);

        // Partial withdraw
        vm.prank(relayer);
        assertEq(mainnetController.withdrawAave(ATOKEN_USDS, 400_000e18), 400_000e18);

        assertEq(ausds.balanceOf(address(almProxy)), fullBalance - 400_000e18);
        assertEq(usds.balanceOf(address(almProxy)),  400_000e18);
        assertEq(usds.balanceOf(address(ausds)),     startingAUSDSBalance + 600_000e18);  // 1m - 400k

        // Withdraw all
        vm.prank(relayer);
        assertEq(mainnetController.withdrawAave(ATOKEN_USDS, type(uint256).max), fullBalance - 400_000e18);

        assertEq(ausds.balanceOf(address(almProxy)), 0);
        assertEq(usds.balanceOf(address(almProxy)),  fullBalance);
        assertEq(usds.balanceOf(address(ausds)),     startingAUSDSBalance + 1_000_000e18 - fullBalance);

        // Interest accrued was withdrawn, reducing cash balance
        assertLe(usds.balanceOf(address(ausds)), startingAUSDSBalance);
    }

    function test_withdrawAave_usdc() public {
        deal(Ethereum.USDC, address(almProxy), 1_000_000e6);
        vm.prank(relayer);
        mainnetController.depositAave(ATOKEN_USDC, 1_000_000e6);

        skip(1 days);

        uint256 fullBalance = ausdc.balanceOf(address(almProxy));

        assertGe(fullBalance, 1_000_000e6);

        assertEq(ausdc.balanceOf(address(almProxy)), fullBalance);
        assertEq(usdc.balanceOf(address(almProxy)),  0);
        assertEq(usdc.balanceOf(address(ausdc)),     startingAUSDCBalance + 1_000_000e6);

        // Partial withdraw
        vm.prank(relayer);
        assertEq(mainnetController.withdrawAave(ATOKEN_USDC, 400_000e6), 400_000e6);

        assertEq(ausdc.balanceOf(address(almProxy)), fullBalance - 400_000e6 + 1);  // Rounding
        assertEq(usdc.balanceOf(address(almProxy)),  400_000e6);
        assertEq(usdc.balanceOf(address(ausdc)),     startingAUSDCBalance + 600_000e6);  // 1m - 400k

        // Withdraw all
        vm.prank(relayer);
        assertEq(mainnetController.withdrawAave(ATOKEN_USDC, type(uint256).max), fullBalance - 400_000e6 + 1);  // Rounding towards LP

        assertEq(ausdc.balanceOf(address(almProxy)), 0);
        assertEq(usdc.balanceOf(address(almProxy)),  fullBalance + 1);  // Rounding towards LP
        assertEq(usdc.balanceOf(address(ausdc)),     startingAUSDCBalance + 1_000_000e6 - fullBalance - 1);  // Rounding towards LP

        // Interest accrued was withdrawn, reducing cash balance
        assertLe(usdc.balanceOf(address(ausdc)), startingAUSDCBalance);
    }

}
