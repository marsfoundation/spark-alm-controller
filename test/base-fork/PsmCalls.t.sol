// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/base-fork/ForkTestBase.t.sol";

contract L2ControllerSwapSuccessTestBase is ForkTestBase {

    function setUp() override public {
        super.setUp();

        deal(USDC_BASE,         address(psmBase), 100e6);
        deal(address(nstBase),  address(psmBase), 100e18);
        deal(address(snstBase), address(psmBase), 100e18);
    }

    function _assertBalances(
        IERC20  token,
        uint256 proxyBalance,
        uint256 psmBalance
    )
        internal view
    {
        assertEq(token.balanceOf(address(almProxy)),     proxyBalance);
        assertEq(token.balanceOf(address(l2Controller)), 0);  // Should always be zero
        assertEq(token.balanceOf(address(psmBase)),      psmBalance);

        // Should always be 0 before and after calls
        assertEq(nstBase.allowance(address(almProxy), address(psmBase)), 0);
    }

    // NOTE: Setting minAmountOut to 0, setting receiver to almProxy, and setting referralCode to 0
    //       for all of these tests for simplicity
    function _doSwapExactIn(IERC20  assetIn, IERC20 assetOut, uint256 amountIn) internal {
        vm.prank(relayer);
        l2Controller.swapExactIn({
            assetIn      : address(assetIn),
            assetOut     : address(assetOut),
            amountIn     : amountIn,
            minAmountOut : 0,
            receiver     : address(almProxy),
            referralCode : 0
        });
    }

}


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

contract L2ControllerSwapExactInTests is L2ControllerSwapSuccessTestBase {

    function test_swapExactIn_nstToUsdc() external {
        deal(address(nstBase), address(almProxy), 1e18);

        _assertBalances({ token: nstBase,  proxyBalance: 1e18, psmBalance: 100e18 });
        _assertBalances({ token: usdcBase, proxyBalance: 0,    psmBalance: 100e6 });

        _doSwapExactIn(nstBase, usdcBase, 1e18);

        _assertBalances({ token: nstBase,  proxyBalance: 0,   psmBalance: 101e18 });
        _assertBalances({ token: usdcBase, proxyBalance: 1e6, psmBalance: 99e6 });
    }

    function test_swapExactIn_nstToSNst() external {
        deal(address(nstBase), address(almProxy), 1e18);

        _assertBalances({ token: nstBase,  proxyBalance: 1e18, psmBalance: 100e18 });
        _assertBalances({ token: snstBase, proxyBalance: 0,    psmBalance: 100e18 });

        _doSwapExactIn(nstBase, snstBase, 1e18);

        _assertBalances({ token: nstBase,  proxyBalance: 0,      psmBalance: 101e18 });
        _assertBalances({ token: snstBase, proxyBalance: 0.8e18, psmBalance: 99.2e18 });
    }

    function test_swapExactIn_snstToNst() external {
        deal(address(snstBase), address(almProxy), 1e18);

        _assertBalances({ token: snstBase, proxyBalance: 1e18, psmBalance: 100e18 });
        _assertBalances({ token: nstBase,  proxyBalance: 0,    psmBalance: 100e18 });

        _doSwapExactIn(snstBase, nstBase, 1e18);

        _assertBalances({ token: snstBase, proxyBalance: 0,       psmBalance: 101e18 });
        _assertBalances({ token: nstBase,  proxyBalance: 1.25e18, psmBalance: 98.75e18 });
    }

    function test_swapExactIn_snstToUsdc() external {
        deal(address(snstBase), address(almProxy), 1e18);

        _assertBalances({ token: snstBase, proxyBalance: 1e18, psmBalance: 100e18 });
        _assertBalances({ token: usdcBase, proxyBalance: 0,    psmBalance: 100e6 });

        _doSwapExactIn(snstBase, usdcBase, 1e18);

        _assertBalances({ token: snstBase, proxyBalance: 0,      psmBalance: 101e18 });
        _assertBalances({ token: usdcBase, proxyBalance: 1.25e6, psmBalance: 98.75e6 });
    }

    function test_swapExactIn_usdcToNst() external {
        deal(address(usdcBase), address(almProxy), 1e6);

        _assertBalances({ token: usdcBase, proxyBalance: 1e6, psmBalance: 100e6 });
        _assertBalances({ token: nstBase,  proxyBalance: 0,   psmBalance: 100e18 });

        _doSwapExactIn(usdcBase, nstBase, 1e6);

        _assertBalances({ token: usdcBase, proxyBalance: 0,    psmBalance: 101e6 });
        _assertBalances({ token: nstBase,  proxyBalance: 1e18, psmBalance: 99e18 });
    }

    function test_swapExactIn_usdcToSNst() external {
        deal(address(usdcBase), address(almProxy), 1e6);

        _assertBalances({ token: usdcBase, proxyBalance: 1e6, psmBalance: 100e6 });
        _assertBalances({ token: snstBase, proxyBalance: 0,   psmBalance: 100e18 });

        _doSwapExactIn(usdcBase, snstBase, 1e6);

        _assertBalances({ token: usdcBase, proxyBalance: 0,      psmBalance: 101e6 });
        _assertBalances({ token: snstBase, proxyBalance: 0.8e18, psmBalance: 99.2e18 });
    }

}

contract L2ControllerSwapExactOutFailureTests is ForkTestBase {

    function test_swapExactOut_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        l2Controller.swapExactOut({
            assetIn      : address(nstBase),
            assetOut     : address(usdcBase),
            amountOut    : 1e18,
            maxAmountIn  : type(uint256).max,
            receiver     : address(almProxy),
            referralCode : 0
        });
    }

    function test_swapExactOut_frozen() external {
        vm.prank(freezer);
        l2Controller.freeze();

        vm.prank(relayer);
        vm.expectRevert("L2Controller/not-active");
        l2Controller.swapExactOut({
            assetIn      : address(nstBase),
            assetOut     : address(usdcBase),
            amountOut    : 1e18,
            maxAmountIn  : type(uint256).max,
            receiver     : address(almProxy),
            referralCode : 0
        });
    }

}


