// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "./UnitTestBase.t.sol";

contract L1ControllerDrawTests is UnitTestBase {

    function test_draw_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        l1Controller.draw(1e18);
    }

    function test_draw() external {
        ( uint256 ink, uint256 art ) = vat.urns(ilk, address(vault));
        ( uint256 Art,,,, )          = vat.ilks(ilk);

        assertEq(vat.dai(address(nstJoin)), 0);

        assertEq(Art, 0);
        assertEq(ink, INK);
        assertEq(art, 0);

        assertEq(nst.balanceOf(address(buffer)), 0);
        assertEq(nst.totalSupply(),              0);

        vm.prank(relayer);
        l1Controller.draw(1e18);

        ( ink, art ) = vat.urns(ilk, address(vault));
        ( Art,,,, )  = vat.ilks(ilk);

        assertEq(vat.dai(address(nstJoin)), 1e45);

        assertEq(Art, 1e18);
        assertEq(ink, INK);
        assertEq(art, 1e18);

        assertEq(nst.balanceOf(address(buffer)), 1e18);
        assertEq(nst.totalSupply(),              1e18);
    }

}

contract L1ControllerWipeTests is UnitTestBase {

    function test_wipe_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        l1Controller.wipe(1e18);
    }

    function test_wipe() external {
        // Setup
        vm.prank(relayer);
        l1Controller.draw(1e18);

        ( uint256 ink, uint256 art ) = vat.urns(ilk, address(vault));
        ( uint256 Art,,,, )          = vat.ilks(ilk);

        assertEq(vat.dai(address(nstJoin)), 1e45);

        assertEq(Art, 1e18);
        assertEq(ink, INK);
        assertEq(art, 1e18);

        assertEq(nst.balanceOf(address(buffer)), 1e18);
        assertEq(nst.totalSupply(),              1e18);

        vm.prank(relayer);
        l1Controller.wipe(1e18);

        ( ink, art ) = vat.urns(ilk, address(vault));
        ( Art,,,, )  = vat.ilks(ilk);

        assertEq(vat.dai(address(nstJoin)), 0);

        assertEq(Art, 0);
        assertEq(ink, INK);
        assertEq(art, 0);

        assertEq(nst.balanceOf(address(buffer)), 0);
        assertEq(nst.totalSupply(),              0);
    }

}
