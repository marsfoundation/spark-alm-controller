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
        vm.expectRevert("L2Controller/not-active");
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

contract L2ControllerSwapExactInTests is ForkTestBase {

    function test_swapExactIn() external {
        // Give the PSM a balance of 100 USDC and 100 NST, give proxy 1 NST.
        // TODO: Refactor to use real deposits once full integration is set up
        deal(USDC_BASE,        address(psmBase),  100e6);
        deal(address(nstBase), address(psmBase),  100e18);
        deal(address(nstBase), address(almProxy), 1e18);

        assertEq(nstBase.balanceOf(address(almProxy)),     1e18);
        assertEq(nstBase.balanceOf(address(l2Controller)), 0);
        assertEq(nstBase.balanceOf(address(psmBase)),      100e18);

        assertEq(usdcBase.balanceOf(address(almProxy)),     0);
        assertEq(usdcBase.balanceOf(address(l2Controller)), 0);
        assertEq(usdcBase.balanceOf(address(psmBase)),      100e6);

        assertEq(nstBase.allowance(address(almProxy), address(psmBase)), 0);

        vm.prank(relayer);
        l2Controller.swapExactIn({
            assetIn      : address(nstBase),
            assetOut     : address(usdcBase),
            amountIn     : 1e18,
            minAmountOut : 0,
            receiver     : address(almProxy),
            referralCode : 0
        });

        assertEq(nstBase.balanceOf(address(almProxy)),     0);
        assertEq(nstBase.balanceOf(address(l2Controller)), 0);
        assertEq(nstBase.balanceOf(address(psmBase)),      101e18);

        assertEq(usdcBase.balanceOf(address(almProxy)),     1e6);
        assertEq(usdcBase.balanceOf(address(l2Controller)), 0);
        assertEq(usdcBase.balanceOf(address(psmBase)),      99e6);

        assertEq(nstBase.allowance(address(almProxy), address(psmBase)), 0);
    }

}
