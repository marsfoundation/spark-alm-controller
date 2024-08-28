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

}

