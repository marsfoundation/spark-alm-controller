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

    function test_swapUSDCToUSDS_firstRefillIncomplete() external {}
    function test_swapUSDCToUSDS_secondfRefillIncomplete() external {}
}

contract MainnetControllerSwapUSDCToUSDSTests is ForkTestBase {

    event Fill(uint256 wad);

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

    function test_swapUSDCToUSDS_partialSingleRefill() external {
        assertEq(DAI_BAL_PSM, 204_506_488.11013e18);

        DssLitePsm psmCode = new DssLitePsm(psm.ilk(), address(psm.gem()), address(psm.daiJoin()), psm.pocket());

        vm.etch(PSM, address(psmCode).code);

        uint256 fillAmount = psm.rush();

        assertEq(fillAmount, 0);

        // The line is just over 2.1 billion, this condition will allow DAI to get minted to get to
        // 2 billion in Art, so it will mint the difference between current Art and 2 billion.
        deal(address(usdc), address(pocket), 1_800_000_000e6);

        fillAmount = psm.rush();

        assertEq(fillAmount, 121_680_037.47418e18);

        deal(address(usdc), address(almProxy), 300_000_000e6);  // Higher than balance of DAI

        assertEq(usds.balanceOf(address(almProxy)),          0);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.totalSupply(),                         0);

        assertEq(dai.balanceOf(address(almProxy)), 0);
        assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM);
        assertEq(dai.totalSupply(),                DAI_SUPPLY);

        assertEq(usdc.balanceOf(address(almProxy)),          300_000_000e6);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.balanceOf(address(pocket)),            1_800_000_000e6);

        assertEq(usds.allowance(address(buffer),   address(vault)),   type(uint256).max);
        assertEq(usds.allowance(address(almProxy), address(daiUsds)), 0);
        assertEq(dai.allowance(address(almProxy),  address(PSM)),     0);

        // NOTE: Art == dai here because rate is 1 for PSM ilk
        ( uint256 Art,,,, ) = dss.vat.ilks(PSM_ILK);

        assertEq(Art, 1_878_319_962.52582e18);
        assertEq(Art, 2_000_000_000e18 - fillAmount);

        vm.prank(relayer);
        vm.expectEmit(PSM);
        emit Fill(fillAmount);
        mainnetController.swapUSDCToUSDS(300_000_000e6);

        ( Art,,,, ) = dss.vat.ilks(PSM_ILK);

        // 2 billion because the USDC balance of the PSM was 1.8 billion, plus 200m buffer allowed
        // it to mint the amount of DAI to get to this 2 billion value, which was difference between
        // original Art and 2 billion.
        assertEq(Art, 2_000_000_000e18);

        assertEq(usds.balanceOf(address(almProxy)),          300_000_000e18);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.totalSupply(),                         300_000_000e18);

        assertEq(dai.balanceOf(address(almProxy)), 0);
        assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM + fillAmount - 300_000_000e18);
        assertEq(dai.balanceOf(address(PSM)),      26_186_525.58431e18);
        assertEq(dai.totalSupply(),                DAI_SUPPLY + fillAmount - 300_000_000e18);

        assertEq(usdc.balanceOf(address(almProxy)),          0);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.balanceOf(address(pocket)),            2_100_000_000e6);  // 1.8 billion + 300 million

        assertEq(usds.allowance(address(buffer),   address(vault)),   type(uint256).max);
        assertEq(usds.allowance(address(almProxy), address(daiUsds)), 0);
        assertEq(dai.allowance(address(almProxy),  address(PSM)),     0);
    }

    function test_swapUSDCToUSDS_exactRefill() external {}
    function test_swapUSDCToUSDS_multipleRefill() external {}

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

