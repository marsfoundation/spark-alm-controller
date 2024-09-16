// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.21;

import "test/unit/UnitTestBase.t.sol";

import { RateLimits, IRateLimits } from "src/RateLimits.sol";

contract RateLimitsTestBase is UnitTestBase {

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

    function _assertLimitData(
        bytes32 key,
        uint256 maxAmount,
        uint256 slope,
        uint256 lastAmount,
        uint256 lastUpdated
    )
        internal view
    {
        IRateLimits.RateLimitData memory d = rateLimits.getRateLimitData(key);

        assertEq(d.maxAmount,   maxAmount);
        assertEq(d.slope,       slope);
        assertEq(d.lastAmount,  lastAmount);
        assertEq(d.lastUpdated, lastUpdated);
    }

}

contract RateLimitsConstructorTest is RateLimitsTestBase {

    function test_constructor() public {
        rateLimits = new RateLimits(admin);

        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, address(this)), false);
        assertEq(rateLimits.hasRole(DEFAULT_ADMIN_ROLE, admin),         true);
    }

}

contract RateLimitsSetRateLimitDataTest is RateLimitsTestBase {

    // Testing for setRateLimitData(bytes32,uint256,uint256,uint256,uint256)

    function test_setRateLimitData_unauthorizedAccount() public {
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

    function test_setRateLimitData_invalidLastUpdated_boundary() public {
        vm.startPrank(admin);
        vm.expectRevert("RateLimits/invalid-lastUpdated");
        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10, 100, block.timestamp + 1);  // Invalid as lastUpdated > block.timestamp

        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10, 100, block.timestamp);
        vm.stopPrank();
    }

    function test_setRateLimitData_invalidAmount_boundary() public {
        vm.startPrank(admin);
        vm.expectRevert("RateLimits/invalid-lastAmount");
        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10, 1001, block.timestamp);  // Invalid as amount > maxAmount

        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10, 1000, block.timestamp);
        vm.stopPrank();
    }

    // Test setting rate limits as the admin
    function test_setRateLimitData() public {
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

}

contract RateLimitsSetRateLimitDataVariant1Test is RateLimitsTestBase {

    // Testing for setRateLimitData(bytes32,uint256,uint256,uint256,uint256)

    function test_setRateLimitData_unauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10, 100, block.timestamp);
    }

    function test_setRateLimitData_invalidLastUpdated_boundary() public {
        vm.startPrank(admin);
        vm.expectRevert("RateLimits/invalid-lastUpdated");
        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10, 100, block.timestamp + 1);  // Invalid as lastUpdated > block.timestamp

        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10, 100, block.timestamp);
        vm.stopPrank();
    }

    function test_setRateLimitData_invalidAmount_boundary() public {
        vm.startPrank(admin);
        vm.expectRevert("RateLimits/invalid-lastAmount");
        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10, 1001, block.timestamp);  // Invalid as amount > maxAmount

        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10, 1000, block.timestamp);
        vm.stopPrank();
    }

    function test_setRateLimitData() public {
        vm.expectEmit(address(rateLimits));
        emit RateLimitDataSet(TEST_KEY1, 1000, 10, 1000, block.timestamp);
        vm.prank(admin);
        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10, 1000, block.timestamp);

        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   1000,
            slope:       10,
            lastAmount:  1000,
            lastUpdated: block.timestamp
        });
    }

}

contract RateLimitsSetRateLimitDataVariant2Test is RateLimitsTestBase {

    // Testing for setRateLimitData(bytes32,uint256,uint256)

    function test_setRateLimitData_unauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10);
    }

    function test_setRateLimitData() public {
        vm.expectEmit(address(rateLimits));
        emit RateLimitDataSet(TEST_KEY1, 1000, 10, 1000, block.timestamp);
        vm.prank(admin);
        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10);

        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   1000,
            slope:       10,
            lastAmount:  1000,
            lastUpdated: block.timestamp
        });
    }

}

contract RateLimitsSetUnlimitedRateLimitDataTest is RateLimitsTestBase {

    function test_setUnlimitedRateLimitData_unauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            DEFAULT_ADMIN_ROLE
        ));
        rateLimits.setUnlimitedRateLimitData(TEST_KEY1);
    }

    function test_setUnlimitedRateLimitData() public {
        vm.expectEmit(address(rateLimits));
        emit RateLimitDataSet(TEST_KEY1, type(uint256).max, 0, type(uint256).max, block.timestamp);
        vm.prank(admin);
        rateLimits.setUnlimitedRateLimitData(TEST_KEY1);
        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   type(uint256).max,
            slope:       0,
            lastAmount:  type(uint256).max,
            lastUpdated: block.timestamp
        });
    }

}

contract RateLimitsGetRateLimitDataTest is RateLimitsTestBase {

    function test_getRateLimitData() public {
        vm.prank(admin);
        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10, 1000, block.timestamp);

        IRateLimits.RateLimitData memory d = rateLimits.getRateLimitData(TEST_KEY1);

        assertEq(d.maxAmount,   1000);
        assertEq(d.slope,       10);
        assertEq(d.lastAmount,  1000);
        assertEq(d.lastUpdated, block.timestamp);
    }

}

contract RateLimitsGetCurrentRateLimitTest is RateLimitsTestBase {

    function test_getCurrentRateLimit_empty() public view {
        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 0);
    }

    function test_getCurrentRateLimit_unlimited() public {
        vm.prank(admin);
        rateLimits.setUnlimitedRateLimitData(TEST_KEY1);

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), type(uint256).max);
    }

    function test_getCurrentRateLimit() public {
        vm.prank(admin);
        rateLimits.setRateLimitData(
            TEST_KEY1,
            5_000_000e18,
            uint256(1_000_000e18) / 1 days,
            0,
            block.timestamp
        );

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 0);

        skip(1 days);

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 999_999.9999999999999936e18);  // ~1m

        skip(1.5 days);

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 2_499_999.999999999999984e18);  // ~2.5m

        skip(2.5 days);

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 4_999_999.999999999999968e18);

        skip(1 seconds); // Surpass max

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 5_000_000e18);

        skip(1 seconds); // Demonstrate max is kept

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 5_000_000e18);

        skip(365 days);

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 5_000_000e18);
    }

}

contract RateLimitsTriggerRateLimitDecreaseTest is RateLimitsTestBase {

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

    function test_triggerRateLimitDecrease_zeroMaxAmountBoundary() public {
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(controller);
        rateLimits.triggerRateLimitDecrease(TEST_KEY1, 100);

        // Set maxAmount to be > 0
        vm.prank(admin);
        rateLimits.setRateLimitData(TEST_KEY1, 1, 10);

        vm.prank(controller);
        rateLimits.triggerRateLimitDecrease(TEST_KEY1, 1);
    }

    function test_triggerRateLimitDecrease_rateLimitExceededBoundary() public {
        vm.prank(admin);
        rateLimits.setRateLimitData(TEST_KEY1, 100, 10, 1, block.timestamp);

        skip(1 seconds);

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 11);  // 1 + 10(1 second)

        vm.expectRevert("RateLimits/rate-limit-exceeded");
        vm.prank(controller);
        rateLimits.triggerRateLimitDecrease(TEST_KEY1, 12);

        vm.prank(controller);
        rateLimits.triggerRateLimitDecrease(TEST_KEY1, 11);
    }

    function test_triggerRateLimitDecrease_unlimitedRateLimit() public {
        // Unlimited does not update timestamp or resulting rate limit
        uint256 start = block.timestamp;

        vm.prank(admin);
        rateLimits.setUnlimitedRateLimitData(TEST_KEY1);

        assertEq(rateLimits.getRateLimitData(TEST_KEY1).lastUpdated, start);

        vm.startPrank(controller);

        assertEq(rateLimits.triggerRateLimitDecrease(TEST_KEY1, 500_000_000e18), type(uint256).max);
        assertEq(rateLimits.getRateLimitData(TEST_KEY1).lastUpdated,             start);

        skip(1 days);

        assertEq(rateLimits.triggerRateLimitDecrease(TEST_KEY1, 500_000_000e18), type(uint256).max);
        assertEq(rateLimits.getRateLimitData(TEST_KEY1).lastUpdated,             start);

        skip(1 days);

        assertEq(rateLimits.triggerRateLimitDecrease(TEST_KEY1, 500_000_000e18), type(uint256).max);
        assertEq(rateLimits.getRateLimitData(TEST_KEY1).lastUpdated,             start);

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

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 30);

        vm.expectEmit(address(rateLimits));
        emit RateLimitDecreaseTriggered(TEST_KEY1, 0, 30, 30);
        vm.prank(controller);
        uint256 resultingLimit = rateLimits.triggerRateLimitDecrease(TEST_KEY1, 0);

        assertEq(resultingLimit, 30);

        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   100,
            slope:       10,
            lastAmount:  30,
            lastUpdated: t2
        });

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 30);  // Unchanged
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

        // First decrease: Use 250k and are left with ~750k left in the rate limit

        skip(1 days);
        uint256 dust = 6400;  // Rounding caused by slope is 6400 wei

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 1_000_000e18 - dust);

        vm.expectEmit(address(rateLimits));
        emit RateLimitDecreaseTriggered(TEST_KEY1, 250_000e18, 1_000_000e18 - dust, 750_000e18 - dust);
        uint256 resultingLimit = rateLimits.triggerRateLimitDecrease(TEST_KEY1, 250_000e18);

        assertEq(resultingLimit, 750_000e18 - dust);

        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   5_000_000e18,
            slope:       rate,
            lastAmount:  750_000e18 - dust,
            lastUpdated: block.timestamp
        });

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 750_000e18 - dust);

        // Second decrease: +2m in capacity for 2 days, use another 1m leaving ~1.75m

        skip(2 days);
        dust = 19_200;  // Rounding caused by slope is now 19,200 wei (6400 * 3)

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 2_750_000e18 - dust);

        resultingLimit = rateLimits.triggerRateLimitDecrease(TEST_KEY1, 1_000_000e18);

        assertEq(resultingLimit, 1_750_000e18 - dust);

        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   5_000_000e18,
            slope:       rate,
            lastAmount:  1_750_000e18 - dust,
            lastUpdated: block.timestamp
        });

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 1_750_000e18 - dust);

        // Third decrease: Warp a year, surpass maxAmount, use full capacity and set to zero

        skip(365 days);

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 5_000_000e18);

        resultingLimit = rateLimits.triggerRateLimitDecrease(TEST_KEY1, 5_000_000e18);

        assertEq(resultingLimit, 0);

        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   5_000_000e18,
            slope:       rate,
            lastAmount:  0,
            lastUpdated: block.timestamp
        });

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 0);

        vm.stopPrank();
    }

    function test_triggerRateLimitDecrease_amountToDecrease_upperBoundary() public {
        vm.prank(admin);
        rateLimits.setUnlimitedRateLimitData(TEST_KEY1);

        vm.startPrank(controller);

        // This will short circuit due to the unlimited rate limit and never update any state or do calculations
        assertEq(rateLimits.triggerRateLimitDecrease(TEST_KEY1, type(uint256).max),     type(uint256).max);
        assertEq(rateLimits.triggerRateLimitDecrease(TEST_KEY1, type(uint256).max - 1), type(uint256).max);

        vm.stopPrank();
    }

}

contract RateLimitsTriggerRateLimitIncreaseTest is RateLimitsTestBase {

    function test_triggerRateLimitIncrease_unauthorizedAccount() public {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            CONTROLLER
        ));
        rateLimits.triggerRateLimitIncrease(TEST_KEY1, 100);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            admin,
            CONTROLLER
        ));
        rateLimits.triggerRateLimitIncrease(TEST_KEY1, 100);
    }

    function test_triggerRateLimitIncrease_zeroMaxAmountBoundary() public {
        vm.expectRevert("RateLimits/zero-maxAmount");
        vm.prank(controller);
        rateLimits.triggerRateLimitIncrease(TEST_KEY1, 100);

        // Set maxAmount to be > 0
        vm.prank(admin);
        rateLimits.setRateLimitData(TEST_KEY1, 1, 10);

        vm.prank(controller);
        rateLimits.triggerRateLimitIncrease(TEST_KEY1, 1);
    }

    function test_triggerRateLimitIncrease() public {
        uint256 start = block.timestamp;

        vm.prank(admin);
        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10, 100, block.timestamp);

        vm.startPrank(controller);

        skip(1 seconds);

        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   1000,
            slope:       10,
            lastAmount:  100,
            lastUpdated: start
        });

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 110);  // 100 + 10(1 second)

        vm.expectEmit(address(rateLimits));
        emit RateLimitIncreaseTriggered(TEST_KEY1, 500, 110, 610);
        uint256 resultingLimit = rateLimits.triggerRateLimitIncrease(TEST_KEY1, 500);

        assertEq(resultingLimit, 610);

        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   1000,
            slope:       10,
            lastAmount:  610,
            lastUpdated: block.timestamp
        });

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 610);
    }

    function test_triggerRateLimitIncrease_aboveMaxAmount() public {
        uint256 start = block.timestamp;

        vm.prank(admin);
        rateLimits.setRateLimitData(TEST_KEY1, 1000, 10, 100, block.timestamp);

        vm.startPrank(controller);

        skip(1 seconds);

        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   1000,
            slope:       10,
            lastAmount:  100,
            lastUpdated: start
        });

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 110);  // 100 + 10(1 second)

        vm.expectEmit(address(rateLimits));
        emit RateLimitIncreaseTriggered(TEST_KEY1, 891, 110, 1000);
        uint256 resultingLimit = rateLimits.triggerRateLimitIncrease(TEST_KEY1, 891);

        // 891 + 110 = 1001, which is above the maxAmount of 1000, so result is 1000
        assertEq(resultingLimit, 1000);

        _assertLimitData({
            key:         TEST_KEY1,
            maxAmount:   1000,
            slope:       10,
            lastAmount:  1000,
            lastUpdated: block.timestamp
        });

        assertEq(rateLimits.getCurrentRateLimit(TEST_KEY1), 1000);
    }

    function test_triggerRateLimitIncrease_amountToIncrease_upperBoundary() public {
        vm.prank(admin);
        rateLimits.setUnlimitedRateLimitData(TEST_KEY1);

        vm.startPrank(controller);

        // This will short circuit due to the unlimited rate limit and never update any state or do calculations
        assertEq(rateLimits.triggerRateLimitIncrease(TEST_KEY1, type(uint256).max),     type(uint256).max);
        assertEq(rateLimits.triggerRateLimitIncrease(TEST_KEY1, type(uint256).max - 1), type(uint256).max);

        vm.stopPrank();
    }

}
