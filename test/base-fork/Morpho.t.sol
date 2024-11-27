// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/base-fork/ForkTestBase.t.sol";

import { IERC4626 } from "lib/forge-std/src/interfaces/IERC4626.sol";

import { RateLimitHelpers } from "src/RateLimitHelpers.sol";

import { IMetaMorpho, Id }       from "metamorpho/interfaces/IMetaMorpho.sol";
import { MarketParamsLib }       from "morpho-blue/src/libraries/MarketParamsLib.sol";
import { IMorpho, MarketParams } from "morpho-blue/src/interfaces/IMorpho.sol";

contract MorphoBaseTest is ForkTestBase {

    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    address constant MORPHO_VAULT_USDS = 0x0fFDeCe791C5a2cb947F8ddBab489E5C02c6d4F7;
    address constant MORPHO_VAULT_USDC = 0x305E03Ed9ADaAB22F4A58c24515D79f2B1E2FD5D;

    IERC4626 usdsVault = IERC4626(MORPHO_VAULT_USDS);
    IERC4626 usdcVault = IERC4626(MORPHO_VAULT_USDC);

    function setUp() public override {
        super.setUp();

        vm.startPrank(Base.SPARK_EXECUTOR);

        // Add in the idle markets so deposits can be made
        MarketParams memory usdsParams = MarketParams({
            loanToken:       Base.USDS,
            collateralToken: address(0),
            oracle:          address(0),
            irm:             address(0),
            lltv:            0
        });
        MarketParams memory usdcParams = MarketParams({
            loanToken:       Base.USDC,
            collateralToken: address(0),
            oracle:          address(0),
            irm:             address(0),
            lltv:            0
        });
        IMorpho(MORPHO).createMarket(
            usdsParams
        );
        // USDC idle market already exists
        IMetaMorpho(MORPHO_VAULT_USDS).submitCap(
            usdsParams,
            type(uint184).max
        );
        IMetaMorpho(MORPHO_VAULT_USDC).submitCap(
            usdcParams,
            type(uint184).max
        );

        skip(1 days);

        IMetaMorpho(MORPHO_VAULT_USDS).acceptCap(usdsParams);
        IMetaMorpho(MORPHO_VAULT_USDC).acceptCap(usdcParams);
        
        Id[] memory supplyQueueUSDS = new Id[](1);
        supplyQueueUSDS[0] = MarketParamsLib.id(usdsParams);
        IMetaMorpho(MORPHO_VAULT_USDS).setSupplyQueue(supplyQueueUSDS);
        Id[] memory supplyQueueUSDC = new Id[](1);
        supplyQueueUSDC[0] = MarketParamsLib.id(usdcParams);
        IMetaMorpho(MORPHO_VAULT_USDC).setSupplyQueue(supplyQueueUSDC);

        rateLimits.setRateLimitData(
            RateLimitHelpers.makeAssetKey(
                foreignController.LIMIT_4626_DEPOSIT(),
                MORPHO_VAULT_USDS
            ),
            25_000_000e18,
            uint256(5_000_000e18) / 1 days
        );
        rateLimits.setRateLimitData(
            RateLimitHelpers.makeAssetKey(
                foreignController.LIMIT_4626_DEPOSIT(),
                MORPHO_VAULT_USDC
            ),
            25_000_000e6,
            uint256(5_000_000e6) / 1 days
        );

        vm.stopPrank();
    }

    function _getBlock() internal pure override returns (uint256) {
        return 22841965;  // November 24, 2024
    }

}

/**********************************************************************************************/
/*** Only testing USDS failure modes because it is the same for USDC                        ***/
/**********************************************************************************************/

contract MorphoFailureTests is MorphoBaseTest {

    function test_morpho_deposit_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        foreignController.depositERC4626(MORPHO_VAULT_USDS, 1_000_000e18);
    }

    function test_morpho_deposit_frozen() external {
        vm.prank(freezer);
        foreignController.freeze();

        vm.prank(relayer);
        vm.expectRevert("ForeignController/not-active");
        foreignController.depositERC4626(MORPHO_VAULT_USDS, 1_000_000e18);
    }

    function test_morpho_deposit_rateLimited() external {
        deal(Base.USDS, address(almProxy), 25_000_001e18);

        assertEq(usdsVault.convertToAssets(usdsVault.balanceOf(address(almProxy))), 0);
        assertEq(IERC20(Base.USDS).balanceOf(address(almProxy)),                    25_000_001e18);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(relayer);
        foreignController.depositERC4626(MORPHO_VAULT_USDS, 25_000_001e18);

        vm.prank(relayer);
        foreignController.depositERC4626(MORPHO_VAULT_USDS, 25_000_000e18);

        assertEq(usdsVault.convertToAssets(usdsVault.balanceOf(address(almProxy))), 25_000_000e18);
        assertEq(IERC20(Base.USDS).balanceOf(address(almProxy)),                    1e18);
    }

    function test_morpho_withdraw_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        foreignController.withdrawERC4626(MORPHO_VAULT_USDS, 1_000_000e18);
    }

    function test_morpho_withdraw_frozen() external {
        vm.prank(freezer);
        foreignController.freeze();

        vm.prank(relayer);
        vm.expectRevert("ForeignController/not-active");
        foreignController.withdrawERC4626(MORPHO_VAULT_USDS, 1_000_000e18);
    }

    function test_morpho_redeem_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        foreignController.redeemERC4626(MORPHO_VAULT_USDS, 1_000_000e18);
    }

    function test_morpho_redeem_frozen() external {
        vm.prank(freezer);
        foreignController.freeze();

        vm.prank(relayer);
        vm.expectRevert("ForeignController/not-active");
        foreignController.redeemERC4626(MORPHO_VAULT_USDS, 1_000_000e18);
    }

}

/**********************************************************************************************/
/*** Success modes testing both USDS and USDC                                               ***/
/**********************************************************************************************/

contract MorphoUSDSSuccessTests is MorphoBaseTest {

    function test_morpho_usds_deposit() public {
        deal(Base.USDS, address(almProxy), 1_000_000e18);

        assertEq(usdsVault.convertToAssets(usdsVault.balanceOf(address(almProxy))), 0);
        assertEq(IERC20(Base.USDS).balanceOf(address(almProxy)),                    1_000_000e18);

        vm.prank(relayer);
        foreignController.depositERC4626(MORPHO_VAULT_USDS, 1_000_000e18);

        assertEq(usdsVault.convertToAssets(usdsVault.balanceOf(address(almProxy))), 1_000_000e18);
        assertEq(IERC20(Base.USDS).balanceOf(address(almProxy)),                    0);
    }

    function test_morpho_usds_withdraw() public {
        deal(Base.USDS, address(almProxy), 1_000_000e18);
        vm.prank(relayer);
        foreignController.depositERC4626(MORPHO_VAULT_USDS, 1_000_000e18);

        assertEq(usdsVault.convertToAssets(usdsVault.balanceOf(address(almProxy))), 1_000_000e18);
        assertEq(IERC20(Base.USDS).balanceOf(address(almProxy)),                    0);

        vm.prank(relayer);
        foreignController.withdrawERC4626(MORPHO_VAULT_USDS, 1_000_000e18);

        assertEq(usdsVault.convertToAssets(usdsVault.balanceOf(address(almProxy))), 0);
        assertEq(IERC20(Base.USDS).balanceOf(address(almProxy)),                    1_000_000e18);
    }

    function test_morpho_usds_redeem() public {
        deal(Base.USDS, address(almProxy), 1_000_000e18);
        vm.prank(relayer);
        foreignController.depositERC4626(MORPHO_VAULT_USDS, 1_000_000e18);

        assertEq(usdsVault.convertToAssets(usdsVault.balanceOf(address(almProxy))), 1_000_000e18);
        assertEq(IERC20(Base.USDS).balanceOf(address(almProxy)),                    0);

        uint256 shares = usdsVault.balanceOf(address(almProxy));
        vm.prank(relayer);
        foreignController.redeemERC4626(MORPHO_VAULT_USDS, shares);

        assertEq(usdsVault.convertToAssets(usdsVault.balanceOf(address(almProxy))), 0);
        assertEq(IERC20(Base.USDS).balanceOf(address(almProxy)),                    1_000_000e18);
    }

}

contract MorphoUSDCSuccessTests is MorphoBaseTest {

    function test_morpho_usdc_deposit() public {
        deal(Base.USDC, address(almProxy), 1_000_000e6);

        assertEq(usdcVault.convertToAssets(usdcVault.balanceOf(address(almProxy))), 0);
        assertEq(IERC20(Base.USDC).balanceOf(address(almProxy)),                    1_000_000e6);

        vm.prank(relayer);
        foreignController.depositERC4626(MORPHO_VAULT_USDC, 1_000_000e6);

        assertEq(usdcVault.convertToAssets(usdcVault.balanceOf(address(almProxy))), 1_000_000e6);
        assertEq(IERC20(Base.USDC).balanceOf(address(almProxy)),                    0);
    }

    function test_morpho_usdc_withdraw() public {
        deal(Base.USDC, address(almProxy), 1_000_000e6);
        vm.prank(relayer);
        foreignController.depositERC4626(MORPHO_VAULT_USDC, 1_000_000e6);

        assertEq(usdcVault.convertToAssets(usdcVault.balanceOf(address(almProxy))), 1_000_000e6);
        assertEq(IERC20(Base.USDC).balanceOf(address(almProxy)),                    0);

        vm.prank(relayer);
        foreignController.withdrawERC4626(MORPHO_VAULT_USDC, 1_000_000e6);

        assertEq(usdcVault.convertToAssets(usdcVault.balanceOf(address(almProxy))), 0);
        assertEq(IERC20(Base.USDC).balanceOf(address(almProxy)),                    1_000_000e6);
    }

    function test_morpho_usdc_redeem() public {
        deal(Base.USDC, address(almProxy), 1_000_000e6);
        vm.prank(relayer);
        foreignController.depositERC4626(MORPHO_VAULT_USDC, 1_000_000e6);

        assertEq(usdcVault.convertToAssets(usdcVault.balanceOf(address(almProxy))), 1_000_000e6);
        assertEq(IERC20(Base.USDC).balanceOf(address(almProxy)),                    0);

        uint256 shares = usdcVault.balanceOf(address(almProxy));
        vm.prank(relayer);
        foreignController.redeemERC4626(MORPHO_VAULT_USDC, shares);

        assertEq(usdcVault.convertToAssets(usdcVault.balanceOf(address(almProxy))), 0);
        assertEq(IERC20(Base.USDC).balanceOf(address(almProxy)),                    1_000_000e6);
    }

}
