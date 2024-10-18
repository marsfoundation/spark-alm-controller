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

import { AllocatorVault }    from "lib/dss-allocator/src/AllocatorVault.sol";
import { AllocatorBuffer }   from "lib/dss-allocator/src/AllocatorBuffer.sol";
import { AllocatorRegistry } from "lib/dss-allocator/src/AllocatorRegistry.sol";
import { AllocatorRoles }    from "lib/dss-allocator/src/AllocatorRoles.sol";

import { MainnetController } from "src/MainnetController.sol";
import { ForeignController } from "src/ForeignController.sol";
import { ALMProxy }          from "src/ALMProxy.sol";
import { RateLimits }        from "src/RateLimits.sol";

import { PSM3, IERC20 }      from "lib/spark-psm/src/PSM3.sol";
import { IRateProviderLike } from "lib/spark-psm/src/interfaces/IRateProviderLike.sol";

interface IVatLike {
    function can(address, address) external view returns (uint256);
}

contract DeployEthereumTest is Test {

    using stdJson for *;
    using DomainHelpers for *;
    using CCTPBridgeTesting for *;
    using ScriptTools for *;

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    address admin;
    address safeBase;  // Will be the same on all chains
    address safeMainnet;
    address usdsJoin;

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
    IERC20 dai;

    AllocatorVault    vault;
    AllocatorBuffer   buffer;
    AllocatorRegistry registry;
    AllocatorRoles    roles;

    ALMProxy          almProxy;
    MainnetController mainnetController;
    RateLimits        rateLimits;

    // Base contracts
    PSM3 psmBase;

    IERC20 usdsBase;
    IERC20 susdsBase;
    IERC20 usdcBase;

    ALMProxy          foreignAlmProxy;
    ForeignController foreignController;
    RateLimits        foreignRateLimits;

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
        dai   = IERC20(inputMainnet.readAddress(".dai"));

        vault    = AllocatorVault(outputMainnet.readAddress(".allocatorVault"));
        buffer   = AllocatorBuffer(outputMainnet.readAddress(".allocatorBuffer"));
        registry = AllocatorRegistry(outputMainnet.readAddress(".allocatorRegistry"));
        roles    = AllocatorRoles(outputMainnet.readAddress(".allocatorRoles"));

        mainnetController = MainnetController(outputMainnet.readAddress(".controller"));
        almProxy          = ALMProxy(payable(outputMainnet.readAddress(".almProxy")));
        rateLimits        = RateLimits(outputMainnet.readAddress(".rateLimits"));

        usdsJoin = outputMainnet.readAddress(".usdsJoin");

        safeBase = outputBase.readAddress(".safe");
        psmBase  = PSM3(outputBase.readAddress(".psm"));

        usdsBase  = IERC20(outputBase.readAddress(".usds"));
        susdsBase = IERC20(outputBase.readAddress(".sUsds"));
        usdcBase  = IERC20(outputBase.readAddress(".usdc"));

        foreignAlmProxy   = ALMProxy(payable(outputBase.readAddress(".almProxy")));
        foreignController = ForeignController(outputBase.readAddress(".controller"));
        foreignRateLimits = RateLimits(outputBase.readAddress(".rateLimits"));

        mainnet.selectFork();
    }

    function test_mainnetConfiguration() public {
        // Mainnet controller initialization

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

        assertEq(
            mainnetController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
            bytes32(uint256(uint160(outputBase.readAddress(".almProxy"))))
        );

        // ALM system roles

        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, admin),          true);
        assertEq(mainnetController.hasRole(DEFAULT_ADMIN_ROLE, admin), true);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, admin),        true);

        assertEq(mainnetController.hasRole(mainnetController.FREEZER(), makeAddr("freezer")), true);
        assertEq(mainnetController.hasRole(mainnetController.RELAYER(), safeMainnet),         true);

        assertEq(almProxy.hasRole(almProxy.CONTROLLER(), address(mainnetController)), true);

        assertEq(rateLimits.hasRole(rateLimits.CONTROLLER(), address(mainnetController)), true);

        // Allocation system deployment and initialization

        bytes32 ilk = ScriptTools.readInput("common").readString(".ilk").stringToBytes32();

        assertEq(registry.buffers(ilk), address(buffer));
        assertEq(address(vault.jug()),  outputMainnet.readAddress(".jug"));

        assertEq(usds.allowance(address(buffer), address(almProxy)), type(uint256).max);
        assertEq(usds.allowance(address(vault),  usdsJoin),          type(uint256).max);

        assertEq(roles.ilkAdmins(ilk), admin);

        assertEq(buffer.wards(address(admin)),   1);
        assertEq(registry.wards(address(admin)), 1);
        assertEq(roles.wards(address(admin)),    1);
        assertEq(vault.wards(address(admin)),    1);
        assertEq(vault.wards(address(almProxy)), 1);

        address vat = outputMainnet.readAddress(".vat");

        assertEq(address(vault.roles()),    address(roles));
        assertEq(address(vault.buffer()),   address(buffer));
        assertEq(bytes32(vault.ilk()),      ilk);
        assertEq(address(vault.usdsJoin()), usdsJoin);
        assertEq(address(vault.vat()),      vat);

        // NOTE: Not asserting vat.can because vat is mocked in this deployment and storage doesn't
        //       get updated on vat.hope in vault constructor

        // Starting token balances

        assertEq(usds.balanceOf(address(almProxy)),  0);
        assertEq(usdc.balanceOf(address(almProxy)),  0);
        assertEq(susds.balanceOf(address(almProxy)), 0);

        assertEq(
            usds.balanceOf(address(usdsJoin)),
            ScriptTools.readInput("common").readUint(".usdsUnitSize") * 1e18
        );

        // Amount added to PSM wrapper to make `fill` logic work on swaps
        assertEq(
            dai.balanceOf(outputMainnet.readAddress(".psm")),
            ScriptTools.readInput("common").readUint(".usdsUnitSize") * 10 * 1e18
        );

        // TODO: Rate limits
    }

    function test_baseConfiguration() public {
        base.selectFork();

        // PSM configuration

        assertEq(address(psmBase.usdc()),   outputBase.readAddress(".usdc"));
        assertEq(address(psmBase.usds()),   outputBase.readAddress(".usds"));
        assertEq(address(psmBase.susds()),  outputBase.readAddress(".sUsds"));
        assertEq(address(psmBase.pocket()), outputBase.readAddress(".psm"));

        assertEq(psmBase.totalAssets(), 1e18);
        assertEq(psmBase.totalShares(), 1e18);

        assertEq(IRateProviderLike(psmBase.rateProvider()).getConversionRate(), 1.2e27);

        // Foreign controller initialization

        assertEq(address(foreignController.proxy()),      outputBase.readAddress(".almProxy"));
        assertEq(address(foreignController.rateLimits()), outputBase.readAddress(".rateLimits"));
        assertEq(address(foreignController.psm()),        outputBase.readAddress(".psm"));
        assertEq(address(foreignController.usdc()),       outputBase.readAddress(".usdc"));
        assertEq(address(foreignController.cctp()),       inputBase.readAddress(".cctpTokenMessenger"));

        assertEq(foreignController.active(), true);

        assertEq(
            foreignController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM),
            bytes32(uint256(uint160(outputMainnet.readAddress(".almProxy"))))
        );

        // ALM System roles

        assertEq(almProxy.hasRole(DEFAULT_ADMIN_ROLE, admin),          true);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, admin),        true);
        assertEq(foreignController.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(foreignController.hasRole(foreignController.FREEZER(), makeAddr("freezer")), true);
        assertEq(foreignController.hasRole(foreignController.RELAYER(), safeBase),            true);

        assertEq(foreignAlmProxy.hasRole(foreignAlmProxy.CONTROLLER(), address(foreignController)), true);

        assertEq(foreignRateLimits.hasRole(foreignRateLimits.CONTROLLER(), address(foreignController)), true);

        // Starting token balances

        assertEq(
            usdsBase.balanceOf(address(foreignAlmProxy)),
            ScriptTools.readInput("common").readUint(".usdsUnitSize") * 1e18
        );

        assertEq(
            susdsBase.balanceOf(address(foreignAlmProxy)),
            ScriptTools.readInput("common").readUint(".usdsUnitSize") * 1e18
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

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)), 0);

        mainnet.selectFork();

        vm.startPrank(safeMainnet);
        mainnetController.mintUSDS(10e18);
        mainnetController.swapUSDSToUSDC(10e6);
        mainnetController.transferUSDCToCCTP(10e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
        vm.stopPrank();

        cctpBridge.relayMessagesToDestination(true);

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)), 10e6);
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

        vm.startPrank(safeMainnet);
        mainnetController.swapUSDCToUSDS(1e6);
        mainnetController.burnUSDS(1e18);
        vm.stopPrank();
    }

}
