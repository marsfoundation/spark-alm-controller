// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/mainnet-fork/ForkTestBase.t.sol";

contract CompromisedRelayerTests is ForkTestBase {

    address newRelayer = makeAddr("newRelayer");
    bytes32 key;

    function setUp() public override {
        super.setUp();

        key = mainnetController.LIMIT_SUSDE_COOLDOWN();

        vm.prank(SPARK_PROXY);
        rateLimits.setRateLimitData(key, 5_000_000e18, uint256(1_000_000e18) / 4 hours);
    }

    function test_compromisedRelayer_lockingFundsInEthenaSilo() external {
        deal(address(susde), address(almProxy), 1_000_000e18);

        address silo = susde.silo();

        uint256 startingSiloBalance = usde.balanceOf(silo);

        vm.prank(relayer);
        mainnetController.cooldownAssetsSUSDe(1_000_000e18);

        skip(7 days);

        // Relayer is now compromised and wants to lock funds in the silo

        vm.prank(relayer);
        mainnetController.cooldownAssetsSUSDe(1);

        // Relayer cannot withdraw when they want to
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSignature("InvalidCooldown()"));
        mainnetController.unstakeSUSDe();

        vm.prank(freezer);
        mainnetController.freeze();

        skip(7 days);

        // Compromised relayer cannot perform attack
        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.cooldownAssetsSUSDe(1);

        // Action taken through spell to grant access to safe new relayer, and reactivates the system
        vm.startPrank(SPARK_PROXY);
        mainnetController.grantRole(mainnetController.RELAYER(), newRelayer);
        mainnetController.revokeRole(mainnetController.RELAYER(), relayer);
        mainnetController.reactivate();
        vm.stopPrank();

        // Compromised relayer cannot perform attack on unfrozen system
        vm.prank(relayer);
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            relayer,
            RELAYER
        ));
        mainnetController.cooldownAssetsSUSDe(1);

        // Funds have been locked in the silo this whole time
        assertEq(usde.balanceOf(address(almProxy)), 0);
        assertEq(usde.balanceOf(silo),              startingSiloBalance + 1_000_000e18 + 1);  // 1 wei deposit as well

        // New relayer can unstake the funds
        vm.prank(newRelayer);
        mainnetController.unstakeSUSDe();

        assertEq(usde.balanceOf(address(almProxy)), 1_000_000e18 + 1);
        assertEq(usde.balanceOf(silo),              startingSiloBalance);
    }

}
