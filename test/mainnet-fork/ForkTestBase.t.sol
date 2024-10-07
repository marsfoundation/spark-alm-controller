// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "dss-test/DssTest.sol";

import { AllocatorInit, AllocatorIlkConfig } from "dss-allocator/deploy/AllocatorInit.sol";

import {
    AllocatorIlkInstance,
    AllocatorSharedInstance
} from "dss-allocator/deploy/AllocatorInstances.sol";

import { AllocatorDeploy } from "dss-allocator/deploy/AllocatorDeploy.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { ISUsds } from "sdai/src/ISUsds.sol";

import { Ethereum } from "spark-address-registry/Ethereum.sol";

import { Bridge }                from "xchain-helpers/src/testing/Bridge.sol";
import { CCTPForwarder }         from "xchain-helpers/src/forwarders/CCTPForwarder.sol";
import { Domain, DomainHelpers } from "xchain-helpers/src/testing/Domain.sol";

import { MainnetControllerDeploy } from "deploy/ControllerDeploy.sol";
import { ControllerInstance }      from "deploy/ControllerInstance.sol";

import { MainnetControllerInit,
    MintRecipient,
    RateLimitData
} from "deploy/ControllerInit.sol";


import { ALMProxy }          from "src/ALMProxy.sol";
import { RateLimits }        from "src/RateLimits.sol";
import { RateLimitHelpers }  from "src/RateLimitHelpers.sol";
import { MainnetController } from "src/MainnetController.sol";

interface IChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

interface IBufferLike {
    function approve(address, address, uint256) external;
}

interface IPSMLike {
    function bud(address) external view returns (uint256);
    function pocket() external view returns (address);
    function kiss(address) external;
    function rush() external view returns (uint256);
}

interface IVaultLike {
    function rely(address) external;
    function wards(address) external returns (uint256);
}

contract ForkTestBase is DssTest {

    using DomainHelpers for *;

    /**********************************************************************************************/
    /*** Constants/state variables                                                              ***/
    /**********************************************************************************************/

    bytes32 constant ilk = "ILK-A";

    uint256 constant INK = 1e12 * 1e18;  // Ink initialization amount

    uint256 constant SEVEN_PCT_APY = 1.000000002145441671308778766e27;  // 7% APY (current DSR)
    uint256 constant EIGHT_PCT_APY = 1.000000002440418608258400030e27;  // 8% APY (current DSR + 1%)

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    address freezer = makeAddr("freezer");
    address relayer = makeAddr("relayer");

    bytes32 CONTROLLER;
    bytes32 FREEZER;
    bytes32 RELAYER;

    uint256 DAI_BAL_PSM;
    uint256 DAI_SUPPLY;
    uint256 USDC_BAL_PSM;
    uint256 USDC_SUPPLY;

    /**********************************************************************************************/
    /*** Mainnet addresses/constants                                                            ***/
    /**********************************************************************************************/

    address constant CCTP_MESSENGER = 0xBd3fa81B58Ba92a82136038B25aDec7066af3155;
    address constant LOG            = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    address constant PSM = Ethereum.PSM;

    IERC20 dai   = IERC20(Ethereum.DAI);
    IERC20 usdc  = IERC20(Ethereum.USDC);
    IERC20 usds  = IERC20(Ethereum.USDS);
    ISUsds susds = ISUsds(Ethereum.SUSDS);

    IPSMLike psm = IPSMLike(PSM);

    bytes32 constant PSM_ILK = 0x4c4954452d50534d2d555344432d410000000000000000000000000000000000;

    DssInstance dss;  // Mainnet DSS

    address ILK_REGISTRY;

    address constant PAUSE_PROXY = Ethereum.PAUSE_PROXY;
    address constant SPARK_PROXY = Ethereum.SPARK_PROXY;

    /**********************************************************************************************/
    /*** Deployment instances                                                                   ***/
    /**********************************************************************************************/

    AllocatorIlkInstance    ilkInst;
    AllocatorSharedInstance sharedInst;

    /**********************************************************************************************/
    /*** ALM system deployments                                                                 ***/
    /**********************************************************************************************/

    ALMProxy          almProxy;
    RateLimits        rateLimits;
    MainnetController mainnetController;

    /**********************************************************************************************/
    /*** Casted addresses for testing                                                           ***/
    /**********************************************************************************************/

    address buffer;
    address daiUsds;
    address usdsJoin;
    address pocket;
    address vault;

    /**********************************************************************************************/
    /*** Bridging setup                                                                         ***/
    /**********************************************************************************************/

    Bridge bridge;
    Domain source;
    Domain destination;

    /**********************************************************************************************/
    /*** Test setup                                                                             ***/
    /**********************************************************************************************/

    function setUp() public virtual {

        /*** Step 1: Set up environment, cast addresses ***/

        source = getChain("mainnet").createSelectFork(20819000);  //  September 24, 2024

        dss = MCD.loadFromChainlog(LOG);
        ILK_REGISTRY = IChainlogLike(LOG).getAddress("ILK_REGISTRY");

        usdsJoin = IChainlogLike(LOG).getAddress("USDS_JOIN");
        buffer   = ilkInst.buffer;
        daiUsds  = Ethereum.DAI_USDS;
        pocket   = IPSMLike(PSM).pocket();
        vault    = ilkInst.vault;

        DAI_BAL_PSM  = dai.balanceOf(PSM);
        DAI_SUPPLY   = dai.totalSupply();
        USDC_BAL_PSM = usdc.balanceOf(pocket);
        USDC_SUPPLY  = usdc.totalSupply();

        /*** Step 2: Deploy and configure allocation system ***/

        sharedInst = AllocatorDeploy.deployShared(address(this), Ethereum.PAUSE_PROXY);

        ilkInst = AllocatorDeploy.deployIlk({
            deployer : address(this),
            owner    : Ethereum.PAUSE_PROXY,  // TODO: Is this correct?
            roles    : sharedInst.roles,
            ilk      : ilk,
            usdsJoin : usdsJoin
        });

        AllocatorIlkConfig memory ilkConfig = AllocatorIlkConfig({
            ilk            : ilk,
            duty           : EIGHT_PCT_APY,
            maxLine        : 100_000_000 * RAD,
            gap            : 10_000_000 * RAD,
            ttl            : 6 hours,
            allocatorProxy : SPARK_PROXY,
            ilkRegistry    : ILK_REGISTRY
        });

        vm.startPrank(PAUSE_PROXY);
        AllocatorInit.initShared(dss, sharedInst);
        AllocatorInit.initIlk(dss, sharedInst, ilkInst, ilkConfig);
        vm.stopPrank();

        /*** Step 3: Deploy and configure ALM system ***/

        ControllerInstance memory controllerInst = MainnetControllerDeploy.deployFull({
            admin  : Ethereum.SPARK_PROXY,
            vault  : ilkInst.vault,
            psm    : Ethereum.PSM,
            daiUsds: Ethereum.DAI_USDS,
            cctp   : Ethereum.CCTP_TOKEN_MESSENGER,
            susds  : Ethereum.SUSDS
        });

        almProxy          = ALMProxy(payable(controllerInst.almProxy));
        rateLimits        = RateLimits(controllerInst.rateLimits);
        mainnetController = MainnetController(controllerInst.controller);

        CONTROLLER = almProxy.CONTROLLER();
        FREEZER    = mainnetController.FREEZER();
        RELAYER    = mainnetController.RELAYER();

        MainnetControllerInit.AddressParams memory addresses = MainnetControllerInit.AddressParams({
            admin         : Ethereum.SPARK_PROXY,
            freezer       : freezer,
            relayer       : relayer,
            oldController : address(0),
            psm           : Ethereum.PSM,
            vault         : ilkInst.vault,
            buffer        : ilkInst.buffer,
            cctpMessenger : Ethereum.CCTP_TOKEN_MESSENGER,
            dai           : Ethereum.DAI,
            daiUsds       : Ethereum.DAI_USDS,
            usdc          : Ethereum.USDC,
            usds          : Ethereum.USDS,
            susds         : Ethereum.SUSDS
        });

        RateLimitData memory usdsMintData = RateLimitData({
            maxAmount : 5_000_000e18,
            slope     : uint256(1_000_000e18) / 4 hours
        });

        RateLimitData memory usdcToUsdsData = RateLimitData({
            maxAmount : 5_000_000e6,
            slope     : uint256(1_000_000e6) / 4 hours
        });

        RateLimitData memory usdcToCctpData = RateLimitData({
            maxAmount : 5_000_000e6,
            slope     : uint256(1_000_000e6) / 4 hours
        });

        RateLimitData memory cctpToBaseDomainData = RateLimitData({
            maxAmount : 5_000_000e6,
            slope     : uint256(1_000_000e6) / 4 hours
        });

        MainnetControllerInit.InitRateLimitData memory rateLimitData
            = MainnetControllerInit.InitRateLimitData({
                usdsMintData         : usdsMintData,
                usdcToUsdsData       : usdcToUsdsData,
                usdcToCctpData       : usdcToCctpData,
                cctpToBaseDomainData : cctpToBaseDomainData
            });

        MintRecipient[] memory mintRecipients = new MintRecipient[](1);

        mintRecipients[0] = MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            mintRecipient : bytes32(uint256(uint160(makeAddr("baseAlmProxy"))))
        });

        vm.startPrank(SPARK_PROXY);
        MainnetControllerInit.subDaoInitFull(
            addresses,
            controllerInst,
            rateLimitData,
            mintRecipients
        );
        vm.stopPrank();

        vm.prank(PAUSE_PROXY);
        MainnetControllerInit.pauseProxyInit(Ethereum.PSM, controllerInst.almProxy);
    }

}
