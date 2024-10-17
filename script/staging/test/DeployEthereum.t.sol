// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { ScriptTools } from "dss-test/ScriptTools.sol";

import { Bridge }                from "xchain-helpers/src/testing/Bridge.sol";
import { Domain, DomainHelpers } from "xchain-helpers/src/testing/Domain.sol";
import { CCTPBridgeTesting }     from "xchain-helpers/src/testing/bridges/CCTPBridgeTesting.sol";

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

    address admin;
    address safe;  // Will be the same on all chains

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
        vm.setEnv("FOUNDRY_ROOT_CHAINID", "1");

        mainnet = getChain("mainnet").createSelectFork();
        base    = getChain("base").createFork();

        inputMainnet  = ScriptTools.readInput("mainnet");
        outputMainnet = ScriptTools.readOutput("mainnet-release", 20241017);
        inputBase     = ScriptTools.readInput("base");
        outputBase    = ScriptTools.readOutput("base-release", 20241017);

        cctpBridge = CCTPBridgeTesting.init(Bridge({
            source:                         mainnet,
            destination:                    base,
            sourceCrossChainMessenger:      inputMainnet.readAddress(".cctpTokenMessenger"),
            destinationCrossChainMessenger: inputBase.readAddress(".cctpTokenMessenger"),
            lastSourceLogIndex:             0,
            lastDestinationLogIndex:        0,
            extraData:                      ""
        }));

        admin = outputMainnet.readAddress(".admin");
        safe  = outputMainnet.readAddress(".safe");

        usds  = Usds(outputMainnet.readAddress(".usds"));
        susds = SUsds(outputMainnet.readAddress(".sUsds"));
        usdc  = IERC20(inputMainnet.readAddress(".usdc"));

        allocatorVault  = AllocatorVault(outputMainnet.readAddress(".allocatorVault"));
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

        mainnet.selectFork();
    }

    function test_mintUSDS() public {
        assertEq(usds.balanceOf(address(almProxy)), 0);

        vm.prank(safe);
        mainnetController.mintUSDS(10e18);

        assertEq(usds.balanceOf(address(almProxy)), 10e18);
    }

}
