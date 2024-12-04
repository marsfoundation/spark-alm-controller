// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/mainnet-fork/ForkTestBase.t.sol";

interface IEthenaMinterLike {
    function delegatedSigner(address signer, address owner) external view returns (uint8);
}

contract MainnetControllerSetDelegatedSignerFailureTests is ForkTestBase {

    function test_setDelegatedSigner_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.setDelegatedSigner(makeAddr("signer"));
    }

    function test_setDelegatedSigner_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.setDelegatedSigner(makeAddr("signer"));
    }

}

contract MainnetControllerSetDelegatedSignerSuccessTests is ForkTestBase {

    event DelegatedSignerInitiated(address indexed delegateTo, address indexed initiatedBy);

    function test_setDelegatedSigner() external {
        address signer = makeAddr("signer");

        IEthenaMinterLike ethenaMinter = IEthenaMinterLike(ETHENA_MINTER);

        assertEq(ethenaMinter.delegatedSigner(signer, address(almProxy)), 0);  // REJECTED

        vm.prank(relayer);
        vm.expectEmit(ETHENA_MINTER);
        emit DelegatedSignerInitiated(signer, address(almProxy));
        mainnetController.setDelegatedSigner(signer);

        assertEq(ethenaMinter.delegatedSigner(signer, address(almProxy)), 1);  // PENDING
    }

}

contract MainnetControllerRemoveDelegatedSignerFailureTests is ForkTestBase {

    function test_removeDelegatedSigner_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.removeDelegatedSigner(makeAddr("signer"));
    }

    function test_removeDelegatedSigner_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.removeDelegatedSigner(makeAddr("signer"));
    }

}

contract MainnetControllerRemoveDelegatedSignerSuccessTests is ForkTestBase {

    event DelegatedSignerRemoved(address indexed removedSigner, address indexed initiatedBy);

    function test_removeDelegatedSigner() external {
        address signer = makeAddr("signer");

        IEthenaMinterLike ethenaMinter = IEthenaMinterLike(ETHENA_MINTER);

        vm.prank(relayer);
        mainnetController.setDelegatedSigner(signer);

        assertEq(ethenaMinter.delegatedSigner(signer, address(almProxy)), 1);  // PENDING

        vm.prank(relayer);
        vm.expectEmit(ETHENA_MINTER);
        emit DelegatedSignerRemoved(signer, address(almProxy));
        mainnetController.removeDelegatedSigner(signer);

        assertEq(ethenaMinter.delegatedSigner(signer, address(almProxy)), 0);  // REJECTED
    }

}

contract MainnetControllerPrepareUSDeMintFailureTests is ForkTestBase {

    function test_prepareUSDeMint_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.prepareUSDeMint(100);
    }

    function test_prepareUSDeMint_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.prepareUSDeMint(100);
    }

    function test_prepareUSDeMint_rateLimitBoundary() external {
        vm.prank(relayer);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.prepareUSDeMint(5_000_000e6 + 1);

        vm.prank(relayer);
        mainnetController.prepareUSDeMint(5_000_000e6);
    }

}

contract MainnetControllerPrepareUSDeMintSuccessTests is ForkTestBase {

    function test_prepareUSDeMint() external {
        assertEq(usdc.allowance(address(almProxy), ETHENA_MINTER), 0);

        vm.prank(relayer);
        mainnetController.prepareUSDeMint(5_000_000e6);

        assertEq(usdc.allowance(address(almProxy), ETHENA_MINTER), 5_000_000e6);
    }

    function test_prepareUSDeMint_rateLimits() external {
        assertEq(rateLimits.getCurrentRateLimit(usdeMintKey), 5_000_000e6);

        vm.prank(relayer);
        mainnetController.prepareUSDeMint(4_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(usdeMintKey), 1_000_000e6);

        skip(4 hours);

        assertEq(rateLimits.getCurrentRateLimit(usdeMintKey), 2_000_000e6 - 6400);  // Rounding

        vm.prank(relayer);
        mainnetController.prepareUSDeMint(600_000e6);

        assertEq(rateLimits.getCurrentRateLimit(usdeMintKey), 1_400_000e6 - 6400);  // Rounding
    }

}

contract MainnetControllerPrepareUSDeBurnFailureTests is ForkTestBase {

    function test_prepareUSDeBurn_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.prepareUSDeBurn(100);
    }

    function test_prepareUSDeBurn_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.prepareUSDeBurn(100);
    }

    function test_prepareUSDeBurn_rateLimitBoundary() external {
        vm.prank(relayer);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.prepareUSDeBurn(5_000_000e18 + 1);

        vm.prank(relayer);
        mainnetController.prepareUSDeBurn(5_000_000e18);
    }

}

contract MainnetControllerPrepareUSDeBurnSuccessTests is ForkTestBase {

    function test_prepareUSDeBurn() external {
        assertEq(usde.allowance(address(almProxy), ETHENA_MINTER), 0);

        vm.prank(relayer);
        mainnetController.prepareUSDeBurn(5_000_000e18);

        assertEq(usde.allowance(address(almProxy), ETHENA_MINTER), 5_000_000e18);
    }

    function test_prepareUSDeBurn_rateLimits() external {
        assertEq(rateLimits.getCurrentRateLimit(usdeBurnKey), 5_000_000e18);

        vm.prank(relayer);
        mainnetController.prepareUSDeBurn(4_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(usdeBurnKey), 1_000_000e18);

        skip(4 hours);

        assertEq(rateLimits.getCurrentRateLimit(usdeBurnKey), 2_000_000e18 - 6400);  // Rounding

        vm.prank(relayer);
        mainnetController.prepareUSDeBurn(600_000e18);

        assertEq(rateLimits.getCurrentRateLimit(usdeBurnKey), 1_400_000e18 - 6400);  // Rounding
    }

}

contract MainnetControllerCooldownAssetsSUSDeFailureTests is ForkTestBase {

    function test_cooldownAssetsSUSDe_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.cooldownAssetsSUSDe(5_000_000e18);
    }

    function test_cooldownAssetsSUSDe_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.cooldownAssetsSUSDe(5_000_000e18);
    }

    function test_cooldownAssetsSUSDe_rateLimitBoundary() external {
        // For success case (exchange rate is more than 1:1)
        deal(address(susde), address(almProxy), 5_000_000e18);

        vm.startPrank(relayer);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.cooldownAssetsSUSDe(5_000_000e18 + 1);

        mainnetController.cooldownAssetsSUSDe(5_000_000e18);
    }

}

contract MainnetControllerCooldownAssetsSUSDeSuccessTests is ForkTestBase {

    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    function test_cooldownAssetsSUSDe() external {
        address silo = susde.silo();

        uint256 startingSiloBalance = usde.balanceOf(silo);

        uint256 assets = susde.convertToAssets(100e18);

        // Exchange rate is more than 1:1
        deal(address(susde), address(almProxy), 100e18);

        assertEq(susde.balanceOf(address(almProxy)), 100e18);
        assertEq(usde.balanceOf(silo),               startingSiloBalance);

        vm.prank(relayer);
        vm.expectEmit(address(susde));
        emit Withdraw(address(almProxy), silo, address(almProxy), assets, 100e18);
        mainnetController.cooldownAssetsSUSDe(assets);

        assertEq(susde.balanceOf(address(almProxy)), 0);
        assertEq(usde.balanceOf(silo),               startingSiloBalance + assets);
    }

    function test_cooldownAssetsSUSDe_rateLimits() external {
        // Exchange rate is more than 1:1
        deal(address(susde), address(almProxy), 5_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(susdeCooldownKey), 5_000_000e18);

        vm.prank(relayer);
        mainnetController.cooldownAssetsSUSDe(4_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(susdeCooldownKey), 1_000_000e18);

        skip(4 hours);

        assertEq(rateLimits.getCurrentRateLimit(susdeCooldownKey), 2_000_000e18 - 6400);  // Rounding

        vm.prank(relayer);
        mainnetController.cooldownAssetsSUSDe(600_000e18);

        assertEq(rateLimits.getCurrentRateLimit(susdeCooldownKey), 1_400_000e18 - 6400);  // Rounding
    }

}

contract MainnetControllerCooldownSharesSUSDeFailureTests is ForkTestBase {

    function test_cooldownSharesSUSDe_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.cooldownSharesSUSDe(100);
    }

    function test_cooldownSharesSUSDe_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.cooldownSharesSUSDe(100);
    }

    function test_cooldownSharesSUSDe_rateLimitBoundary() external {
        deal(address(susde), address(almProxy), 5_000_000e18);  // For success case

        uint256 overBoundaryShares = susde.convertToShares(5_000_000e18 + 2);
        uint256 boundaryShares     = susde.convertToShares(5_000_000e18 + 1);

        // Demonstrate how rounding works
        assertEq(susde.convertToAssets(overBoundaryShares), 5_000_000e18 + 1);
        assertEq(susde.convertToAssets(boundaryShares),     5_000_000e18);

        vm.startPrank(relayer);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.cooldownSharesSUSDe(overBoundaryShares);

        mainnetController.cooldownSharesSUSDe(boundaryShares);
    }

}

contract MainnetControllerCooldownSharesSUSDeSuccessTests is ForkTestBase {

    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    function test_cooldownSharesSUSDe() external {
        address silo = susde.silo();

        uint256 startingSiloBalance = usde.balanceOf(silo);

        uint256 assets = susde.convertToAssets(100e18);

        deal(address(susde), address(almProxy), 100e18);

        assertEq(susde.balanceOf(address(almProxy)), 100e18);
        assertEq(usde.balanceOf(silo),               startingSiloBalance);

        vm.prank(relayer);
        vm.expectEmit(address(susde));
        emit Withdraw(address(almProxy), silo, address(almProxy), assets, 100e18);
        mainnetController.cooldownSharesSUSDe(100e18);

        assertEq(susde.balanceOf(address(almProxy)), 0);
        assertEq(usde.balanceOf(silo),               startingSiloBalance + assets);
    }

    function test_cooldownSharesSUSDe_rateLimits() external {
        // Exchange rate is more than 1:1
        deal(address(susde), address(almProxy), 5_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(susdeCooldownKey), 5_000_000e18);

        vm.prank(relayer);
        mainnetController.cooldownSharesSUSDe(4_000_000e18);

        uint256 assets1 = susde.convertToAssets(4_000_000e18);

        assertGe(assets1, 4_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(susdeCooldownKey), 5_000_000e18 - assets1);

        skip(4 hours);

        assertEq(rateLimits.getCurrentRateLimit(susdeCooldownKey), 5_000_000e18 - assets1 + (1_000_000e18 - 6400));  // Rounding

        vm.prank(relayer);
        mainnetController.cooldownSharesSUSDe(600_000e18);

        uint256 assets2 = susde.convertToAssets(600_000e18);

        assertGe(assets2, 600_000e18);

        assertEq(rateLimits.getCurrentRateLimit(susdeCooldownKey), 5_000_000e18 - assets1 + (1_000_000e18 - 6400) - assets2);
    }

}

contract MainnetControllerUnstakeSUSDeFailureTests is ForkTestBase {

    function test_unstakeSUSDe_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.unstakeSUSDe();
    }

    function test_unstakeSUSDe_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.unstakeSUSDe();
    }

    function test_unstakeSUSDe_cooldownBoundary() external {
        // Exchange rate greater than 1:1
        deal(address(susde), address(almProxy), 100e18);

        vm.prank(relayer);
        mainnetController.cooldownAssetsSUSDe(100e18);

        skip(7 days - 1);  // Cooldown period boundary

        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSignature("InvalidCooldown()"));
        mainnetController.unstakeSUSDe();

        skip(1 seconds);

        vm.prank(relayer);
        mainnetController.unstakeSUSDe();
    }

}

contract MainnetControllerUnstakeSUSDeSuccessTests is ForkTestBase {

    function test_unstakeSUSDe() external {
        address silo = susde.silo();

        uint256 startingSiloBalance = usde.balanceOf(silo);

        uint256 assets = susde.convertToAssets(100e18);

        deal(address(susde), address(almProxy), 100e18);

        vm.prank(relayer);
        mainnetController.cooldownSharesSUSDe(100e18);

        assertEq(usde.balanceOf(address(almProxy)), 0);
        assertEq(usde.balanceOf(silo),              startingSiloBalance + assets);

        skip(7 days);  // Cooldown period

        vm.prank(relayer);
        mainnetController.unstakeSUSDe();

        assertEq(usde.balanceOf(address(almProxy)), assets);
        assertEq(usde.balanceOf(silo),              startingSiloBalance);
    }

}

contract MainnetControllerEthenaE2ETests is ForkTestBase {

    address signer = makeAddr("signer");

    // NOTE: In reality this is performed by the signer submitting an order with an EIP712 signature
    //       which is verified by the ethenaMinter contract, minting USDe into the ALMProxy.
    //       Also, for the purposes of this test, minting is done 1:1 with USDC.
    function _simulateUsdeMint(uint256 amount) internal {
        vm.prank(ETHENA_MINTER);
        usdc.transferFrom(address(almProxy), ETHENA_MINTER, amount);
        deal(address(usde), address(almProxy), amount * 1e12);
    }

    // NOTE: In reality this is performed by the signer submitting an order with an EIP712 signature
    //       which is verified by the ethenaMinter contract, minting USDe into the ALMProxy.
    //       Also, for the purposes of this test, minting is done 1:1 with USDC.
    function _simulateUsdeBurn(uint256 amount) internal {
        vm.prank(ETHENA_MINTER);
        usde.transferFrom(address(almProxy), ETHENA_MINTER, amount);
        deal(address(usdc), address(almProxy), amount / 1e12);
    }

    function test_ethena_e2eFlowUsingAssets() external {
        deal(address(usdc), address(almProxy), 1_000_000e6);

        uint256 startingMinterBalance = usdc.balanceOf(ETHENA_MINTER);  // From mainnet state

        // Step 1: Mint USDe

        assertEq(rateLimits.getCurrentRateLimit(usdeMintKey), 5_000_000e6);

        vm.prank(relayer);
        mainnetController.prepareUSDeMint(1_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(usdeMintKey), 4_000_000e6);

        assertEq(usdc.allowance(address(almProxy), ETHENA_MINTER), 1_000_000e6);

        assertEq(usdc.balanceOf(address(almProxy)), 1_000_000e6);
        assertEq(usdc.balanceOf(ETHENA_MINTER),     startingMinterBalance);

        assertEq(usde.balanceOf(address(almProxy)), 0);

        _simulateUsdeMint(1_000_000e6);

        assertEq(usdc.allowance(address(almProxy), ETHENA_MINTER), 0);

        assertEq(usdc.balanceOf(address(almProxy)), 0);
        assertEq(usdc.balanceOf(ETHENA_MINTER),     startingMinterBalance + 1_000_000e6);

        assertEq(usde.balanceOf(address(almProxy)), 1_000_000e18);

        // Step 2: Convert half of assets to sUSDe

        uint256 startingAssets = usde.balanceOf(address(susde));

        assertEq(usde.allowance(address(almProxy), address(susde)), 0);

        assertEq(susde.convertToAssets(susde.balanceOf(address(almProxy))), 0);

        assertEq(usde.balanceOf(address(susde)),    startingAssets);
        assertEq(usde.balanceOf(address(almProxy)), 1_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(susdeDepositKey), 5_000_000e18);

        vm.prank(relayer);
        mainnetController.depositERC4626(address(susde), 500_000e18);

        assertEq(rateLimits.getCurrentRateLimit(susdeDepositKey), 4_500_000e18);

        assertEq(usde.allowance(address(almProxy), address(susde)), 0);

        assertEq(susde.convertToAssets(susde.balanceOf(address(almProxy))), 500_000e18 - 1);  // Rounding

        assertEq(usde.balanceOf(address(susde)),    startingAssets + 500_000e18);
        assertEq(usde.balanceOf(address(almProxy)), 500_000e18);

        // Step 3: Cooldown sUSDe

        address silo = susde.silo();

        uint256 startingSiloBalance = usde.balanceOf(silo);

        assertEq(susde.convertToAssets(susde.balanceOf(address(almProxy))), 500_000e18 - 1);  // Rounding

        assertEq(usde.balanceOf(silo), startingSiloBalance);

        assertEq(rateLimits.getCurrentRateLimit(susdeCooldownKey), 5_000_000e18);

        vm.prank(relayer);
        mainnetController.cooldownAssetsSUSDe(500_000e18 - 1);

        assertEq(rateLimits.getCurrentRateLimit(susdeCooldownKey), 4_500_000e18 + 1);

        assertEq(susde.convertToAssets(susde.balanceOf(address(almProxy))), 0);

        assertEq(usde.balanceOf(silo), startingSiloBalance + 500_000e18 - 1);

        // Step 4: Wait for cooldown window to pass then unstake sUSDe

        skip(7 days);

        assertEq(usde.balanceOf(silo),              startingSiloBalance + 500_000e18 - 1);
        assertEq(usde.balanceOf(address(almProxy)), 500_000e18);

        vm.prank(relayer);
        mainnetController.unstakeSUSDe();

        assertEq(usde.balanceOf(silo),              startingSiloBalance);
        assertEq(usde.balanceOf(address(almProxy)), 1_000_000e18 - 1);

        // Step 5: Redeem USDe for USDC

        startingMinterBalance = usde.balanceOf(ETHENA_MINTER);  // From mainnet state

        assertEq(rateLimits.getCurrentRateLimit(usdeBurnKey), 5_000_000e18);

        vm.prank(relayer);
        mainnetController.prepareUSDeBurn(1_000_000e18 - 1);

        assertEq(rateLimits.getCurrentRateLimit(usdeBurnKey), 4_000_000e18 + 1);

        assertEq(usde.allowance(address(almProxy), ETHENA_MINTER), 1_000_000e18 - 1);

        assertEq(usde.balanceOf(address(almProxy)), 1_000_000e18 - 1);
        assertEq(usde.balanceOf(ETHENA_MINTER),     startingMinterBalance);

        assertEq(usdc.balanceOf(address(almProxy)), 0);

        _simulateUsdeBurn(1_000_000e18 - 1);

        assertEq(usde.allowance(address(almProxy), ETHENA_MINTER), 0);

        assertEq(usde.balanceOf(address(almProxy)), 0);
        assertEq(usde.balanceOf(ETHENA_MINTER),     startingMinterBalance + 1_000_000e18 - 1);

        assertEq(usdc.balanceOf(address(almProxy)), 1_000_000e6 - 1);  // Rounding
    }

    function test_ethena_e2eFlowUsingShares() external {
        deal(address(usdc), address(almProxy), 1_000_000e6);

        uint256 startingMinterBalance = usdc.balanceOf(ETHENA_MINTER);  // From mainnet state

        // Step 1: Mint USDe

        assertEq(rateLimits.getCurrentRateLimit(usdeMintKey), 5_000_000e6);

        vm.prank(relayer);
        mainnetController.prepareUSDeMint(1_000_000e6);

        assertEq(rateLimits.getCurrentRateLimit(usdeMintKey), 4_000_000e6);

        assertEq(usdc.allowance(address(almProxy), ETHENA_MINTER), 1_000_000e6);

        assertEq(usdc.balanceOf(address(almProxy)), 1_000_000e6);
        assertEq(usdc.balanceOf(ETHENA_MINTER),     startingMinterBalance);

        assertEq(usde.balanceOf(address(almProxy)), 0);

        _simulateUsdeMint(1_000_000e6);

        assertEq(usdc.allowance(address(almProxy), ETHENA_MINTER), 0);

        assertEq(usdc.balanceOf(address(almProxy)), 0);
        assertEq(usdc.balanceOf(ETHENA_MINTER),     startingMinterBalance + 1_000_000e6);

        assertEq(usde.balanceOf(address(almProxy)), 1_000_000e18);

        // Step 2: Convert half of assets to sUSDe

        uint256 startingAssets = usde.balanceOf(address(susde));

        assertEq(usde.allowance(address(almProxy), address(susde)), 0);

        assertEq(susde.convertToAssets(susde.balanceOf(address(almProxy))), 0);

        assertEq(usde.balanceOf(address(susde)),    startingAssets);
        assertEq(usde.balanceOf(address(almProxy)), 1_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(susdeDepositKey), 5_000_000e18);

        vm.prank(relayer);
        uint256 susdeShares = mainnetController.depositERC4626(address(susde), 500_000e18);

        assertEq(rateLimits.getCurrentRateLimit(susdeDepositKey), 4_500_000e18);

        assertEq(susde.balanceOf(address(almProxy)), susdeShares);

        assertEq(usde.allowance(address(almProxy), address(susde)), 0);

        assertEq(susde.convertToAssets(susdeShares), 500_000e18 - 1);  // Rounding

        assertEq(usde.balanceOf(address(susde)),    startingAssets + 500_000e18);
        assertEq(usde.balanceOf(address(almProxy)), 500_000e18);

        // Step 3: Cooldown sUSDe

        address silo = susde.silo();

        uint256 startingSiloBalance = usde.balanceOf(silo);

        assertEq(susde.convertToAssets(susde.balanceOf(address(almProxy))), 500_000e18 - 1);  // Rounding

        assertEq(usde.balanceOf(silo), startingSiloBalance);

        assertEq(rateLimits.getCurrentRateLimit(susdeCooldownKey), 5_000_000e18);

        vm.prank(relayer);
        mainnetController.cooldownSharesSUSDe(susdeShares);

        assertEq(rateLimits.getCurrentRateLimit(susdeCooldownKey), 4_500_000e18 + 1);

        assertEq(susde.convertToAssets(susde.balanceOf(address(almProxy))), 0);

        assertEq(usde.balanceOf(silo), startingSiloBalance + 500_000e18 - 1);

        // Step 4: Wait for cooldown window to pass then unstake sUSDe

        skip(7 days);

        assertEq(usde.balanceOf(silo),              startingSiloBalance + 500_000e18 - 1);
        assertEq(usde.balanceOf(address(almProxy)), 500_000e18);

        vm.prank(relayer);
        mainnetController.unstakeSUSDe();

        assertEq(usde.balanceOf(silo),              startingSiloBalance);
        assertEq(usde.balanceOf(address(almProxy)), 1_000_000e18 - 1);

        // Step 5: Redeem USDe for USDC

        startingMinterBalance = usde.balanceOf(ETHENA_MINTER);  // From mainnet state

        assertEq(rateLimits.getCurrentRateLimit(usdeBurnKey), 5_000_000e18);

        vm.prank(relayer);
        mainnetController.prepareUSDeBurn(1_000_000e18 - 1);

        assertEq(rateLimits.getCurrentRateLimit(usdeBurnKey), 4_000_000e18 + 1);

        assertEq(usde.allowance(address(almProxy), ETHENA_MINTER), 1_000_000e18 - 1);

        assertEq(usde.balanceOf(address(almProxy)), 1_000_000e18 - 1);
        assertEq(usde.balanceOf(ETHENA_MINTER),     startingMinterBalance);

        assertEq(usdc.balanceOf(address(almProxy)), 0);

        _simulateUsdeBurn(1_000_000e18 - 1);

        assertEq(usde.allowance(address(almProxy), ETHENA_MINTER), 0);

        assertEq(usde.balanceOf(address(almProxy)), 0);
        assertEq(usde.balanceOf(ETHENA_MINTER),     startingMinterBalance + 1_000_000e18 - 1);

        assertEq(usdc.balanceOf(address(almProxy)), 1_000_000e6 - 1);  // Rounding
    }

    function test_e2e_cooldownSharesAndAssets_sameRateLimit() public {
        // Exchange rate is more than 1:1
        deal(address(susde), address(almProxy), 5_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(susdeCooldownKey), 5_000_000e18);

        vm.prank(relayer);
        mainnetController.cooldownAssetsSUSDe(4_000_000e18);

        assertEq(rateLimits.getCurrentRateLimit(susdeCooldownKey), 1_000_000e18);

        skip(4 hours);

        assertEq(rateLimits.getCurrentRateLimit(susdeCooldownKey), 1_000_000e18 + (1_000_000e18 - 6400));  // Rounding

        vm.prank(relayer);
        mainnetController.cooldownSharesSUSDe(600_000e18);

        uint256 assets2 = susde.convertToAssets(600_000e18);

        assertGe(assets2, 600_000e18);

        assertEq(rateLimits.getCurrentRateLimit(susdeCooldownKey), 1_000_000e18 + (1_000_000e18 - 6400) - assets2);
    }

}
