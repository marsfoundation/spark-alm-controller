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

    string outputMainnet;
    string inputBase;
    string outputBase;

    Domain mainnet;
    Domain base;
    Bridge bridge;
    Bridge cctpBridge;

    // Mainnet contracts
    Usds   usds;
    SUsds  susds;
    IERC20 usdc;

    address safe;

    AllocatorVault allocatorVault;
    AllocatorBuffer allocatorBuffer;

    MainnetController mainnetController;
    ALMProxy almProxy;
    RateLimits rateLimits;

    // Base contracts
    address safeBase;

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

        outputMainnet = ScriptTools.readOutput("mainnet");
        inputBase = ScriptTools.readInput("base");
        outputBase = ScriptTools.readOutput("base");

        admin = outputMainnet.readAddress(".admin");

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

        vm.prank(admin);
        mainnetController.mintUSDS(1000e18);

        assertEq(usds.balanceOf(address(almProxy)), 1000e18);
    }

    function test_mintAndSwapToUSDC() public {
        assertEq(usdc.balanceOf(address(almProxy)), 0);

        vm.startPrank(admin);

        mainnetController.mintUSDS(1000e18);
        mainnetController.swapUSDSToUSDC(1000e6);

        vm.stopPrank();

        assertEq(usdc.balanceOf(address(almProxy)), 1000e6);
    }

    function test_transferCCTP() public {
        base.selectFork();

        assertEq(usdcBase.balanceOf(address(almProxyBase)), 0);

        vm.startPrank(admin);

        mainnetController.mintUSDS(1000e18);
        mainnetController.swapUSDSToUSDC(1000e6);
        mainnetController.transferUSDCToCCTP(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE, 1000e6);

        vm.stopPrank();

        cctpBridge.relayMessagesToDestination(true);

        assertEq(usdcBase.balanceOf(address(almProxyBase)), 1000e6);
    }

}
