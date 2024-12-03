// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import { IAToken }            from "aave-v3-origin/src/core/contracts/interfaces/IAToken.sol";
import { IPool as IAavePool } from "aave-v3-origin/src/core/contracts/interfaces/IPool.sol";

import { IERC20 }   from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { ERC20Mock } from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

import { Base }     from "spark-address-registry/src/Base.sol";
import { Ethereum } from "spark-address-registry/src/Ethereum.sol";

import { PSM3Deploy } from "spark-psm/deploy/PSM3Deploy.sol";
import { IPSM3 }      from "spark-psm/src/PSM3.sol";

import { CCTPForwarder } from "xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { ForeignControllerDeploy } from "deploy/ControllerDeploy.sol";
import { ControllerInstance }      from "deploy/ControllerInstance.sol";

import {
    ForeignControllerInit,
    MintRecipient
} from "deploy/ControllerInit.sol";

import { CCTPForwarder } from "xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { ForeignControllerDeploy } from "deploy/ControllerDeploy.sol";
import { ControllerInstance }      from "deploy/ControllerInstance.sol";

import {
    ForeignControllerInit,
    MintRecipient
} from "deploy/ControllerInit.sol";

import { ALMProxy }          from "src/ALMProxy.sol";
import { ForeignController } from "src/ForeignController.sol";
import { RateLimits }        from "src/RateLimits.sol";
import { RateLimitHelpers }  from "src/RateLimitHelpers.sol";

contract ForkTestBase is Test {

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

    address constant ATOKEN_USDC = 0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB;
    address constant AAVE_POOL   = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5;

    address constant MORPHO            = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant MORPHO_VAULT_USDS = 0x0fFDeCe791C5a2cb947F8ddBab489E5C02c6d4F7;
    address constant MORPHO_VAULT_USDC = 0x305E03Ed9ADaAB22F4A58c24515D79f2B1E2FD5D;

    IERC4626 usdsVault = IERC4626(MORPHO_VAULT_USDS);
    IERC4626 usdcVault = IERC4626(MORPHO_VAULT_USDC);

    IAToken ausdc = IAToken(ATOKEN_USDC);

    /**********************************************************************************************/
    /*** ALM system deployments                                                                 ***/
    /**********************************************************************************************/

    ALMProxy          almProxy;
    RateLimits        rateLimits;
    ForeignController foreignController;

    bytes32 aaveUsdcDepositKey;
    bytes32 morphoUsdcDepositKey;
    bytes32 morphoUsdsDepositKey;

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

        susdsBase = IERC20(Base.SUSDS);
        usdcBase  = IERC20(Base.USDC);
        usdsBase  = IERC20(Base.USDS);

        /*** Step 2: Update live PSM with a pocket for more comprehensive testing ***/

        psmBase = IPSM3(Base.PSM3);

        vm.prank(SPARK_EXECUTOR);
        psmBase.setPocket(pocket);

        vm.prank(pocket);
        usdcBase.approve(address(psmBase), type(uint256).max);

        /*** Step 3: Deploy and configure ALM system ***/

        foreignController = ForeignController(ForeignControllerDeploy.deployController({
            admin      : Base.SPARK_EXECUTOR,
            almProxy   : Base.ALM_PROXY,
            rateLimits : Base.ALM_RATE_LIMITS,
            psm        : Base.PSM3,
            usdc       : Base.USDC,
            cctp       : Base.CCTP_TOKEN_MESSENGER
        }));

        almProxy   = ALMProxy(payable(Base.ALM_PROXY));
        rateLimits = RateLimits(Base.ALM_RATE_LIMITS);

        CONTROLLER = almProxy.CONTROLLER();
        FREEZER    = foreignController.FREEZER();
        RELAYER    = foreignController.RELAYER();

        ForeignControllerInit.ConfigAddressParams memory configAddresses
            = ForeignControllerInit.ConfigAddressParams({
                admin         : Base.SPARK_EXECUTOR,
                freezer       : freezer,  // TODO: Use real freezer addresses
                relayer       : relayer,
                oldController : Base.ALM_CONTROLLER
            });

        ForeignControllerInit.AddressCheckParams memory checkAddresses
            = ForeignControllerInit.AddressCheckParams({
                psm           : Base.PSM3,
                cctpMessenger : Base.CCTP_TOKEN_MESSENGER,
                usdc          : Base.USDC,
                usds          : Base.USDS,
                susds         : Base.SUSDS
            });

        ControllerInstance memory controllerInst = ControllerInstance({
            almProxy   : Base.ALM_PROXY,
            controller : address(foreignController),
            rateLimits : Base.ALM_RATE_LIMITS
        });

        MintRecipient[] memory mintRecipients = new MintRecipient[](1);

        mintRecipients[0] = MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_ETHEREUM,
            mintRecipient : bytes32(uint256(uint160(address(almProxy))))
        });

        aaveUsdcDepositKey   = RateLimitHelpers.makeAssetKey(foreignController.LIMIT_AAVE_DEPOSIT(), ATOKEN_USDC);
        morphoUsdcDepositKey = RateLimitHelpers.makeAssetKey(foreignController.LIMIT_4626_DEPOSIT(), MORPHO_VAULT_USDC);
        morphoUsdsDepositKey = RateLimitHelpers.makeAssetKey(foreignController.LIMIT_4626_DEPOSIT(), MORPHO_VAULT_USDS);

        // NOTE: These are the actions performed by the spell
        vm.startPrank(SPARK_EXECUTOR);

        ForeignControllerInit.init(
            configAddresses,
            checkAddresses,
            controllerInst,
            mintRecipients
        );

        rateLimits.setRateLimitData(aaveUsdcDepositKey,   1_000_000e6,   uint256(1_000_000e6)  / 1 days);
        rateLimits.setRateLimitData(morphoUsdcDepositKey, 25_000_000e6,  uint256(5_000_000e6)  / 1 days);
        rateLimits.setRateLimitData(morphoUsdsDepositKey, 25_000_000e18, uint256(5_000_000e18) / 1 days);

        vm.stopPrank();
    }

    function _getBlock() internal virtual pure returns (uint256) {
        return 23190000;  // Dec 2, 2024
    }

}
