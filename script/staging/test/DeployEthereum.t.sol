// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { ScriptTools } from "dss-test/ScriptTools.sol";

import { Bridge }                from "xchain-helpers/src/testing/Bridge.sol";
import { Domain, DomainHelpers } from "xchain-helpers/src/testing/Domain.sol";
import { CCTPBridgeTesting }     from "xchain-helpers/src/testing/bridges/CCTPBridgeTesting.sol";
import { CCTPForwarder }         from "xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { Usds }  from "usds/src/Usds.sol";
import { SUsds } from "sdai/src/SUsds.sol";

import { AllocatorVault }    from "dss-allocator/src/AllocatorVault.sol";
import { AllocatorBuffer }   from "dss-allocator/src/AllocatorBuffer.sol";
import { AllocatorRegistry } from "dss-allocator/src/AllocatorRegistry.sol";
import { AllocatorRoles }    from "dss-allocator/src/AllocatorRoles.sol";

import { IRateLimits } from "../../../src/interfaces/IRateLimits.sol";

import { ALMProxy }          from "../../../src/ALMProxy.sol";
import { ForeignController } from "../../../src/ForeignController.sol";
import { MainnetController } from "../../../src/MainnetController.sol";
import { RateLimits }        from "../../../src/RateLimits.sol";
import { RateLimitHelpers }  from "../../../src/RateLimitHelpers.sol";

import { PSM3, IERC20 }      from "spark-psm/src/PSM3.sol";
import { IRateProviderLike } from "spark-psm/src/interfaces/IRateProviderLike.sol";

interface IVatLike {
    function can(address, address) external view returns (uint256);
}

contract DeployEthereumTest is Test {

    using stdJson           for *;
    using DomainHelpers     for *;
    using CCTPBridgeTesting for *;
    using ScriptTools       for *;

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    // Common variables
    address admin;

    // Configuration data
    string inputMainnet;
    string outputMainnet;
    string inputBase;
    string outputBase;

    // Bridging
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

    address safeMainnet;
    address usdsJoin;

    ALMProxy          almProxy;
    MainnetController mainnetController;
    RateLimits        rateLimits;

    // Base contracts

    address safeBase;

    PSM3 psmBase;

    IERC20 usdsBase;
    IERC20 susdsBase;
    IERC20 usdcBase;

    ALMProxy          foreignAlmProxy;
    ForeignController foreignController;
    RateLimits        foreignRateLimits;

    /**********************************************************************************************/
    /**** Setup                                                                                 ***/
    /**********************************************************************************************/

    function setUp() public {
        vm.setEnv("FOUNDRY_ROOT_CHAINID", "1");

        // Domains and bridge
        mainnet    = getChain("mainnet").createSelectFork();
        base       = getChain("base").createFork();
        cctpBridge = CCTPBridgeTesting.createCircleBridge(mainnet, base);

        // JSON data
        inputMainnet  = ScriptTools.readInput("mainnet");
        outputMainnet = ScriptTools.readOutput("mainnet-release", 20241022);
        inputBase     = ScriptTools.readInput("base");
        outputBase    = ScriptTools.readOutput("base-release", 20241022);

        // Roles
        admin       = outputMainnet.readAddress(".admin");
        safeMainnet = outputMainnet.readAddress(".safe");

        // Tokens
        usds  = Usds(outputMainnet.readAddress(".usds"));
        susds = SUsds(outputMainnet.readAddress(".susds"));
        usdc  = IERC20(inputMainnet.readAddress(".usdc"));
        dai   = IERC20(inputMainnet.readAddress(".dai"));

        // Allocation system and MCD
        buffer   = AllocatorBuffer(outputMainnet.readAddress(".allocatorBuffer"));
        registry = AllocatorRegistry(outputMainnet.readAddress(".allocatorRegistry"));
        roles    = AllocatorRoles(outputMainnet.readAddress(".allocatorRoles"));
        vault    = AllocatorVault(outputMainnet.readAddress(".allocatorVault"));
        usdsJoin = outputMainnet.readAddress(".usdsJoin");

        // ALM system
        almProxy          = ALMProxy(payable(outputMainnet.readAddress(".almProxy")));
        mainnetController = MainnetController(outputMainnet.readAddress(".controller"));
        rateLimits        = RateLimits(outputMainnet.readAddress(".rateLimits"));

        // Base roles
        safeBase = outputBase.readAddress(".safe");

        // Base tokens
        usdsBase  = IERC20(outputBase.readAddress(".usds"));
        susdsBase = IERC20(outputBase.readAddress(".susds"));
        usdcBase  = IERC20(outputBase.readAddress(".usdc"));

        // Base ALM system
        foreignAlmProxy   = ALMProxy(payable(outputBase.readAddress(".almProxy")));
        foreignController = ForeignController(outputBase.readAddress(".controller"));
        foreignRateLimits = RateLimits(outputBase.readAddress(".rateLimits"));

        // Base PSM
        psmBase = PSM3(outputBase.readAddress(".psm"));

        mainnet.selectFork();

        deal(address(usds), address(usdsJoin), 1000e18);  // Ensure there is enough balance
    }

    /**********************************************************************************************/
    /**** Tests                                                                                 ***/
    /**********************************************************************************************/

    function skip_test_mainnetConfiguration() public {
        mainnet.selectFork();

        // Mainnet controller initialization

        assertEq(address(mainnetController.proxy()),      outputMainnet.readAddress(".almProxy"));
        assertEq(address(mainnetController.rateLimits()), outputMainnet.readAddress(".rateLimits"));
        assertEq(address(mainnetController.vault()),      outputMainnet.readAddress(".allocatorVault"));
        assertEq(address(mainnetController.buffer()),     outputMainnet.readAddress(".allocatorBuffer"));
        assertEq(address(mainnetController.psm()),        outputMainnet.readAddress(".psm"));
        assertEq(address(mainnetController.daiUsds()),    outputMainnet.readAddress(".daiUsds"));
        assertEq(address(mainnetController.cctp()),       inputMainnet.readAddress(".cctpTokenMessenger"));
        assertEq(address(mainnetController.susds()),      outputMainnet.readAddress(".susds"));
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

        uint256 usdsUnitSize = ScriptTools.readInput("common").readUint(".usdsUnitSize");
        uint256 usdcUnitSize = ScriptTools.readInput("common").readUint(".usdcUnitSize");

        // USDS added to join, amount added to PSM wrapper to make `fill` logic work on swaps
        assertEq(usds.balanceOf(address(usdsJoin)),                usdsUnitSize * 1e18);
        assertEq(dai.balanceOf(outputMainnet.readAddress(".psm")), usdsUnitSize * 1e18);

        // Rate limits

        uint256 max6    = usdcUnitSize * 1e6  * 5;
        uint256 max18   = usdcUnitSize * 1e18 * 5;
        uint256 slope6  = usdcUnitSize * 1e6  / 4 hours;
        uint256 slope18 = usdcUnitSize * 1e18 / 4 hours;

        bytes32 domainKeyBase = RateLimitHelpers.makeDomainKey(
            mainnetController.LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE
        );

        _assertRateLimitData(mainnetController.LIMIT_USDS_MINT(),    max18, slope18);
        _assertRateLimitData(mainnetController.LIMIT_USDS_TO_USDC(), max6,  slope6);
        _assertRateLimitData(domainKeyBase,                          max6,  slope6);

        _assertRateLimitData(mainnetController.LIMIT_USDC_TO_CCTP(), type(uint256).max, 0);
    }

    function skip_test_baseConfiguration() public {
        base.selectFork();

        // PSM configuration

        assertEq(address(psmBase.usdc()),   outputBase.readAddress(".usdc"));
        assertEq(address(psmBase.usds()),   outputBase.readAddress(".usds"));
        assertEq(address(psmBase.susds()),  outputBase.readAddress(".susds"));
        assertEq(address(psmBase.pocket()), outputBase.readAddress(".psm"));

        assertGe(psmBase.totalAssets(), 1e18);
        assertGe(psmBase.totalShares(), 1e18);

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

        assertEq(foreignAlmProxy.hasRole(DEFAULT_ADMIN_ROLE, admin),   true);
        assertEq(foreignRateLimits.hasRole(DEFAULT_ADMIN_ROLE, admin), true);
        assertEq(foreignController.hasRole(DEFAULT_ADMIN_ROLE, admin), true);

        assertEq(foreignController.hasRole(foreignController.FREEZER(), makeAddr("freezer")), true);
        assertEq(foreignController.hasRole(foreignController.RELAYER(), safeBase),            true);

        assertEq(foreignAlmProxy.hasRole(foreignAlmProxy.CONTROLLER(), address(foreignController)), true);

        assertEq(foreignRateLimits.hasRole(foreignRateLimits.CONTROLLER(), address(foreignController)), true);

        // Starting token balances

        uint256 usdsUnitSize = ScriptTools.readInput("common").readUint(".usdsUnitSize");
        uint256 usdcUnitSize = ScriptTools.readInput("common").readUint(".usdcUnitSize");

        assertEq(usdsBase.balanceOf(address(foreignAlmProxy)),  usdsUnitSize * 1e18);
        assertEq(susdsBase.balanceOf(address(foreignAlmProxy)), usdsUnitSize * 1e18);

        // Rate limits

        uint256 max6    = usdcUnitSize * 1e6  * 5;
        uint256 max18   = usdcUnitSize * 1e18 * 5;
        uint256 slope6  = usdcUnitSize * 1e6  / 4 hours;
        uint256 slope18 = usdcUnitSize * 1e18 / 4 hours;

        bytes32 domainKeyEthereum = RateLimitHelpers.makeDomainKey(
            foreignController.LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM
        );

        bytes32 cctpKey = foreignController.LIMIT_USDC_TO_CCTP();

        _assertDepositRateLimitData(usdcBase,  max6,  slope6);
        _assertDepositRateLimitData(usdsBase,  max18, slope18);
        _assertDepositRateLimitData(susdsBase, max18, slope18);

        _assertWithdrawRateLimitData(usdcBase,  max6,  slope6);
        _assertWithdrawRateLimitData(usdsBase,  max18, slope18);
        _assertWithdrawRateLimitData(susdsBase, max18, slope18);

        _assertRateLimitData(address(foreignRateLimits), cctpKey, type(uint256).max, 0);

        _assertRateLimitData(address(foreignRateLimits), domainKeyEthereum, max6, slope6);
    }

    function skip_test_mintUSDS() public {
        uint256 startingBalance = usds.balanceOf(address(almProxy));

        vm.prank(safeMainnet);
        mainnetController.mintUSDS(10e18);

        assertEq(usds.balanceOf(address(almProxy)), startingBalance + 10e18);
    }

    function skip_test_mintAndSwapToUSDC() public {
        uint256 startingBalance = usdc.balanceOf(address(almProxy));

        vm.startPrank(safeMainnet);
        mainnetController.mintUSDS(10e18);
        mainnetController.swapUSDSToUSDC(10e6);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(almProxy)), startingBalance + 10e6);
    }

    function skip_test_transferCCTP() public {
        base.selectFork();

        uint256 startingBalance = usdcBase.balanceOf(address(foreignAlmProxy));

        mainnet.selectFork();

        vm.startPrank(safeMainnet);
        mainnetController.mintUSDS(10e18);
        mainnetController.swapUSDSToUSDC(10e6);
        mainnetController.transferUSDCToCCTP(10e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
        vm.stopPrank();

        cctpBridge.relayMessagesToDestination(true);

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)), startingBalance + 10e6);
    }

    function skip_test_transferToPSM() public {
        base.selectFork();

        uint256 startingBalance = usdcBase.balanceOf(address(psmBase));

        mainnet.selectFork();

        vm.startPrank(safeMainnet);
        mainnetController.mintUSDS(10e18);
        mainnetController.swapUSDSToUSDC(10e6);
        mainnetController.transferUSDCToCCTP(10e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
        vm.stopPrank();

        cctpBridge.relayMessagesToDestination(true);

        uint256 startingShares = psmBase.shares(address(foreignAlmProxy));

        vm.startPrank(safeBase);
        foreignController.depositPSM(address(usdcBase), 10e6);
        vm.stopPrank();

        assertEq(usdcBase.balanceOf(address(psmBase)), startingBalance + 10e6);

        assertEq(psmBase.shares(address(foreignAlmProxy)), startingShares + 10e18);
    }

    function skip_test_fullRoundTrip() public {
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

    /**********************************************************************************************/
    /**** Helper functions                                                                      ***/
    /**********************************************************************************************/

    function _assertDepositRateLimitData(IERC20 asset, uint256 maxAmount, uint256 slope)
        internal view
    {
        bytes32 assetKey = RateLimitHelpers.makeAssetKey(
            foreignController.LIMIT_PSM_DEPOSIT(),
            address(asset)
        );

        _assertRateLimitData(address(foreignRateLimits), assetKey, maxAmount, slope);
    }

    function _assertWithdrawRateLimitData(IERC20 asset, uint256 maxAmount, uint256 slope)
        internal view
    {
        bytes32 assetKey = RateLimitHelpers.makeAssetKey(
            foreignController.LIMIT_PSM_WITHDRAW(),
            address(asset)
        );

        _assertRateLimitData(address(foreignRateLimits), assetKey, maxAmount, slope);
    }

    function _assertRateLimitData(bytes32 domainKey, uint256 maxAmount, uint256 slope)
        internal view
    {
        // If no rate limits address specified default to mainnet
        _assertRateLimitData(address(rateLimits), domainKey, maxAmount, slope);
    }

    function _assertRateLimitData(address rateLimits_, bytes32 key, uint256 maxAmount, uint256 slope)
        internal view
    {
        IRateLimits.RateLimitData memory data = IRateLimits(rateLimits_).getRateLimitData(key);

        assertEq(data.maxAmount,  maxAmount);
        assertEq(data.slope,      slope);
        assertEq(data.lastAmount, maxAmount);

        // Deployments are done in the past
        assertLe(data.lastUpdated, block.timestamp);

        // Deployment is assumed to be untouched
        assertEq(IRateLimits(rateLimits_).getCurrentRateLimit(key), maxAmount);
    }

}
