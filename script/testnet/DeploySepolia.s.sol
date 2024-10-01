// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import { Script } from "forge-std/Script.sol";

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
    AllocatorInit,
    AllocatorIlkConfig,
    VaultLike
} from "lib/dss-allocator/deploy/AllocatorInit.sol";
import { AllocatorBuffer } from "lib/dss-allocator/src/AllocatorBuffer.sol";
import { AllocatorVault }  from "lib/dss-allocator/src/AllocatorVault.sol";

import { Jug }        from "../common/Jug.sol";
import { PauseProxy } from "../common/PauseProxy.sol";
import { UsdsJoin }   from "../common/UsdsJoin.sol";
import { Vat }        from "../common/Vat.sol";

struct Domain {
    uint256 forkId;
    address admin;
}

contract DeploySepolia is Script {

    address deployer;

    Domain mainnet;
    Domain base;

    // Mainnet contracts
    Usds usds;
    SUsds susds;

    Vat vat;
    UsdsJoin usdsJoin;
    Jug jug;
    PauseProxy pauseProxy;

    function deployMCDMocks() internal {
        usds = UsdsDeploy.deploy(deployer, deployer, address(vat));

        pauseProxy = new PauseProxy(deployer);
        vat        = new Vat();
        usdsJoin   = new UsdsJoin();
        jug        = new Jug();
    }

    function setupAllocationSystem() internal {
        vm.selectFork(mainnet.forkId);
        
        vm.startBroadcast();

        mainnet.allocatorSharedInstance = AllocatorDeploy.deployShared(deployer, mainnet.admin);
        mainnet.allocatorIlkInstance    = AllocatorDeploy.deployIlk(
            deployer,
            mainnet.admin,
            mainnet.allocatorSharedInstance.roles,
            mainnet.config.readString(".ilk").stringToBytes32(),
            mainnet.usdsInstance.usdsJoin
        );

        vm.stopBroadcast();
    }

    function run() public {
        deployer = msg.sender;

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

        deployMCDMocks();
    }

}
