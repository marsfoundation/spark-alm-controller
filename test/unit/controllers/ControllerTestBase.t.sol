// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import { UnitTestBase } from "test/unit/UnitTestBase.t.sol";

interface IBaseControllerLike {
    function active() external view returns (bool);
    function grantRole(bytes32 role, address account) external;
    function freeze() external;
    function reactivate() external;
}

contract ControllerTestBase is UnitTestBase {

    IBaseControllerLike controller;

    function _setRoles() internal {
        // Done with spell by pause proxy
        vm.startPrank(admin);

        controller.grantRole(FREEZER, freezer);
        controller.grantRole(RELAYER, relayer);

        vm.stopPrank();
    }

}
