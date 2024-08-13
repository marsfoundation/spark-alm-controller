// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/fork/ForkTestBase.t.sol";

contract MainnetControllerSwapNSTToUSDCFailureTests is ForkTestBase {

    function test_swapUSDCToNST_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.swapUSDCToNST(1e6);
    }

    function test_swapUSDCToNST_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.swapNSTToUSDC(1e6);
    }

}

contract MainnetControllerSwapNSTToUSDCTests is ForkTestBase {

    function test_swapNSTToUSDC() external {
        vm.prank(relayer);
        mainnetController.mintNST(1e18);

        assertEq(nst.balanceOf(address(almProxy)),          1e18);
        assertEq(nst.balanceOf(address(mainnetController)), 0);
        assertEq(nst.totalSupply(),                         1e18);

        assertEq(dai.balanceOf(address(almProxy)), 0);
        assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM);
        assertEq(dai.totalSupply(),                DAI_SUPPLY);

        assertEq(usdc.balanceOf(address(almProxy)),          0);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.balanceOf(address(pocket)),            USDC_BAL_PSM);

        assertEq(nst.allowance(address(buffer),   address(vault)),  type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(daiNst)), 0);
        assertEq(dai.allowance(address(almProxy), address(PSM)),    0);

        vm.prank(relayer);
        mainnetController.swapNSTToUSDC(1e6);

        assertEq(nst.balanceOf(address(almProxy)),          0);
        assertEq(nst.balanceOf(address(mainnetController)), 0);
        assertEq(nst.totalSupply(),                         0);

        assertEq(dai.balanceOf(address(almProxy)), 0);
        assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM + 1e18);
        assertEq(dai.totalSupply(),                DAI_SUPPLY + 1e18);

        assertEq(usdc.balanceOf(address(almProxy)),          1e6);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.balanceOf(address(pocket)),            USDC_BAL_PSM - 1e6);

        assertEq(nst.allowance(address(buffer),   address(vault)),  type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(daiNst)), 0);
        assertEq(dai.allowance(address(almProxy), address(PSM)),    0);
    }

}

contract MainnetControllerSwapUSDCToNSTFailureTests is ForkTestBase {

    function test_swapUSDCToNST_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.swapUSDCToNST(1e6);
    }

    function test_swapUSDCToNST_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.swapUSDCToNST(1e6);
    }

}

contract MainnetControllerSwapUSDCToNSTTests is ForkTestBase {

    function test_swapUSDCToNST() external {
        deal(address(usdc), address(almProxy), 1e6);

        assertEq(nst.balanceOf(address(almProxy)),          0);
        assertEq(nst.balanceOf(address(mainnetController)), 0);
        assertEq(nst.totalSupply(),                         0);

        assertEq(dai.balanceOf(address(almProxy)), 0);
        assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM);
        assertEq(dai.totalSupply(),                DAI_SUPPLY);

        assertEq(usdc.balanceOf(address(almProxy)),          1e6);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.balanceOf(address(pocket)),            USDC_BAL_PSM);

        assertEq(nst.allowance(address(buffer),   address(vault)),  type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(daiNst)), 0);
        assertEq(dai.allowance(address(almProxy), address(PSM)),    0);

        vm.prank(relayer);
        mainnetController.swapUSDCToNST(1e6);

        assertEq(nst.balanceOf(address(almProxy)),          1e18);
        assertEq(nst.balanceOf(address(mainnetController)), 0);
        assertEq(nst.totalSupply(),                         1e18);

        assertEq(dai.balanceOf(address(almProxy)), 0);
        assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM - 1e18);
        assertEq(dai.totalSupply(),                DAI_SUPPLY - 1e18);

        assertEq(usdc.balanceOf(address(almProxy)),          0);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.balanceOf(address(pocket)),            USDC_BAL_PSM + 1e6);

        assertEq(nst.allowance(address(buffer),   address(vault)),  type(uint256).max);
        assertEq(nst.allowance(address(almProxy), address(daiNst)), 0);
        assertEq(dai.allowance(address(almProxy), address(PSM)),    0);
    }

}

