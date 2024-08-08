// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "dss-test/DssTest.sol";

import { AllocatorInit, AllocatorIlkConfig } from "dss-allocator/deploy/AllocatorInit.sol";

import {
    AllocatorIlkInstance,
    AllocatorSharedInstance
} from "dss-allocator/deploy/AllocatorInstances.sol";

import { AllocatorDeploy } from "dss-allocator/deploy/AllocatorDeploy.sol";

import { ALMProxy }           from "src/ALMProxy.sol";
import { EthereumController } from "src/EthereumController.sol";

interface ChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

contract ForkTestBase is DssTest {

    /**********************************************************************************************/
    /*** Mainnet addresses                                                                      ***/
    /**********************************************************************************************/

    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    DssInstance dss;  // Mainnet DSS

    address ILK_REGISTRY;
    address PAUSE_PROXY;
    address USDC;

    /**********************************************************************************************/
    /*** NST addresses to be deployed                                                           ***/
    /**********************************************************************************************/

    AllocatorSharedInstance sharedInst;

    /**********************************************************************************************/
    /*** Allocation system deployments                                                          ***/
    /**********************************************************************************************/

    /**********************************************************************************************/
    /*** ALM system deployments                                                                 ***/
    /**********************************************************************************************/

    ALMProxy           almProxy;
    EthereumController ethereumController;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 20484600);  // August 8, 2024

        dss          = MCD.loadFromChainlog(LOG);
        PAUSE_PROXY  = ChainlogLike(LOG).getAddress("MCD_PAUSE_PROXY");
        ILK_REGISTRY = ChainlogLike(LOG).getAddress("ILK_REGISTRY");
        USDC         = ChainlogLike(LOG).getAddress("USDC");

        sharedInst = AllocatorDeploy.deployShared(address(this), PAUSE_PROXY);
    }

    function test_base() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

}
