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

    function setUp() override public {
        super.setUp();

        deal(USDC_BASE,         address(psmBase), 100e6);
        deal(address(nstBase),  address(psmBase), 100e18);
        deal(address(snstBase), address(psmBase), 80e18);
    }

    function _assertBalances(
        IERC20  token,
        uint256 proxyBalance,
        uint256 psmBalance
    )
        internal
    {
        assertEq(token.balanceOf(address(almProxy)),     proxyBalance);
        assertEq(token.balanceOf(address(l2Controller)), 0);
        assertEq(token.balanceOf(address(psmBase)),      psmBalance);

        // Should always be 0 before and after calls
        assertEq(nstBase.allowance(address(almProxy), address(psmBase)), 0);
    }

    function test_swapExactIn_usdcAndNst() external {
        deal(address(nstBase), address(almProxy), 1e18);

        _assertBalances({ token: nstBase,  proxyBalance: 1e18, psmBalance: 100e18 });
        _assertBalances({ token: usdcBase, proxyBalance: 0,    psmBalance: 100e6 });

        vm.prank(relayer);
        l2Controller.swapExactIn({
            assetIn      : address(nstBase),
            assetOut     : address(usdcBase),
            amountIn     : 1e18,
            minAmountOut : 0,
            receiver     : address(almProxy),
            referralCode : 0
        });

        _assertBalances({ token: nstBase,  proxyBalance: 0,   psmBalance: 101e18 });
        _assertBalances({ token: usdcBase, proxyBalance: 1e6, psmBalance: 99e6 });
    }

}
