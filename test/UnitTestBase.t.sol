// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import { AllocatorBuffer } from "lib/dss-allocator/src/AllocatorBuffer.sol";
import { AllocatorRoles }  from "lib/dss-allocator/src/AllocatorRoles.sol";
import { AllocatorVault }  from "lib/dss-allocator/src/AllocatorVault.sol";

import { JugMock, VatMock } from "lib/dss-allocator/test/mocks/JugMock.sol";

import { MockERC20 } from "lib/erc20-helpers/src/MockERC20.sol";

import { NstJoin } from "lib/nst/src/NstJoin.sol";

import { L1Controller } from "src/L1Controller.sol";

contract UnitTestBase is Test {

    address admin   = makeAddr("admin");
    address freezer = makeAddr("freezer");
    address relayer = makeAddr("relayer");

    AllocatorBuffer buffer;
    AllocatorRoles  roles;
    AllocatorVault  vault;
    NstJoin         nstJoin;

    JugMock jug;
    VatMock vat;

    MockERC20 nst;
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    bytes32 public constant FREEZER = keccak256("FREEZER");
    bytes32 public constant RELAYER = keccak256("RELAYER");

    L1Controller l1Controller;

    bytes32 ilk = "ilk";

    function setUp() public virtual {
        vat = new VatMock();
        jug = new JugMock(vat);

        nst = new MockERC20("NST", "NST", 18);

        nstJoin = new NstJoin(address(vat), address(nst));

        buffer = new AllocatorBuffer();
        roles  = new AllocatorRoles();
        vault  = new AllocatorVault(address(roles), address(buffer), ilk, address(nstJoin));

        buffer.approve(address(nst), address(vault), type(uint256).max);

        l1Controller = new L1Controller();
        l1Controller.setVault(address(vault));
        l1Controller.grantRole(DEFAULT_ADMIN_ROLE, admin);
        l1Controller.grantRole(FREEZER, freezer);
        l1Controller.grantRole(RELAYER, relayer);

        vault.rely(address(l1Controller));
        vault.file("jug", address(jug));
    }

}
