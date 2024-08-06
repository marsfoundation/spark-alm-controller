// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "./UnitTestBase.t.sol";

contract L1ControllerDepositNstToSNstFailureTests is UnitTestBase {

    function test_depositNstToSNst_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        l1Controller.depositNstToSNst(1e18);
    }

    function test_draw_frozen() external {
        vm.prank(freezer);
        l1Controller.freeze();

        vm.prank(relayer);
        vm.expectRevert("L1Controller/not-active");
        l1Controller.depositNstToSNst(1e18);
    }

}

contract L1ControllerDepositNstToSNstTests is UnitTestBase {

    function test_depositNstToSNst() external {
        vm.prank(relayer);
        l1Controller.draw(1e18);

        assertEq(nst.balanceOf(address(buffer)),       1e18);
        assertEq(nst.balanceOf(address(l1Controller)), 0);
        assertEq(nst.balanceOf(address(sNst)),         0);

        assertEq(nst.allowance(address(buffer),       address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(l1Controller), address(sNst)),  0);

        assertEq(sNst.totalSupply(),              0);
        assertEq(sNst.totalAssets(),              0);
        assertEq(sNst.balanceOf(address(buffer)), 0);

        vm.prank(relayer);
        l1Controller.depositNstToSNst(1e18);

        assertEq(nst.balanceOf(address(buffer)),       0);
        assertEq(nst.balanceOf(address(l1Controller)), 0);
        assertEq(nst.balanceOf(address(sNst)),         1e18);

        assertEq(nst.allowance(address(buffer),       address(vault)), type(uint256).max);
        assertEq(nst.allowance(address(l1Controller), address(sNst)),  0);

        // NOTE: 1:1 exchange rate
        assertEq(sNst.totalSupply(),              1e18);
        assertEq(sNst.totalAssets(),              1e18);
        assertEq(sNst.balanceOf(address(buffer)), 1e18);
    }

}

