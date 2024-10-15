// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { ScriptTools } from "dss-test/ScriptTools.sol";

import { stdJson } from "forge-std/StdJson.sol";

import { Domain, StagingDeploymentBase } from "script/staging/StagingDeploymentBase.sol";

contract DeploySepoliaStaging is StagingDeploymentBase {

    using stdJson     for string;
    using ScriptTools for string;

    function run() public {
        vm.setEnv("FOUNDRY_ROOT_CHAINID",             "11155111");
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        deployer = msg.sender;

        setChain("sepolia_base", ChainData({
            rpcUrl  : "https://base-sepolia-rpc.publicnode.com",
            chainId : 84532,
            name    : "Sepolia Base Testnet"
        }));

        mainnet = Domain({
            name   : "mainnet",
            config : ScriptTools.loadConfig("mainnet"),
            forkId : vm.createFork(getChain("sepolia").rpcUrl),
            admin  : deployer
        });
        base = Domain({
            name   : "base",
            config : ScriptTools.loadConfig("base"),
            forkId : vm.createFork(getChain("sepolia_base").rpcUrl),
            admin  : deployer
        });

        _runFullDeployment();
    }

}


