// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { Script }       from "forge-std/Script.sol";
import { IERC20 }       from "forge-std/interfaces/IERC20.sol";
import { ScriptTools }  from "dss-test/ScriptTools.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { UsdsDeploy } from "lib/usds/deploy/UsdsDeploy.sol";
import { Usds }       from "lib/usds/src/Usds.sol";

import { SUsdsDeploy } from "lib/sdai/deploy/SUsdsDeploy.sol";
import { SUsds }       from "lib/sdai/src/SUsds.sol";

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

import { Jug }        from "../common/Jug.sol";
import { PauseProxy } from "../common/PauseProxy.sol";
import { Vat }        from "../common/Vat.sol";
import { UsdsJoin }   from "../common/UsdsJoin.sol";
import { PSM }        from "./PSM.sol";

struct Domain {
    uint256 forkId;
    address admin;
}

contract DeploySepolia is Script {

    address CCTP_TOKEN_MESSENGER_MAINNET = 0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5;
    address USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    address deployer;
    bytes32 ilk;

    Domain mainnet;
    Domain base;

    // Mainnet contracts
    Usds usds;
    SUsds susds;
    IERC20 usdc = IERC20(USDC);

    Vat vat;
    UsdsJoin usdsJoin;
    Jug jug;
    PauseProxy pauseProxy;

    AllocatorSharedInstance allocatorSharedInstance;
    AllocatorIlkInstance    allocatorIlkInstance;

    function _deployUSDS(address _deployer, address _owner) internal {
        address _usdsImp = address(new Usds());
        address _usds = address((new ERC1967Proxy(_usdsImp, abi.encodeCall(Usds.initialize, ()))));
        ScriptTools.switchOwner(_usds, _deployer, _owner);
        usds = Usds(_usds);
    }

    function setupMCDMocks() internal {
        vm.selectFork(mainnet.forkId);

        // Pre-requirements check
        require(usdc.balanceOf(deployer) >= 1e6, "USDC balance too low");
        
        vm.startBroadcast();

        _deployUSDS(deployer, mainnet.admin);

        vat        = new Vat();
        pauseProxy = new PauseProxy(mainnet.admin);
        usdsJoin   = new UsdsJoin(mainnet.admin, address(vat), address(usds));
        jug        = new Jug();

        // Mint some USDS into the join contract
        usds.mint(address(usdsJoin), 1_000_000e18);

        // Fill the psm with dai and usdc
        usdc.transfer(address(psm), 1e6);
        dai.transfer(address(psm), 1e18);

        vm.stopBroadcast();
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

        vm.stopBroadcast();
    }

    function setupALMController() internal {
        vm.selectFork(mainnet.forkId);
        
        vm.startBroadcast();

        MainnetControllerDeploy.deployFull({
            admin:   mainnet.admin,
            vault:   address(allocatorIlkInstance.vault),
            buffer:  address(allocatorIlkInstance.buffer),
            psm:     address(psm),
            daiUsds: address(daiUsds),
            cctp:    CCTP_TOKEN_MESSENGER_MAINNET,
            susds:   address(susds)
        })

        vm.stopBroadcast();
    }

    function run() public {
        deployer = msg.sender;
        ilk      = "ALLOCATOR-SPARK-1";

        setChain("sepolia_base", ChainData({
            rpcUrl: "https://base-sepolia-rpc.publicnode.com",
            chainId: 84532,
            name: "Sepolia Base Testnet"
        }));

        mainnet = Domain({
            forkId: vm.createFork(getChain("sepolia").rpcUrl),
            admin:  deployer
        });
        base = Domain({
            forkId: vm.createFork(getChain("sepolia_base").rpcUrl),
            admin:  deployer
        });

        setupMCDMocks();
        setupAllocationSystem();
        setupALMController();
    }

}
