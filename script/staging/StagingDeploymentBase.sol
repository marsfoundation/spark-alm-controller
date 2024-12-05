// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import {
    AllocatorDeploy,
    AllocatorIlkInstance,
    AllocatorSharedInstance
} from "dss-allocator/deploy/AllocatorDeploy.sol";

import {
    BufferLike,
    RegistryLike,
    RolesLike,
    VaultLike
} from "dss-allocator/deploy/AllocatorInit.sol";

import { AllocatorBuffer } from "dss-allocator/src/AllocatorBuffer.sol";
import { AllocatorVault }  from "dss-allocator/src/AllocatorVault.sol";

import { ScriptTools } from "dss-test/ScriptTools.sol";

import { MockERC20 } from "erc20-helpers/MockERC20.sol";

import { IERC20 }  from "forge-std/interfaces/IERC20.sol";
import { Script }  from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";

import { PSM3Deploy } from "spark-psm/deploy/PSM3Deploy.sol";

import { CCTPForwarder } from "xchain-helpers/src/forwarders/CCTPForwarder.sol";

import {
    ControllerInstance,
    ForeignController,
    ForeignControllerDeploy,
    MainnetController,
    MainnetControllerDeploy
} from "../../deploy/ControllerDeploy.sol";

import {
    ForeignControllerInit,
    MainnetControllerInit,
    MintRecipient,
    RateLimitData
} from "../../deploy/ControllerInit.sol";

import { MockDaiUsds }      from "./mocks/MockDaiUsds.sol";
import { MockJug }          from "./mocks/MockJug.sol";
import { MockPSM }          from "./mocks/MockPSM.sol";
import { MockRateProvider } from "./mocks/MockRateProvider.sol";
import { MockSUsds }        from "./mocks/MockSUsds.sol";
import { MockUsdsJoin }     from "./mocks/MockUsdsJoin.sol";
import { MockVat }          from "./mocks/MockVat.sol";
import { PSMWrapper }       from "./mocks/PSMWrapper.sol";

struct Domain {
    string  name;
    string  config;
    uint256 forkId;
    address admin;
}

contract StagingDeploymentBase is Script {

    using stdJson     for string;
    using ScriptTools for string;

    /**********************************************************************************************/
    /*** Existing addresses (populated from JSON)                                               ***/
    /**********************************************************************************************/

    address CCTP_TOKEN_MESSENGER_BASE;
    address CCTP_TOKEN_MESSENGER_MAINNET;

    address SAFE_MAINNET;
    address SAFE_BASE;
    address USDC;
    address USDC_BASE;

    /**********************************************************************************************/
    /*** Mainnet existing/mock deployments                                                      ***/
    /**********************************************************************************************/

    address dai;
    address daiUsds;
    address livePsm;
    address psm;
    address susds;
    address usds;

    // Mocked MCD contracts
    address jug;
    address usdsJoin;
    address vat;

    /**********************************************************************************************/
    /*** Mainnet allocation system deployments                                                  ***/
    /**********************************************************************************************/

    address oracle;
    address roles;
    address registry;

    address buffer;
    address vault;

    /**********************************************************************************************/
    /*** ALM system deployments                                                                 ***/
    /**********************************************************************************************/

    address baseAlmProxy;
    address baseController;

    address mainnetAlmProxy;
    address mainnetController;

    /**********************************************************************************************/
    /*** Base dependency deployments                                                            ***/
    /**********************************************************************************************/

    address usdsBase;
    address susdsBase;

    address psmBase;

    /**********************************************************************************************/
    /*** Deployment-specific variables                                                          ***/
    /**********************************************************************************************/

    address deployer;
    bytes32 ilk;

    uint256 USDC_UNIT_SIZE;
    uint256 USDS_UNIT_SIZE;

    Domain mainnet;
    Domain base;

    /**********************************************************************************************/
    /*** Helper functions                                                                       ***/
    /**********************************************************************************************/

    function _setUpDependencies(bool useLiveContracts) internal {
        vm.selectFork(mainnet.forkId);
        vm.startBroadcast();

        // Step 1: Deploy or use existing contracts for tokens, DaiUsds and PSM
        if (useLiveContracts) _useLiveContracts();
        else _setUpMocks();

        // Step 2: Deploy mocked MCD contracts

        vat      = address(new MockVat(mainnet.admin));
        usdsJoin = address(new MockUsdsJoin(mainnet.admin, vat, usds));
        jug      = address(new MockJug());

        // Step 3: Transfer USDS into the join contract

        require(IERC20(usds).balanceOf(deployer) >= USDS_UNIT_SIZE, "USDS balance too low");

        IERC20(usds).transfer(usdsJoin, USDS_UNIT_SIZE);

        vm.stopBroadcast();

        // Step 4: Export all deployed addresses

        ScriptTools.exportContract(mainnet.name, "dai",      dai);
        ScriptTools.exportContract(mainnet.name, "daiUsds",  daiUsds);
        ScriptTools.exportContract(mainnet.name, "jug",      jug);
        ScriptTools.exportContract(mainnet.name, "psm",      psm);
        ScriptTools.exportContract(mainnet.name, "susds",    susds);
        ScriptTools.exportContract(mainnet.name, "usdc",     USDC);
        ScriptTools.exportContract(mainnet.name, "usds",     usds);
        ScriptTools.exportContract(mainnet.name, "usdsJoin", usdsJoin);
        ScriptTools.exportContract(mainnet.name, "vat",      vat);
    }

    function _useLiveContracts() internal {
        dai     = mainnet.config.readAddress(".dai");
        usds    = mainnet.config.readAddress(".usds");
        susds   = mainnet.config.readAddress(".susds");
        daiUsds = mainnet.config.readAddress(".daiUsds");
        livePsm = mainnet.config.readAddress(".psm");

        // This contract is necessary to get past the `kiss` requirement from the pause proxy.
        // It wraps the `noFee` calls with regular PSM swap calls.
        psm = address(new PSMWrapper(USDC, dai, livePsm));

        // NOTE: This is a HACK to make sure that `fill` doesn't get called until the call reverts.
        //       Because this PSM contract is a wrapper over the real PSM, the controller queries
        //       the DAI balance of the PSM to check if it should fill or not. Filling with DAI
        //       fills the live PSM NOT the wrapper, so the while loop will continue until the
        //       function reverts. Dealing DAI into the wrapper will prevent fill from being called.
        IERC20(dai).transfer(psm, USDS_UNIT_SIZE);
    }

    function _setUpMocks() internal {
        require(IERC20(USDC).balanceOf(deployer) >= USDC_UNIT_SIZE * 10, "USDC balance too low");

        dai   = address(new MockERC20("DAI",  "DAI",  18));
        usds  = address(new MockERC20("USDS", "USDS", 18));
        susds = address(new MockSUsds(usds));

        daiUsds = address(new MockDaiUsds(mainnet.admin, dai, usds));
        psm     = address(new MockPSM(mainnet.admin, USDC, dai));

        // Mint USDS into deployer so it can be transferred into usdsJoin
        MockERC20(usds).mint(deployer, USDS_UNIT_SIZE);

        // Fill the psm with dai and usdc
        IERC20(USDC).transfer(psm, USDC_UNIT_SIZE * 10);
        MockERC20(dai).mint(psm, USDS_UNIT_SIZE);

        // Fill the DaiUsds contract with both tokens
        MockERC20(dai).mint(daiUsds, USDS_UNIT_SIZE);
        MockERC20(usds).mint(daiUsds, USDS_UNIT_SIZE);
    }

    function _setUpAllocationSystem() internal {
        vm.selectFork(mainnet.forkId);
        vm.startBroadcast();

        // Step 1: Deploy allocation system

        AllocatorSharedInstance memory allocatorSharedInstance
            = AllocatorDeploy.deployShared(deployer, mainnet.admin);

        AllocatorIlkInstance memory allocatorIlkInstance = AllocatorDeploy.deployIlk(
            deployer,
            mainnet.admin,
            allocatorSharedInstance.roles,
            ilk,
            usdsJoin
        );

        oracle   = allocatorSharedInstance.oracle;
        registry = allocatorSharedInstance.registry;
        roles    = allocatorSharedInstance.roles;

        buffer = allocatorIlkInstance.buffer;
        vault  = allocatorIlkInstance.vault;

        // Step 2: Perform partial initialization (not using library because of mocked MCD)

        RegistryLike(registry).file(ilk, "buffer", buffer);
        VaultLike(vault).file("jug", jug);
        BufferLike(buffer).approve(usds, vault, type(uint256).max);
        RolesLike(roles).setIlkAdmin(ilk, mainnet.admin);

        // Step 3: Move ownership of both the vault and buffer to the admin

        ScriptTools.switchOwner(vault,  allocatorIlkInstance.owner, mainnet.admin);
        ScriptTools.switchOwner(buffer, allocatorIlkInstance.owner, mainnet.admin);

        vm.stopBroadcast();

        // Step 4: Export all deployed addresses

        ScriptTools.exportContract(mainnet.name, "allocatorOracle",   oracle);
        ScriptTools.exportContract(mainnet.name, "allocatorRegistry", registry);
        ScriptTools.exportContract(mainnet.name, "allocatorRoles",    roles);

        ScriptTools.exportContract(mainnet.name, "allocatorBuffer", buffer);
        ScriptTools.exportContract(mainnet.name, "allocatorVault",  vault);
    }

    function _setUpALMController() internal {
        vm.selectFork(mainnet.forkId);
        vm.startBroadcast();

        // Step 1: Deploy ALM controller

        ControllerInstance memory instance = MainnetControllerDeploy.deployFull({
            admin   : mainnet.admin,
            vault   : vault,
            psm     : psm,
            daiUsds : daiUsds,
            cctp    : CCTP_TOKEN_MESSENGER_MAINNET,
            susds   : susds
        });

        mainnetAlmProxy   = instance.almProxy;
        mainnetController = instance.controller;

        // Step 2: Initialize ALM controller, setting rate limits, mint recipients, and setting ACL

        // Still constrained by the USDC_UNIT_SIZE
        RateLimitData memory rateLimitData18 = RateLimitData({
            maxAmount : USDC_UNIT_SIZE * 1e12 * 5,
            slope     : USDC_UNIT_SIZE * 1e12 / 4 hours
        });
        RateLimitData memory rateLimitData6 = RateLimitData({
            maxAmount : USDC_UNIT_SIZE * 5,
            slope     : USDC_UNIT_SIZE / 4 hours
        });
        RateLimitData memory unlimitedRateLimit = RateLimitData({
            maxAmount : type(uint256).max,
            slope     : 0
        });

        // Configure this after Base ALM Proxy is deployed
        MintRecipient[] memory mintRecipients = new MintRecipient[](0);

        MainnetControllerInit.subDaoInitFull({
            addresses: MainnetControllerInit.AddressParams({
                admin         : mainnet.admin,
                freezer       : makeAddr("freezer"),
                relayer       : SAFE_MAINNET,
                oldController : address(0),
                psm           : psm,
                vault         : vault,
                buffer        : buffer,
                cctpMessenger : CCTP_TOKEN_MESSENGER_MAINNET,
                dai           : dai,
                daiUsds       : daiUsds,
                usdc          : USDC,
                usds          : usds,
                susds         : susds
            }),
            controllerInst: instance,
            data: MainnetControllerInit.InitRateLimitData({
                usdsMintData         : rateLimitData18,
                usdsToUsdcData       : rateLimitData6,
                usdcToCctpData       : unlimitedRateLimit,
                cctpToBaseDomainData : rateLimitData6,
                susdsDepositData     : rateLimitData18
            }),
            mintRecipients: mintRecipients
        });

        // Step 3: Transfer ownership of mock usdsJoin to the vault (able to mint usds)

        MockUsdsJoin(usdsJoin).transferOwnership(vault);

        vm.stopBroadcast();

        // Step 4: Export all deployed addresses

        ScriptTools.exportContract(mainnet.name, "safe",       SAFE_MAINNET);
        ScriptTools.exportContract(mainnet.name, "almProxy",   instance.almProxy);
        ScriptTools.exportContract(mainnet.name, "controller", instance.controller);
        ScriptTools.exportContract(mainnet.name, "rateLimits", instance.rateLimits);
    }

    function _setUpBasePSM() public {
        vm.selectFork(base.forkId);
        vm.startBroadcast();

        usdsBase  = address(new MockERC20("USDS",  "USDS",  18));
        susdsBase = address(new MockERC20("sUSDS", "sUSDS", 18));

        // Mint enough for seeded deposit
        MockERC20(usdsBase).mint(deployer, 1e18);

        psmBase = PSM3Deploy.deploy({
            owner        : deployer,
            usdc         : USDC_BASE,
            usds         : usdsBase,
            susds        : susdsBase,
            rateProvider : address(new MockRateProvider())
        });

        vm.stopBroadcast();

        ScriptTools.exportContract(base.name, "usds",  usdsBase);
        ScriptTools.exportContract(base.name, "susds", susdsBase);
        ScriptTools.exportContract(base.name, "usdc",  USDC_BASE);
        ScriptTools.exportContract(base.name, "psm",   psmBase);
    }

    function _setUpBaseALMController() public {
        vm.selectFork(base.forkId);
        vm.startBroadcast();

        // Step 1: Deploy ALM controller

        ControllerInstance memory instance = ForeignControllerDeploy.deployFull({
            admin : base.admin,
            psm   : address(psmBase),
            usdc  : USDC_BASE,
            cctp  : CCTP_TOKEN_MESSENGER_BASE
        });

        baseAlmProxy   = instance.almProxy;
        baseController = instance.controller;

        // Step 2: Initialize ALM controller, setting rate limits, mint recipients, and setting ACL

        // Still constrained by the USDC_UNIT_SIZE
        RateLimitData memory rateLimitData18 = RateLimitData({
            maxAmount : USDC_UNIT_SIZE * 1e12 * 5,
            slope     : USDC_UNIT_SIZE * 1e12 / 4 hours
        });
        RateLimitData memory rateLimitData6 = RateLimitData({
            maxAmount : USDC_UNIT_SIZE * 5,
            slope     : USDC_UNIT_SIZE / 4 hours
        });
        RateLimitData memory unlimitedRateLimit = RateLimitData({
            maxAmount : type(uint256).max,
            slope     : 0
        });

        MintRecipient[] memory mintRecipients = new MintRecipient[](1);
        mintRecipients[0] = MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            mintRecipient : bytes32(uint256(uint160(mainnetAlmProxy)))
        });

        ForeignControllerInit.init({
            addresses: ForeignControllerInit.AddressParams({
                admin         : base.admin,
                freezer       : makeAddr("freezer"),
                relayer       : SAFE_BASE,
                oldController : address(0),
                psm           : psmBase,
                cctpMessenger : CCTP_TOKEN_MESSENGER_BASE,
                usdc          : USDC_BASE,
                usds          : usdsBase,
                susds         : susdsBase
            }),
            controllerInst: instance,
            data: ForeignControllerInit.InitRateLimitData({
                usdcDepositData          : rateLimitData6,
                usdcWithdrawData         : rateLimitData6,
                usdsDepositData          : rateLimitData18,
                usdsWithdrawData         : rateLimitData18,
                susdsDepositData         : rateLimitData18,
                susdsWithdrawData        : rateLimitData18,
                usdcToCctpData           : unlimitedRateLimit,
                cctpToEthereumDomainData : rateLimitData6
            }),
            mintRecipients: mintRecipients
        });

        // Step 3: Seed ALM Proxy with initial amounts of USDS and sUSDS

        MockERC20(usdsBase).mint(baseAlmProxy,  USDS_UNIT_SIZE);
        MockERC20(susdsBase).mint(baseAlmProxy, USDS_UNIT_SIZE);

        vm.stopBroadcast();

        // Step 4: Export all deployed addresses

        ScriptTools.exportContract(base.name, "safe",       SAFE_BASE);
        ScriptTools.exportContract(base.name, "almProxy",   instance.almProxy);
        ScriptTools.exportContract(base.name, "controller", instance.controller);
        ScriptTools.exportContract(base.name, "rateLimits", instance.rateLimits);
    }

    function _setBaseMintRecipient() internal {
        vm.selectFork(mainnet.forkId);
        vm.startBroadcast();

        MainnetController(mainnetController).setMintRecipient(
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            bytes32(uint256(uint160(baseAlmProxy)))
        );

        vm.stopBroadcast();
    }

    function _transferOwnershipOfMocks() internal {
        vm.selectFork(mainnet.forkId);
        vm.startBroadcast();

        MockDaiUsds(daiUsds).transferOwnership(mainnetAlmProxy);
        MockPSM(psm).transferOwnership(mainnetAlmProxy);

        vm.stopBroadcast();
    }

    function _runFullDeployment(bool useLiveContracts) internal {
        // Step 1: Load general configuration

        string memory common = ScriptTools.loadConfig("common");

        ilk = common.readString(".ilk").stringToBytes32();

        // Ballpark sizing of rate limits, tokens in PSMs, etc
        // Ballpark sizing of USDS to put in the join contracts, PSMs, etc
        USDC_UNIT_SIZE = common.readUint(".usdcUnitSize") * 1e6;
        USDS_UNIT_SIZE = common.readUint(".usdsUnitSize") * 1e18;

        // Step 2: Load domain-specific configurations

        CCTP_TOKEN_MESSENGER_MAINNET = mainnet.config.readAddress(".cctpTokenMessenger");
        CCTP_TOKEN_MESSENGER_BASE    = base.config.readAddress(".cctpTokenMessenger");

        SAFE_MAINNET = mainnet.config.readAddress(".safe");
        USDC         = mainnet.config.readAddress(".usdc");

        SAFE_BASE = base.config.readAddress(".safe");
        USDC_BASE = base.config.readAddress(".usdc");

        // Step 3: Run deployment scripts after setting storage variables

        _setUpDependencies(useLiveContracts);
        _setUpAllocationSystem();
        _setUpALMController();
        _setUpBasePSM();
        _setUpBaseALMController();
        _setBaseMintRecipient();

        if (!useLiveContracts) _transferOwnershipOfMocks();

        ScriptTools.exportContract(mainnet.name, "admin", deployer);
        ScriptTools.exportContract(base.name,    "admin", deployer);
    }

}
