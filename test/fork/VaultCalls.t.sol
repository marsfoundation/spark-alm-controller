// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "test/fork/ForkTestBase.t.sol";

contract EthereumControllerMintNSTTests is ForkTestBase {

    function test_mintNST_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        ethereumController.mintNST(1e18);
    }

    function test_mintNST_frozen() external {
        vm.prank(freezer);
        ethereumController.freeze();

        vm.prank(relayer);
        vm.expectRevert("EthereumController/not-active");
        ethereumController.mintNST(1e18);
    }

    function test_mintNST() external {
        ( uint256 ink, uint256 art ) = dss.vat.urns(ilk, vault);
        ( uint256 Art,,,, )          = dss.vat.ilks(ilk);

        assertEq(dss.vat.dai(nstJoin), 0);

        assertEq(Art, 0);
        assertEq(ink, INK);
        assertEq(art, 0);

        assertEq(nst.balanceOf(address(almProxy)), 0);
        assertEq(nst.totalSupply(),                0);

        vm.prank(relayer);
        ethereumController.mintNST(1e18);

        ( ink, art ) = dss.vat.urns(ilk, vault);
        ( Art,,,, )  = dss.vat.ilks(ilk);

        assertEq(dss.vat.dai(nstJoin), 1e45);

        assertEq(Art, 1e18);
        assertEq(ink, INK);
        assertEq(art, 1e18);

        assertEq(nst.balanceOf(address(almProxy)), 1e18);
        assertEq(nst.totalSupply(),                1e18);
    }

}

contract EthereumControllerBurnNSTTests is ForkTestBase {

    function test_burnNST_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        ethereumController.burnNST(1e18);
    }

    function test_burnNST_frozen() external {
        vm.prank(freezer);
        ethereumController.freeze();

        vm.prank(relayer);
        vm.expectRevert("EthereumController/not-active");
        ethereumController.burnNST(1e18);
    }

    function test_burnNST() external {
        // Setup
        vm.prank(relayer);
        ethereumController.mintNST(1e18);

        ( uint256 ink, uint256 art ) = dss.vat.urns(ilk, vault);
        ( uint256 Art,,,, )          = dss.vat.ilks(ilk);

        assertEq(dss.vat.dai(address(nstJoin)), 1e45);

        assertEq(Art, 1e18);
        assertEq(ink, INK);
        assertEq(art, 1e18);

        assertEq(nst.balanceOf(address(almProxy)), 1e18);
        assertEq(nst.totalSupply(),                1e18);

        vm.prank(relayer);
        ethereumController.burnNST(1e18);

        ( ink, art ) = dss.vat.urns(ilk, vault);
        ( Art,,,, )  = dss.vat.ilks(ilk);

        assertEq(dss.vat.dai(address(nstJoin)), 0);

        assertEq(Art, 0);
        assertEq(ink, INK);
        assertEq(art, 0);

        assertEq(nst.balanceOf(address(almProxy)), 0);
        assertEq(nst.totalSupply(),                0);
    }

}
