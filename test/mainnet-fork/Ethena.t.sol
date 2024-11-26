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
        vm.startPrank(SPARK_PROXY);
        rateLimits.setRateLimitData(
            mainnetController.LIMIT_USDE_MINT(),
            100e6,
            uint256(100e6) / 1 hours
        );
        vm.stopPrank();

        vm.prank(relayer);
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        mainnetController.prepareUSDeMint(100e6 + 1);

        vm.prank(relayer);
        mainnetController.prepareUSDeMint(100e6);
    }

}

contract MainnetControllerPrepareUSDeMintSuccessTests is ForkTestBase {

    bytes32 key;

    function setUp() public override {
        super.setUp();

        key = mainnetController.LIMIT_USDE_MINT();

        vm.prank(SPARK_PROXY);
        rateLimits.setRateLimitData(key, 100e6, uint256(10e18) / 1 hours);
    }

    function test_prepareUSDeMint() external {
        assertEq(usdc.allowance(address(almProxy), ETHENA_MINTER), 0);

        vm.prank(relayer);
        mainnetController.prepareUSDeMint(100e6);

        assertEq(usdc.allowance(address(almProxy), ETHENA_MINTER), 100e6);
    }

    function test_prepareUSDeMint_rateLimits() external {
        assertEq(rateLimits.getCurrentRateLimit(key), 100e6);

        vm.prank(relayer);
        mainnetController.prepareUSDeMint(40e6);

        assertEq(rateLimits.getCurrentRateLimit(key), 60e6);

        skip(1 hours);

        assertEq(rateLimits.getCurrentRateLimit(key), 70e6 - 2800);  // Rounding

        vm.prank(relayer);
        mainnetController.prepareUSDeMint(30e6);

        assertEq(rateLimits.getCurrentRateLimit(key), 40e6 - 2800);  // Rounding
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
