// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { AccessControl } from "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract ALMProxy is AccessControl {

    /**********************************************************************************************/
    /*** State variables                                                                        ***/
    /**********************************************************************************************/

    bytes32 public constant FREEZER    = keccak256("FREEZER");
    bytes32 public constant CONTROLLER = keccak256("CONTROLLER");

    bool public active;

    /**********************************************************************************************/
    /*** Initialization                                                                         ***/
    /**********************************************************************************************/

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);

        active = true;
    }

    /**********************************************************************************************/
    /*** Modifiers                                                                              ***/
    /**********************************************************************************************/

    modifier isActive {
        require(active, "L1Controller/not-active");
        _;
    }

    /**********************************************************************************************/
    /*** Freezer functions                                                                      ***/
    /**********************************************************************************************/

    function freeze() external onlyRole(FREEZER) {
        active = false;
    }

    function reactivate() external onlyRole(DEFAULT_ADMIN_ROLE) {
        active = true;
    }

    /**********************************************************************************************/
    /*** Call functions                                                                      ***/
    /**********************************************************************************************/

    function doCall(address target, bytes memory data)
        external payable onlyRole(CONTROLLER) isActive
    {
        ( bool success, bytes memory result ) = target.call(data);
        require(success, string(result));
    }

    function doDelegateCall(address target, bytes memory data)
        external payable onlyRole(CONTROLLER) isActive
    {
        ( bool success, bytes memory result ) = target.call(data);
        require(success, string(result));
    }

}
