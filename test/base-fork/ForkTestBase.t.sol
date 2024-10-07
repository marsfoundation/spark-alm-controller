// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import { IERC20 } from "lib/forge-std/src/interfaces/IERC20.sol";

import { ERC20Mock } from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

import { PSM3Deploy }       from "spark-psm/deploy/PSM3Deploy.sol";
import { IPSM3 }            from "spark-psm/src/PSM3.sol";
import { MockRateProvider } from "spark-psm/test/mocks/MockRateProvider.sol";

import { ALMProxy }          from "src/ALMProxy.sol";
import { ForeignController } from "src/ForeignController.sol";
import { RateLimitHelpers }  from "src/RateLimitHelpers.sol";
import { RateLimits }        from "src/RateLimits.sol";

contract ForkTestBase is Test {

    // TODO: Refactor to use deployment libraries/testnet addresses

    /**********************************************************************************************/
    /*** Constants/state variables                                                              ***/
    /**********************************************************************************************/

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    bytes32 CONTROLLER;
    bytes32 FREEZER;
    bytes32 RELAYER;

    address admin   = makeAddr("admin");
    address freezer = makeAddr("freezer");
    address pocket  = makeAddr("pocket");
    address relayer = makeAddr("relayer");

    /**********************************************************************************************/
    /*** Base addresses                                                                         ***/
    /**********************************************************************************************/

    address CCTP_MESSENGER_BASE = 0x1682Ae6375C4E4A97e4B583BC394c861A46D8962;
    address USDC_BASE           = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

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

    MockRateProvider rateProvider;

    IPSM3 psmBase;

    /**********************************************************************************************/
    /*** Test setup                                                                             ***/
    /**********************************************************************************************/

    function setUp() public virtual {
        vm.createSelectFork(getChain('base').rpcUrl, 18181500);  // August 8, 2024

        usdsBase  = IERC20(address(new ERC20Mock()));
        susdsBase = IERC20(address(new ERC20Mock()));
        usdcBase  = IERC20(USDC_BASE);

        rateProvider = new MockRateProvider();

        rateProvider.__setConversionRate(1.25e27);

        deal(address(usdsBase), address(this), 1e18);  // For seeding PSM during deployment

        psmBase = IPSM3(PSM3Deploy.deploy(
            admin, USDC_BASE, address(usdsBase), address(susdsBase), address(rateProvider)
        ));

        vm.prank(admin);
        psmBase.setPocket(pocket);

        vm.prank(pocket);
        usdcBase.approve(address(psmBase), type(uint256).max);

        almProxy = new ALMProxy(admin);

        rateLimits = new RateLimits(admin);

        foreignController = new ForeignController({
            admin_      : admin,
            proxy_      : address(almProxy),
            rateLimits_ : address(rateLimits),
            psm_        : address(psmBase),
            usdc_       : USDC_BASE,
            cctp_       : CCTP_MESSENGER_BASE
        });

        CONTROLLER = almProxy.CONTROLLER();
        FREEZER    = foreignController.FREEZER();
        RELAYER    = foreignController.RELAYER();

        vm.startPrank(admin);

        foreignController.grantRole(FREEZER, freezer);
        foreignController.grantRole(RELAYER, relayer);

        almProxy.grantRole(CONTROLLER, address(foreignController));

        rateLimits.grantRole(CONTROLLER, address(foreignController));

        // Setup rate limits
        rateLimits.setRateLimitData(_makeDepositKey(usdcBase),   5_000_000e6,  uint256(1_000_000e6)  / 4 hours);
        rateLimits.setRateLimitData(_makeDepositKey(usdsBase),   5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(_makeDepositKey(susdsBase),  5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(_makeWithdrawKey(usdcBase),  5_000_000e6,  uint256(1_000_000e6)  / 4 hours);
        rateLimits.setRateLimitData(_makeWithdrawKey(usdsBase),  5_000_000e18, uint256(1_000_000e18) / 4 hours);
        rateLimits.setRateLimitData(_makeWithdrawKey(susdsBase), 5_000_000e18, uint256(1_000_000e18) / 4 hours);

        vm.stopPrank();
    }

    function _makeDepositKey(IERC20 asset) internal view returns (bytes32) {
        return RateLimitHelpers.makeAssetKey(foreignController.LIMIT_PSM_DEPOSIT(), address(asset));
    }

    function _makeWithdrawKey(IERC20 asset) internal view returns (bytes32) {
        return RateLimitHelpers.makeAssetKey(foreignController.LIMIT_PSM_WITHDRAW(), address(asset));
    }

}
