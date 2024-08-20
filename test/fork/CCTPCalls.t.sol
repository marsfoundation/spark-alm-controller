// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/fork/ForkTestBase.t.sol";

contract MainnetControllerTransferUSDCToCTTPFailureTests is ForkTestBase {

    uint32 constant DOMAIN_ID_CIRCLE_ARBITRUM = 3;

    function test_transferUSDCToCCTP_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.transferUSDCToCCTP(1e6, DOMAIN_ID_CIRCLE_OPTIMISM);
    }

    function test_transferUSDCToCCTP_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.transferUSDCToCCTP(1e6, DOMAIN_ID_CIRCLE_OPTIMISM);
    }

    function test_transferUSDCToCCTP_invalidMintRecipient() external {
        vm.prank(relayer);
        vm.expectRevert("MainnetController/invalid-mint-recipient");
        mainnetController.transferUSDCToCCTP(1e6, DOMAIN_ID_CIRCLE_ARBITRUM);
    }

}

contract MainnetControllerTransferUSDCToCTTPTests is ForkTestBase {

    function test_transferUSDCToCCTP() external {
        deal(address(usdc), address(almProxy), 1e6);

        assertEq(usdc.balanceOf(address(almProxy)),          1e6);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.totalSupply(),                         USDC_SUPPLY);

        assertEq(nst.allowance(address(almProxy), CCTP_MESSENGER),  0);

        vm.prank(relayer);
        mainnetController.transferUSDCToCCTP(1e6, DOMAIN_ID_CIRCLE_OPTIMISM);

        assertEq(usdc.balanceOf(address(almProxy)),          0);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.totalSupply(),                         USDC_SUPPLY - 1e6);

        assertEq(nst.allowance(address(almProxy), CCTP_MESSENGER),  0);
    }

}
