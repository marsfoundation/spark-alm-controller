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

contract DeploySepoliaTest is Test {

    using stdJson for *;
    using DomainHelpers for *;
    using CCTPBridgeTesting for *;

    address CCTP_TOKEN_MESSENGER_MAINNET = 0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5;
    address CCTP_MESSENGER_MAINNET       = 0x7865fAfC2db2093669d92c0F33AeEF291086BEFD;
    address CCTP_MESSENGER_BASE          = 0x7865fAfC2db2093669d92c0F33AeEF291086BEFD;
    address USDC                         = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    address admin;
    address safe;  // Will be the same on all chains

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

    AllocatorVault allocatorVault;
    AllocatorBuffer allocatorBuffer;

    MainnetController mainnetController;
    ALMProxy almProxy;
    RateLimits rateLimits;

    // Base contracts
    PSM3 psm;

    IERC20 usdsBase;
    IERC20 susdsBase;
    IERC20 usdcBase;

    ForeignController foreignController;
    ALMProxy almProxyBase;

    function setUp() public {
        vm.setEnv("FOUNDRY_ROOT_CHAINID", "11155111");

        setChain("sepolia_base", ChainData({
            rpcUrl: "https://base-sepolia-rpc.publicnode.com",
            chainId: 84532,
            name: "Sepolia Base Testnet"
        }));

        mainnet    = getChain("sepolia").createSelectFork();
        base       = getChain("sepolia_base").createFork();
        cctpBridge = CCTPBridgeTesting.init(Bridge({
            source:                         mainnet,
            destination:                    base,
            sourceCrossChainMessenger:      CCTP_MESSENGER_MAINNET,
            destinationCrossChainMessenger: CCTP_MESSENGER_BASE,
            lastSourceLogIndex:             0,
            lastDestinationLogIndex:        0,
            extraData:                      ""
        }));

        outputMainnet = ScriptTools.readOutput("mainnet-release", 20241005);
        inputBase = ScriptTools.readInput("base");
        outputBase = ScriptTools.readOutput("base-release", 20241005);

        admin = outputMainnet.readAddress(".admin");
        safe  = outputMainnet.readAddress(".safe");

        usds  = Usds(outputMainnet.readAddress(".usds"));
        susds = SUsds(outputMainnet.readAddress(".sUsds"));
        usdc  = IERC20(USDC);

        allocatorVault = AllocatorVault(outputMainnet.readAddress(".allocatorVault"));
        allocatorBuffer = AllocatorBuffer(outputMainnet.readAddress(".allocatorBuffer"));

        mainnetController = MainnetController(outputMainnet.readAddress(".controller"));
        almProxy          = ALMProxy(payable(outputMainnet.readAddress(".almProxy")));
        rateLimits        = RateLimits(outputMainnet.readAddress(".rateLimits"));

        psm = PSM3(outputBase.readAddress(".psm"));

        usdsBase  = IERC20(outputBase.readAddress(".usds"));
        susdsBase = IERC20(outputBase.readAddress(".sUsds"));
        usdcBase  = IERC20(outputBase.readAddress(".usdc"));

        foreignController = ForeignController(outputBase.readAddress(".controller"));
        almProxyBase      = ALMProxy(payable(outputBase.readAddress(".almProxy")));
    }

    function test_mintUSDS() public {
        assertEq(usds.balanceOf(address(almProxy)), 0);

        vm.prank(safe);
        mainnetController.mintUSDS(1000e18);

        assertEq(usds.balanceOf(address(almProxy)), 1000e18);
    }

    function test_mintAndSwapToUSDC() public {
        assertEq(usdc.balanceOf(address(almProxy)), 0);

        vm.startPrank(safe);
        mainnetController.mintUSDS(1000e18);
        mainnetController.swapUSDSToUSDC(1000e6);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(almProxy)), 1000e6);
    }

    function test_transferCCTP() public {
        base.selectFork();

        assertEq(usdcBase.balanceOf(address(almProxyBase)), 0);

        mainnet.selectFork();

        vm.startPrank(safe);
        mainnetController.mintUSDS(1000e18);
        mainnetController.swapUSDSToUSDC(1000e6);
        mainnetController.transferUSDCToCCTP(1000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
        vm.stopPrank();

        cctpBridge.relayMessagesToDestination(true);

        assertEq(usdcBase.balanceOf(address(almProxyBase)), 1000e6);
    }

    function test_transferToPSM() public {
        base.selectFork();

        assertEq(usdcBase.balanceOf(address(psm)), 0);

        mainnet.selectFork();

        vm.startPrank(safe);
        mainnetController.mintUSDS(1000e18);
        mainnetController.swapUSDSToUSDC(1000e6);
        mainnetController.transferUSDCToCCTP(1000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
        vm.stopPrank();

        cctpBridge.relayMessagesToDestination(true);

        vm.startPrank(safe);
        foreignController.depositPSM(address(usdcBase), 1000e6);
        vm.stopPrank();

        assertEq(usdcBase.balanceOf(address(psm)), 1000e6);
    }

    function test_fullRoundTrip() public {
        mainnet.selectFork();

        vm.startPrank(safe);
        mainnetController.mintUSDS(1000e18);
        mainnetController.swapUSDSToUSDC(1000e6);
        mainnetController.transferUSDCToCCTP(1000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
        vm.stopPrank();

        cctpBridge.relayMessagesToDestination(true);

        vm.startPrank(safe);
        foreignController.depositPSM(address(usdcBase), 1000e6);
        foreignController.withdrawPSM(address(usdcBase), 1000e6);
        foreignController.transferUSDCToCCTP(1000e6, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);
        vm.stopPrank();

        // There is a bug when the messenger addresses are the same
        // Need to force update to skip the previous relayed message
        // See: https://github.com/marsfoundation/xchain-helpers/issues/24
        cctpBridge.lastDestinationLogIndex = cctpBridge.lastSourceLogIndex;
        cctpBridge.relayMessagesToSource(true);

        vm.startPrank(safe);
        mainnetController.swapUSDCToUSDS(1000e6);
        mainnetController.burnUSDS(1000e18);
        vm.stopPrank();
    }

}
