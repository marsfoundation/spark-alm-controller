// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { Base } from "lib/spark-address-registry/src/Base.sol";

import { Ethereum } from "lib/spark-address-registry/src/Ethereum.sol";

import { ControllerInstance } from "../deploy/ControllerInstance.sol";

import { ForeignControllerDeploy, MainnetControllerDeploy } from "../deploy/ControllerDeploy.sol";

contract DeployMainnetFull is Script {

    function run() internal {

        console.log("Deploying Mainnet ALMProxy, Controller and RateLimits...");

        vm.startBroadcast();

        ControllerInstance memory instance = MainnetControllerDeploy.deployFull({
            admin      : Ethereum.SPARK_PROXY,
            psm        : Ethereum.PSM,
            usdc       : Ethereum.USDC,
            cctp       : Ethereum.  //  TODO: xchain-helpers forwarders
        });

        vm.stopBroadcast();

        console.log("ALMProxy   deployed at", instance.almProxy);
        console.log("Controller deployed at", instance.controller);
        console.log("RateLimits deployed at", instance.rateLimits);
    }

}

contract DeployBaseFull is Script {

    function run() internal {
        console.log("Deploying Mainnet ALMProxy, Controller and RateLimits...");

        vm.startBroadcast();

        ControllerInstance memory instance = ForeignControllerDeploy.deployFull({
            admin      : Ethereum.SPARK_PROXY,
            psm        : Ethereum.PSM,
            usdc       : Ethereum.USDC,
            cctp       : Ethereum.CCTP_MESSENGER
        });

        vm.stopBroadcast();

        console.log("ALMProxy   deployed at", instance.almProxy);
        console.log("Controller deployed at", instance.controller);
        console.log("RateLimits deployed at", instance.rateLimits);
    }

}
