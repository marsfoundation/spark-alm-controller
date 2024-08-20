// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/base-fork/ForkTestBase.t.sol";

contract L2ControllerSwapExactInFailureTests is ForkTestBase {

    function test_swapExactIn_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        l2Controller.swapExactIn({
            assetIn      : address(nstBase),
            assetOut     : address(usdcBase),
            amountIn     : 1e18,
            minAmountOut : 0,
            receiver     : address(almProxy),
            referralCode : 0
        });
    }

    function test_swapExactIn_frozen() external {
        vm.prank(freezer);
        l2Controller.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        l2Controller.swapExactIn({
            assetIn      : address(nstBase),
            assetOut     : address(usdcBase),
            amountIn     : 1e18,
            minAmountOut : 0,
            receiver     : address(almProxy),
            referralCode : 0
        });
    }

}

// contract MainnetControllerSwapNSTToUSDCTests is ForkTestBase {

//     function test_swapNSTToUSDC() external {
//         vm.prank(relayer);
//         l2Controller.mintNST(1e18);

//         assertEq(nstBase.balanceOf(address(almProxy)),          1e18);
//         assertEq(nstBase.balanceOf(address(l2Controller)), 0);
//         assertEq(nstBase.totalSupply(),                         1e18);

//         assertEq(dai.balanceOf(address(almProxy)), 0);
//         assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM);
//         assertEq(dai.totalSupply(),                DAI_SUPPLY);

//         assertEq(usdcBase.balanceOf(address(almProxy)),          0);
//         assertEq(usdcBase.balanceOf(address(l2Controller)), 0);
//         assertEq(usdcBase.balanceOf(address(pocket)),            USDC_BAL_PSM);

//         assertEq(nstBase.allowance(address(buffer),   address(vault)),  type(uint256).max);
//         assertEq(nstBase.allowance(address(almProxy), address(daiNst)), 0);
//         assertEq(dai.allowance(address(almProxy), address(PSM)),    0);

//         vm.prank(relayer);
//         l2Controller.swapNSTToUSDC(1e6);

//         assertEq(nstBase.balanceOf(address(almProxy)),          0);
//         assertEq(nstBase.balanceOf(address(l2Controller)), 0);
//         assertEq(nstBase.totalSupply(),                         0);

//         assertEq(dai.balanceOf(address(almProxy)), 0);
//         assertEq(dai.balanceOf(address(PSM)),      DAI_BAL_PSM + 1e18);
//         assertEq(dai.totalSupply(),                DAI_SUPPLY + 1e18);

//         assertEq(usdcBase.balanceOf(address(almProxy)),          1e6);
//         assertEq(usdcBase.balanceOf(address(l2Controller)), 0);
//         assertEq(usdcBase.balanceOf(address(pocket)),            USDC_BAL_PSM - 1e6);

//         assertEq(nstBase.allowance(address(buffer),   address(vault)),  type(uint256).max);
//         assertEq(nstBase.allowance(address(almProxy), address(daiNst)), 0);
//         assertEq(dai.allowance(address(almProxy), address(PSM)),    0);
//     }

// }
