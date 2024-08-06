// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./UnitTestBase.t.sol";

contract L1ControllerMintSNstTests is UnitTestBase {

    function test_depositNstToSNst() external {
        vm.prank(relayer);
        l1Controller.draw(1e18);

        assertEq(nst.balanceOf(address(buffer)), 1e18);
        assertEq(nst.balanceOf(address(sNst)),   0);

        assertEq(sNst.totalSupply(),              0);
        assertEq(sNst.totalAssets(),              0);
        assertEq(sNst.balanceOf(address(buffer)), 0);

        vm.prank(relayer);
        l1Controller.depositNstToSNst(1e18);
    }
}

