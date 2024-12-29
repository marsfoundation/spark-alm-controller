// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { ScriptTools } from "dss-test/ScriptTools.sol";

import "forge-std/Script.sol";

import { ControllerInstance } from "../deploy/ControllerInstance.sol";

import { ForeignControllerDeploy, MainnetControllerDeploy } from "../deploy/ControllerDeploy.sol";

contract InitMainnetController is Script {

    using stdJson     for string;
    using ScriptTools for string;

    function run() external {
        vm.setEnv("FOUNDRY_ROOT_CHAINID",             "1");
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        vm.createSelectFork(getChain("mainnet").rpcUrl);

        console.log("Initializing Mainnet Controller...");

        string memory fileSlug = string(abi.encodePacked("mainnet-", vm.envString("ENV")));

        vm.startBroadcast();

        string memory config = ScriptTools.loadConfig(fileSlug);

        address controller = MainnetControllerDeploy.deployController({
            admin      : config.readAddress(".admin"),
            almProxy   : config.readAddress(".almProxy"),
            rateLimits : config.readAddress(".rateLimits"),
            vault      : config.readAddress(".allocatorVault"),
            psm        : config.readAddress(".psm"),
            daiUsds    : config.readAddress(".daiUsds"),
            cctp       : config.readAddress(".cctpTokenMessenger")
        });

        vm.stopBroadcast();

        console.log("Controller deployed at", controller);

        ScriptTools.exportContract(fileSlug, "controller", controller);
    }

}

contract DeployForeignController is Script {

    using stdJson     for string;
    using ScriptTools for string;

    function run() external {
        vm.setEnv("FOUNDRY_ROOT_CHAINID",             "1");
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        string memory chainName = vm.envString("CHAIN");
        string memory fileSlug  = string(abi.encodePacked(chainName, "-", vm.envString("ENV")));
        string memory config    = ScriptTools.loadConfig(fileSlug);

        vm.createSelectFork(getChain(chainName).rpcUrl);

        console.log(string(abi.encodePacked("Deploying ", chainName, " Controller...")));

        vm.startBroadcast();

        address controller = ForeignControllerDeploy.deployController({
            admin      : config.readAddress(".admin"),
            almProxy   : config.readAddress(".almProxy"),
            rateLimits : config.readAddress(".rateLimits"),
            psm        : config.readAddress(".psm"),
            usdc       : config.readAddress(".usdc"),
            cctp       : config.readAddress(".cctpTokenMessenger")
        });

        vm.stopBroadcast();

        console.log("Controller deployed at", controller);

        ScriptTools.exportContract(fileSlug, "controller", controller);
    }

}
