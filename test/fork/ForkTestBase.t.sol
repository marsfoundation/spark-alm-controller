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

import { NstDeploy }   from "nst/deploy/NstDeploy.sol";
import { NstInit }     from "nst/deploy/NstInit.sol";
import { NstInstance } from "nst/deploy/NstInstance.sol";

import { ISNst }                from "sdai/src/ISNst.sol";
import { SNstDeploy }           from "sdai/deploy/SNstDeploy.sol";
import { SNstInit, SNstConfig } from "sdai/deploy/SNstInit.sol";
import { SNstInstance }         from "sdai/deploy/SNstInstance.sol";

import { ALMProxy }          from "src/ALMProxy.sol";
import { MainnetController } from "src/MainnetController.sol";

interface IChainlogLike {
    function getAddress(bytes32) external view returns (address);
}

interface IBufferLike {
    function approve(address, address, uint256) external;
}

interface IPSMLike {
    function pocket() external view returns (address);
    function kiss(address) external;
}

interface IVaultLike {
    function rely(address) external;
}

contract ForkTestBase is DssTest {

    /**********************************************************************************************/
    /*** Constants/state variables                                                              ***/
    /**********************************************************************************************/

    bytes32 constant ilk = "ILK-A";

    uint256 constant INK = 1e12 * 1e18;  // Ink initialization amount

    uint256 constant SEVEN_PCT_APY = 1.000000002145441671308778766e27;  // 7% APY (current DSR)
    uint256 constant EIGHT_PCT_APY = 1.000000002440418608258400030e27;  // 8% APY (current DSR + 1%)

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    bytes32 CONTROLLER;
    bytes32 FREEZER;
    bytes32 RELAYER;

    address freezer = makeAddr("freezer");
    address relayer = makeAddr("relayer");

    uint256 DAI_BAL_PSM;
    uint256 DAI_SUPPLY;
    uint256 USDC_BAL_PSM;
    uint256 USDC_SUPPLY;

    /**********************************************************************************************/
    /*** Mainnet addresses                                                                      ***/
    /**********************************************************************************************/

    address constant CCTP_MESSENGER = 0xBd3fa81B58Ba92a82136038B25aDec7066af3155;
    address constant LOG            = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;
    address constant PSM            = 0xf6e72Db5454dd049d0788e411b06CfAF16853042;  // Lite PSM
    address constant SPARK_PROXY    = 0x3300f198988e4C9C63F75dF86De36421f06af8c4;

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
    NstInstance             nstInst;
    SNstInstance            snstInst;

    /**********************************************************************************************/
    /*** ALM system deployments                                                                 ***/
    /**********************************************************************************************/

    ALMProxy          almProxy;
    MainnetController mainnetController;

    /**********************************************************************************************/
    /*** Casted addresses for testing                                                           ***/
    /**********************************************************************************************/

    IERC20 dai;
    IERC20 nst;
    IERC20 usdc;
    ISNst  snst;

    address buffer;
    address daiNst;
    address nstJoin;
    address pocket;
    address vault;

    /**********************************************************************************************/
    /*** Test setup                                                                             ***/
    /**********************************************************************************************/

    function setUp() public virtual {
        vm.createSelectFork(getChain('mainnet').rpcUrl, 20484600);  // August 8, 2024

        dss          = MCD.loadFromChainlog(LOG);
        DAI          = IChainlogLike(LOG).getAddress("MCD_DAI");
        ILK_REGISTRY = IChainlogLike(LOG).getAddress("ILK_REGISTRY");
        PAUSE_PROXY  = IChainlogLike(LOG).getAddress("MCD_PAUSE_PROXY");
        USDC         = IChainlogLike(LOG).getAddress("USDC");

        /*** Step 1: Deploy NST, sNST and allocation system ***/

        nstInst = NstDeploy.deploy(
            address(this),
            PAUSE_PROXY,
            IChainlogLike(LOG).getAddress("MCD_JOIN_DAI")
        );

        snstInst = SNstDeploy.deploy({
            deployer : address(this),
            owner    : PAUSE_PROXY,
            nstJoin  : nstInst.nstJoin
        });

        sharedInst = AllocatorDeploy.deployShared(address(this), PAUSE_PROXY);

        ilkInst = AllocatorDeploy.deployIlk({
            deployer : address(this),
            owner    : PAUSE_PROXY,
            roles    : sharedInst.roles,
            ilk      : ilk,
            nstJoin  : nstInst.nstJoin
        });

        /*** Step 2: Configure NST, sNST and allocation system ***/

        SNstConfig memory snstConfig = SNstConfig({
            nstJoin: address(nstInst.nstJoin),
            nst: address(nstInst.nst),
            nsr: SEVEN_PCT_APY
        });

        AllocatorIlkConfig memory ilkConfig = AllocatorIlkConfig({
            ilk            : ilk,
            duty           : EIGHT_PCT_APY,
            maxLine        : 100_000_000 * RAD,
            gap            : 5_000_000 * RAD,
            ttl            : 6 hours,
            allocatorProxy : SPARK_PROXY,
            ilkRegistry    : ILK_REGISTRY
        });

        vm.startPrank(PAUSE_PROXY);

        NstInit.init(dss, nstInst);
        SNstInit.init(dss, snstInst, snstConfig);
        AllocatorInit.initShared(dss, sharedInst);
        AllocatorInit.initIlk(dss, sharedInst, ilkInst, ilkConfig);

        vm.stopPrank();

        /*** Step 3: Deploy ALM system ***/

        almProxy = new ALMProxy(SPARK_PROXY);

        mainnetController = new MainnetController({
            admin_  : SPARK_PROXY,
            proxy_  : address(almProxy),
            vault_  : ilkInst.vault,
            buffer_ : ilkInst.buffer,
            psm_    : PSM,
            daiNst_ : nstInst.daiNst,
            cctp_   : CCTP_MESSENGER,
            snst_   : snstInst.sNst
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

        IBufferLike(ilkInst.buffer).approve(nstInst.nst, address(almProxy), type(uint256).max);

        vm.stopPrank();

        vm.prank(PAUSE_PROXY);
        IPSMLike(PSM).kiss(address(almProxy));  // Allow using no fee functionality

        /*** Step 5: Perform casting for easier testing, cache values from mainnet ***/

        buffer  = ilkInst.buffer;
        dai     = IERC20(DAI);
        daiNst  = nstInst.daiNst;
        nst     = IERC20(address(nstInst.nst));
        nstJoin = nstInst.nstJoin;
        pocket  = IPSMLike(PSM).pocket();
        snst    = ISNst(address(snstInst.sNst));
        usdc    = IERC20(USDC);
        vault   = ilkInst.vault;

        DAI_BAL_PSM  = dai.balanceOf(PSM);
        DAI_SUPPLY   = dai.totalSupply();
        USDC_BAL_PSM = usdc.balanceOf(pocket);
        USDC_SUPPLY  = usdc.totalSupply();
    }

}
