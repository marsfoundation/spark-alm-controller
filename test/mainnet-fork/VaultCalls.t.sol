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
        ( uint256 ink, uint256 art ) = dss.vat.urns(ilk, vault);
        ( uint256 Art,,,, )          = dss.vat.ilks(ilk);

        assertEq(dss.vat.dai(usdsJoin), 0);

        assertEq(Art, 0);
        assertEq(ink, INK);
        assertEq(art, 0);

        assertEq(usds.balanceOf(address(almProxy)), 0);
        assertEq(usds.totalSupply(),                0);

        vm.prank(relayer);
        mainnetController.mintUSDS(1e18);

        ( ink, art ) = dss.vat.urns(ilk, vault);
        ( Art,,,, )  = dss.vat.ilks(ilk);

        assertEq(dss.vat.dai(usdsJoin), 1e45);

        assertEq(Art, 1e18);
        assertEq(ink, INK);
        assertEq(art, 1e18);

        assertEq(usds.balanceOf(address(almProxy)), 1e18);
        assertEq(usds.totalSupply(),                1e18);
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

        ( uint256 ink, uint256 art ) = dss.vat.urns(ilk, vault);
        ( uint256 Art,,,, )          = dss.vat.ilks(ilk);

        assertEq(dss.vat.dai(address(usdsJoin)), 1e45);

        assertEq(Art, 1e18);
        assertEq(ink, INK);
        assertEq(art, 1e18);

        assertEq(usds.balanceOf(address(almProxy)), 1e18);
        assertEq(usds.totalSupply(),                1e18);

        vm.prank(relayer);
        mainnetController.burnUSDS(1e18);

        ( ink, art ) = dss.vat.urns(ilk, vault);
        ( Art,,,, )  = dss.vat.ilks(ilk);

        assertEq(dss.vat.dai(address(usdsJoin)), 0);

        assertEq(Art, 0);
        assertEq(ink, INK);
        assertEq(art, 0);

        assertEq(usds.balanceOf(address(almProxy)), 0);
        assertEq(usds.totalSupply(),                0);
    }

}
