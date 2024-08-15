// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import { ALMProxy }          from "src/ALMProxy.sol";
import { MainnetController } from "src/MainnetController.sol";

import { MockDaiNst } from "test/unit/mocks/MockDaiNst.sol";
import { MockPsm }    from "test/unit/mocks/MockPsm.sol";
import { MockSNst }   from "test/unit/mocks/MockSNst.sol";

contract UnitTestBase is Test {

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    bytes32 constant CONTROLLER = keccak256("CONTROLLER");
    bytes32 constant FREEZER    = keccak256("FREEZER");
    bytes32 constant RELAYER    = keccak256("RELAYER");

    address admin   = makeAddr("admin");
    address freezer = makeAddr("freezer");
    address relayer = makeAddr("relayer");

    MockDaiNst daiNst;
    MockPsm    psm;
    MockSNst   snst;

    ALMProxy          almProxy;
    MainnetController mainnetController;

    function setUp() public virtual {
        psm  = new MockPsm(makeAddr("usdc"));
        snst = new MockSNst(makeAddr("nst"));
        daiNst = new MockDaiNst(makeAddr("dai"));

        almProxy = new ALMProxy(admin);

        mainnetController = new MainnetController(
            admin,
            address(almProxy),
            makeAddr("vault"),
            makeAddr("buffer"),
            address(psm),
            address(daiNst),
            makeAddr("cctp"),
            address(snst)
        );

        // Done with spell by pause proxy
        vm.startPrank(admin);

        mainnetController.grantRole(FREEZER, freezer);
        mainnetController.grantRole(RELAYER, relayer);

        almProxy.grantRole(CONTROLLER, address(mainnetController));

        vm.stopPrank();
    }

}
