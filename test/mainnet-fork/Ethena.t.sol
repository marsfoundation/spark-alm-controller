// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/mainnet-fork/ForkTestBase.t.sol";

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
        vm.prank(relayer);
        vm.expectEmit(ETHENA_MINTER);
        emit DelegatedSignerInitiated(signer, address(almProxy));
        mainnetController.setDelegatedSigner(signer);
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
        vm.prank(relayer);
        vm.expectEmit(ETHENA_MINTER);
        emit DelegatedSignerRemoved(signer, address(almProxy));
        mainnetController.removeDelegatedSigner(signer);
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
        vm.startPrank(SPARK_PROXY);
        rateLimits.setRateLimitData(
            mainnetController.LIMIT_USDE_MINT(),
            100e18,
            uint256(100e18) / 1 hours
        );
        vm.stopPrank();

        vm.prank(relayer);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.prepareUSDeMint(100e18 + 1);

        vm.prank(relayer);
        mainnetController.prepareUSDeMint(100e18);
    }

}

contract MainnetControllerPrepareUSDeMintSuccessTests is ForkTestBase {

    bytes32 key;

    function setUp() public override {
        super.setUp();

        key = mainnetController.LIMIT_USDE_MINT();

        vm.prank(SPARK_PROXY);
        rateLimits.setRateLimitData(key, 100e18, uint256(10e18) / 1 hours);
    }

    function test_prepareUSDeMint() external {
        assertEq(usdc.allowance(address(almProxy), ETHENA_MINTER), 0);

        vm.prank(relayer);
        mainnetController.prepareUSDeMint(100);

        assertEq(usdc.allowance(address(almProxy), ETHENA_MINTER), 100);
    }

    function test_prepareUSDeMint_rateLimits() external {
        assertEq(rateLimits.getCurrentRateLimit(key), 100e18);

        vm.prank(relayer);
        mainnetController.prepareUSDeMint(40e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 60e18);

        skip(1 hours);

        assertEq(rateLimits.getCurrentRateLimit(key), 70e18 - 2800);  // Rounding

        vm.prank(relayer);
        mainnetController.prepareUSDeMint(30e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 40e18 - 2800);  // Rounding
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
        vm.startPrank(SPARK_PROXY);
        rateLimits.setRateLimitData(
            mainnetController.LIMIT_USDE_BURN(),
            100e18,
            uint256(100e18) / 1 hours
        );
        vm.stopPrank();

        vm.prank(relayer);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.prepareUSDeBurn(100e18 + 1);

        vm.prank(relayer);
        mainnetController.prepareUSDeBurn(100e18);
    }

}

contract MainnetControllerPrepareUSDeBurnSuccessTests is ForkTestBase {

    bytes32 key;

    function setUp() public override {
        super.setUp();

        key = mainnetController.LIMIT_USDE_BURN();

        vm.prank(SPARK_PROXY);
        rateLimits.setRateLimitData(key, 100e18, uint256(10e18) / 1 hours);
    }

    function test_prepareUSDeBurn() external {
        assertEq(usde.allowance(address(almProxy), ETHENA_MINTER), 0);

        vm.prank(relayer);
        mainnetController.prepareUSDeBurn(100);

        assertEq(usde.allowance(address(almProxy), ETHENA_MINTER), 100);
    }

    function test_prepareUSDeBurn_rateLimits() external {
        assertEq(rateLimits.getCurrentRateLimit(key), 100e18);

        vm.prank(relayer);
        mainnetController.prepareUSDeBurn(40e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 60e18);

        skip(1 hours);

        assertEq(rateLimits.getCurrentRateLimit(key), 70e18 - 2800);  // Rounding

        vm.prank(relayer);
        mainnetController.prepareUSDeBurn(30e18);

        assertEq(rateLimits.getCurrentRateLimit(key), 40e18 - 2800);  // Rounding
    }

}

contract MainnetControllerCooldownAssetsSUSDeFailureTests is ForkTestBase {

    function test_cooldownAssetsSUSDe_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.cooldownAssetsSUSDe(100);
    }

    function test_cooldownAssetsSUSDe_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.cooldownAssetsSUSDe(100);
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
        deal(address(susde), address(almProxy), 100e18);

        vm.prank(relayer);
        mainnetController.cooldownSharesSUSDe(100e18);

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

    function setUp() public override {
        super.setUp();

        vm.startPrank(SPARK_PROXY);

        rateLimits.setRateLimitData(
            RateLimitHelpers.makeAssetKey(mainnetController.LIMIT_4626_DEPOSIT(), address(susde)),
            5_000_000e18,
            uint256(1_000_000e18) / 4 hours
        );
        rateLimits.setRateLimitData(
            mainnetController.LIMIT_USDE_MINT(),
            5_000_000e18,
            uint256(1_000_000e18) / 4 hours
        );
        rateLimits.setRateLimitData(
            mainnetController.LIMIT_USDE_BURN(),
            5_000_000e18,
            uint256(1_000_000e18) / 4 hours
        );

        vm.stopPrank();
    }

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

        vm.prank(relayer);
        mainnetController.prepareUSDeMint(1_000_000e6);

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

        vm.prank(relayer);
        mainnetController.depositERC4626(address(susde), 500_000e18);

        assertEq(usde.allowance(address(almProxy), address(susde)), 0);

        assertEq(susde.convertToAssets(susde.balanceOf(address(almProxy))), 500_000e18 - 2);  // Rounding

        assertEq(usde.balanceOf(address(susde)),    startingAssets + 500_000e18);
        assertEq(usde.balanceOf(address(almProxy)), 500_000e18);

        // Step 3: Cooldown sUSDe

        address silo = susde.silo();

        uint256 startingSiloBalance = usde.balanceOf(silo);

        assertEq(susde.convertToAssets(susde.balanceOf(address(almProxy))), 500_000e18 - 2);  // Rounding

        assertEq(usde.balanceOf(silo), startingSiloBalance);

        vm.prank(relayer);
        mainnetController.cooldownAssetsSUSDe(500_000e18 - 2);

        assertEq(susde.convertToAssets(susde.balanceOf(address(almProxy))), 0);

        assertEq(usde.balanceOf(silo), startingSiloBalance + 500_000e18 - 2);

        // Step 4: Wait for cooldown window to pass then unstake sUSDe

        skip(7 days);

        assertEq(usde.balanceOf(silo),              startingSiloBalance + 500_000e18 - 2);
        assertEq(usde.balanceOf(address(almProxy)), 500_000e18);

        vm.prank(relayer);
        mainnetController.unstakeSUSDe();

        assertEq(usde.balanceOf(silo),              startingSiloBalance);
        assertEq(usde.balanceOf(address(almProxy)), 1_000_000e18 - 2);

        // Step 5: Redeem USDe for USDC

        startingMinterBalance = usde.balanceOf(ETHENA_MINTER);  // From mainnet state

        vm.prank(relayer);
        mainnetController.prepareUSDeBurn(1_000_000e18 - 2);

        assertEq(usde.allowance(address(almProxy), ETHENA_MINTER), 1_000_000e18 - 2);

        assertEq(usde.balanceOf(address(almProxy)), 1_000_000e18 - 2);
        assertEq(usde.balanceOf(ETHENA_MINTER),     startingMinterBalance);

        assertEq(usdc.balanceOf(address(almProxy)), 0);

        _simulateUsdeBurn(1_000_000e18 - 2);

        assertEq(usde.allowance(address(almProxy), ETHENA_MINTER), 0);

        assertEq(usde.balanceOf(address(almProxy)), 0);
        assertEq(usde.balanceOf(ETHENA_MINTER),     startingMinterBalance + 1_000_000e18 - 2);

        assertEq(usdc.balanceOf(address(almProxy)), 1_000_000e6 - 1);  // Rounding
    }

}