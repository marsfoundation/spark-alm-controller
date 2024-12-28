// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import { IERC20 } from "forge-std/interfaces/IERC20.sol";

import { ERC20Mock } from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

import { Base } from "spark-address-registry/Base.sol";

import { PSM3Deploy } from "spark-psm/deploy/PSM3Deploy.sol";
import { IPSM3 }      from "spark-psm/src/PSM3.sol";

import { CCTPForwarder } from "xchain-helpers/forwarders/CCTPForwarder.sol";

import { ForeignControllerDeploy } from "../../deploy/ControllerDeploy.sol";
import { ControllerInstance }      from "../../deploy/ControllerInstance.sol";

import { ForeignControllerInit as Init } from "../../deploy/ForeignControllerInit.sol";

import { ALMProxy }          from "../../src/ALMProxy.sol";
import { ForeignController } from "../../src/ForeignController.sol";
import { RateLimits }        from "../../src/RateLimits.sol";

import { RateLimitHelpers, RateLimitData }  from "../../src/RateLimitHelpers.sol";

contract ForkTestBase is Test {

    // TODO: Refactor to use live addresses

    /**********************************************************************************************/
    /*** Constants/state variables                                                              ***/
    /**********************************************************************************************/

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    bytes32 CONTROLLER;
    bytes32 FREEZER;
    bytes32 RELAYER;

    address freezer = Base.ALM_FREEZER;
    address relayer = Base.ALM_RELAYER;

    address pocket = makeAddr("pocket");

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

        vm.createSelectFork(getChain('base').rpcUrl, _getBlock());

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

        /*** Step 3: Deploy ALM system ***/

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

        /*** Step 3: Configure ALM system through Spark governance (Spark spell payload) ***/


        Init.ConfigAddressParams memory configAddresses = Init.ConfigAddressParams({
            freezer       : freezer,
            relayer       : relayer,
            oldController : address(0)
        });

        Init.CheckAddressParams memory checkAddresses = Init.CheckAddressParams({
            admin : Base.SPARK_EXECUTOR,
            psm   : address(psmBase),
            cctp  : Base.CCTP_TOKEN_MESSENGER,
            usdc  : address(usdcBase),
            susds : address(susdsBase),
            usds  : address(usdsBase)
        });

        Init.MintRecipient[] memory mintRecipients = new Init.MintRecipient[](1);

        mintRecipients[0] = Init.MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            mintRecipient : bytes32(uint256(uint160(makeAddr("ethereumAlmProxy"))))
        });

        vm.startPrank(SPARK_EXECUTOR);

        Init.initAlmSystem(
            controllerInst,
            configAddresses,
            checkAddresses,
            mintRecipients
        );

        RateLimitData memory standardUsdcData = RateLimitData({
            maxAmount : 5_000_000e6,
            slope     : uint256(1_000_000e6) / 4 hours
        });

        RateLimitData memory standardUsdsData = RateLimitData({
            maxAmount : 5_000_000e18,
            slope     : uint256(1_000_000e18) / 4 hours
        });

        RateLimitData memory unlimitedData = RateLimitData({
            maxAmount : type(uint256).max,
            slope     : 0
        });

        bytes32 depositKey  = foreignController.LIMIT_PSM_DEPOSIT();
        bytes32 withdrawKey = foreignController.LIMIT_PSM_WITHDRAW();

        bytes32 domainKeyEthereum = RateLimitHelpers.makeDomainKey(
            foreignController.LIMIT_USDC_TO_DOMAIN(),
            CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM
        );

        // NOTE: Using minimal config for test base setup
        RateLimitHelpers.setRateLimitData(RateLimitHelpers.makeAssetKey(depositKey,  address(usdcBase)),  address(rateLimits), standardUsdcData, "usdcDepositData",  6);
        RateLimitHelpers.setRateLimitData(RateLimitHelpers.makeAssetKey(withdrawKey, address(usdcBase)),  address(rateLimits), standardUsdcData, "usdcWithdrawData", 6);
        RateLimitHelpers.setRateLimitData(RateLimitHelpers.makeAssetKey(depositKey,  address(usdsBase)),  address(rateLimits), standardUsdsData, "usdsDepositData",  18);
        RateLimitHelpers.setRateLimitData(RateLimitHelpers.makeAssetKey(withdrawKey, address(usdsBase)),  address(rateLimits), unlimitedData,    "usdsWithdrawData", 18);
        RateLimitHelpers.setRateLimitData(RateLimitHelpers.makeAssetKey(depositKey,  address(susdsBase)), address(rateLimits), standardUsdsData, "susdsDepositData", 18);
        RateLimitHelpers.setRateLimitData(RateLimitHelpers.makeAssetKey(withdrawKey, address(susdsBase)), address(rateLimits), unlimitedData,    "susdsWithdrawData", 18);

        RateLimitHelpers.setRateLimitData(foreignController.LIMIT_USDC_TO_CCTP(), address(rateLimits), standardUsdcData, "usdcToCctpData",           6);
        RateLimitHelpers.setRateLimitData(domainKeyEthereum,                      address(rateLimits), standardUsdcData, "cctpToEthereumDomainData", 6);

        vm.stopPrank();
    }

    // Default configuration for the fork, can be overridden in inheriting tests
    function _getBlock() internal virtual pure returns (uint256) {
        return 20782500;  // October 8, 2024
    }

}
