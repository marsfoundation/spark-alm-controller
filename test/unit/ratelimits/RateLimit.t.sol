// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "test/unit/UnitTestBase.t.sol";

import { RateLimits } from "src/RateLimits.sol";

contract RateLimitsTest is UnitTestBase {

    event RateLimitSet(
        bytes32 indexed key,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 slope,
        uint256 amount,
        uint256 lastUpdated
    );

    bytes32 constant TEST_KEY1 = keccak256("TEST_KEY1");
    bytes32 constant TEST_KEY2 = keccak256("TEST_KEY2");
    bytes32 constant TEST_KEY3 = keccak256("TEST_KEY3");

    address controller = makeAddr("controller");
    address asset1     = makeAddr("asset1");
    address asset2     = makeAddr("asset2");

    RateLimits rateLimits;

    function setUp() public {
        // Deploy the RateLimits contract with `admin` as the initial admin
        rateLimits = new RateLimits(admin);

        // Grant the CONTROLLER role to the `controller` address
        vm.prank(admin);
        rateLimits.grantRole(CONTROLLER, controller);
    }

    function test_constructor() public {
        rateLimits = new RateLimits(admin);
        
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, address(this)), false);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, admin),         true);
    }

    function test_setRateLimit_unauthorizedAccount() public {
        // Test all variants of setRateLimit with unauthorized account

        // Variant1
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        rateLimits.setRateLimit(TEST_KEY1, 100, 1000, 10);

        // Variant2
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        rateLimits.setRateLimit(TEST_KEY1, asset1, 100, 1000, 10);

        // Variant3
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        rateLimits.setRateLimit(TEST_KEY1, 100, 1000, 10, 100, block.timestamp);

        // Variant4
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        rateLimits.setUnlimitedRateLimit(TEST_KEY1);

        // Variant5
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        rateLimits.setUnlimitedRateLimit(TEST_KEY1, asset1);
    }

    function test_setRateLimit_invalidMinMax_boundary() public {
        vm.startPrank(admin);

        // Variant1
        vm.expectRevert("RateLimits/invalid-minAmount-maxAmount");
        rateLimits.setRateLimit(TEST_KEY1, 1001, 1000, 10);  // Invalid as minAmount > maxAmount

        rateLimits.setRateLimit(TEST_KEY1, 1000, 1000, 10);

        // Variant2
        vm.expectRevert("RateLimits/invalid-minAmount-maxAmount");
        rateLimits.setRateLimit(TEST_KEY1, asset1, 1001, 1000, 10);

        rateLimits.setRateLimit(TEST_KEY1, asset1, 1000, 1000, 10);

        // Variant3
        vm.expectRevert("RateLimits/invalid-minAmount-maxAmount");
        rateLimits.setRateLimit(TEST_KEY1, 1001, 1000, 10, 1000, block.timestamp);

        rateLimits.setRateLimit(TEST_KEY1, 1000, 1000, 10, 1000, block.timestamp);
    }

    function test_setRateLimit_invalidLastUpdated_boundary() public {
        vm.startPrank(admin);
        vm.expectRevert("RateLimits/invalid-lastUpdated");
        rateLimits.setRateLimit(TEST_KEY1, 100, 1000, 10, 100, block.timestamp + 1);  // Invalid as lastUpdated > block.timestamp

        rateLimits.setRateLimit(TEST_KEY1, 100, 1000, 10, 100, block.timestamp);
    }

    function test_setRateLimit_invalidAmount_lowerBoundary() public {
        vm.startPrank(admin);
        vm.expectRevert("RateLimits/invalid-amount");
        rateLimits.setRateLimit(TEST_KEY1, 100, 1000, 10, 99, block.timestamp);  // Invalid as amount < minAmount

        rateLimits.setRateLimit(TEST_KEY1, 100, 1000, 10, 1000, block.timestamp);
    }

    function test_setRateLimit_invalidAmount_upperBoundary() public {
        vm.startPrank(admin);
        vm.expectRevert("RateLimits/invalid-amount");
        rateLimits.setRateLimit(TEST_KEY1, 100, 1000, 10, 1001, block.timestamp);  // Invalid as amount > maxAmount

        rateLimits.setRateLimit(TEST_KEY1, 100, 1000, 10, 1000, block.timestamp);
    }

    // Test setting rate limits as the admin
    function test_setRateLimit() public {
        vm.startPrank(admin);

        // Variant1
        vm.expectEmit(address(rateLimits));
        emit RateLimitSet(TEST_KEY1, 100, 1000, 10, 100, block.timestamp);
        rateLimits.setRateLimit(TEST_KEY1, 100, 1000, 10);
        _assertLimits({
            key:         TEST_KEY1,
            minAmount:   100,
            maxAmount:   1000,
            slope:       10,
            amount:      100,
            lastUpdated: block.timestamp
        });

        // Variant2
        vm.expectEmit(address(rateLimits));
        emit RateLimitSet(_getKey(TEST_KEY1, asset1), 100, 1000, 10, 100, block.timestamp);
        rateLimits.setRateLimit(TEST_KEY1, asset1, 100, 1000, 10);
        _assertLimits({
            key:         _getKey(TEST_KEY1, asset1),
            minAmount:   100,
            maxAmount:   1000,
            slope:       10,
            amount:      100,
            lastUpdated: block.timestamp
        });
        
        // Variant3
        vm.expectEmit(address(rateLimits));
        emit RateLimitSet(TEST_KEY1, 100, 1000, 10, 101, block.timestamp - 1);
        rateLimits.setRateLimit(TEST_KEY1, 100, 1000, 10, 101, block.timestamp - 1);
        _assertLimits({
            key:         TEST_KEY1,
            minAmount:   100,
            maxAmount:   1000,
            slope:       10,
            amount:      101,
            lastUpdated: block.timestamp - 1
        });

        // Variant4
        vm.expectEmit(address(rateLimits));
        emit RateLimitSet(TEST_KEY1, type(uint256).max, type(uint256).max, 0, type(uint256).max, block.timestamp);
        rateLimits.setUnlimitedRateLimit(TEST_KEY1);
        _assertLimits({
            key:         TEST_KEY1,
            minAmount:   type(uint256).max,
            maxAmount:   type(uint256).max,
            slope:       0,
            amount:      type(uint256).max,
            lastUpdated: block.timestamp
        });

        // Variant5
        vm.expectEmit(address(rateLimits));
        emit RateLimitSet(_getKey(TEST_KEY1, asset1), type(uint256).max, type(uint256).max, 0, type(uint256).max, block.timestamp);
        rateLimits.setUnlimitedRateLimit(TEST_KEY1, asset1);
        _assertLimits({
            key:         _getKey(TEST_KEY1, asset1),
            minAmount:   type(uint256).max,
            maxAmount:   type(uint256).max,
            slope:       0,
            amount:      type(uint256).max,
            lastUpdated: block.timestamp
        });
    }

    function test_getCurrentRateLimit_empty() public view {
        uint256 amount = rateLimits.getCurrentRateLimit(TEST_KEY1);
        assertEq(amount, 0);
    }

    function test_getCurrentRateLimit_unlimited() public {
        vm.prank(admin);
        rateLimits.setUnlimitedRateLimit(TEST_KEY1);

        uint256 amount = rateLimits.getCurrentRateLimit(TEST_KEY1);
        assertEq(amount, type(uint256).max);
    }

    function test_getCurrentRateLimit() public {
        vm.prank(admin);
        rateLimits.setRateLimit(TEST_KEY1, 0, 5_000_000e18, uint256(1_000_000e18) / 1 days);

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 0);

        skip(1 days);

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 999_999.9999999999999936e18);  // ~1m

        skip(36 hours);

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 2_499_999.999999999999984e18);  // ~2.5m

        skip(365 days);

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 5_000_000e18);
    }

    function test_getCurrentRateLimit_assetVersion() public {
        vm.prank(admin);
        rateLimits.setRateLimit(TEST_KEY1, asset1, 0, 5_000_000e18, uint256(1_000_000e18) / 1 days);

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1, asset1), 0);

        skip(1 days);

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1, asset1), 999_999.9999999999999936e18);  // ~1m

        skip(36 hours);

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1, asset1), 2_499_999.999999999999984e18);  // ~2.5m

        skip(365 days);

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1, asset1), 5_000_000e18);
    }

    function test_triggerRateLimit_unauthorizedAccount() public {
        // Variant1
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            CONTROLLER
        ));
        rateLimits.triggerRateLimit(TEST_KEY1, 100);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            admin,
            CONTROLLER
        ));
        rateLimits.triggerRateLimit(TEST_KEY1, 100);

        // Variant2
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            CONTROLLER
        ));
        rateLimits.triggerRateLimit(TEST_KEY1, asset1, 100);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            admin,
            CONTROLLER
        ));
        rateLimits.triggerRateLimit(TEST_KEY1, asset1, 100);
    }

    function test_triggerRateLimit_emptyAmount() public {
        vm.prank(admin);
        rateLimits.setUnlimitedRateLimit(TEST_KEY1);

        vm.prank(controller);
        vm.expectRevert("RateLimits/invalid-amount");
        rateLimits.triggerRateLimit(TEST_KEY1, 0);
    } 

    function test_triggerRateLimit_emptyRateLimit() public {
        vm.startPrank(controller);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        rateLimits.triggerRateLimit(TEST_KEY1, 100);

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        rateLimits.triggerRateLimit(TEST_KEY1, 1);

        vm.expectRevert("RateLimits/invalid-amount");
        rateLimits.triggerRateLimit(TEST_KEY1, 0);
    }

    function test_triggerRateLimit_unlimitedRateLimit() public {
        vm.prank(admin);
        rateLimits.setUnlimitedRateLimit(TEST_KEY1);

        vm.startPrank(controller);

        // Unlimited does not update timestamp
        uint256 t = block.timestamp;
        (,,,, uint256 lastUpdated) = rateLimits.limits(TEST_KEY1);
        assertEq(lastUpdated, block.timestamp);
        assertEq(rateLimits.triggerRateLimit(TEST_KEY1, 100), type(uint256).max);
        skip(1 days);
        (,,,, lastUpdated) = rateLimits.limits(TEST_KEY1);
        assertEq(lastUpdated, t);
        assertEq(rateLimits.triggerRateLimit(TEST_KEY1, 500_000_000e18), type(uint256).max);
        skip(1 days);
        (,,,, lastUpdated) = rateLimits.limits(TEST_KEY1);
        assertEq(lastUpdated, t);
    }

    function test_triggerRateLimit() public {
        uint256 rate = uint256(1_000_000e18) / 1 days;

        vm.prank(admin);
        rateLimits.setRateLimit(TEST_KEY1, 0, 5_000_000e18, rate);

        vm.startPrank(controller);

        _assertLimits({
            key:         TEST_KEY1,
            minAmount:   0,
            maxAmount:   5_000_000e18,
            slope:       rate,
            amount:      0,
            lastUpdated: block.timestamp
        });

        // Use 250k and are left with ~750k left in the rate limit
        skip(1 days);
        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 999_999.9999999999999936e18);
        assertEq(rateLimits.triggerRateLimit(TEST_KEY1, 250_000e18), 749_999.9999999999999936e18);
        _assertLimits({
            key:         TEST_KEY1,
            minAmount:   0,
            maxAmount:   5_000_000e18,
            slope:       rate,
            amount:      749_999.9999999999999936e18,
            lastUpdated: block.timestamp
        });

        // +2m in capacity for 2 days, but use another 1m means ~1.75m left
        skip(2 days);
        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 2_749_999.9999999999999808e18);
        assertEq(rateLimits.triggerRateLimit(TEST_KEY1, 1_000_000e18), 1_749_999.9999999999999808e18);
        _assertLimits({
            key:         TEST_KEY1,
            minAmount:   0,
            maxAmount:   5_000_000e18,
            slope:       rate,
            amount:      1_749_999.9999999999999808e18,
            lastUpdated: block.timestamp
        });

        skip(365 days);
        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 5_000_000e18);
        assertEq(rateLimits.triggerRateLimit(TEST_KEY1, 5_000_000e18), 0);
        _assertLimits({
            key:         TEST_KEY1,
            minAmount:   0,
            maxAmount:   5_000_000e18,
            slope:       rate,
            amount:      0,
            lastUpdated: block.timestamp
        });
    }

    function _assertLimits(bytes32 key, uint256 minAmount, uint256 maxAmount, uint256 slope, uint256 amount, uint256 lastUpdated) internal view {
        (uint256 _minAmount, uint256 _maxAmount, uint256 _slope, uint256 _amount, uint256 _lastUpdated) = rateLimits.limits(key);
        assertEq(_minAmount,   minAmount);
        assertEq(_maxAmount,   maxAmount);
        assertEq(_slope,       slope);
        assertEq(_amount,      amount);
        assertEq(_lastUpdated, lastUpdated);
    }

    function _getKey(bytes32 key, address asset) internal pure returns (bytes32) {
        return keccak256(abi.encode(key, asset));
    }

}
