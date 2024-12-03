// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/base-fork/ForkTestBase.t.sol";

import { RateLimitHelpers } from "src/RateLimitHelpers.sol";

import { IRateProviderLike } from "spark-psm/src/PSM3.sol";

contract ForeignControllerPSMSuccessTestBase is ForkTestBase {

    uint256 PSM_USDS_BAL;
    uint256 PSM_USDC_BAL;
    uint256 PSM_SUSDS_BAL;

    uint256 PSM_TOTAL_ASSETS;
    uint256 PSM_TOTAL_SHARES;
    uint256 PSM_PROXY_SHARES;

    function setUp() public virtual override {
        super.setUp();

        PSM_USDS_BAL  = usdsBase.balanceOf(address(psmBase));
        PSM_USDC_BAL  = usdcBase.balanceOf(address(pocket));
        PSM_SUSDS_BAL = susdsBase.balanceOf(address(psmBase));

        PSM_TOTAL_ASSETS = psmBase.totalAssets();
        PSM_TOTAL_SHARES = psmBase.totalShares();
        PSM_PROXY_SHARES = psmBase.shares(address(almProxy));
    }

    function _assertState(
        IERC20  token,
        uint256 proxyBalance,
        uint256 psmBalance,
        uint256 proxyShares,
        uint256 totalShares,
        uint256 totalAssets,
        bytes32 rateLimitKey,
        uint256 currentRateLimit
    )
        internal view
    {
        address custodian = address(token) == address(usdcBase) ? pocket : address(psmBase);

        assertEq(token.balanceOf(address(almProxy)),          proxyBalance);
        assertEq(token.balanceOf(address(foreignController)), 0);  // Should always be zero
        assertEq(token.balanceOf(custodian),                  psmBalance);

        assertEq(psmBase.shares(address(almProxy)), proxyShares);
        assertEq(psmBase.totalShares(),             totalShares);
        assertEq(psmBase.totalAssets(),             totalAssets);

        bytes32 assetKey = RateLimitHelpers.makeAssetKey(rateLimitKey, address(token));

        assertEq(rateLimits.getCurrentRateLimit(assetKey), currentRateLimit);

        // Should always be 0 before and after calls
        assertEq(usdsBase.allowance(address(almProxy), address(psmBase)), 0);
    }

}


contract ForeignControllerDepositPSMFailureTests is ForkTestBase {

    function test_depositPSM_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        foreignController.depositPSM(address(usdsBase), 100e18);
    }

    function test_depositPSM_frozen() external {
        vm.prank(freezer);
        foreignController.freeze();

        vm.prank(relayer);
        vm.expectRevert("ForeignController/not-active");
        foreignController.depositPSM(address(usdsBase), 100e18);
    }

}

contract ForeignControllerDepositTests is ForeignControllerPSMSuccessTestBase {

    function test_deposit_usds() external {
        bytes32 key = foreignController.LIMIT_PSM_DEPOSIT();

        deal(address(usdsBase), address(almProxy), 1_000_000e18);

        _assertState({
            token            : usdsBase,
            proxyBalance     : 1_000_000e18,
            psmBalance       : PSM_USDS_BAL,
            proxyShares      : PSM_PROXY_SHARES,
            totalShares      : PSM_TOTAL_SHARES,
            totalAssets      : PSM_TOTAL_ASSETS,
            rateLimitKey     : key,
            currentRateLimit : 5_000_000e18
        });

        vm.prank(relayer);
        uint256 shares = foreignController.depositPSM(address(usdsBase), 1_000_000e18);

        assertEq(shares, 1_000_000e18 * PSM_TOTAL_SHARES / PSM_TOTAL_ASSETS);

        _assertState({
            token            : usdsBase,
            proxyBalance     : 0,
            psmBalance       : PSM_USDS_BAL + 1_000_000e18,
            proxyShares      : PSM_PROXY_SHARES + shares,
            totalShares      : PSM_TOTAL_SHARES + shares,
            totalAssets      : PSM_TOTAL_ASSETS + 1_000_000e18,
            rateLimitKey     : key,
            currentRateLimit : 4_000_000e18
        });
    }

    function test_deposit_usdc() external {
        bytes32 key = foreignController.LIMIT_PSM_DEPOSIT();

        deal(address(usdcBase), address(almProxy), 1_000_000e6);

        _assertState({
            token            : usdcBase,
            proxyBalance     : 1_000_000e6,
            psmBalance       : PSM_USDC_BAL,
            proxyShares      : PSM_PROXY_SHARES,
            totalShares      : PSM_TOTAL_SHARES,
            totalAssets      : PSM_TOTAL_ASSETS,
            rateLimitKey     : key,
            currentRateLimit : 4_000_000e6
        });

        vm.prank(relayer);
        uint256 shares = foreignController.depositPSM(address(usdcBase), 1_000_000e6);

        assertEq(shares, 1_000_000e6 * 1e12 * PSM_TOTAL_SHARES / PSM_TOTAL_ASSETS);

        _assertState({
            token            : usdcBase,
            proxyBalance     : 0,
            psmBalance       : PSM_USDC_BAL + 1_000_000e6,
            proxyShares      : PSM_PROXY_SHARES + shares,
            totalShares      : PSM_TOTAL_SHARES + shares,
            totalAssets      : PSM_TOTAL_ASSETS + 1_000_000e18,
            rateLimitKey     : key,
            currentRateLimit : 3_000_000e6
        });
    }

    function test_deposit_susds() external {
        bytes32 key = foreignController.LIMIT_PSM_DEPOSIT();

        deal(address(susdsBase), address(almProxy), 1_000_000e18);

        _assertState({
            token            : susdsBase,
            proxyBalance     : 1_000_000e18,
            psmBalance       : PSM_SUSDS_BAL,
            proxyShares      : PSM_PROXY_SHARES,
            totalShares      : PSM_TOTAL_SHARES,
            totalAssets      : PSM_TOTAL_ASSETS,
            rateLimitKey     : key,
            currentRateLimit : 8_000_000e18
        });

        uint256 conversionRate  = IRateProviderLike(psmBase.rateProvider()).getConversionRate();
        uint256 assetsDeposited = 1_000_000e18 * conversionRate / 1e27;

        vm.prank(relayer);
        uint256 shares = foreignController.depositPSM(address(susdsBase), 1_000_000e18);

        assertEq(shares, assetsDeposited * PSM_TOTAL_SHARES / PSM_TOTAL_ASSETS);

        _assertState({
            token            : susdsBase,
            proxyBalance     : 0,
            psmBalance       : PSM_SUSDS_BAL + 1_000_000e18,
            proxyShares      : PSM_PROXY_SHARES + shares,
            totalShares      : PSM_TOTAL_SHARES + shares,
            totalAssets      : PSM_TOTAL_ASSETS + assetsDeposited,
            rateLimitKey     : key,
            currentRateLimit : 7_000_000e18
        });
    }

}

contract ForeignControllerWithdrawPSMFailureTests is ForkTestBase {

    function test_withdrawPSM_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        foreignController.withdrawPSM(address(usdsBase), 100e18);
    }

    function test_withdrawPSM_frozen() external {
        vm.prank(freezer);
        foreignController.freeze();

        vm.prank(relayer);
        vm.expectRevert("ForeignController/not-active");
        foreignController.withdrawPSM(address(usdsBase), 100e18);
    }

}

contract ForeignControllerWithdrawTests is ForeignControllerPSMSuccessTestBase {

    function test_withdraw_usds() external {
        bytes32 key = foreignController.LIMIT_PSM_WITHDRAW();

        deal(address(usdsBase), address(almProxy), 1_000_000e18);

        vm.prank(relayer);
        uint256 shares = foreignController.depositPSM(address(usdsBase), 1_000_000e18);

        _assertState({
            token            : usdsBase,
            proxyBalance     : 0,
            psmBalance       : PSM_USDS_BAL + 1_000_000e18,
            proxyShares      : PSM_PROXY_SHARES + shares,
            totalShares      : PSM_TOTAL_SHARES + shares,
            totalAssets      : PSM_TOTAL_ASSETS + 1_000_000e18,
            rateLimitKey     : key,
            currentRateLimit : type(uint256).max
        });

        vm.prank(relayer);
        uint256 amountWithdrawn = foreignController.withdrawPSM(address(usdsBase), 1_000_000e18);

        assertEq(amountWithdrawn, 1_000_000e18);

        _assertState({
            token            : usdsBase,
            proxyBalance     : 1_000_000e18,
            psmBalance       : PSM_USDS_BAL,
            proxyShares      : PSM_PROXY_SHARES - 1,  // Rounding
            totalShares      : PSM_TOTAL_SHARES - 1,  // Rounding
            totalAssets      : PSM_TOTAL_ASSETS,
            rateLimitKey     : key,
            currentRateLimit : type(uint256).max
        });
    }

    function test_withdraw_usdc() external {
        bytes32 key = foreignController.LIMIT_PSM_WITHDRAW();

        deal(address(usdcBase), address(almProxy), 1_000_000e6);
        vm.prank(relayer);
        uint256 shares = foreignController.depositPSM(address(usdcBase), 1_000_000e6);

        _assertState({
            token            : usdcBase,
            proxyBalance     : 0,
            psmBalance       : PSM_USDC_BAL + 1_000_000e6,
            proxyShares      : PSM_PROXY_SHARES + shares,
            totalShares      : PSM_TOTAL_SHARES + shares,
            totalAssets      : PSM_TOTAL_ASSETS + 1_000_000e18,
            rateLimitKey     : key,
            currentRateLimit : 7_000_000e6
        });

        vm.prank(relayer);
        uint256 amountWithdrawn = foreignController.withdrawPSM(address(usdcBase), 1_000_000e6);

        assertEq(amountWithdrawn, 1_000_000e6);

        _assertState({
            token            : usdcBase,
            proxyBalance     : 1_000_000e6,
            psmBalance       : PSM_USDC_BAL,
            proxyShares      : PSM_PROXY_SHARES - 1,
            totalShares      : PSM_TOTAL_SHARES - 1,
            totalAssets      : PSM_TOTAL_ASSETS,
            rateLimitKey     : key,
            currentRateLimit : 6_000_000e6
        });
    }

    function test_withdraw_susds() external {
        bytes32 key = foreignController.LIMIT_PSM_WITHDRAW();

        deal(address(susdsBase), address(almProxy), 1_000_000e18);
        vm.prank(relayer);
        uint256 shares = foreignController.depositPSM(address(susdsBase), 1_000_000e18);

        uint256 conversionRate  = IRateProviderLike(psmBase.rateProvider()).getConversionRate();
        uint256 assetsDeposited = 1_000_000e18 * conversionRate / 1e27;

        _assertState({
            token            : susdsBase,
            proxyBalance     : 0,
            psmBalance       : PSM_SUSDS_BAL + 1_000_000e18,
            proxyShares      : PSM_PROXY_SHARES + shares,
            totalShares      : PSM_TOTAL_SHARES + shares,
            totalAssets      : PSM_TOTAL_ASSETS + assetsDeposited,
            rateLimitKey     : key,
            currentRateLimit : type(uint256).max
        });

        vm.prank(relayer);
        uint256 amountWithdrawn = foreignController.withdrawPSM(address(susdsBase), 1_000_000e18);

        assertEq(amountWithdrawn, 1_000_000e18);

        _assertState({
            token            : susdsBase,
            proxyBalance     : 1_000_000e18,
            psmBalance       : PSM_SUSDS_BAL,
            proxyShares      : PSM_PROXY_SHARES - 2,  // Double rounding on two conversions
            totalShares      : PSM_TOTAL_SHARES - 2,
            totalAssets      : PSM_TOTAL_ASSETS,
            rateLimitKey     : key,
            currentRateLimit : type(uint256).max
        });
    }

}
