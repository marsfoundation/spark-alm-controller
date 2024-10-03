// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { Base } from "lib/spark-address-registry/src/Base.sol";

import { Ethereum } from "lib/spark-address-registry/src/Ethereum.sol";  // Update to master branch

import { ControllerInstance } from "../deploy/ControllerInstance.sol";

import { ForeignControllerDeploy, MainnetControllerDeploy } from "../deploy/ControllerDeploy.sol";

contract DeployMainnetFull is Script {

    function run() external {
        console.log("Deploying Mainnet ALMProxy, Controller and RateLimits...");

        vm.startBroadcast();

        ControllerInstance memory instance = MainnetControllerDeploy.deployFull({
            admin   : Ethereum.SPARK_PROXY,
            vault   : address(0),  // TODO: Replace
            buffer  : address(0),  // TODO: Replace
            psm     : Ethereum.PSM,
            daiUsds : Ethereum.DAI_USDS,
            cctp    : Ethereum.CCTP_TOKEN_MESSENGER,
            susds   : Ethereum.SUSDS
        });

        vm.stopBroadcast();

        console.log("ALMProxy   deployed at", instance.almProxy);
        console.log("Controller deployed at", instance.controller);
        console.log("RateLimits deployed at", instance.rateLimits);
    }

}

contract DeployBaseFull is Script {

    function run() external {
        console.log("Deploying Mainnet ALMProxy, Controller and RateLimits...");

        vm.startBroadcast();

        ControllerInstance memory instance = ForeignControllerDeploy.deployFull({
            admin      : Base.SPARK_EXECUTOR,
            psm        : address(0),  // TODO: Replace
            usdc       : Base.USDC,
            cctp       : Base.CCTP_TOKEN_MESSENGER
        });

        vm.stopBroadcast();

        console.log("ALMProxy   deployed at", instance.almProxy);
        console.log("Controller deployed at", instance.controller);
        console.log("RateLimits deployed at", instance.rateLimits);
    }

}
