// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "dss-test/DssTest.sol";

import { AllocatorInit, AllocatorIlkConfig } from "dss-allocator/deploy/AllocatorInit.sol";

import {
    AllocatorIlkInstance,
    AllocatorSharedInstance
} from "dss-allocator/deploy/AllocatorInstances.sol";

import { AllocatorDeploy } from "dss-allocator/deploy/AllocatorDeploy.sol";

import { IERC20 }   from "forge-std/interfaces/IERC20.sol";
import { IERC4626 } from "forge-std/interfaces/IERC4626.sol";

import { ISUsds } from "sdai/src/ISUsds.sol";

import { Ethereum } from "spark-address-registry/src/Ethereum.sol";

import { Bridge }                from "xchain-helpers/src/testing/Bridge.sol";
import { CCTPForwarder }         from "xchain-helpers/src/forwarders/CCTPForwarder.sol";
import { Domain, DomainHelpers } from "xchain-helpers/src/testing/Domain.sol";

import { MainnetControllerDeploy } from "deploy/ControllerDeploy.sol";
import { ControllerInstance }      from "deploy/ControllerInstance.sol";

import {
    MainnetControllerInit,
    MintRecipient
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

interface ISUSDELike is IERC4626 {
    function cooldownAssets(uint256 usdeAmount) external;
    function cooldownShares(uint256 susdeAmount) external;
    function unstake(address receiver) external;
    function silo() external view returns(address);
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

    bytes32 constant ilk                = "ILK-A";
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    bytes32 constant PSM_ILK = 0x4c4954452d50534d2d555344432d410000000000000000000000000000000000;

    uint256 constant INK           = 1e12 * 1e18;  // Ink initialization amount
    uint256 constant SEVEN_PCT_APY = 1.000000002145441671308778766e27;  // 7% APY (current DSR)
    uint256 constant EIGHT_PCT_APY = 1.000000002440418608258400030e27;  // 8% APY (current DSR + 1%)

    address freezer = makeAddr("freezer");
    address relayer = makeAddr("relayer");

    bytes32 CONTROLLER;
    bytes32 FREEZER;
    bytes32 RELAYER;

    bytes32 usdeBurnKey;
    bytes32 susdeCooldownKey;
    bytes32 susdeDepositKey;
    bytes32 susdsDepositKey;
    bytes32 usdeMintKey;

    /**********************************************************************************************/
    /*** Mainnet addresses/constants                                                            ***/
    /**********************************************************************************************/

    address constant LOG = 0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F;

    address constant CCTP_MESSENGER = Ethereum.CCTP_TOKEN_MESSENGER;
    address constant DAI_USDS       = Ethereum.DAI_USDS;
    address constant ETHENA_MINTER  = Ethereum.ETHENA_MINTER;
    address constant PAUSE_PROXY    = Ethereum.PAUSE_PROXY;
    address constant PSM            = Ethereum.PSM;
    address constant SPARK_PROXY    = Ethereum.SPARK_PROXY;

    IERC20 constant dai   = IERC20(Ethereum.DAI);
    IERC20 constant usdc  = IERC20(Ethereum.USDC);
    IERC20 constant usde  = IERC20(Ethereum.USDE);
    IERC20 constant usds  = IERC20(Ethereum.USDS);
    ISUsds constant susds = ISUsds(Ethereum.SUSDS);

    ISUSDELike constant susde = ISUSDELike(Ethereum.SUSDE);

    IPSMLike constant psm = IPSMLike(PSM);

    address POCKET;
    address USDS_JOIN;

    DssInstance dss;  // Mainnet DSS

    /**********************************************************************************************/
    /*** ALM system and allocation system deployments                                           ***/
    /**********************************************************************************************/

    ALMProxy          almProxy;
    RateLimits        rateLimits;
    MainnetController mainnetController;

    address buffer;
    address vault;

    /**********************************************************************************************/
    /*** Bridging setup                                                                         ***/
    /**********************************************************************************************/

    Bridge bridge;
    Domain source;
    Domain destination;

    /**********************************************************************************************/
    /*** Cached mainnet state variables                                                         ***/
    /**********************************************************************************************/

    uint256 DAI_BAL_PSM;
    uint256 DAI_SUPPLY;
    uint256 USDC_BAL_PSM;
    uint256 USDC_SUPPLY;
    uint256 USDS_SUPPLY;
    uint256 USDS_BAL_SUSDS;
    uint256 VAT_DAI_USDS_JOIN;

    /**********************************************************************************************/
    /*** Test setup                                                                             ***/
    /**********************************************************************************************/

    function setUp() public virtual {

        /*** Step 1: Set up environment, cast addresses ***/

        source = getChain("mainnet").createSelectFork(21294900);  //  November 29, 2024

        dss = MCD.loadFromChainlog(LOG);

        USDS_JOIN = IChainlogLike(LOG).getAddress("USDS_JOIN");
        POCKET    = IChainlogLike(LOG).getAddress("MCD_LITE_PSM_USDC_A_POCKET");

        DAI_BAL_PSM       = dai.balanceOf(PSM);
        DAI_SUPPLY        = dai.totalSupply();
        USDC_BAL_PSM      = usdc.balanceOf(POCKET);
        USDC_SUPPLY       = usdc.totalSupply();
        USDS_SUPPLY       = usds.totalSupply();
        USDS_BAL_SUSDS    = usds.balanceOf(address(susds));
        VAT_DAI_USDS_JOIN = dss.vat.dai(USDS_JOIN);

        buffer = Ethereum.ALLOCATOR_BUFFER;
        vault  = Ethereum.ALLOCATOR_VAULT;

        almProxy   = ALMProxy(payable(Ethereum.ALM_PROXY));
        rateLimits = RateLimits(Ethereum.ALM_RATE_LIMITS);

        /*** Step 3: Deploy latest controller and upgrade ***/

        mainnetController = MainnetController(MainnetControllerDeploy.deployController({
            admin      : Ethereum.SPARK_PROXY,
            almProxy   : Ethereum.ALM_PROXY,
            rateLimits : Ethereum.ALM_RATE_LIMITS,
            vault      : Ethereum.ALLOCATOR_VAULT,
            psm        : Ethereum.PSM,
            daiUsds    : Ethereum.DAI_USDS,
            cctp       : Ethereum.CCTP_TOKEN_MESSENGER,
            susds      : Ethereum.SUSDS
        }));

        CONTROLLER = almProxy.CONTROLLER();
        FREEZER    = mainnetController.FREEZER();
        RELAYER    = mainnetController.RELAYER();

        MainnetControllerInit.ConfigAddressParams memory configAddresses
            = MainnetControllerInit.ConfigAddressParams({
                admin         : Ethereum.SPARK_PROXY,
                freezer       : freezer,
                relayer       : relayer,
                oldController : Ethereum.ALM_CONTROLLER
            });

        MainnetControllerInit.AddressCheckParams memory checkAddresses
            = MainnetControllerInit.AddressCheckParams({
                proxy        : Ethereum.ALM_PROXY,
                rateLimits   : Ethereum.ALM_RATE_LIMITS,
                buffer       : buffer,
                cctp         : Ethereum.CCTP_TOKEN_MESSENGER,
                daiUsds      : Ethereum.DAI_USDS,
                ethenaMinter : Ethereum.ETHENA_MINTER,
                psm          : Ethereum.PSM,
                vault        : vault,
                dai          : Ethereum.DAI,
                usds         : Ethereum.USDS,
                usde         : Ethereum.USDE,
                usdc         : Ethereum.USDC,
                susde        : Ethereum.SUSDE,
                susds        : Ethereum.SUSDS
            });

        ControllerInstance memory controllerInst = ControllerInstance({
            almProxy   : Ethereum.ALM_PROXY,
            controller : address(mainnetController),
            rateLimits : Ethereum.ALM_RATE_LIMITS
        });

        MintRecipient[] memory mintRecipients = new MintRecipient[](1);

        mintRecipients[0] = MintRecipient({
            domain        : CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            mintRecipient : bytes32(uint256(uint160(makeAddr("baseAlmProxy"))))
        });

        // Actions performed by spell
        vm.startPrank(Ethereum.SPARK_PROXY);

        MainnetControllerInit.subDaoInitController(
            configAddresses,
            checkAddresses,
            controllerInst,
            mintRecipients
        );

        usdeBurnKey         = mainnetController.LIMIT_USDE_BURN();
        susdeCooldownKey     = mainnetController.LIMIT_SUSDE_COOLDOWN();
        susdeDepositKey = RateLimitHelpers.makeAssetKey(mainnetController.LIMIT_4626_DEPOSIT(), address(susde));
        susdsDepositKey = RateLimitHelpers.makeAssetKey(mainnetController.LIMIT_4626_DEPOSIT(), address(susds));
        usdeMintKey         = mainnetController.LIMIT_USDE_MINT();

        rateLimits.setRateLimitData(usdeBurnKey,         5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(susdeCooldownKey,     5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(susdeDepositKey, 5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(susdsDepositKey, 5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(usdeMintKey,         5_000_000e6,  uint256(1_000_000e6)  / 4 hours);

        vm.stopPrank();

        /*** Step 4: Label addresses ***/

        vm.label(buffer,         "buffer");
        vm.label(address(susds), "susds");
        vm.label(address(usdc),  "usdc");
        vm.label(address(usds),  "usds");
        vm.label(vault,          "vault");
    }

}
