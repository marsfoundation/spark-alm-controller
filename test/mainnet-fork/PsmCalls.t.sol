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

    function test_swapUSDCToUSDS_incompleteFillBoundary() external {
        // The line is just over 2.1 billion, this condition will allow DAI to get minted to get to
        // 2 billion in Art, and then another fill to get to the `line`.
        deal(address(usdc), address(pocket), 1_800_000_000e6);

        uint256 fillAmount = psm.rush();

        assertEq(fillAmount, 121_680_037.47418e18);  // Only first fill amount

        // NOTE: Art == dai here because rate is 1 for PSM ilk
        ( uint256 Art,,, uint256 line, ) = dss.vat.ilks(PSM_ILK);

        assertEq(Art,  1_878_319_962.52582e18);
        assertEq(Art,  2_000_000_000e18 - fillAmount);  // First fill gets art to 2 billion
        assertEq(line, 2_124_094_563.678406e45);

        // The first fill increases the Art to 2 billion and the USDC balance of the PSM to 2.1 billion.
        // For the second fill, the USDC balance + buffer option is ~2.3 billion so it instead fills to the line
        // which is 2.124 billion.
        uint256 expectedFillAmount2 = line / 1e27 - 2_000_000_000e18;

        assertEq(expectedFillAmount2, 124_094_563.678406e18);

        // Max amount of DAI that can be swapped, converted to USDC precision
        uint256 maxSwapAmount = (DAI_BAL_PSM + fillAmount + expectedFillAmount2) / 1e12;

        assertEq(maxSwapAmount, 450_281_089.262716e6);

        deal(address(usdc), address(almProxy), maxSwapAmount + 1);

        vm.startPrank(relayer);
        vm.expectRevert("DssLitePsm/nothing-to-fill");
        mainnetController.swapUSDCToUSDS(maxSwapAmount + 1);

        mainnetController.swapUSDCToUSDS(maxSwapAmount);

        ( Art,,,, ) = dss.vat.ilks(PSM_ILK);

        // Art has now been filled to the debt ceiling and there is no DAI left in the PSM.
        assertEq(Art, line / 1e27);
        assertEq(Art, 2_124_094_563.678406e18);

        assertEq(dai.balanceOf(address(PSM)), 0);
    }

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

    function test_swapUSDCToUSDS_partialRefill() external {
        assertEq(DAI_BAL_PSM, 204_506_488.11013e18);

        // PSM is not fillable at current fork so need to deal USDC
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

    function test_swapUSDCToUSDS_multipleRefills() external {
        assertEq(DAI_BAL_PSM, 204_506_488.11013e18);

        // PSM is not fillable at current fork so need to deal USDC
        uint256 fillAmount = psm.rush();

        assertEq(fillAmount, 0);

        // The line is just over 2.1 billion, this condition will allow DAI to get minted to get to
        // 2 billion in Art, and then another fill to get to the `line`.
        deal(address(usdc), address(pocket), 1_800_000_000e6);

        fillAmount = psm.rush();

        assertEq(fillAmount, 121_680_037.47418e18);  // Only first fill amount

        deal(address(usdc), address(almProxy), 400_000_000e6);  // Higher than balance of DAI + fillAmount

        assertEq(usds.balanceOf(address(almProxy)),          0);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.totalSupply(),                         0);

        assertEq(dai.balanceOf(address(almProxy)), 0);
        assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM);
        assertEq(dai.totalSupply(),                DAI_SUPPLY);

        assertEq(usdc.balanceOf(address(almProxy)),          400_000_000e6);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.balanceOf(address(pocket)),            1_800_000_000e6);

        assertEq(usds.allowance(address(buffer),   address(vault)),   type(uint256).max);
        assertEq(usds.allowance(address(almProxy), address(daiUsds)), 0);
        assertEq(dai.allowance(address(almProxy),  address(PSM)),     0);

        // NOTE: Art == dai here because rate is 1 for PSM ilk
        ( uint256 Art,,, uint256 line, ) = dss.vat.ilks(PSM_ILK);

        assertEq(Art,  1_878_319_962.52582e18);
        assertEq(Art,  2_000_000_000e18 - fillAmount);  // First fill gets art to 2 billion
        assertEq(line, 2_124_094_563.678406e45);

        // The first fill increases the Art to 2 billion and the USDC balance of the PSM to 2.1 billion.
        // For the second fill, the USDC balance + buffer option is ~2.3 billion so it instead fills to the line
        // which is 2.124 billion.
        uint256 expectedFillAmount2 = line / 1e27 - 2_000_000_000e18;

        assertEq(expectedFillAmount2, 124_094_563.678406e18);

        assertEq(Art + fillAmount + expectedFillAmount2, line / 1e27);  // Two fills will increase Art to the debt ceiling

        vm.prank(relayer);
        vm.expectEmit(PSM);
        emit Fill(fillAmount);
        emit Fill(expectedFillAmount2);
        mainnetController.swapUSDCToUSDS(400_000_000e6);

        ( Art,,,, ) = dss.vat.ilks(PSM_ILK);

        // Art has now been filled to the debt ceiling.
        assertEq(Art, line / 1e27);
        assertEq(Art, 2_124_094_563.678406e18);

        assertEq(usds.balanceOf(address(almProxy)),          400_000_000e18);
        assertEq(usds.balanceOf(address(mainnetController)), 0);
        assertEq(usds.totalSupply(),                         400_000_000e18);

        assertEq(dai.balanceOf(address(almProxy)), 0);
        assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM + fillAmount + expectedFillAmount2 - 400_000_000e18);
        assertEq(dai.balanceOf(address(PSM)),      50_281_089.262716e18);
        assertEq(dai.totalSupply(),                DAI_SUPPLY + fillAmount + expectedFillAmount2 - 400_000_000e18);

        assertEq(usdc.balanceOf(address(almProxy)),          0);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.balanceOf(address(pocket)),            2_200_000_000e6);  // 1.8 billion + 400 million

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

