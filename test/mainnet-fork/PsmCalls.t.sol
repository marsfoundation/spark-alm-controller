// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/mainnet-fork/ForkTestBase.t.sol";

contract MainnetControllerSwapUSDSToUSDCFailureTests is ForkTestBase {

    function test_swapUSDCToUSDS_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.swapUSDCToUSDS(1e6);
    }

    function test_swapUSDCToUSDS_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.swapUSDCToUSDS(1e6);
    }

}

contract MainnetControllerSwapUSDSToUSDCTests is ForkTestBase {

    function test_swapUSDSToUSDC() external {
        vm.prank(relayer);
        mainnetController.mintUSDS(1e18);

        assertEq(usds.balanceOf(address(almProxy)),          1e18);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.totalSupply(),                         1e18);

        assertEq(dai.balanceOf(address(almProxy)), 0);
        assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM);
        assertEq(dai.totalSupply(),                DAI_SUPPLY);

        assertEq(usdc.balanceOf(address(almProxy)),          0);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.balanceOf(address(pocket)),            USDC_BAL_PSM);

        assertEq(usds.allowance(address(buffer),   address(vault)),   type(uint256).max);
        assertEq(usds.allowance(address(almProxy), address(daiUsds)), 0);
        assertEq(dai.allowance(address(almProxy),  address(PSM)),     0);

        vm.prank(relayer);
        mainnetController.swapUSDSToUSDC(1e6);

        assertEq(usds.balanceOf(address(almProxy)),          0);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.totalSupply(),                         0);

        assertEq(dai.balanceOf(address(almProxy)), 0);
        assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM + 1e18);
        assertEq(dai.totalSupply(),                DAI_SUPPLY + 1e18);

        assertEq(usdc.balanceOf(address(almProxy)),          1e6);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.balanceOf(address(pocket)),            USDC_BAL_PSM - 1e6);

        assertEq(usds.allowance(address(buffer),   address(vault)),   type(uint256).max);
        assertEq(usds.allowance(address(almProxy), address(daiUsds)), 0);
        assertEq(dai.allowance(address(almProxy),  address(PSM)),     0);
    }

    function test_swapUSDSToUSDC_rateLimited() external {
        vm.startPrank(SPARK_PROXY);
        rateLimits.setUnlimitedRateLimitData(mainnetController.LIMIT_USDS_MINT());
        vm.stopPrank();

        bytes32 key = mainnetController.LIMIT_USDS_TO_USDC();
        vm.startPrank(relayer);

        mainnetController.mintUSDS(9_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 5_000_000e6);
        assertEq(usds.balanceOf(address(almProxy)),   9_000_000e18);
        assertEq(usdc.balanceOf(address(almProxy)),   0);

        mainnetController.swapUSDSToUSDC(1_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(key), 4_000_000e6);
        assertEq(usds.balanceOf(address(almProxy)),   8_000_000e18);
        assertEq(usdc.balanceOf(address(almProxy)),   1_000_000e6);

        skip(1 hours);

        assertEq(rateLimits.getCurrentRateLimit(key), 4_249_999.9984e6);
        assertEq(usds.balanceOf(address(almProxy)),   8_000_000e18);
        assertEq(usdc.balanceOf(address(almProxy)),   1_000_000e6);

        mainnetController.swapUSDSToUSDC(4_249_999.9984e6);

        assertEq(rateLimits.getCurrentRateLimit(key), 0);
        assertEq(usds.balanceOf(address(almProxy)),   3_750_000.0016e18);
        assertEq(usdc.balanceOf(address(almProxy)),   5_249_999.9984e6);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.swapUSDSToUSDC(1);

        vm.stopPrank();
    }

}

contract MainnetControllerSwapUSDCToUSDSFailureTests is ForkTestBase {

    function test_swapUSDCToUSDS_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.swapUSDCToUSDS(1e6);
    }

    function test_swapUSDCToUSDS_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.swapUSDCToUSDS(1e6);
    }

}

contract MainnetControllerSwapUSDCToUSDSTests is ForkTestBase {

    function test_swapUSDCToUSDS() external {
        deal(address(usdc), address(almProxy), 1e6);

        assertEq(usds.balanceOf(address(almProxy)),          0);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.totalSupply(),                         0);

        assertEq(dai.balanceOf(address(almProxy)), 0);
        assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM);
        assertEq(dai.totalSupply(),                DAI_SUPPLY);

        assertEq(usdc.balanceOf(address(almProxy)),          1e6);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.balanceOf(address(pocket)),            USDC_BAL_PSM);

        assertEq(usds.allowance(address(buffer),   address(vault)),   type(uint256).max);
        assertEq(usds.allowance(address(almProxy), address(daiUsds)), 0);
        assertEq(dai.allowance(address(almProxy),  address(PSM)),     0);

        vm.prank(relayer);
        mainnetController.swapUSDCToUSDS(1e6);

        assertEq(usds.balanceOf(address(almProxy)),          1e18);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.totalSupply(),                         1e18);

        assertEq(dai.balanceOf(address(almProxy)), 0);
        assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM - 1e18);
        assertEq(dai.totalSupply(),                DAI_SUPPLY - 1e18);

        assertEq(usdc.balanceOf(address(almProxy)),          0);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.balanceOf(address(pocket)),            USDC_BAL_PSM + 1e6);

        assertEq(usds.allowance(address(buffer),   address(vault)),   type(uint256).max);
        assertEq(usds.allowance(address(almProxy), address(daiUsds)), 0);
        assertEq(dai.allowance(address(almProxy),  address(PSM)),     0);
    }

    function test_swapUSDCToUSDS_rateLimited() external {
        bytes32 key = mainnetController.LIMIT_USDS_TO_USDC();
        vm.startPrank(relayer);

        mainnetController.mintUSDS(5_000_000e18);

        mainnetController.swapUSDSToUSDC(1_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(key), 4_000_000e6);
        assertEq(usds.balanceOf(address(almProxy)),   4_000_000e18);
        assertEq(usdc.balanceOf(address(almProxy)),   1_000_000e6);


        mainnetController.swapUSDCToUSDS(400_000e6);

        assertEq(rateLimits.getCurrentRateLimit(key), 4_400_000e6);
        assertEq(usds.balanceOf(address(almProxy)),   4_400_000e18);
        assertEq(usdc.balanceOf(address(almProxy)),   600_000e6);

        skip(4 hours);

        assertEq(rateLimits.getCurrentRateLimit(key), 5_000_000e6);
        assertEq(usds.balanceOf(address(almProxy)),   4_400_000e18);
        assertEq(usdc.balanceOf(address(almProxy)),   600_000e6);

        mainnetController.swapUSDCToUSDS(600_000e6);

        assertEq(rateLimits.getCurrentRateLimit(key), 5_000_000e6);
        assertEq(usds.balanceOf(address(almProxy)),   5_000_000e18);
        assertEq(usdc.balanceOf(address(almProxy)),   0);

        vm.stopPrank();
    }

}

