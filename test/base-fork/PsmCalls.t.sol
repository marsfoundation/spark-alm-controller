// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/base-fork/ForkTestBase.t.sol";

contract ForeignControllerPSMSuccessTestBase is ForkTestBase {

    function _assertState(
        IERC20  token,
        uint256 proxyBalance,
        uint256 psmBalance,
        uint256 proxyShares,
        uint256 totalShares,
        uint256 totalAssets
    )
        internal view
    {
        assertEq(token.balanceOf(address(almProxy)),          proxyBalance);
        assertEq(token.balanceOf(address(foreignController)), 0);  // Should always be zero
        assertEq(token.balanceOf(address(psmBase)),           psmBalance);

        assertEq(psmBase.shares(address(almProxy)), proxyShares);
        assertEq(psmBase.totalShares(),             totalShares);
        assertEq(psmBase.totalAssets(),             totalAssets);

        // Should always be 0 before and after calls
        assertEq(usdsBase.allowance(address(almProxy), address(psmBase)), 0);
    }

}


contract ForeignControllerDepositPSMFailureTests is ForkTestBase {

    function test_depositPSM_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        foreignController.depositPSM(address(usdsBase), 100e18);
    }

    function test_depositPSM_frozen() external {
        vm.prank(freezer);
        foreignController.freeze();

        vm.prank(relayer);
        vm.expectRevert("ForeignController/not-active");
        foreignController.depositPSM(address(usdsBase), 100e18);
    }

}

contract ForeignControllerDepositTests is ForeignControllerPSMSuccessTestBase {

    function test_deposit_usds() external {
        deal(address(usdsBase), address(almProxy), 100e18);

        _assertState({
            token        : usdsBase,
            proxyBalance : 100e18,
            psmBalance   : 1e18,  // From seeding USDS
            proxyShares  : 0,
            totalShares  : 1e18,  // From seeding USDS
            totalAssets  : 1e18   // From seeding USDS
        });

        vm.prank(relayer);
        uint256 shares = foreignController.depositPSM(address(usdsBase), 100e18);

        assertEq(shares, 100e18);

        _assertState({
            token        : usdsBase,
            proxyBalance : 0,
            psmBalance   : 101e18,
            proxyShares  : 100e18,
            totalShares  : 101e18,
            totalAssets  : 101e18
        });
    }

    function test_deposit_usdc() external {
        deal(address(usdcBase), address(almProxy), 100e6);

        _assertState({
            token        : usdcBase,
            proxyBalance : 100e6,
            psmBalance   : 0,
            proxyShares  : 0,
            totalShares  : 1e18,  // From seeding USDS
            totalAssets  : 1e18   // From seeding USDS
        });

        vm.prank(relayer);
        uint256 shares = foreignController.depositPSM(address(usdcBase), 100e6);

        assertEq(shares, 100e18);

        _assertState({
            token        : usdcBase,
            proxyBalance : 0,
            psmBalance   : 100e6,
            proxyShares  : 100e18,
            totalShares  : 101e18,
            totalAssets  : 101e18
        });
    }

    function test_deposit_susds() external {
        deal(address(susdsBase), address(almProxy), 100e18);

        _assertState({
            token        : susdsBase,
            proxyBalance : 100e18,
            psmBalance   : 0,
            proxyShares  : 0,
            totalShares  : 1e18,  // From seeding USDS
            totalAssets  : 1e18   // From seeding USDS
        });

        vm.prank(relayer);
        uint256 shares = foreignController.depositPSM(address(susdsBase), 100e18);

        assertEq(shares, 125e18);

        _assertState({
            token        : susdsBase,
            proxyBalance : 0,
            psmBalance   : 100e18,
            proxyShares  : 125e18,
            totalShares  : 126e18,
            totalAssets  : 126e18
        });
    }

}

contract ForeignControllerWithdrawPSMFailureTests is ForkTestBase {

    function test_withdrawPSM_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        foreignController.withdrawPSM(address(usdsBase), 100e18);
    }

    function test_withdrawPSM_frozen() external {
        vm.prank(freezer);
        foreignController.freeze();

        vm.prank(relayer);
        vm.expectRevert("ForeignController/not-active");
        foreignController.withdrawPSM(address(usdsBase), 100e18);
    }

}

contract ForeignControllerWithdrawTests is ForeignControllerPSMSuccessTestBase {

    function test_withdraw_usds() external {
        deal(address(usdsBase), address(almProxy), 100e18);
        vm.prank(relayer);
        foreignController.depositPSM(address(usdsBase), 100e18);

        _assertState({
            token        : usdsBase,
            proxyBalance : 0,
            psmBalance   : 101e18,
            proxyShares  : 100e18,
            totalShares  : 101e18,
            totalAssets  : 101e18
        });

        vm.prank(relayer);
        uint256 amountWithdrawn = foreignController.withdrawPSM(address(usdsBase), 100e18);

        assertEq(amountWithdrawn, 100e18);

        _assertState({
            token        : usdsBase,
            proxyBalance : 100e18,
            psmBalance   : 1e18,  // From seeding USDS
            proxyShares  : 0,
            totalShares  : 1e18,  // From seeding USDS
            totalAssets  : 1e18   // From seeding USDS
        });
    }

    function test_withdraw_usdc() external {
        deal(address(usdcBase), address(almProxy), 100e6);
        vm.prank(relayer);
        foreignController.depositPSM(address(usdcBase), 100e6);

        _assertState({
            token        : usdcBase,
            proxyBalance : 0,
            psmBalance   : 100e6,
            proxyShares  : 100e18,
            totalShares  : 101e18,
            totalAssets  : 101e18
        });

        vm.prank(relayer);
        uint256 amountWithdrawn = foreignController.withdrawPSM(address(usdcBase), 100e6);

        assertEq(amountWithdrawn, 100e6);

        _assertState({
            token        : usdcBase,
            proxyBalance : 100e6,
            psmBalance   : 0,
            proxyShares  : 0,
            totalShares  : 1e18,  // From seeding USDS
            totalAssets  : 1e18   // From seeding USDS
        });
    }

    function test_withdraw_susds() external {
        deal(address(susdsBase), address(almProxy), 100e18);
        vm.prank(relayer);
        foreignController.depositPSM(address(susdsBase), 100e18);

        _assertState({
            token        : susdsBase,
            proxyBalance : 0,
            psmBalance   : 100e18,
            proxyShares  : 125e18,
            totalShares  : 126e18,
            totalAssets  : 126e18
        });

        vm.prank(relayer);
        uint256 amountWithdrawn = foreignController.withdrawPSM(address(susdsBase), 100e18);

        assertEq(amountWithdrawn, 100e18);

        _assertState({
            token        : susdsBase,
            proxyBalance : 100e18,
            psmBalance   : 0,
            proxyShares  : 0,
            totalShares  : 1e18,  // From seeding USDS
            totalAssets  : 1e18   // From seeding USDS
        });
    }

}
