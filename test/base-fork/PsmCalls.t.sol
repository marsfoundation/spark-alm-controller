// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/base-fork/ForkTestBase.t.sol";

contract L2ControllerSwapSuccessTestBase is ForkTestBase {

    function _assertState(
        IERC20  token,
        uint256 proxyBalance,
        uint256 psmBalance,
        uint256 returnedShares,
        uint256 proxyShares,
        uint256 totalShares,
        uint256 totalAssets
    )
        internal view
    {
        assertEq(token.balanceOf(address(almProxy)),     proxyBalance);
        assertEq(token.balanceOf(address(l2Controller)), 0);  // Should always be zero
        assertEq(token.balanceOf(address(psmBase)),      psmBalance);

        assertEq(psmBase.shares(address(almProxy)), proxyShares);
        assertEq(psmBase.totalShares(),             totalShares);
        assertEq(psmBase.totalAssets(),             totalAssets);

        assertEq(returnedShares, proxyShares);

        // Should always be 0 before and after calls
        assertEq(nstBase.allowance(address(almProxy), address(psmBase)), 0);
    }

}


contract L2ControllerDepositPSMFailureTests is ForkTestBase {

    function test_depositPSM_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        l2Controller.depositPSM(address(nstBase), 100e18);
    }

    function test_depositPSM_frozen() external {
        vm.prank(freezer);
        l2Controller.freeze();

        vm.prank(relayer);
        vm.expectRevert("L2Controller/not-active");
        l2Controller.depositPSM(address(nstBase), 100e18);
    }

}

contract L2ControllerDepositTests is L2ControllerSwapSuccessTestBase {

    function test_deposit_nst() external {
        deal(address(nstBase), address(almProxy), 100e18);

        _assertState({
            token          : nstBase,
            proxyBalance   : 100e18,
            psmBalance     : 1e18,  // From seeding
            returnedShares : 0,
            proxyShares    : 0,
            totalShares    : 1e18,  // From seeding
            totalAssets    : 1e18   // From seeding
        });

        vm.prank(relayer);
        uint256 shares = l2Controller.depositPSM(address(nstBase), 100e18);

        _assertState({
            token          : nstBase,
            proxyBalance   : 0,
            psmBalance     : 101e18,
            returnedShares : shares,
            proxyShares    : 100e18,
            totalShares    : 101e18,
            totalAssets    : 101e18
        });
    }

    function test_deposit_usdc() external {
        deal(address(usdcBase), address(almProxy), 100e6);

        _assertState({
            token          : usdcBase,
            proxyBalance   : 100e6,
            psmBalance     : 0,
            returnedShares : 0,
            proxyShares    : 0,
            totalShares    : 1e18,  // From seeding
            totalAssets    : 1e18   // From seeding
        });

        vm.prank(relayer);
        uint256 shares = l2Controller.depositPSM(address(usdcBase), 100e6);

        _assertState({
            token          : usdcBase,
            proxyBalance   : 0,
            psmBalance     : 100e6,
            returnedShares : shares,
            proxyShares    : 100e18,
            totalShares    : 101e18,
            totalAssets    : 101e18
        });
    }

    function test_deposit_snst() external {
        deal(address(snstBase), address(almProxy), 100e18);

        _assertState({
            token          : snstBase,
            proxyBalance   : 100e18,
            psmBalance     : 0,
            returnedShares : 0,
            proxyShares    : 0,
            totalShares    : 1e18,  // From seeding
            totalAssets    : 1e18   // From seeding
        });

        vm.prank(relayer);
        uint256 shares = l2Controller.depositPSM(address(snstBase), 100e18);

        _assertState({
            token          : snstBase,
            proxyBalance   : 0,
            psmBalance     : 100e18,
            returnedShares : shares,
            proxyShares    : 125e18,
            totalShares    : 126e18,
            totalAssets    : 126e18
        });
    }

}

// contract L2ControllerSwapExactOutFailureTests is ForkTestBase {

//     function test_swapExactOut_notRelayer() external {
//         vm.expectRevert(abi.encodeWithSignature(
//             "AccessControlUnauthorizedAccount(address,bytes32)",
//             address(this),
//             RELAYER
//         ));
//         // l2Controller.swapExactOut({
//         //     assetIn      : address(nstBase),
//         //     assetOut     : address(usdcBase),
//         //     amountOut    : 1e18,
//         //     maxAmountIn  : type(uint256).max,
//         //     referralCode : 0
//         // });
//     }

//     function test_swapExactOut_frozen() external {
//         vm.prank(freezer);
//         l2Controller.freeze();

//         vm.prank(relayer);
//         vm.expectRevert("L2Controller/not-active");
//         // l2Controller.swapExactOut({
//         //     assetIn      : address(nstBase),
//         //     assetOut     : address(usdcBase),
//         //     amountOut    : 1e18,
//         //     maxAmountIn  : type(uint256).max,
//         //     referralCode : 0
//         // });
//     }

// }

// contract L2ControllerSwapExactOutTests is L2ControllerSwapSuccessTestBase {

//     // function test_swapExactOut_usdcToSNst() external {
//     //     deal(address(usdcBase), address(almProxy), 1e6);

//     //     _assertBalances({ token: usdcBase, proxyBalance: 1e6, psmBalance: 100e6 });
//     //     _assertBalances({ token: snstBase, proxyBalance: 0,   psmBalance: 100e18 });

//     //     uint256 amountIn = _doSwapExactOut(usdcBase, snstBase, 0.8e18);

//     //     assertEq(amountIn, 1e6);

//     //     _assertBalances({ token: usdcBase, proxyBalance: 0,      psmBalance: 101e6 });
//     //     _assertBalances({ token: snstBase, proxyBalance: 0.8e18, psmBalance: 99.2e18 });
//     // }

// }


