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

import { UsdsDeploy }   from "usds/deploy/UsdsDeploy.sol";
import { UsdsInit }     from "usds/deploy/UsdsInit.sol";
import { UsdsInstance } from "usds/deploy/UsdsInstance.sol";

import { ISUsds }                 from "sdai/src/ISUsds.sol";
import { SUsdsDeploy }            from "sdai/deploy/SUsdsDeploy.sol";
import { SUsdsInit, SUsdsConfig } from "sdai/deploy/SUsdsInit.sol";
import { SUsdsInstance }          from "sdai/deploy/SUsdsInstance.sol";

import { Ethereum } from "spark-address-registry/Ethereum.sol";

import { Bridge }                from "xchain-helpers/src/testing/Bridge.sol";
import { CCTPForwarder }         from "xchain-helpers/src/forwarders/CCTPForwarder.sol";
import { Domain, DomainHelpers } from "xchain-helpers/src/testing/Domain.sol";

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
    address constant PSM            = 0xf6e72Db5454dd049d0788e411b06CfAF16853042;  // Lite PSM
    address constant SPARK_PROXY    = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;

    IERC20 dai   = IERC20(Ethereum.DAI);
    IERC20 usdc  = IERC20(Ethereum.USDC);
    IERC20 usds  = IERC20(Ethereum.USDS);
    ISUsds susds = ISUsds(Ethereum.SUSDS);

    IPSMLike psm = IPSMLike(Ethereum.PSM);

    bytes32 constant PSM_ILK = 0x4c4954452d50534d2d555344432d410000000000000000000000000000000000;

    DssInstance dss;  // Mainnet DSS

    address ILK_REGISTRY;
    address PAUSE_PROXY;
    address USDC;
    address DAI;

    /**********************************************************************************************/
    /*** Deployment instances                                                                   ***/
    /**********************************************************************************************/

    AllocatorIlkInstance    ilkInst;
    AllocatorSharedInstance sharedInst;
    UsdsInstance            usdsInst;
    SUsdsInstance           susdsInst;

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
        source = getChain("mainnet").createSelectFork(20819000);  //  September 24, 2024

        dss          = MCD.loadFromChainlog(LOG);
        DAI          = IChainlogLike(LOG).getAddress("MCD_DAI");
        ILK_REGISTRY = IChainlogLike(LOG).getAddress("ILK_REGISTRY");
        PAUSE_PROXY  = IChainlogLike(LOG).getAddress("MCD_PAUSE_PROXY");
        USDC         = IChainlogLike(LOG).getAddress("USDC");

        /*** Step 1: Deploy USDS, sUSDS and allocation system ***/

        usdsInst = UsdsDeploy.deploy(
            address(this),
            PAUSE_PROXY,
            IChainlogLike(LOG).getAddress("MCD_JOIN_DAI")
        );

        susdsInst = SUsdsDeploy.deploy({
            deployer : address(this),
            owner    : PAUSE_PROXY,
            usdsJoin : usdsInst.usdsJoin
        });

        sharedInst = AllocatorDeploy.deployShared(address(this), PAUSE_PROXY);

        ilkInst = AllocatorDeploy.deployIlk({
            deployer : address(this),
            owner    : PAUSE_PROXY,
            roles    : sharedInst.roles,
            ilk      : ilk,
            usdsJoin : usdsInst.usdsJoin
        });

        /*** Step 2: Configure USDS, sUSDS and allocation system ***/

        SUsdsConfig memory susdsConfig = SUsdsConfig({
            usdsJoin : address(usdsInst.usdsJoin),
            usds     : address(usdsInst.usds),
            ssr      : SEVEN_PCT_APY
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

        UsdsInit.init(dss, usdsInst);
        SUsdsInit.init(dss, susdsInst, susdsConfig);
        AllocatorInit.initShared(dss, sharedInst);
        AllocatorInit.initIlk(dss, sharedInst, ilkInst, ilkConfig);

        vm.stopPrank();

        /*** Step 3: Deploy ALM system ***/

        almProxy = new ALMProxy(SPARK_PROXY);

        rateLimits = new RateLimits(SPARK_PROXY);

        mainnetController = new MainnetController({
            admin_      : SPARK_PROXY,
            proxy_      : address(almProxy),
            rateLimits_ : address(rateLimits),
            vault_      : ilkInst.vault,
            psm_        : PSM,
            daiUsds_    : usdsInst.daiUsds,
            cctp_       : CCTP_MESSENGER,
            susds_      : susdsInst.sUsds
        });

        CONTROLLER = almProxy.CONTROLLER();
        FREEZER    = mainnetController.FREEZER();
        RELAYER    = mainnetController.RELAYER();

        /*** Step 4: Configure ALM system in allocation system ***/

        vm.startPrank(SPARK_PROXY);

        IVaultLike(ilkInst.vault).rely(address(almProxy));

        mainnetController.grantRole(FREEZER, freezer);
        mainnetController.grantRole(RELAYER, relayer);

        almProxy.grantRole(CONTROLLER, address(mainnetController));

        rateLimits.grantRole(CONTROLLER, address(mainnetController));

        bytes32 domainKeyBase = RateLimitHelpers.makeDomainKey(
            mainnetController.LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE
        );

        // Setup rate limits to be 1m / 4 hours recharge and 5m max
        rateLimits.setRateLimitData(mainnetController.LIMIT_USDS_MINT(),    5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(mainnetController.LIMIT_USDS_TO_USDC(), 5_000_000e6,  uint256(1_000_000e6)  / 4 hours);
        rateLimits.setRateLimitData(mainnetController.LIMIT_USDC_TO_CCTP(), 5_000_000e6,  uint256(1_000_000e6)  / 4 hours);
        rateLimits.setRateLimitData(domainKeyBase,                          5_000_000e6,  uint256(1_000_000e6)  / 4 hours);

        IBufferLike(ilkInst.buffer).approve(usdsInst.usds, address(almProxy), type(uint256).max);

        vm.stopPrank();

        vm.prank(PAUSE_PROXY);
        IPSMLike(PSM).kiss(address(almProxy));  // Allow using no fee functionality

        /*** Step 5: Perform casting for easier testing, cache values from mainnet ***/

        buffer   = ilkInst.buffer;
        dai      = IERC20(DAI);
        daiUsds  = usdsInst.daiUsds;
        usds     = IERC20(address(usdsInst.usds));
        usdsJoin = usdsInst.usdsJoin;
        pocket   = IPSMLike(PSM).pocket();
        psm      = IPSMLike(PSM);
        susds    = ISUsds(address(susdsInst.sUsds));
        usdc     = IERC20(USDC);
        vault    = ilkInst.vault;

        DAI_BAL_PSM  = dai.balanceOf(PSM);
        DAI_SUPPLY   = dai.totalSupply();
        USDC_BAL_PSM = usdc.balanceOf(pocket);
        USDC_SUPPLY  = usdc.totalSupply();
    }

}
