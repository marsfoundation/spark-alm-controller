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

import { PSM3, IERC20 } from "spark-psm/src/PSM3.sol";

import { IRateLimits } from "../../../src/interfaces/IRateLimits.sol";

import { ALMProxy }          from "../../../src/ALMProxy.sol";
import { ForeignController } from "../../../src/ForeignController.sol";
import { MainnetController } from "../../../src/MainnetController.sol";
import { RateLimits }        from "../../../src/RateLimits.sol";
import { RateLimitHelpers }  from "../../../src/RateLimitHelpers.sol";

import { MainnetControllerDeploy } from "../../../deploy/ControllerDeploy.sol";
import { MainnetControllerInit }   from "../../../deploy/ControllerInit.sol";

interface IVatLike {
    function can(address, address) external view returns (uint256);
}

contract DeployEthereumTest is Test {

    using stdJson           for *;
    using DomainHelpers     for *;
    using CCTPBridgeTesting for *;
    using ScriptTools       for *;

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    uint256 constant RELEASE_DATE = 20241210;

    // Common variables
    address admin;

    // Configuration data
    string inputBase;
    string inputMainnet;
    string outputBase;
    string outputBaseDeps;
    string outputMainnet;
    string outputMainnetDeps;

    // Bridging
    Domain mainnet;
    Domain base;
    Bridge cctpBridge;

    // Mainnet contracts

    Usds   usds;
    SUsds  susds;
    IERC20 usdc;
    IERC20 dai;

    address vault;
    address relayerSafe;
    address usdsJoin;

    ALMProxy          almProxy;
    MainnetController mainnetController;
    RateLimits        rateLimits;

    // Base contracts

    address relayerSafeBase;

    PSM3 psmBase;

    IERC20 usdsBase;
    IERC20 susdsBase;
    IERC20 usdcBase;

    ALMProxy          baseAlmProxy;
    ForeignController baseController;
    RateLimits        baseRateLimits;

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
        inputBase    = ScriptTools.readInput("base-staging");
        inputMainnet = ScriptTools.readInput("mainnet-staging");

        outputBase        = ScriptTools.readOutput("base-staging-release",         RELEASE_DATE);
        outputBaseDeps    = ScriptTools.readOutput("base-staging-deps-release",    RELEASE_DATE);
        outputMainnet     = ScriptTools.readOutput("mainnet-staging-release",      RELEASE_DATE);
        outputMainnetDeps = ScriptTools.readOutput("mainnet-staging-deps-release", RELEASE_DATE);

        // Roles
        admin       = outputMainnetDeps.readAddress(".admin");
        relayerSafe = outputMainnetDeps.readAddress(".relayer");

        // Tokens
        usds  = Usds(outputMainnetDeps.readAddress(".usds"));
        susds = SUsds(outputMainnetDeps.readAddress(".susds"));
        usdc  = IERC20(outputMainnetDeps.readAddress(".usdc"));
        dai   = IERC20(outputMainnetDeps.readAddress(".dai"));

        // Dependencies
        vault    = outputMainnetDeps.readAddress(".allocatorVault");
        usdsJoin = outputMainnetDeps.readAddress(".usdsJoin");

        // ALM system
        almProxy          = ALMProxy(payable(outputMainnet.readAddress(".almProxy")));
        rateLimits        = RateLimits(outputMainnet.readAddress(".rateLimits"));
        mainnetController = _reconfigureMainnetController();

        // Base roles
        relayerSafeBase = outputBaseDeps.readAddress(".relayer");

        // Base tokens
        usdsBase  = IERC20(inputBase.readAddress(".usds"));
        susdsBase = IERC20(inputBase.readAddress(".susds"));
        usdcBase  = IERC20(inputBase.readAddress(".usdc"));

        // Base ALM system
        baseAlmProxy   = ALMProxy(payable(outputBase.readAddress(".almProxy")));
        baseController = ForeignController(outputBase.readAddress(".controller"));
        baseRateLimits = RateLimits(outputBase.readAddress(".rateLimits"));

        // Base PSM
        psmBase = PSM3(inputBase.readAddress(".psm"));

        mainnet.selectFork();

        deal(address(usds), address(usdsJoin), 1000e18);  // Ensure there is enough balance
    }

    // TODO: Remove this once a deployment has been done on mainnet
    function _reconfigureMainnetController() internal returns (MainnetController newController) {
        newController = MainnetController(MainnetControllerDeploy.deployController({
            admin      : admin,
            almProxy   : address(almProxy),
            rateLimits : address(rateLimits),
            vault      : address(vault),
            psm        : inputMainnet.readAddress(".psm"),
            daiUsds    : inputMainnet.readAddress(".daiUsds"),
            cctp       : inputMainnet.readAddress(".cctpTokenMessenger")
        }));

        vm.startPrank(admin);

        newController.grantRole(newController.FREEZER(), inputMainnet.readAddress(".freezer"));
        newController.grantRole(newController.RELAYER(), inputMainnet.readAddress(".relayer"));

        almProxy.grantRole(almProxy.CONTROLLER(), address(newController));
        rateLimits.grantRole(rateLimits.CONTROLLER(), address(newController));

        almProxy.revokeRole(almProxy.CONTROLLER(), outputMainnet.readAddress(".controller"));
        rateLimits.revokeRole(rateLimits.CONTROLLER(), outputMainnet.readAddress(".controller"));

        newController.setMintRecipient(
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE, 
            bytes32(uint256(uint160(address(outputBase.readAddress(".almProxy")))))
        );

        vm.stopPrank();
    }

    /**********************************************************************************************/
    /**** Tests                                                                                 ***/
    /**********************************************************************************************/

    function test_mintUSDS() public {
        uint256 startingBalance = usds.balanceOf(address(almProxy));

        vm.prank(relayerSafe);
        mainnetController.mintUSDS(10e18);

        assertEq(usds.balanceOf(address(almProxy)), startingBalance + 10e18);
    }

    function test_mintAndSwapToUSDC() public {
        uint256 startingBalance = usdc.balanceOf(address(almProxy));

        vm.startPrank(relayerSafe);
        mainnetController.mintUSDS(10e18);
        mainnetController.swapUSDSToUSDC(10e6);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(almProxy)), startingBalance + 10e6);
    }

    function test_transferCCTP() public {
        base.selectFork();

        uint256 startingBalance = usdcBase.balanceOf(address(baseAlmProxy));

        mainnet.selectFork();

        vm.startPrank(relayerSafe);
        mainnetController.mintUSDS(10e18);
        mainnetController.swapUSDSToUSDC(10e6);
        mainnetController.transferUSDCToCCTP(10e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
        vm.stopPrank();

        cctpBridge.relayMessagesToDestination(true);

        assertEq(usdcBase.balanceOf(address(baseAlmProxy)), startingBalance + 10e6);
    }

    function test_transferToPSM() public {
        base.selectFork();

        uint256 startingBalance = usdcBase.balanceOf(address(psmBase));

        mainnet.selectFork();

        vm.startPrank(relayerSafe);
        mainnetController.mintUSDS(10e18);
        mainnetController.swapUSDSToUSDC(10e6);
        mainnetController.transferUSDCToCCTP(10e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
        vm.stopPrank();

        cctpBridge.relayMessagesToDestination(true);

        uint256 startingShares = psmBase.shares(address(baseAlmProxy));

        vm.startPrank(relayerSafeBase);
        baseController.depositPSM(address(usdcBase), 10e6);
        vm.stopPrank();

        assertEq(usdcBase.balanceOf(address(psmBase)), startingBalance + 10e6);

        assertEq(psmBase.shares(address(baseAlmProxy)), startingShares + psmBase.convertToShares(10e18));
    }

    function test_fullRoundTrip() public {
        mainnet.selectFork();

        vm.startPrank(relayerSafe);
        mainnetController.mintUSDS(1e18);
        mainnetController.swapUSDSToUSDC(1e6);
        mainnetController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
        vm.stopPrank();

        cctpBridge.relayMessagesToDestination(true);

        vm.startPrank(relayerSafeBase);
        baseController.depositPSM(address(usdcBase), 1e6);
        baseController.withdrawPSM(address(usdcBase), 1e6);
        baseController.transferUSDCToCCTP(1e6 - 1, CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM);  // Account for potential rounding
        vm.stopPrank();

        // There is a bug when the messenger addresses are the same
        // Need to force update to skip the previous relayed message
        // See: https://github.com/marsfoundation/xchain-helpers/issues/24
        cctpBridge.lastDestinationLogIndex = cctpBridge.lastSourceLogIndex;
        cctpBridge.relayMessagesToSource(true);

        vm.startPrank(relayerSafe);
        mainnetController.swapUSDCToUSDS(1e6 - 1);
        mainnetController.burnUSDS((1e6 - 1) * 1e12);
        vm.stopPrank();
    }

}
