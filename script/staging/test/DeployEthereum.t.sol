// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { ScriptTools } from "dss-test/ScriptTools.sol";

import { Bridge }                from "xchain-helpers/src/testing/Bridge.sol";
import { Domain, DomainHelpers } from "xchain-helpers/src/testing/Domain.sol";
import { CCTPBridgeTesting }     from "xchain-helpers/src/testing/bridges/CCTPBridgeTesting.sol";
import { CCTPForwarder }         from "xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { Usds }  from "lib/usds/src/Usds.sol";
import { SUsds } from "lib/sdai/src/SUsds.sol";

import { AllocatorVault }  from "lib/dss-allocator/src/AllocatorVault.sol";
import { AllocatorBuffer } from "lib/dss-allocator/src/AllocatorBuffer.sol";

import { MainnetController } from "src/MainnetController.sol";
import { ForeignController } from "src/ForeignController.sol";
import { ALMProxy }          from "src/ALMProxy.sol";
import { RateLimits }        from "src/RateLimits.sol";

import { PSM3, IERC20 } from "lib/spark-psm/src/PSM3.sol";

contract DeployEthereumTest is Test {

    using stdJson for *;
    using DomainHelpers for *;
    using CCTPBridgeTesting for *;

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    address admin;
    address safeBase;  // Will be the same on all chains
    address safeMainnet;

    string inputMainnet;
    string outputMainnet;
    string inputBase;
    string outputBase;

    Domain mainnet;
    Domain base;
    Bridge cctpBridge;

    // Mainnet contracts
    Usds   usds;
    SUsds  susds;
    IERC20 usdc;

    AllocatorVault  allocatorVault;
    AllocatorBuffer allocatorBuffer;

    ALMProxy          almProxy;
    MainnetController mainnetController;
    RateLimits        rateLimits;

    // Base contracts
    PSM3 psmBase;

    IERC20 usdsBase;
    IERC20 susdsBase;
    IERC20 usdcBase;

    ForeignController foreignController;
    ALMProxy almProxyBase;

    function setUp() public {
        vm.setEnv("FOUNDRY_ROOT_CHAINID", "1");

        mainnet = getChain("mainnet").createSelectFork();
        base    = getChain("base").createFork();

        inputMainnet  = ScriptTools.readInput("mainnet");
        outputMainnet = ScriptTools.readOutput("mainnet-release", 20241017);
        inputBase     = ScriptTools.readInput("base");
        outputBase    = ScriptTools.readOutput("base-release", 20241017);

        cctpBridge = CCTPBridgeTesting.createCircleBridge(mainnet, base);

        admin       = outputMainnet.readAddress(".admin");
        safeMainnet = outputMainnet.readAddress(".safe");

        usds  = Usds(outputMainnet.readAddress(".usds"));
        susds = SUsds(outputMainnet.readAddress(".sUsds"));
        usdc  = IERC20(inputMainnet.readAddress(".usdc"));

        allocatorVault  = AllocatorVault(outputMainnet.readAddress(".allocatorVault"));
        allocatorBuffer = AllocatorBuffer(outputMainnet.readAddress(".allocatorBuffer"));

        mainnetController = MainnetController(outputMainnet.readAddress(".controller"));
        almProxy          = ALMProxy(payable(outputMainnet.readAddress(".almProxy")));
        rateLimits        = RateLimits(outputMainnet.readAddress(".rateLimits"));

        safeBase = outputBase.readAddress(".safe");
        psmBase  = PSM3(outputBase.readAddress(".psm"));

        usdsBase  = IERC20(outputBase.readAddress(".usds"));
        susdsBase = IERC20(outputBase.readAddress(".sUsds"));
        usdcBase  = IERC20(outputBase.readAddress(".usdc"));

        foreignController = ForeignController(outputBase.readAddress(".controller"));
        almProxyBase      = ALMProxy(payable(outputBase.readAddress(".almProxy")));

        mainnet.selectFork();
    }

    function test_mainnetConfiguration() public {
        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, admin),          true);
        assertEq(mainnetController.hasRole(DEFAULT_ADMIN_ROLE, admin), true);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, admin),        true);

        assertEq(address(mainnetController.proxy()),      outputMainnet.readAddress(".almProxy"));
        assertEq(address(mainnetController.rateLimits()), outputMainnet.readAddress(".rateLimits"));
        assertEq(address(mainnetController.vault()),      outputMainnet.readAddress(".allocatorVault"));
        assertEq(address(mainnetController.buffer()),     outputMainnet.readAddress(".allocatorBuffer"));
        assertEq(address(mainnetController.psm()),        outputMainnet.readAddress(".psm"));
        assertEq(address(mainnetController.daiUsds()),    outputMainnet.readAddress(".daiUsds"));
        assertEq(address(mainnetController.cctp()),       inputMainnet.readAddress(".cctpTokenMessenger"));
        assertEq(address(mainnetController.susds()),      outputMainnet.readAddress(".sUsds"));  // TODO: Update casing
        assertEq(address(mainnetController.dai()),        outputMainnet.readAddress(".dai"));
        assertEq(address(mainnetController.usdc()),       outputMainnet.readAddress(".usdc"));
        assertEq(address(mainnetController.usds()),       outputMainnet.readAddress(".usds"));

        assertEq(mainnetController.psmTo18ConversionFactor(), 1e12);
        assertEq(mainnetController.active(),                  true);

        assertEq(mainnetController.hasRole(mainnetController.RELAYER(), safeMainnet), true);

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), address(mainnetController)), true);

        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(mainnetController)), true);

        assertEq(
            mainnetController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
            bytes32(uint256(uint160(outputBase.readAddress(".almProxy"))))
        );

        assertEq(allocatorVault.wards(address(almProxy)), 1);

        assertEq(usds.allowance(address(allocatorBuffer), address(almProxy)), type(uint256).max);
    }

    function test_baseConfiguration() public {
        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, SPARK_EXECUTOR),          true);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, SPARK_EXECUTOR),        true);
        assertEq(foreignController.hasRole(DEFAULT_ADMIN_ROLE, SPARK_EXECUTOR), true);

        assertEq(address(foreignController.proxy()),      controllerInst.almProxy);
        assertEq(address(foreignController.rateLimits()), controllerInst.rateLimits);
        assertEq(address(foreignController.psm()),        address(psmBase));
        assertEq(address(foreignController.usdc()),       USDC_BASE);
        assertEq(address(foreignController.cctp()),       CCTP_MESSENGER_BASE);

        assertEq(foreignController.hasRole(foreignController.FREEZER(), freezer), true);
        assertEq(foreignController.hasRole(foreignController.RELAYER(), relayer), true);

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), address(foreignController)), true);

        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(foreignController)), true);

        assertEq(
            foreignController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
            bytes32(uint256(uint160(makeAddr("ethereumAlmProxy"))))
        );
    }

    function test_mintUSDS() public {
        assertEq(usds.balanceOf(address(almProxy)), 0);

        vm.prank(safeMainnet);
        mainnetController.mintUSDS(10e18);

        assertEq(usds.balanceOf(address(almProxy)), 10e18);
    }

    function test_mintAndSwapToUSDC() public {
        assertEq(usdc.balanceOf(address(almProxy)), 0);

        vm.startPrank(safeMainnet);
        mainnetController.mintUSDS(10e18);
        mainnetController.swapUSDSToUSDC(10e6);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(almProxy)), 10e6);
    }

    function test_transferCCTP() public {
        base.selectFork();

        assertEq(usdcBase.balanceOf(address(almProxyBase)), 0);

        mainnet.selectFork();

        vm.startPrank(safeMainnet);
        mainnetController.mintUSDS(10e18);
        mainnetController.swapUSDSToUSDC(10e6);
        mainnetController.transferUSDCToCCTP(10e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
        vm.stopPrank();

        cctpBridge.relayMessagesToDestination(true);

        assertEq(usdcBase.balanceOf(address(almProxyBase)), 10e6);
    }

    function test_transferToPSM() public {
        base.selectFork();

        assertEq(usdcBase.balanceOf(address(psmBase)), 0);

        mainnet.selectFork();

        vm.startPrank(safeMainnet);
        mainnetController.mintUSDS(10e18);
        mainnetController.swapUSDSToUSDC(10e6);
        mainnetController.transferUSDCToCCTP(10e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
        vm.stopPrank();

        cctpBridge.relayMessagesToDestination(true);

        vm.startPrank(safeBase);
        foreignController.depositPSM(address(usdcBase), 10e6);
        vm.stopPrank();

        assertEq(usdcBase.balanceOf(address(psmBase)), 10e6);
    }

    function test_fullRoundTrip() public {
        mainnet.selectFork();

        vm.startPrank(safeMainnet);
        mainnetController.mintUSDS(1e18);
        mainnetController.swapUSDSToUSDC(1e6);
        mainnetController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
        vm.stopPrank();

        cctpBridge.relayMessagesToDestination(true);

        vm.startPrank(safeBase);
        foreignController.depositPSM(address(usdcBase), 1e6);
        foreignController.withdrawPSM(address(usdcBase), 1e6);
        foreignController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);
        vm.stopPrank();

        // There is a bug when the messenger addresses are the same
        // Need to force update to skip the previous relayed message
        // See: https://github.com/marsfoundation/xchain-helpers/issues/24
        cctpBridge.lastDestinationLogIndex = cctpBridge.lastSourceLogIndex;
        cctpBridge.relayMessagesToSource(true);

        // NOTE: This is a HACK to make sure that `fill` doesn't get called until the call reverts.
        //       Because this PSM contract is a wrapper over the real PSM, the controller queries
        //       the DAI balance of the PSM to check if it should fill or not. Filling with DAI
        //       fills the live PSM NOT the wrapper, so the while loop will continue until the
        //       function reverts. Dealing DAI into the wrapper will prevent fill from being called.
        address psm = outputMainnet.readAddress(".psm");
        address dai = inputMainnet.readAddress(".dai");
        deal(address(dai), psm, 100e18);

        vm.startPrank(safeMainnet);
        mainnetController.swapUSDCToUSDS(1e6);
        mainnetController.burnUSDS(1e18);
        vm.stopPrank();
    }

}
