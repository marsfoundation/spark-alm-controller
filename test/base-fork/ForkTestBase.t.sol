// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import { IERC20 } from "lib/forge-std/src/interfaces/IERC20.sol";

import { ERC20Mock } from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

import { Base } from "spark-address-registry/Base.sol";

import { PSM3Deploy } from "spark-psm/deploy/PSM3Deploy.sol";
import { IPSM3 }      from "spark-psm/src/PSM3.sol";

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { ForeignControllerDeploy } from "deploy/ControllerDeploy.sol";
import { ControllerInstance }      from "deploy/ControllerInstance.sol";

import { ForeignControllerInit,
    MintRecipient,
    RateLimitData
} from "deploy/ControllerInit.sol";

import { CCTPForwarder } from "lib/xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { ForeignControllerDeploy } from "deploy/ControllerDeploy.sol";
import { ControllerInstance }      from "deploy/ControllerInstance.sol";

import { ForeignControllerInit,
    MintRecipient,
    RateLimitData
} from "deploy/ControllerInit.sol";

import { ALMProxy }          from "src/ALMProxy.sol";
import { ForeignController } from "src/ForeignController.sol";
import { RateLimits }        from "src/RateLimits.sol";

contract ForkTestBase is Test {

    // TODO: Refactor to use live addresses

    /**********************************************************************************************/
    /*** Constants/state variables                                                              ***/
    /**********************************************************************************************/

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    bytes32 CONTROLLER;
    bytes32 FREEZER;
    bytes32 RELAYER;

    address freezer = makeAddr("freezer");
    address pocket  = makeAddr("pocket");
    address relayer = makeAddr("relayer");

    /**********************************************************************************************/
    /*** Base addresses                                                                         ***/
    /**********************************************************************************************/

    address constant SPARK_EXECUTOR      = Base.SPARK_EXECUTOR;
    address constant CCTP_MESSENGER_BASE = Base.CCTP_TOKEN_MESSENGER;
    address constant USDC_BASE           = Base.USDC;
    address constant SSR_ORACLE          = Base.SSR_AUTH_ORACLE;

    /**********************************************************************************************/
    /*** ALM system deployments                                                                 ***/
    /**********************************************************************************************/

    ALMProxy          almProxy;
    RateLimits        rateLimits;
    ForeignController foreignController;

    /**********************************************************************************************/
    /*** Casted addresses for testing                                                           ***/
    /**********************************************************************************************/

    IERC20 usdsBase;
    IERC20 susdsBase;
    IERC20 usdcBase;

    IPSM3 psmBase;

    /**********************************************************************************************/
    /*** Test setup                                                                             ***/
    /**********************************************************************************************/

    function setUp() public virtual {
        /*** Step 1: Set up environment, deploy mock addresses ***/

        vm.createSelectFork(getChain('base').rpcUrl, 22841965);  // November 24, 2024

        usdsBase  = IERC20(address(new ERC20Mock()));
        susdsBase = IERC20(address(new ERC20Mock()));
        usdcBase  = IERC20(USDC_BASE);

        /*** Step 2: Deploy and configure PSM with a pocket ***/

        deal(address(usdsBase), address(this), 1e18);  // For seeding PSM during deployment

        psmBase = IPSM3(PSM3Deploy.deploy(
            SPARK_EXECUTOR, USDC_BASE, address(usdsBase), address(susdsBase), SSR_ORACLE
        ));

        vm.prank(SPARK_EXECUTOR);
        psmBase.setPocket(pocket);

        vm.prank(pocket);
        usdcBase.approve(address(psmBase), type(uint256).max);

        /*** Step 3: Deploy and configure ALM system ***/

        ControllerInstance memory controllerInst = ForeignControllerDeploy.deployFull({
            admin : SPARK_EXECUTOR,
            psm   : address(psmBase),
            usdc  : USDC_BASE,
            cctp  : CCTP_MESSENGER_BASE
        });

        almProxy          = ALMProxy(payable(controllerInst.almProxy));
        rateLimits        = RateLimits(controllerInst.rateLimits);
        foreignController = ForeignController(controllerInst.controller);

        CONTROLLER = almProxy.CONTROLLER();
        FREEZER    = foreignController.FREEZER();
        RELAYER    = foreignController.RELAYER();

        ForeignControllerInit.AddressParams memory addresses = ForeignControllerInit.AddressParams({
            admin         : SPARK_EXECUTOR,
            freezer       : freezer,
            relayer       : relayer,
            oldController : address(0),  // Empty
            psm           : address(psmBase),
            cctpMessenger : CCTP_MESSENGER_BASE,
            usdc          : USDC_BASE,
            usds          : address(usdsBase),
            susds         : address(susdsBase)
        });

        RateLimitData memory standardUsdcRateLimitData = RateLimitData({
            maxAmount : 5_000_000e6,
            slope     : uint256(1_000_000e6) / 4 hours
        });

        RateLimitData memory standardUsdsRateLimitData = RateLimitData({
            maxAmount : 5_000_000e18,
            slope     : uint256(1_000_000e18) / 4 hours
        });

        RateLimitData memory unlimitedRateLimitData = RateLimitData({
            maxAmount : type(uint256).max,
            slope     : 0
        });

        ForeignControllerInit.InitRateLimitData memory rateLimitData
            = ForeignControllerInit.InitRateLimitData({
                usdcDepositData          : standardUsdcRateLimitData,
                usdcWithdrawData         : standardUsdcRateLimitData,
                usdsDepositData          : standardUsdsRateLimitData,
                usdsWithdrawData         : unlimitedRateLimitData,
                susdsDepositData         : standardUsdsRateLimitData,
                susdsWithdrawData        : unlimitedRateLimitData,
                usdcToCctpData           : standardUsdcRateLimitData,
                cctpToEthereumDomainData : standardUsdcRateLimitData
            });

        MintRecipient[] memory mintRecipients = new MintRecipient[](1);

        mintRecipients[0] = MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            mintRecipient : bytes32(uint256(uint160(makeAddr("ethereumAlmProxy"))))
        });

        vm.startPrank(SPARK_EXECUTOR);
        ForeignControllerInit.init(addresses, controllerInst, rateLimitData, mintRecipients);
        vm.stopPrank();
    }

}
