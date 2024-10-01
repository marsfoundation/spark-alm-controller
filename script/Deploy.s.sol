// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import { ControllerInstance } from "../deploy/ControllerInstance.sol";

import { ForeignControllerDeploy, MainnetControllerDeploy } from "../deploy/ControllerDeploy.sol";

contract DeployMainnetAddresses is Script {

    address constant CCTP_MESSENGER = 0xBd3fa81B58Ba92a82136038B25aDec7066af3155;
    address constant PSM            = 0xf6e72Db5454dd049d0788e411b06CfAF16853042;
    address constant SPARK_PROXY    = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;

    function deployFull(string memory remoteRpcUrl) internal {
        vm.startBroadcast();

        ControllerInstance memory instance = ForeignControllerDeploy.deployFull({
            admin      : admin,
            almProxy   : almProxy,
            rateLimits : rateLimits,
            psm        : psm,
            usdc       : usdc,
            cctp       : cctp
        });

        vm.stopBroadcast();
    }

}

contract DeployMainnetFull is DeployMainnetAddresses, Script {

    function run() internal {
        vm.startBroadcast();

        ControllerInstance memory instance = ForeignControllerDeploy.deployFull({
            admin      : admin,
            almProxy   : almProxy,
            rateLimits : rateLimits,
            psm        : psm,
            usdc       : usdc,
            cctp       : cctp
        });

        vm.stopBroadcast();
    }

}

contract DeployBase is Deploy {

    function run() external {
        deploy(getChain("base").rpcUrl);
    }

}

contract DeployWorldChain is Deploy {

    function run() external {
        deploy(vm.envString("WORLD_CHAIN_RPC_URL"));
    }

    function deployForwarder(address receiver) internal override returns (address) {
        return address(new SSROracleForwarderOptimism(SUSDS, receiver, OptimismForwarder.L1_CROSS_DOMAIN_WORLD_CHAIN));
    }

    function deployReceiver(address forwarder, address oracle) internal override returns (address) {
        return address(new OptimismReceiver(forwarder, oracle));
    }

}

contract DeployGnosis is Deploy {

    function run() external {
        deploy(getChain("gnosis_chain").rpcUrl);
    }

    function deployForwarder(address receiver) internal override returns (address) {
        return address(new SSROracleForwarderGnosis(SUSDS, receiver));
    }

    function deployReceiver(address forwarder, address oracle) internal override returns (address) {
        return address(new AMBReceiver(Gnosis.L2_AMB, bytes32(uint256(1)), forwarder, oracle));
    }

}

contract DeployArbitrumOne is Deploy {

    function run() external {
        deploy(getChain("arbitrum_one").rpcUrl);
    }

    function deployForwarder(address receiver) internal override returns (address) {
        return address(new SSROracleForwarderArbitrum(SUSDS, receiver, ArbitrumForwarder.L1_CROSS_DOMAIN_ARBITRUM_ONE));
    }

    function deployReceiver(address forwarder, address oracle) internal override returns (address) {
        return address(new ArbitrumReceiver(forwarder, oracle));
    }

}
