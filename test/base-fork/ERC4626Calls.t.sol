// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/base-fork/ForkTestBase.t.sol";

import { RateLimitHelpers } from "src/RateLimitHelpers.sol";

contract ForeignControllerMorphoTestBase is ForkTestBase {

    address constant MORPHO_VAULT_USDS = 0x0fFDeCe791C5a2cb947F8ddBab489E5C02c6d4F7;
    address constant MORPHO_VAULT_USDC = 0x305E03Ed9ADaAB22F4A58c24515D79f2B1E2FD5D;

    IERC4626 usdsVault = IERC4626(MORPHO_VAULT_USDS);
    IERC4626 usdcVault = IERC4626(MORPHO_VAULT_USDC);

    function setUp() public override {
        super.setUp();

        vm.startPrank(Base.SPARK_EXECUTOR);

        

        vm.stopPrank();

        rateLimits.setRateLimitData(
            RateLimitHelpers.makeVaultKey(
                foreignController.LIMIT_VAULT_DEPOSIT(),
                MORPHO_VAULT_USDS
            ),
            25_000_000e18,
            uint256(5_000_000e18) / 1 days
        );
        rateLimits.setRateLimitData(
            RateLimitHelpers.makeVaultKey(
                foreignController.LIMIT_VAULT_DEPOSIT(),
                MORPHO_VAULT_USDC
            ),
            25_000_000e6,
            uint256(5_000_000e6) / 1 days
        );
    }

    function test_morpho_usds_deposit() public {
        deal(Base.USDS, address(almProxy), 1_000_000e18);

        assertEq(usdsVault)

        foreignController.depositVault(MORPHO_VAULT_USDS, 1_000_000e18);
    }

}
