// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import { AllocatorBuffer } from "lib/dss-allocator/src/AllocatorBuffer.sol";
import { AllocatorRoles }  from "lib/dss-allocator/src/AllocatorRoles.sol";
import { AllocatorVault }  from "lib/dss-allocator/src/AllocatorVault.sol";

import { Vat } from "lib/dss/src/vat.sol";

import { DssLitePsm } from "lib/dss-lite-psm/src/DssLitePsm.sol";

import { MockERC20 } from "lib/erc20-helpers/src/MockERC20.sol";

import { NstJoin } from "lib/nst/src/NstJoin.sol";

import { ERC1967Proxy } from "lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { SNst } from "lib/sdai/src/SNst.sol";

import { ALMProxy }           from "src/ALMProxy.sol";
import { EthereumController } from "src/EthereumController.sol";

import { MockJug }    from "test/mocks/MockJug.sol";
import { MockPocket } from "test/mocks/MockPocket.sol";

contract UnitTestBase is Test {

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    bytes32 constant CONTROLLER = keccak256("CONTROLLER");
    bytes32 constant FREEZER    = keccak256("FREEZER");
    bytes32 constant RELAYER    = keccak256("RELAYER");

    uint256 constant INK = 1e12 * 1e18;  // 1 trillion

    address admin   = makeAddr("admin");
    address freezer = makeAddr("freezer");
    address relayer = makeAddr("relayer");

    AllocatorBuffer buffer;
    AllocatorRoles  roles;
    AllocatorVault  vault;
    NstJoin         nstJoin;

    MockPocket pocket;
    DssLitePsm psm;

    MockJug jug;  // Need mock because `now` has been deprecated and won't compile
    Vat     vat;

    MockERC20 nst;
    MockERC20 usdc;
    SNst      snst;

    ALMProxy           almProxy;
    EthereumController ethereumController;

    address vow = makeAddr("vow");

    bytes32 ilk = "ilk";

    function setUp() public virtual {
        vat = new Vat();
        jug = new MockJug(address(vat));

        nst  = new MockERC20("NST", "NST", 18);
        usdc = new MockERC20("GEM", "GEM", 6);

        nstJoin = new NstJoin(address(vat), address(nst));

        address snstImpl = address(new SNst(address(nstJoin), vow));  // No calls made to vow

        snst = SNst(address(new ERC1967Proxy(snstImpl, abi.encodeCall(SNst.initialize, ()))));

        buffer = new AllocatorBuffer();
        roles  = new AllocatorRoles();
        vault  = new AllocatorVault(address(roles), address(buffer), ilk, address(nstJoin));

        pocket = new MockPocket();
        psm    = new DssLitePsm("lite-psm", address(usdc), address(nstJoin), address(pocket));

        almProxy = new ALMProxy(admin);

        ethereumController = new EthereumController(
            admin,
            address(almProxy),
            address(vault),
            address(buffer),
            address(snst),
            address(psm)
        );

        deal(address(usdc), address(pocket), 100e6);  // Gem is held in pocket
        deal(address(nst),  address(psm),    100e18);

        pocket.approve(address(usdc), address(psm));

        buffer.approve(address(nst), address(almProxy), type(uint256).max);

        // TODO: Use initialization library for this
        psm.kiss(address(almProxy));  // Allow using no fee functionality

        // Done with spell by pause proxy
        vm.startPrank(admin);

        ethereumController.grantRole(FREEZER, freezer);
        ethereumController.grantRole(RELAYER, relayer);

        almProxy.grantRole(FREEZER,    freezer);
        almProxy.grantRole(CONTROLLER, address(ethereumController));

        vm.stopPrank();

        buffer.approve(address(nst), address(vault), type(uint256).max);

        vat.rely(address(jug));
        vat.rely(address(snst));
        vat.init(ilk);
        vat.file("Line", 1e9 * 1e45);
        vat.file(ilk, "line", 1e9 * 1e45);  // Use 1 billion lines for testing
        vat.file(ilk, "spot", 1e27);

        // Initialize the vault in the same way as the real system, with 1 trillion in ink
        vat.slip(ilk, address(vault), int256(INK));
        vat.grab(ilk, address(vault), address(vault), address(0), int256(INK), 0);

        jug.file("vow",  vow);
        jug.file("base", 1e27);

        vault.rely(address(almProxy));
        vault.file("jug", address(jug));
    }

}
