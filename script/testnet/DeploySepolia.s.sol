// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { Script, console } from "forge-std/Script.sol";
import { IERC20 }          from "forge-std/interfaces/IERC20.sol";
import { ScriptTools }     from "dss-test/ScriptTools.sol";
import { ERC1967Proxy }    from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { MockERC20 }       from "erc20-helpers/MockERC20.sol";

import { Usds }  from "lib/usds/src/Usds.sol";
import { SUsds } from "lib/sdai/src/SUsds.sol";

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
    ControllerInstance
} from "deploy/ControllerDeploy.sol";
import {
    MainnetControllerInit,
    RateLimitData
} from "deploy/ControllerInit.sol";

import { Jug }        from "../common/Jug.sol";
import { PauseProxy } from "../common/PauseProxy.sol";
import { Vat }        from "../common/Vat.sol";
import { UsdsJoin }   from "../common/UsdsJoin.sol";
import { DaiUsds }    from "../common/DaiUsds.sol";
import { PSM }        from "./PSM.sol";

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

    uint256 constant USDC_UNIT_SIZE = 1000e6;        // Ballpark sizing of rate limits, tokens in PSMs, etc
    uint256 constant USDS_UNIT_SIZE = 1_000_000e18;  // Ballpark sizing of USDS to put in the join contracts, PSMs, etc

    address deployer;
    bytes32 ilk;

    Domain mainnet;
    Domain base;

    // Mainnet contracts
    MockERC20 dai;
    Usds usds;
    SUsds susds;
    IERC20 usdc = IERC20(USDC);

    Vat vat;
    UsdsJoin usdsJoin;
    DaiUsds daiUsds;
    Jug jug;
    PauseProxy pauseProxy;
    PSM psm;

    AllocatorSharedInstance allocatorSharedInstance;
    AllocatorIlkInstance    allocatorIlkInstance;

    // Base contracts

    function _deployUSDS(address _deployer, address _owner) internal {
        address _usdsImp = address(new Usds());
        address _usds = address((new ERC1967Proxy(_usdsImp, abi.encodeCall(Usds.initialize, ()))));
        ScriptTools.switchOwner(_usds, _deployer, _owner);
        usds = Usds(_usds);
    }

    function _deploySUSDS(address _deployer, address _owner) internal {
        address _sUsdsImp = address(new SUsds(address(usdsJoin), address(0)));
        address _sUsds = address(new ERC1967Proxy(_sUsdsImp, abi.encodeCall(SUsds.initialize, ())));
        ScriptTools.switchOwner(_sUsds, _deployer, _owner);
        susds = SUsds(_sUsds);
    }

    function setupMCDMocks() internal {
        vm.selectFork(mainnet.forkId);

        // Pre-requirements check
        require(usdc.balanceOf(deployer) >= USDC_UNIT_SIZE * 10, "USDC balance too low");
        require(USDC_UNIT_SIZE * 1000 <= usdc.balanceOf(deployer), "Unit size too large (don't want to run out of USDC)");
        
        vm.startBroadcast();

        // Init tokens
        dai = new MockERC20("DAI", "DAI", 18);
        _deployUSDS(deployer, mainnet.admin);

        // Init MCD contracts
        vat        = new Vat();
        pauseProxy = new PauseProxy(mainnet.admin);
        usdsJoin   = new UsdsJoin(mainnet.admin, address(vat), address(usds));
        daiUsds    = new DaiUsds(mainnet.admin, address(dai), address(usds));
        jug        = new Jug();
        psm        = new PSM(mainnet.admin, address(usdc), address(dai));

        // Dependency on usdsJoin
        _deploySUSDS(deployer, mainnet.admin);

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

        ControllerInstance memory instance = MainnetControllerDeploy.deployFull({
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

        MainnetControllerInit.subDaoInitFull({
            params: MainnetControllerInit.AddressParams({
                admin:   mainnet.admin,
                freezer: makeAddr("freezer"),
                relayer: deployer, // TODO: replace with SAFE
                oldController: address(0),
                psm: address(psm),
                cctpMessenger: CCTP_TOKEN_MESSENGER_MAINNET,
                dai: address(dai),
                daiUsds: address(daiUsds),
                usdc: address(usdc),
                usds: address(usds),
                susds: address(susds)
            }),
            controllerInst: instance,
            ilkInst: allocatorIlkInstance,
            data: MainnetControllerInit.InitRateLimitData({
                usdsMintData: rateLimitData18,
                usdcToUsdsData: rateLimitData6,
                usdcToCctpData: unlimitedRateLimit,
                cctpToBaseDomainData: rateLimitData6
            })
        });

        // Custom contract permission changes (not relevant for production deploy)
        daiUsds.transferOwnership(instance.almProxy);
        psm.transferOwnership(instance.almProxy);

        vm.stopBroadcast();

        ScriptTools.exportContract(mainnet.name, "almProxy",   instance.almProxy);
        ScriptTools.exportContract(mainnet.name, "controller", instance.controller);
        ScriptTools.exportContract(mainnet.name, "rateLimits", instance.rateLimits);
    }
    
    function setupBaseALMController() public {
        vm.selectFork(base.forkId);
        
        vm.startBroadcast();

        ControllerInstance memory instance = ForeignControllerDeploy.deployFull({
            admin: mainnet.admin,
            psm:   address(psmBase),
            usdc:  USDC_BASE,
            cctp:  CCTP_TOKEN_MESSENGER_BASE
        });

        RateLimitData memory rateLimitData6 = RateLimitData({
            maxAmount: USDC_UNIT_SIZE * 5,
            slope:     USDC_UNIT_SIZE / 4 hours
        });
        RateLimitData memory unlimitedRateLimit = RateLimitData({
            maxAmount: type(uint256).max,
            slope:     0
        });

        ForeignControllerDeploy.init({
            params: ForeignControllerDeploy.AddressParams({
                admin:   base.admin,
                freezer: makeAddr("freezer"),
                relayer: deployer, // TODO: replace with SAFE
                oldController: address(0),
                psm: address(psmBase),
                cctpMessenger: CCTP_TOKEN_MESSENGER_BASE,
                usdc: USDC_BASE,
                usds: USDC_BASE,
                susds: USDC_BASE
            }),
            controllerInst: instance,
            data: ForeignControllerDeploy.InitRateLimitData({
                usdcDepositData: rateLimitData6,
                usdcWithdrawData: rateLimitData6,
                usdcToCctpData: unlimitedRateLimit,
                cctpToEthereumDomainData: rateLimitData6
            })
        });

        // Custom contract permission changes (not relevant for production deploy)
        daiUsds.transferOwnership(instance.almProxy);
        psm.transferOwnership(instance.almProxy);

        vm.stopBroadcast();

        ScriptTools.exportContract(mainnet.name, "almProxy",   instance.almProxy);
        ScriptTools.exportContract(mainnet.name, "controller", instance.controller);
        ScriptTools.exportContract(mainnet.name, "rateLimits", instance.rateLimits);
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
        setupBaseALMController();

        ScriptTools.exportContract(mainnet.name, "admin", deployer);
        ScriptTools.exportContract(base.name, "admin", deployer);
    }

}
