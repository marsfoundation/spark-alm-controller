// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { ScriptTools } from "dss-test/ScriptTools.sol";

import "forge-std/Script.sol";

import { CCTPForwarder } from "xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { ControllerInstance } from "../deploy/ControllerInstance.sol";

import {
    ForeignControllerInit,
    MainnetControllerInit,
    RateLimitData,
    MintRecipient
} from "../deploy/ControllerInit.sol";

import { MainnetController } from "../src/MainnetController.sol";
import { RateLimitHelpers }  from "../src/RateLimitHelpers.sol";
import { RateLimits }        from "../src/RateLimits.sol";

contract InitMainnetFull is Script {

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

        MainnetControllerInit.AddressParams memory addresses = MainnetControllerInit.AddressParams({
            admin         : config.readAddress(".admin"),
            freezer       : config.readAddress(".freezer"),
            relayer       : config.readAddress(".relayer"),
            oldController : config.readAddress(".controller"),
            psm           : config.readAddress(".psm"),
            vault         : config.readAddress(".allocatorVault"),
            buffer        : config.readAddress(".buffer"),
            cctpMessenger : config.readAddress(".cctpMessenger"),
            dai           : config.readAddress(".dai"),
            daiUsds       : config.readAddress(".daiUsds"),
            usdc          : config.readAddress(".usdc"),
            usds          : config.readAddress(".usds"),
            susds         : config.readAddress("susds")
        });

        RateLimitData memory standardUsdsData = RateLimitData({
            maxAmount : 5_000_000e18,
            slope     : uint256(1_000_000e18) / 4 hours
        });

        RateLimitData memory standardUsdcData = RateLimitData({
            maxAmount : 5_000_000e6,
            slope     : uint256(1_000_000e6) / 4 hours
        });

        MainnetControllerInit.InitRateLimitData memory rateLimitData
            = MainnetControllerInit.InitRateLimitData({
                usdsMintData         : standardUsdsData,
                usdsToUsdcData       : standardUsdcData,
                usdcToCctpData       : standardUsdcData,
                cctpToBaseDomainData : standardUsdcData,
                susdsDepositData     : standardUsdsData
            });

        MintRecipient[] memory mintRecipients = new MintRecipient[](1);

        mintRecipients[0] = MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            mintRecipient : bytes32(uint256(uint160(makeAddr("baseAlmProxy"))))
        });

        ControllerInstance memory controllerInst = ControllerInstance({
            almProxy   : config.readAddress(".almProxy"),
            controller : config.readAddress(".controller"),
            rateLimits : config.readAddress(".rateLimits")
        });

        // Step 1: Initialize the controller, overwriting previous rate limits
        MainnetControllerInit.subDaoInitController(
            addresses,
            controllerInst,
            rateLimitData,
            mintRecipients
        );

        MainnetController controller = MainnetController(controllerInst.controller);
        RateLimits        rateLimits = RateLimits(controllerInst.rateLimits);

        bytes32 usdeBurnKey      = controller.LIMIT_USDE_BURN();
        bytes32 susdeCooldownKey = controller.LIMIT_SUSDE_COOLDOWN();
        bytes32 susdeDepositKey  = RateLimitHelpers.makeAssetKey(controller.LIMIT_4626_DEPOSIT(), config.readAddress(".susde"));
        bytes32 susdsDepositKey  = RateLimitHelpers.makeAssetKey(controller.LIMIT_4626_DEPOSIT(), config.readAddress(".susds"));
        bytes32 usdeMintKey      = controller.LIMIT_USDE_MINT();

        rateLimits.setRateLimitData(usdeBurnKey,      5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(susdeCooldownKey, 5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(susdeDepositKey,  5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(susdsDepositKey,  5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(usdeMintKey,      5_000_000e6,  uint256(1_000_000e6)  / 4 hours);

        vm.stopBroadcast();

        console.log("Controller initialized at", controllerInst.controller);
    }

}
