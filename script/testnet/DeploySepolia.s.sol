// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { Script }           from "forge-std/Script.sol";
import { IERC20 }           from "forge-std/interfaces/IERC20.sol";
import { ScriptTools }      from "lib/dss-test/src/ScriptTools.sol";
import { MockERC20 }        from "erc20-helpers/MockERC20.sol";
import { CCTPForwarder }    from "xchain-helpers/src/forwarders/CCTPForwarder.sol";
import { Safe }             from "lib/safe-smart-account/contracts/Safe.sol";
import { SafeProxyFactory } from "lib/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";

import {
    AllocatorDeploy,
    AllocatorSharedInstance,
    AllocatorIlkInstance
} from "lib/dss-allocator/deploy/AllocatorDeploy.sol";
import {
    RolesLike,
    RegistryLike,
    VaultLike,
    BufferLike
} from "lib/dss-allocator/deploy/AllocatorInit.sol";
import { AllocatorBuffer } from "lib/dss-allocator/src/AllocatorBuffer.sol";
import { AllocatorVault }  from "lib/dss-allocator/src/AllocatorVault.sol";

import {
    MainnetControllerDeploy,
    ForeignControllerDeploy,
    ControllerInstance,
    MainnetController,
    ForeignController
} from "deploy/ControllerDeploy.sol";
import {
    MainnetControllerInit,
    ForeignControllerInit,
    RateLimitData,
    MintRecipient
} from "deploy/ControllerInit.sol";

import { PSM3 } from "lib/spark-psm/src/PSM3.sol";

import { Jug }          from "../common/Jug.sol";
import { Vat }          from "../common/Vat.sol";
import { UsdsJoin }     from "../common/UsdsJoin.sol";
import { DaiUsds }      from "../common/DaiUsds.sol";
import { PSM }          from "./PSM.sol";
import { RateProvider } from "./RateProvider.sol";
import { SUsds }        from "./SUsds.sol";

struct Domain {
    string  name;
    string  config;
    uint256 forkId;
    address admin;
}

contract DeploySepolia is Script {

    address constant CCTP_TOKEN_MESSENGER_MAINNET = 0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5;
    address constant CCTP_TOKEN_MESSENGER_BASE = 0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5;
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address constant USDC_BASE = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
    address constant SAFE_FACTORY = 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67;
    address constant SAFE_SINGLETON = 0x41675C099F32341bf84BFc5382aF534df5C7461a;

    uint256 constant USDC_UNIT_SIZE = 1000e6;        // Ballpark sizing of rate limits, tokens in PSMs, etc
    uint256 constant USDS_UNIT_SIZE = 1_000_000e18;  // Ballpark sizing of USDS to put in the join contracts, PSMs, etc

    address deployer;
    bytes32 ilk;

    Domain mainnet;
    Domain base;

    // Mainnet contracts
    MockERC20 dai;
    MockERC20 usds;
    SUsds susds;
    IERC20 usdc = IERC20(USDC);

    Vat vat;
    UsdsJoin usdsJoin;
    DaiUsds daiUsds;
    Jug jug;
    PSM psm;

    AllocatorSharedInstance allocatorSharedInstance;
    AllocatorIlkInstance    allocatorIlkInstance;

    ControllerInstance mainnetController;

    // Base contracts
    IERC20 usdcBase = IERC20(USDC_BASE);
    MockERC20 usdsBase;
    MockERC20 susdsBase;
    
    PSM3 psmBase;

    function setupMCDMocks() internal {
        vm.selectFork(mainnet.forkId);

        // Pre-requirements check
        require(usdc.balanceOf(deployer) >= USDC_UNIT_SIZE * 10, "USDC balance too low");
        require(USDC_UNIT_SIZE * 1000 <= usdc.balanceOf(deployer), "Unit size too large (don't want to run out of USDC)");
        
        vm.startBroadcast();

        // Init tokens
        dai = new MockERC20("DAI", "DAI", 18);
        usds = new MockERC20("USDS", "USDS", 18);
        susds = new SUsds(address(usds));

        // Init MCD contracts
        vat        = new Vat(mainnet.admin);
        usdsJoin   = new UsdsJoin(mainnet.admin, address(vat), address(usds));
        daiUsds    = new DaiUsds(mainnet.admin, address(dai), address(usds));
        jug        = new Jug();
        psm        = new PSM(mainnet.admin, address(usdc), address(dai));

        // Mint some USDS into the join contract
        usds.mint(address(usdsJoin), USDS_UNIT_SIZE);

        // Fill the psm with dai and usdc
        usdc.transfer(address(psm), USDC_UNIT_SIZE * 10);
        dai.mint(address(psm), USDS_UNIT_SIZE);

        // Fill the DaiUsds join contract
        dai.mint(address(daiUsds), USDS_UNIT_SIZE);
        usds.mint(address(daiUsds), USDS_UNIT_SIZE);

        vm.stopBroadcast();

        ScriptTools.exportContract(mainnet.name, "usdc", address(usdc));
        ScriptTools.exportContract(mainnet.name, "dai", address(dai));
        ScriptTools.exportContract(mainnet.name, "usds", address(usds));
        ScriptTools.exportContract(mainnet.name, "sUsds", address(susds));
    }

    function setupAllocationSystem() internal {
        vm.selectFork(mainnet.forkId);
        
        vm.startBroadcast();

        allocatorSharedInstance = AllocatorDeploy.deployShared(deployer, mainnet.admin);
        allocatorIlkInstance    = AllocatorDeploy.deployIlk(
            deployer,
            mainnet.admin,
            allocatorSharedInstance.roles,
            ilk,
            address(usdsJoin)
        );

        // Pull out relevant config from the AllocatorInit script
        // We don't want to execute it all because of our mocked MCD environment
        RegistryLike(allocatorSharedInstance.registry).file(ilk, "buffer", allocatorIlkInstance.buffer);
        VaultLike(allocatorIlkInstance.vault).file("jug", address(jug));
        BufferLike(allocatorIlkInstance.buffer).approve(address(usds), allocatorIlkInstance.vault, type(uint256).max);
        RolesLike(allocatorSharedInstance.roles).setIlkAdmin(ilk, mainnet.admin);
        ScriptTools.switchOwner(allocatorIlkInstance.vault,  allocatorIlkInstance.owner, mainnet.admin);
        ScriptTools.switchOwner(allocatorIlkInstance.buffer, allocatorIlkInstance.owner, mainnet.admin);

        // Custom contract permission changes (not relevant for production deploy)
        usdsJoin.transferOwnership(allocatorIlkInstance.vault);

        vm.stopBroadcast();

        ScriptTools.exportContract(mainnet.name, "allocatorOracle",   allocatorSharedInstance.oracle);
        ScriptTools.exportContract(mainnet.name, "allocatorRoles",    allocatorSharedInstance.roles);
        ScriptTools.exportContract(mainnet.name, "allocatorRegistry", allocatorSharedInstance.registry);
        ScriptTools.exportContract(mainnet.name, "allocatorVault",    allocatorIlkInstance.vault);
        ScriptTools.exportContract(mainnet.name, "allocatorBuffer",   allocatorIlkInstance.buffer);
    }

    function setupALMController() internal {
        vm.selectFork(mainnet.forkId);
        
        vm.startBroadcast();

        address safe = _setupSafe(mainnet.admin);

        ControllerInstance memory instance = mainnetController = MainnetControllerDeploy.deployFull({
            admin:   mainnet.admin,
            vault:   address(allocatorIlkInstance.vault),
            psm:     address(psm),
            daiUsds: address(daiUsds),
            cctp:    CCTP_TOKEN_MESSENGER_MAINNET,
            susds:   address(susds)
        });

        // Still constrained by the USDC_UNIT_SIZE
        RateLimitData memory rateLimitData18 = RateLimitData({
            maxAmount: USDC_UNIT_SIZE * 1e12 * 5,
            slope:     USDC_UNIT_SIZE * 1e12 / 4 hours
        });
        RateLimitData memory rateLimitData6 = RateLimitData({
            maxAmount: USDC_UNIT_SIZE * 5,
            slope:     USDC_UNIT_SIZE / 4 hours
        });
        RateLimitData memory unlimitedRateLimit = RateLimitData({
            maxAmount: type(uint256).max,
            slope:     0
        });

        // Configure this after Base ALM Proxy is deployed
        MintRecipient[] memory mintRecipients = new MintRecipient[](0);

        MainnetControllerInit.subDaoInitFull({
            addresses: MainnetControllerInit.AddressParams({
                admin: mainnet.admin,
                freezer: makeAddr("freezer"),
                relayer: safe,
                oldController: address(0),
                psm: address(psm),
                vault: address(allocatorIlkInstance.vault),
                buffer: address(allocatorIlkInstance.buffer),
                cctpMessenger: CCTP_TOKEN_MESSENGER_MAINNET,
                dai: address(dai),
                daiUsds: address(daiUsds),
                usdc: address(usdc),
                usds: address(usds),
                susds: address(susds)
            }),
            controllerInst: instance,
            data: MainnetControllerInit.InitRateLimitData({
                usdsMintData: rateLimitData18,
                usdsToUsdcData: rateLimitData6,
                usdcToCctpData: unlimitedRateLimit,
                cctpToBaseDomainData: rateLimitData6
            }),
            mintRecipients: mintRecipients
        });

        // Custom contract permission changes (not relevant for production deploy)
        daiUsds.transferOwnership(instance.almProxy);
        psm.transferOwnership(instance.almProxy);

        vm.stopBroadcast();

        ScriptTools.exportContract(mainnet.name, "safe",       safe);
        ScriptTools.exportContract(mainnet.name, "almProxy",   instance.almProxy);
        ScriptTools.exportContract(mainnet.name, "controller", instance.controller);
        ScriptTools.exportContract(mainnet.name, "rateLimits", instance.rateLimits);
    }

    function setupBasePSM() public {
        vm.selectFork(base.forkId);
        
        vm.startBroadcast();

        usdsBase = new MockERC20("USDS", "USDS", 18);
        susdsBase = new MockERC20("sUSDS", "sUSDS", 18);

        psmBase = new PSM3(
            base.admin,
            address(usdcBase),
            address(usdsBase),
            address(susdsBase),
            address(new RateProvider())
        );

        // Fill the PSM with USDS and sUSDS amounts
        usdsBase.mint(deployer, USDS_UNIT_SIZE);
        susdsBase.mint(deployer, USDS_UNIT_SIZE);
        usdsBase.approve(address(psmBase), type(uint256).max);
        susdsBase.approve(address(psmBase), type(uint256).max);
        psmBase.deposit(address(usdsBase), deployer, USDS_UNIT_SIZE);
        psmBase.deposit(address(susdsBase), deployer, USDS_UNIT_SIZE);

        vm.stopBroadcast();

        ScriptTools.exportContract(base.name, "usds", address(usdsBase));
        ScriptTools.exportContract(base.name, "sUsds", address(susdsBase));
        ScriptTools.exportContract(base.name, "usdc", address(usdcBase));
        ScriptTools.exportContract(base.name, "psm", address(psmBase));
    }
    
    function setupBaseALMController() public {
        vm.selectFork(base.forkId);
        
        vm.startBroadcast();

        address safe = _setupSafe(base.admin);

        ControllerInstance memory instance = ForeignControllerDeploy.deployFull({
            admin: base.admin,
            psm:   address(psmBase),
            usdc:  USDC_BASE,
            cctp:  CCTP_TOKEN_MESSENGER_BASE
        });

        RateLimitData memory rateLimitData18 = RateLimitData({
            maxAmount: USDC_UNIT_SIZE * 1e12 * 5,
            slope:     USDC_UNIT_SIZE * 1e12 / 4 hours
        });
        RateLimitData memory rateLimitData6 = RateLimitData({
            maxAmount: USDC_UNIT_SIZE * 5,
            slope:     USDC_UNIT_SIZE / 4 hours
        });
        RateLimitData memory unlimitedRateLimit = RateLimitData({
            maxAmount: type(uint256).max,
            slope:     0
        });

        MintRecipient[] memory mintRecipients = new MintRecipient[](1);
        mintRecipients[0] = MintRecipient({
            domain:        CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            mintRecipient: bytes32(uint256(uint160(mainnetController.almProxy)))
        });

        ForeignControllerInit.init({
            addresses: ForeignControllerInit.AddressParams({
                admin: base.admin,
                freezer: makeAddr("freezer"),
                relayer: safe,
                oldController: address(0),
                psm: address(psmBase),
                cctpMessenger: CCTP_TOKEN_MESSENGER_BASE,
                usdc: USDC_BASE,
                usds: USDC_BASE,
                susds: USDC_BASE
            }),
            controllerInst: instance,
            data: ForeignControllerInit.InitRateLimitData({
                usdcDepositData: rateLimitData6,
                usdcWithdrawData: rateLimitData6,
                usdsDepositData: rateLimitData18,
                usdsWithdrawData: rateLimitData18,
                susdsDepositData: rateLimitData18,
                susdsWithdrawData: rateLimitData18,
                usdcToCctpData: unlimitedRateLimit,
                cctpToEthereumDomainData: rateLimitData6
            }),
            mintRecipients: mintRecipients
        });

        vm.stopBroadcast();

        vm.selectFork(mainnet.forkId);
        
        vm.startBroadcast();

        // Doing this after the fact because we have the address now
        MainnetController(mainnetController.controller).setMintRecipient(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE, bytes32(uint256(uint160(instance.almProxy))));

        vm.stopBroadcast();

        ScriptTools.exportContract(base.name, "safe",       safe);
        ScriptTools.exportContract(base.name, "almProxy",   instance.almProxy);
        ScriptTools.exportContract(base.name, "controller", instance.controller);
        ScriptTools.exportContract(base.name, "rateLimits", instance.rateLimits);
    }

    function run() public {
        vm.setEnv("FOUNDRY_ROOT_CHAINID", "11155111");
        vm.setEnv("FOUNDRY_EXPORTS_OVERWRITE_LATEST", "true");

        deployer = msg.sender;
        ilk      = "ALLOCATOR-SPARK-1";

        setChain("sepolia_base", ChainData({
            rpcUrl: "https://base-sepolia-rpc.publicnode.com",
            chainId: 84532,
            name: "Sepolia Base Testnet"
        }));

        mainnet = Domain({
            name:   "mainnet",
            config: ScriptTools.loadConfig("mainnet"),
            forkId: vm.createFork(getChain("sepolia").rpcUrl),
            admin:  deployer
        });
        base = Domain({
            name:   "base",
            config: ScriptTools.loadConfig("base"),
            forkId: vm.createFork(getChain("sepolia_base").rpcUrl),
            admin:  deployer
        });

        setupMCDMocks();
        setupAllocationSystem();
        setupALMController();
        setupBasePSM();
        setupBaseALMController();

        ScriptTools.exportContract(mainnet.name, "admin", deployer);
        ScriptTools.exportContract(base.name, "admin", deployer);
    }

    function _setupSafe(
        address relayerAddress
    ) internal returns (address) {
        SafeProxyFactory factory = SafeProxyFactory(SAFE_FACTORY);

        address[] memory owners = new address[](1);
        owners[0] = relayerAddress;

        bytes memory initData = abi.encodeCall(Safe.setup, (
            owners,
            1,
            address(0),
            "",
            address(0),
            address(0),
            0,
            payable(address(0))));
        return address(factory.createProxyWithNonce(SAFE_SINGLETON, initData, 0));
    }

}
