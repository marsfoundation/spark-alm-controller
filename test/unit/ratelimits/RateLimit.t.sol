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
        {
            vm.expectEmit(address(rateLimits));
            emit RateLimitSet(TEST_KEY1, 100, 1000, 10, 100, block.timestamp);
            rateLimits.setRateLimit(TEST_KEY1, 100, 1000, 10);
            (uint256 minAmount, uint256 maxAmount, uint256 slope, uint256 amount, uint256 lastUpdated) = rateLimits.limits(TEST_KEY1);
            assertEq(minAmount,   100);
            assertEq(maxAmount,   1000);
            assertEq(slope,       10);
            assertEq(amount,      100);
            assertEq(lastUpdated, block.timestamp);
        }

        // Variant2
        {
            vm.expectEmit(address(rateLimits));
            emit RateLimitSet(_getKey(TEST_KEY1, asset1), 100, 1000, 10, 100, block.timestamp);
            rateLimits.setRateLimit(TEST_KEY1, asset1, 100, 1000, 10);
            (uint256 minAmount, uint256 maxAmount, uint256 slope, uint256 amount, uint256 lastUpdated) = rateLimits.limits(_getKey(TEST_KEY1, asset1));
            assertEq(minAmount,   100);
            assertEq(maxAmount,   1000);
            assertEq(slope,       10);
            assertEq(amount,      100);
            assertEq(lastUpdated, block.timestamp);
        }
        
        // Variant3
        {
            vm.expectEmit(address(rateLimits));
            emit RateLimitSet(TEST_KEY1, 100, 1000, 10, 101, block.timestamp - 1);
            rateLimits.setRateLimit(TEST_KEY1, 100, 1000, 10, 101, block.timestamp - 1);
            (uint256 minAmount, uint256 maxAmount, uint256 slope, uint256 amount, uint256 lastUpdated) = rateLimits.limits(TEST_KEY1);
            assertEq(minAmount,   100);
            assertEq(maxAmount,   1000);
            assertEq(slope,       10);
            assertEq(amount,      101);
            assertEq(lastUpdated, block.timestamp - 1);
        }

        // Variant4
        {
            vm.expectEmit(address(rateLimits));
            emit RateLimitSet(TEST_KEY1, type(uint256).max, type(uint256).max, 0, type(uint256).max, block.timestamp);
            rateLimits.setUnlimitedRateLimit(TEST_KEY1);
            (uint256 minAmount, uint256 maxAmount, uint256 slope, uint256 amount, uint256 lastUpdated) = rateLimits.limits(TEST_KEY1);
            assertEq(minAmount,   type(uint256).max);
            assertEq(maxAmount,   type(uint256).max);
            assertEq(slope,       0);
            assertEq(amount,      type(uint256).max);
            assertEq(lastUpdated, block.timestamp);
        }

        // Variant5
        {
            vm.expectEmit(address(rateLimits));
            emit RateLimitSet(_getKey(TEST_KEY1, asset1), type(uint256).max, type(uint256).max, 0, type(uint256).max, block.timestamp);
            rateLimits.setUnlimitedRateLimit(TEST_KEY1, asset1);
            (uint256 minAmount, uint256 maxAmount, uint256 slope, uint256 amount, uint256 lastUpdated) = rateLimits.limits(_getKey(TEST_KEY1, asset1));
            assertEq(minAmount,   type(uint256).max);
            assertEq(maxAmount,   type(uint256).max);
            assertEq(slope,       0);
            assertEq(amount,      type(uint256).max);
            assertEq(lastUpdated, block.timestamp);
        }
    }

    function _getKey(bytes32 key, address asset) internal pure returns (bytes32) {
        return keccak256(abi.encode(key, asset));
    }

}
