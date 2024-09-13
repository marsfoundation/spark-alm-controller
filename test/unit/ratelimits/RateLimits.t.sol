// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "test/unit/UnitTestBase.t.sol";

import { RateLimits, IRateLimits } from "src/RateLimits.sol";

contract RateLimitsTest is UnitTestBase {

    event RateLimitDataSet(
        bytes32 indexed key,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    );

    event RateLimitDecreaseTriggered(
        bytes32 indexed key,
        uint256 amountToDecrease,
        uint256 oldRateLimit,
        uint256 newRateLimit
    );

    event RateLimitIncreaseTriggered(
        bytes32 indexed key,
        uint256 amountToIncrease,
        uint256 oldRateLimit,
        uint256 newRateLimit
    );

    bytes32 constant TEST_KEY1 = keccak256("TEST_KEY1");

    address controller = makeAddr("controller");
    address asset1     = makeAddr("asset1");

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
        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10);

        // Variant2
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10, 100, block.timestamp);

        // Variant3
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        rateLimits.setUnlimitedRateLimitData(TEST_KEY1);
    }

    function test_setRateLimit_invalidLastUpdated_boundary() public {
        vm.startPrank(admin);
        vm.expectRevert("RateLimits/invalid-lastUpdated");
        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10, 100, block.timestamp + 1);  // Invalid as lastUpdated > block.timestamp

        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10, 100, block.timestamp);
        vm.stopPrank();
    }

    function test_setRateLimit_invalidAmount_boundary() public {
        vm.startPrank(admin);
        vm.expectRevert("RateLimits/invalid-lastAmount");
        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10, 1001, block.timestamp);  // Invalid as amount > maxAmount

        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10, 1000, block.timestamp);
        vm.stopPrank();
    }

    // Test setting rate limits as the admin
    function test_setRateLimit() public {
        vm.startPrank(admin);

        // Variant1
        vm.expectEmit(address(rateLimits));
        emit RateLimitDataSet(TEST_KEY1, 1000, 10, 1000, block.timestamp);
        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10);
        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   1000,
            slope:       10,
            lastAmount:  1000,
            lastUpdated: block.timestamp
        });
        
        // Variant2
        vm.expectEmit(address(rateLimits));
        emit RateLimitDataSet(TEST_KEY1, 1000, 10, 101, block.timestamp - 1);
        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10, 101, block.timestamp - 1);
        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   1000,
            slope:       10,
            lastAmount:  101,
            lastUpdated: block.timestamp - 1
        });

        // Variant3
        vm.expectEmit(address(rateLimits));
        emit RateLimitDataSet(TEST_KEY1, type(uint256).max, 0, type(uint256).max, block.timestamp);
        rateLimits.setUnlimitedRateLimitData(TEST_KEY1);
        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   type(uint256).max,
            slope:       0,
            lastAmount:  type(uint256).max,
            lastUpdated: block.timestamp
        });

        vm.stopPrank();
    }

    function test_getCurrentRateLimit_empty() public view {
        uint256 amount = rateLimits.getCurrentRateLimit(TEST_KEY1);
        assertEq(amount, 0);
    }

    function test_getCurrentRateLimit_unlimited() public {
        vm.prank(admin);
        rateLimits.setUnlimitedRateLimitData(TEST_KEY1);

        uint256 amount = rateLimits.getCurrentRateLimit(TEST_KEY1);
        assertEq(amount, type(uint256).max);
    }

    function test_getCurrentRateLimit() public {
        vm.prank(admin);
        rateLimits.setRateLimitData(TEST_KEY1, 5_000_000e18, uint256(1_000_000e18) / 1 days, 0, block.timestamp);

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 0);

        skip(1 days);

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 999_999.9999999999999936e18);  // ~1m

        skip(36 hours);

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 2_499_999.999999999999984e18);  // ~2.5m

        skip(2.5 days + 1); // +1 for rounding

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 5_000_000e18);

        skip(365 days);

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 5_000_000e18);
    }

    function test_triggerRateLimitDecrease_unauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            CONTROLLER
        ));
        rateLimits.triggerRateLimitDecrease(TEST_KEY1, 100);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            admin,
            CONTROLLER
        ));
        rateLimits.triggerRateLimitDecrease(TEST_KEY1, 100);
    }

    function test_triggerRateLimitDecrease_emptyRateLimit() public {
        vm.startPrank(controller);

        vm.expectRevert("RateLimits/zero-maxAmount");
        rateLimits.triggerRateLimitDecrease(TEST_KEY1, 100);

        vm.expectRevert("RateLimits/zero-maxAmount");
        rateLimits.triggerRateLimitDecrease(TEST_KEY1, 1);

        vm.expectRevert("RateLimits/zero-maxAmount");
        rateLimits.triggerRateLimitDecrease(TEST_KEY1, 0);
        
        vm.stopPrank();
    }

    function test_triggerRateLimitDecrease_unlimitedRateLimit() public {
        vm.prank(admin);
        rateLimits.setUnlimitedRateLimitData(TEST_KEY1);

        vm.startPrank(controller);

        // Unlimited does not update timestamp
        uint256 t = block.timestamp;
        assertEq(rateLimits.getRateLimitData(TEST_KEY1).lastUpdated, block.timestamp);
        assertEq(rateLimits.triggerRateLimitDecrease(TEST_KEY1, 100), type(uint256).max);
        skip(1 days);
        assertEq(rateLimits.getRateLimitData(TEST_KEY1).lastUpdated, t);
        assertEq(rateLimits.triggerRateLimitDecrease(TEST_KEY1, 500_000_000e18), type(uint256).max);
        skip(1 days);
        assertEq(rateLimits.getRateLimitData(TEST_KEY1).lastUpdated, t);
        
        vm.stopPrank();
    }

    function test_triggerRateLimitDecrease_emptyAmount() public {
        vm.prank(admin);
        rateLimits.setRateLimitData(TEST_KEY1, 100, 10, 0, block.timestamp);

        uint256 t1 = block.timestamp;
        uint256 t2 = block.timestamp + 3;

        skip(3);

        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   100,
            slope:       10,
            lastAmount:  0,
            lastUpdated: t1
        });

        vm.expectEmit(address(rateLimits));
        emit RateLimitDecreaseTriggered(TEST_KEY1, 0, 30, 30);
        vm.prank(controller);
        rateLimits.triggerRateLimitDecrease(TEST_KEY1, 0);

        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   100,
            slope:       10,
            lastAmount:  30,
            lastUpdated: t2
        });
    }

    function test_triggerRateLimitDecrease() public {
        uint256 rate = uint256(1_000_000e18) / 1 days;

        vm.prank(admin);
        rateLimits.setRateLimitData(TEST_KEY1, 5_000_000e18, rate, 0, block.timestamp);

        vm.startPrank(controller);

        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   5_000_000e18,
            slope:       rate,
            lastAmount:  0,
            lastUpdated: block.timestamp
        });

        // Use 250k and are left with ~750k left in the rate limit
        skip(1 days);
        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 999_999.9999999999999936e18);
        vm.expectEmit(address(rateLimits));
        emit RateLimitDecreaseTriggered(TEST_KEY1, 250_000e18, 999_999.9999999999999936e18, 749_999.9999999999999936e18);
        assertEq(rateLimits.triggerRateLimitDecrease(TEST_KEY1, 250_000e18), 749_999.9999999999999936e18);
        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   5_000_000e18,
            slope:       rate,
            lastAmount:  749_999.9999999999999936e18,
            lastUpdated: block.timestamp
        });

        // +2m in capacity for 2 days, but use another 1m means ~1.75m left
        skip(2 days);
        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 2_749_999.9999999999999808e18);
        assertEq(rateLimits.triggerRateLimitDecrease(TEST_KEY1, 1_000_000e18), 1_749_999.9999999999999808e18);
        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   5_000_000e18,
            slope:       rate,
            lastAmount:  1_749_999.9999999999999808e18,
            lastUpdated: block.timestamp
        });

        skip(365 days);
        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 5_000_000e18);
        assertEq(rateLimits.triggerRateLimitDecrease(TEST_KEY1, 5_000_000e18), 0);
        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   5_000_000e18,
            slope:       rate,
            lastAmount:  0,
            lastUpdated: block.timestamp
        });
        
        vm.stopPrank();
    }

    function test_triggerRateLimitDecrease_amountToDecrease_upperBoundary() public {
        vm.prank(admin);
        rateLimits.setUnlimitedRateLimitData(TEST_KEY1);

        vm.startPrank(controller);

        // This will short circuit due to the unlimited rate limit and never update any state or do calculations
        assertEq(rateLimits.triggerRateLimitDecrease(TEST_KEY1, type(uint256).max), type(uint256).max);
        assertEq(rateLimits.triggerRateLimitDecrease(TEST_KEY1, type(uint256).max - 1), type(uint256).max);
        
        vm.stopPrank();
    }

    function test_triggerRateLimitIncrease_emptyRateLimit() public {
        vm.startPrank(controller);

        vm.expectRevert("RateLimits/zero-maxAmount");
        rateLimits.triggerRateLimitDecrease(TEST_KEY1, 100);

        vm.expectRevert("RateLimits/zero-maxAmount");
        rateLimits.triggerRateLimitDecrease(TEST_KEY1, 1);

        vm.expectRevert("RateLimits/zero-maxAmount");
        rateLimits.triggerRateLimitDecrease(TEST_KEY1, 0);
        
        vm.stopPrank();
    }

    function test_triggerRateLimitIncrease() public {
        vm.prank(admin);
        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10);

        vm.startPrank(controller);

        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   1000,
            slope:       10,
            lastAmount:  1000,
            lastUpdated: block.timestamp
        });

        rateLimits.triggerRateLimitDecrease(TEST_KEY1, 500);

        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   1000,
            slope:       10,
            lastAmount:  500,
            lastUpdated: block.timestamp
        });

        // Over the limit
        vm.expectRevert("RateLimits/rate-limit-exceeded");
        rateLimits.triggerRateLimitDecrease(TEST_KEY1, 501);

        // Free up some room
        vm.expectEmit(address(rateLimits));
        emit RateLimitIncreaseTriggered(TEST_KEY1, 1, 500, 501);
        rateLimits.triggerRateLimitIncrease(TEST_KEY1, 1);

        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   1000,
            slope:       10,
            lastAmount:  501,
            lastUpdated: block.timestamp
        });

        rateLimits.triggerRateLimitDecrease(TEST_KEY1, 501);

        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   1000,
            slope:       10,
            lastAmount:  0,
            lastUpdated: block.timestamp
        });

        // Release more than the maxAmount
        vm.expectEmit(address(rateLimits));
        emit RateLimitIncreaseTriggered(TEST_KEY1, 2000, 0, 1000);
        rateLimits.triggerRateLimitIncrease(TEST_KEY1, 2000);

        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   1000,
            slope:       10,
            lastAmount:  1000,
            lastUpdated: block.timestamp
        });

        vm.stopPrank();
    }

    function test_triggerRateLimitIncrease_amountToIncrease_upperBoundary() public {
        vm.prank(admin);
        rateLimits.setUnlimitedRateLimitData(TEST_KEY1);

        vm.startPrank(controller);

        // This will short circuit due to the unlimited rate limit and never update any state or do calculations
        assertEq(rateLimits.triggerRateLimitIncrease(TEST_KEY1, type(uint256).max), type(uint256).max);
        assertEq(rateLimits.triggerRateLimitIncrease(TEST_KEY1, type(uint256).max - 1), type(uint256).max);
        
        vm.stopPrank();
    }

    function _assertLimitData(bytes32 key, uint256 maxAmount, uint256 slope, uint256 lastAmount, uint256 lastUpdated) internal view {
        IRateLimits.RateLimitData memory d = rateLimits.getRateLimitData(key);
        assertEq(d.maxAmount,   maxAmount);
        assertEq(d.slope,       slope);
        assertEq(d.lastAmount,  lastAmount);
        assertEq(d.lastUpdated, lastUpdated);
    }

}
