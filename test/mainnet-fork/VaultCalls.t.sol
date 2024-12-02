// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "test/mainnet-fork/ForkTestBase.t.sol";

contract MainnetControllerMintUSDSTests is ForkTestBase {

    function test_mintUSDS_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.mintUSDS(1e18);
    }

    function test_mintUSDS_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.mintUSDS(1e18);
    }

    function test_mintUSDS() external {
        uint256 Art;
        uint256 rate;

        ( uint256 ink, uint256 art ) = dss.vat.urns(ilk, vault);
        ( Art, rate,,, )             = dss.vat.ilks(ilk);

        assertEq(dss.vat.dai(USDS_JOIN), VAT_DAI_USDS_JOIN);

        assertEq(Art, VAT_ART);
        assertEq(ink, VAT_INK);
        assertEq(art, VAT_ART);

        assertEq(usds.balanceOf(address(almProxy)), 0);
        assertEq(usds.totalSupply(),                USDS_SUPPLY);

        vm.prank(relayer);
        mainnetController.mintUSDS(1e18);

        ( ink, art )     = dss.vat.urns(ilk, vault);
        ( Art, rate,,, ) = dss.vat.ilks(ilk);

        uint256 debt = 1e18 * 1e27 / rate + 1;  // Rounding

        assertEq(dss.vat.dai(USDS_JOIN), VAT_DAI_USDS_JOIN + 1e45);

        assertEq(Art, VAT_ART + debt);
        assertEq(ink, VAT_INK);
        assertEq(art, VAT_ART + debt);

        assertEq(usds.balanceOf(address(almProxy)), 1e18);
        assertEq(usds.totalSupply(),                USDS_SUPPLY + 1e18);
    }

    function test_mintUSDS_rateLimited() external {
        _overwriteDebtCeiling(200_000_000e45);

        bytes32 key = mainnetController.LIMIT_USDS_MINT();
        vm.startPrank(relayer);

        assertEq(rateLimits.getCurrentRateLimit(key), 4_000_000e18);
        assertEq(usds.balanceOf(address(almProxy)),   0);

        mainnetController.mintUSDS(1_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 3_000_000e18);
        assertEq(usds.balanceOf(address(almProxy)),   1_000_000e18);

        skip(4 hours);

        uint256 remainingLimit = 3_000_000e18 + 2_000_000e18 / uint256(24 hours) * 4 hours;

        assertEq(rateLimits.getCurrentRateLimit(key), remainingLimit);
        assertEq(usds.balanceOf(address(almProxy)),   1_000_000e18);

        mainnetController.mintUSDS(remainingLimit);

        assertEq(rateLimits.getCurrentRateLimit(key), 0);
        assertEq(usds.balanceOf(address(almProxy)),   1_000_000e18 + remainingLimit);
        assertEq(usds.balanceOf(address(almProxy)),   4_333_333.3333333333333312e18);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.mintUSDS(1);

        vm.stopPrank();
    }

}

contract MainnetControllerBurnUSDSTests is ForkTestBase {

    function test_burnUSDS_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.burnUSDS(1e18);
    }

    function test_burnUSDS_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.burnUSDS(1e18);
    }

    function test_burnUSDS() external {
        // Setup
        vm.prank(relayer);
        mainnetController.mintUSDS(1e18);

        ( uint256 ink, uint256 art )     = dss.vat.urns(ilk, vault);
        ( uint256 Art, uint256 rate,,, ) = dss.vat.ilks(ilk);

        uint256 debt1 = 1e18 * 1e27 / rate + 1;  // Rounding

        assertEq(dss.vat.dai(USDS_JOIN), VAT_DAI_USDS_JOIN + 1e45);

        assertEq(Art, VAT_ART + debt1);
        assertEq(ink, VAT_INK);
        assertEq(art, VAT_ART + debt1);

        assertEq(usds.balanceOf(address(almProxy)), 1e18);
        assertEq(usds.totalSupply(),                USDS_SUPPLY + 1e18);

        vm.prank(relayer);
        mainnetController.burnUSDS(1e18);

        ( ink, art )     = dss.vat.urns(ilk, vault);
        ( Art, rate,,, ) = dss.vat.ilks(ilk);

        uint256 debt2 = 1e18 * 1e27 / rate;

        assertEq(dss.vat.dai(USDS_JOIN), VAT_DAI_USDS_JOIN);

        assertEq(Art, VAT_ART + debt1 - debt2);
        assertEq(ink, VAT_INK);
        assertEq(art, VAT_ART + debt1 - debt2);

        assertEq(usds.balanceOf(address(almProxy)), 0);
        assertEq(usds.totalSupply(),                USDS_SUPPLY);
    }

    function test_burnUSDS_rateLimited() external {
        _overwriteDebtCeiling(200_000_000e45);

        bytes32 key = mainnetController.LIMIT_USDS_MINT();
        vm.startPrank(relayer);

        assertEq(rateLimits.getCurrentRateLimit(key), 4_000_000e18);
        assertEq(usds.balanceOf(address(almProxy)),   0);

        mainnetController.mintUSDS(1_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 3_000_000e18);
        assertEq(usds.balanceOf(address(almProxy)),   1_000_000e18);

        mainnetController.burnUSDS(500_000e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 3_500_000e18);
        assertEq(usds.balanceOf(address(almProxy)),   500_000e18);

        skip(4 hours);

        assertEq(rateLimits.getCurrentRateLimit(key), 3_500_000e18 + 2_000_000e18 / uint256(24 hours) * 4 hours);
        assertEq(usds.balanceOf(address(almProxy)),   500_000e18);

        mainnetController.burnUSDS(500_000e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 4_000_000e18);
        assertEq(usds.balanceOf(address(almProxy)),   0);

        vm.stopPrank();
    }

}
