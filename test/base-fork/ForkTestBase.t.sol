// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import { IERC20 } from "lib/forge-std/src/interfaces/IERC20.sol";

import { ERC20Mock } from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

import { PSM3Deploy }       from "spark-psm/deploy/PSM3Deploy.sol";
import { IPSM3 }            from "spark-psm/src/PSM3.sol";
import { MockRateProvider } from "spark-psm/test/mocks/MockRateProvider.sol";

import { ALMProxy }     from "src/ALMProxy.sol";
import { L2Controller } from "src/L2Controller.sol";

contract ForkTestBase is Test {

    // TODO: Refactor to use deployment libraries/testnet addresses

    /**********************************************************************************************/
    /*** Constants/state variables                                                              ***/
    /**********************************************************************************************/

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    bytes32 CONTROLLER;
    bytes32 FREEZER;
    bytes32 RELAYER;

    address admin   = makeAddr("admin");
    address freezer = makeAddr("freezer");
    address relayer = makeAddr("relayer");

    /**********************************************************************************************/
    /*** Base addresses                                                                         ***/
    /**********************************************************************************************/

    address USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    /**********************************************************************************************/
    /*** ALM system deployments                                                                 ***/
    /**********************************************************************************************/

    ALMProxy     almProxy;
    L2Controller l2Controller;

    /**********************************************************************************************/
    /*** Casted addresses for testing                                                           ***/
    /**********************************************************************************************/

    IERC20 nstBase;
    IERC20 snstBase;
    IERC20 usdcBase;

    MockRateProvider rateProvider;

    IPSM3 psmBase;

    /**********************************************************************************************/
    /*** Test setup                                                                             ***/
    /**********************************************************************************************/

    function setUp() public virtual {
        vm.createSelectFork(getChain('base').rpcUrl, 18181500);  // August 8, 2024

        nstBase  = IERC20(address(new ERC20Mock()));
        snstBase = IERC20(address(new ERC20Mock()));
        usdcBase = IERC20(USDC_BASE);

        rateProvider = new MockRateProvider();

        rateProvider.__setConversionRate(1.25e27);

        deal(address(nstBase), address(this), 1e18);  // For seeding PSM during deployment

        psmBase = IPSM3(PSM3Deploy.deploy(
            address(nstBase), USDC_BASE, address(snstBase), address(rateProvider)
        ));

        almProxy = new ALMProxy(admin);

        l2Controller = new L2Controller({
            admin_ : admin,
            proxy_ : address(almProxy),
            psm_   : address(psmBase)
        });

        CONTROLLER = almProxy.CONTROLLER();
        FREEZER    = l2Controller.FREEZER();
        RELAYER    = l2Controller.RELAYER();

        vm.startPrank(admin);

        l2Controller.grantRole(FREEZER, freezer);
        l2Controller.grantRole(RELAYER, relayer);

        almProxy.grantRole(CONTROLLER, address(l2Controller));

        vm.stopPrank();
    }

}
