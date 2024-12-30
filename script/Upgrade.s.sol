// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { ScriptTools } from "dss-test/ScriptTools.sol";

import "forge-std/Script.sol";

import { CCTPForwarder } from "xchain-helpers/forwarders/CCTPForwarder.sol";

import { ControllerInstance }                   from "../deploy/ControllerInstance.sol";
import { ForeignControllerInit as ForeignInit } from "../deploy/ForeignControllerInit.sol";
import { MainnetControllerInit as MainnetInit } from "../deploy/MainnetControllerInit.sol";

contract UpgradeMainnetController is Script {

    using stdJson     for string;
    using ScriptTools for string;

    function run() external {
        vm.setEnv("FOUNDRY_ROOT_CHAINID",             "1");
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        vm.createSelectFork(getChain("mainnet").rpcUrl);

        console.log("Upgrading mainnet controller...");

        string memory fileSlug = string(abi.encodePacked("mainnet-", vm.envString("ENV")));

        uint256 date = vm.envUint("DATE");

        address newController = vm.envAddress("NEW_CONTROLLER");

        vm.startBroadcast();

        string memory inputConfig   = ScriptTools.readInput(fileSlug);
        string memory releaseConfig = ScriptTools.readOutput(string(abi.encodePacked(fileSlug, "-release")), date);

        ControllerInstance memory controllerInst = ControllerInstance({
            almProxy   : releaseConfig.readAddress(".almProxy"),
            controller : newController,
            rateLimits : releaseConfig.readAddress(".rateLimits")
        });

        MainnetInit.ConfigAddressParams memory configAddresses = MainnetInit.ConfigAddressParams({
            freezer       : inputConfig.readAddress(".freezer"),
            relayer       : inputConfig.readAddress(".relayer"),
            oldController : releaseConfig.readAddress(".controller")
        });

        MainnetInit.CheckAddressParams memory checkAddresses = MainnetInit.CheckAddressParams({
            admin      : inputConfig.readAddress(".admin"),
            proxy      : releaseConfig.readAddress(".almProxy"),
            rateLimits : releaseConfig.readAddress(".rateLimits"),
            vault      : inputConfig.readAddress(".allocatorVault"),
            psm        : inputConfig.readAddress(".psm"),
            daiUsds    : inputConfig.readAddress(".daiUsds"),
            cctp       : inputConfig.readAddress(".cctpTokenMessenger")
        });

        MainnetInit.MintRecipient[] memory mintRecipients = new MainnetInit.MintRecipient[](1);

        string memory baseReleaseConfig = ScriptTools.readOutput(
            string(abi.encodePacked("base-", vm.envString("ENV"), "-release")), 
            date
        );

        address baseAlmProxy = baseReleaseConfig.readAddress(".almProxy");

        mintRecipients[0] = MainnetInit.MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            mintRecipient : bytes32(uint256(uint160(baseAlmProxy)))
        });

        MainnetInit.upgradeController(controllerInst, configAddresses, checkAddresses, mintRecipients);

        vm.stopBroadcast();

        console.log("Controller upgraded at      ", newController);
        console.log("Old controller deprecated at", releaseConfig.readAddress(".controller"));
    }

}

contract UpgradeForeignController is Script {

    using stdJson     for string;
    using ScriptTools for string;

    function run() external {
        vm.setEnv("FOUNDRY_ROOT_CHAINID",             "1");
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        string memory chainName = vm.envString("CHAIN");
        string memory fileSlug  = string(abi.encodePacked(chainName, "-", vm.envString("ENV")));
        string memory config    = ScriptTools.loadConfig(fileSlug);

        uint256 date = vm.envUint("DATE");

        address newController = vm.envAddress("NEW_CONTROLLER");

        vm.createSelectFork(getChain(chainName).rpcUrl);

        console.log(string(abi.encodePacked("Upgrading ", chainName, " controller...")));

        vm.startBroadcast();

        string memory inputConfig   = ScriptTools.readInput(fileSlug);
        string memory releaseConfig = ScriptTools.readOutput(string(abi.encodePacked(fileSlug, "-release")), date);

        ControllerInstance memory controllerInst = ControllerInstance({
            almProxy   : releaseConfig.readAddress(".almProxy"),
            controller : newController,
            rateLimits : releaseConfig.readAddress(".rateLimits")
        });

        ForeignInit.ConfigAddressParams memory configAddresses = ForeignInit.ConfigAddressParams({
            freezer       : inputConfig.readAddress(".freezer"),
            relayer       : inputConfig.readAddress(".relayer"),
            oldController : releaseConfig.readAddress(".controller")
        });

        ForeignInit.CheckAddressParams memory checkAddresses = ForeignInit.CheckAddressParams({
            admin : inputConfig.readAddress(".admin"),
            psm   : inputConfig.readAddress(".psm"),
            cctp  : inputConfig.readAddress(".cctpTokenMessenger"),
            usdc  : inputConfig.readAddress(".usdc"),
            susds : inputConfig.readAddress(".susds"),
            usds  : inputConfig.readAddress(".usds")
        });

        ForeignInit.MintRecipient[] memory mintRecipients = new ForeignInit.MintRecipient[](1);

        string memory mainnetReleaseConfig = ScriptTools.readOutput(
            string(abi.encodePacked("mainnet-", vm.envString("ENV"), "-release")), 
            date
        );

        address mainnetAlmProxy = mainnetReleaseConfig.readAddress(".almProxy");

        mintRecipients[0] = ForeignInit.MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            mintRecipient : bytes32(uint256(uint160(mainnetAlmProxy)))
        });

        ForeignInit.upgradeController(controllerInst, configAddresses, checkAddresses, mintRecipients);

        vm.stopBroadcast();

        console.log("Controller upgraded at      ", newController);
        console.log("Old controller deprecated at", releaseConfig.readAddress(".controller"));
    }

}
