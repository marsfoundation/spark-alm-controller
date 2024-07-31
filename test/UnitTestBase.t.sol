// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import { AllocatorBuffer } from "lib/dss-allocator/src/AllocatorBuffer.sol";
import { AllocatorRoles }  from "lib/dss-allocator/src/AllocatorRoles.sol";
import { AllocatorVault }  from "lib/dss-allocator/src/AllocatorVault.sol";

import { Vat } from "lib/dss/src/vat.sol";

import { MockERC20 } from "lib/erc20-helpers/src/MockERC20.sol";

import { NstJoin } from "lib/nst/src/NstJoin.sol";

import { SNst } from "lib/sdai/src/SNst.sol";

import { UpgradeableProxy } from "lib/upgradeable-proxy/src/UpgradeableProxy.sol";

import { L1Controller } from "src/L1Controller.sol";

import { MockJug } from "test/mocks/MockJug.sol";

contract UnitTestBase is Test {

    address admin   = makeAddr("admin");
    address freezer = makeAddr("freezer");
    address relayer = makeAddr("relayer");

    AllocatorBuffer buffer;
    AllocatorRoles  roles;
    AllocatorVault  vault;
    NstJoin         nstJoin;

    MockJug jug;  // Need mock because `now` has been deprecated and won't compile
    Vat     vat;

    MockERC20 nst;
    SNst      sNst;

    L1Controller     l1Controller;
    L1Controller     l1ControllerImplementation;
    UpgradeableProxy l1ControllerProxy;

    address vow = makeAddr("vow");

    bytes32 ilk = "ilk";

    function setUp() public virtual {
        vat = new Vat();
        jug = new MockJug(address(vat));

        nst = new MockERC20("NST", "NST", 18);

        nstJoin = new NstJoin(address(vat), address(nst));

        sNst = new SNst(address(nstJoin), vow);  // No calls made to vow

        buffer = new AllocatorBuffer();
        roles  = new AllocatorRoles();
        vault  = new AllocatorVault(address(roles), address(buffer), ilk, address(nstJoin));

        l1ControllerProxy          = new UpgradeableProxy();
        l1ControllerImplementation = new L1Controller();

        l1ControllerProxy.setImplementation(address(l1ControllerImplementation));

        l1Controller = L1Controller(address(l1ControllerProxy));

        l1Controller.setFreezer(freezer);
        l1Controller.setRelayer(relayer);
        l1Controller.setRoles(address(roles));
        l1Controller.setVault(address(vault));
        l1Controller.setSNst(address(sNst));

        UpgradeableProxy(address(l1Controller)).rely(admin);
        UpgradeableProxy(address(l1Controller)).deny(address(this));

        buffer.approve(address(nst), address(vault), type(uint256).max);

        vat.rely(address(jug));
        vat.rely(address(sNst));
        vat.init(ilk);
        vat.file("Line", 1e9 * 1e45);
        vat.file(ilk, "line", 1e9 * 1e45);  // Use 1 billion lines for testing
        vat.file(ilk, "spot", 1e27);
        vat.slip(ilk, address(vault), int256(1_000_000e18));
        vat.grab(ilk, address(vault), address(vault), address(0), int256(1_000_000e18), 0);

        jug.file("vow",  vow);
        jug.file("base", 1e27);

        vault.rely(address(l1Controller));
        vault.file("jug", address(jug));

        // sNst.initialize();
    }

}
