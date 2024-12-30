// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { ScriptTools } from "dss-test/ScriptTools.sol";

import "forge-std/Script.sol";

import { CCTPForwarder } from "xchain-helpers/forwarders/CCTPForwarder.sol";

import { ControllerInstance }                   from "../deploy/ControllerInstance.sol";
import { MainnetControllerInit as MainnetInit } from "../deploy/MainnetControllerInit.sol";

contract UpgradeMainnetController is Script {

    using stdJson     for string;
    using ScriptTools for string;

    function run() external {
        vm.setEnv("FOUNDRY_ROOT_CHAINID",             "1");
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        vm.createSelectFork(getChain("mainnet").rpcUrl);

        console.log("Upgrading Mainnet Controller...");

        string memory fileSlug = string(abi.encodePacked("mainnet-", vm.envString("ENV")));

        uint256 date = vm.envUint("DATE");

        address newController = vm.envAddress("NEW_CONTROLLER");

        console.log("fileSlug", fileSlug);
        console.log("date", date);
        console.log("newController", newController);
        console.log("path", string(abi.encodePacked(fileSlug, "-release-", date)));

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
