// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

import { AllocatorBuffer } from "lib/dss-allocator/src/AllocatorBuffer.sol";
import { AllocatorRoles }  from "lib/dss-allocator/src/AllocatorRoles.sol";
import { AllocatorVault }  from "lib/dss-allocator/src/AllocatorVault.sol";

import { VatMock } from "lib/dss-allocator/test/mocks/VatMock.sol";

import { NstJoin } from "lib/nst/src/NstJoin.sol";

import "./UnitTestBase.t.sol";

contract L1ControllerACLTests is UnitTestBase {

    AllocatorBuffer buffer;
    AllocatorRoles  roles;
    AllocatorVault  vault;
    NstJoin         nstJoin;

    VatMock vat;


    bytes32 ilk = "ilk";

    function setUp() public override {
        super.setUp();

        buffer = new AllocatorBuffer();
        roles  = new AllocatorRoles();
        vault  = new AllocatorVault(address(roles), address(buffer));

    }
}
