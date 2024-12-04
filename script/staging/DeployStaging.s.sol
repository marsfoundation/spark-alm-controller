// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { ScriptTools } from "dss-test/ScriptTools.sol";

import { Script }  from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";

import { Base }     from "spark-address-registry/src/Base.sol";
import { Ethereum } from "spark-address-registry/src/Ethereum.sol";

import { CCTPForwarder } from "xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { ForeignControllerDeploy, MainnetControllerDeploy } from "deploy/ControllerDeploy.sol";

import { ControllerInstance } from "deploy/ControllerInstance.sol";

import {
    ForeignControllerInit,
    MainnetControllerInit,
    MintRecipient
} from "deploy/ControllerInit.sol";

import { ForeignController } from "src/ForeignController.sol";
import { MainnetController } from "src/MainnetController.sol";
import { RateLimitHelpers }  from "src/RateLimitHelpers.sol";
import { RateLimits }        from "src/RateLimits.sol";

struct Domain {
    string  name;
    string  config;
    uint256 forkId;
    address admin;
}

contract DeployStaging is Script {

    address deployer;
    bytes32 ilk;

    uint256 USDC_UNIT_SIZE;
    uint256 USDS_UNIT_SIZE;

    Domain mainnet;
    Domain base;

    address constant ATOKEN_USDC = 0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB;
    address constant AAVE_POOL   = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;

    address constant MORPHO            = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant MORPHO_VAULT_USDS = 0x0fFDeCe791C5a2cb947F8ddBab489E5C02c6d4F7;
    address constant MORPHO_VAULT_USDC = 0x305E03Ed9ADaAB22F4A58c24515D79f2B1E2FD5D;

    /**********************************************************************************************/
    /*** Constant addresses                                                                     ***/
    /**********************************************************************************************/

    using stdJson     for string;
    using ScriptTools for string;

    function run() public {
        vm.setEnv("FOUNDRY_ROOT_CHAINID",             "1");
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        deployer = msg.sender;

        mainnet = Domain({
            name   : "mainnet",
            config : ScriptTools.loadConfig("mainnet"),
            forkId : vm.createFork(getChain("mainnet").rpcUrl),
            admin  : deployer
        });
        base = Domain({
            name   : "base",
            config : ScriptTools.loadConfig("base"),
            forkId : vm.createFork(getChain("base").rpcUrl),
            admin  : deployer
        });

        _upgradeALMControllerMainnet();
        _upgradeALMControllerBase();
    }

    function _upgradeALMControllerMainnet() internal {
        vm.selectFork(mainnet.forkId);
        vm.startBroadcast();

        MainnetController mainnetController = MainnetController(MainnetControllerDeploy.deployController({
            admin      : mainnet.config.readAddress(".admin"),
            almProxy   : mainnet.config.readAddress(".almProxy"),
            rateLimits : mainnet.config.readAddress(".rateLimits"),
            vault      : mainnet.config.readAddress(".allocatorVault"),
            psm        : Ethereum.PSM,
            daiUsds    : Ethereum.DAI_USDS,
            cctp       : Ethereum.CCTP_TOKEN_MESSENGER,
            susds      : Ethereum.SUSDS
        }));

        MainnetControllerInit.ConfigAddressParams memory configAddresses
            = MainnetControllerInit.ConfigAddressParams({
                admin         : mainnet.config.readAddress(".admin"),
                freezer       : mainnet.config.readAddress(".safe"),  // Using for staging only
                relayer       : mainnet.config.readAddress(".safe"),
                oldController : mainnet.config.readAddress(".controller")
            });

        MainnetControllerInit.AddressCheckParams memory checkAddresses
            = MainnetControllerInit.AddressCheckParams({
                proxy        : mainnet.config.readAddress(".almProxy"),
                rateLimits   : mainnet.config.readAddress(".rateLimits"),
                buffer       : mainnet.config.readAddress(".allocatorBuffer"),
                cctp         : Ethereum.CCTP_TOKEN_MESSENGER,
                daiUsds      : Ethereum.DAI_USDS,
                ethenaMinter : Ethereum.ETHENA_MINTER,
                psm          : Ethereum.PSM,
                vault        : mainnet.config.readAddress(".allocatorVault"),
                dai          : Ethereum.DAI,
                usds         : Ethereum.USDS,
                usde         : Ethereum.USDE,
                usdc         : Ethereum.USDC,
                susde        : Ethereum.SUSDE,
                susds        : Ethereum.SUSDS
            });

        // Configure this after Base ALM Proxy is deployed
        MintRecipient[] memory mintRecipients = new MintRecipient[](0);

        ControllerInstance memory controllerInst = ControllerInstance({
            almProxy   : mainnet.config.readAddress(".almProxy"),
            controller : address(mainnetController),
            rateLimits : mainnet.config.readAddress(".rateLimits")
        });

        MainnetControllerInit.subDaoInitController(
            configAddresses,
            checkAddresses,
            controllerInst,
            mintRecipients
        );

        bytes32 usdeBurnKey      = mainnetController.LIMIT_USDE_BURN();
        bytes32 susdeCooldownKey = mainnetController.LIMIT_SUSDE_COOLDOWN();
        bytes32 susdeDepositKey  = RateLimitHelpers.makeAssetKey(mainnetController.LIMIT_4626_DEPOSIT(), Ethereum.SUSDE);
        bytes32 susdsDepositKey  = RateLimitHelpers.makeAssetKey(mainnetController.LIMIT_4626_DEPOSIT(), Ethereum.SUSDS);
        bytes32 usdeMintKey      = mainnetController.LIMIT_USDE_MINT();

        RateLimits rateLimits = RateLimits(mainnet.config.readAddress(".rateLimits"));

        rateLimits.setRateLimitData(usdeBurnKey,      5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(susdeCooldownKey, 5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(susdeDepositKey,  5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(susdsDepositKey,  5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(usdeMintKey,      5_000_000e6,  uint256(1_000_000e6)  / 4 hours);

        ScriptTools.exportContract(mainnet.name, "controller", address(mainnetController));

        vm.stopBroadcast();
    }

    function _upgradeALMControllerBase() internal {
        vm.selectFork(base.forkId);
        vm.startBroadcast();

        ForeignController foreignController = ForeignController(ForeignControllerDeploy.deployController({
            admin      : base.config.readAddress(".admin"),
            almProxy   : base.config.readAddress(".almProxy"),
            rateLimits : base.config.readAddress(".rateLimits"),
            psm        : Base.PSM3,
            usdc       : Base.USDC,
            cctp       : Base.CCTP_TOKEN_MESSENGER
        }));

        ForeignControllerInit.ConfigAddressParams memory configAddresses
            = ForeignControllerInit.ConfigAddressParams({
                admin         : base.config.readAddress(".admin"),
                freezer       : base.config.readAddress(".safe"),  // TODO: Use real freezer addresses
                relayer       : base.config.readAddress(".safe"),
                oldController : base.config.readAddress(".controller")
            });

        ForeignControllerInit.AddressCheckParams memory checkAddresses
            = ForeignControllerInit.AddressCheckParams({
                psm           : Base.PSM3,
                cctpMessenger : Base.CCTP_TOKEN_MESSENGER,
                usdc          : Base.USDC,
                usds          : Base.USDS,
                susds         : Base.SUSDS
            });

        ControllerInstance memory controllerInst = ControllerInstance({
            almProxy   : base.config.readAddress(".almProxy"),
            controller : address(foreignController),
            rateLimits : base.config.readAddress(".rateLimits")
        });

        MintRecipient[] memory mintRecipients = new MintRecipient[](1);

        mintRecipients[0] = MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            mintRecipient : bytes32(uint256(uint160(address(mainnet.config.readAddress(".almProxy")))))
        });

        bytes32 aaveUsdcDepositKey   = RateLimitHelpers.makeAssetKey(foreignController.LIMIT_AAVE_DEPOSIT(), ATOKEN_USDC);
        bytes32 morphoUsdcDepositKey = RateLimitHelpers.makeAssetKey(foreignController.LIMIT_4626_DEPOSIT(), MORPHO_VAULT_USDC);
        bytes32 morphoUsdsDepositKey = RateLimitHelpers.makeAssetKey(foreignController.LIMIT_4626_DEPOSIT(), MORPHO_VAULT_USDS);

        ForeignControllerInit.init(
            configAddresses,
            checkAddresses,
            controllerInst,
            mintRecipients
        );

        RateLimits rateLimits = RateLimits(base.config.readAddress(".rateLimits"));

        rateLimits.setRateLimitData(aaveUsdcDepositKey,   1_000_000e6,   uint256(1_000_000e6)  / 1 days);
        rateLimits.setRateLimitData(morphoUsdcDepositKey, 25_000_000e6,  uint256(5_000_000e6)  / 1 days);
        rateLimits.setRateLimitData(morphoUsdsDepositKey, 25_000_000e18, uint256(5_000_000e18) / 1 days);

        vm.stopBroadcast();
    }

}
