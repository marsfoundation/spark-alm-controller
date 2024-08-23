// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/mainnet-fork/ForkTestBase.t.sol";

contract MainnetControllerTransferUSDCToCCTPFailureTests is ForkTestBase {

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
        vm.expectRevert("MainnetController/domain-not-configured");
        mainnetController.transferUSDCToCCTP(1e6, DOMAIN_ID_CIRCLE_ARBITRUM);
    }

}

contract MainnetControllerTransferUSDCToCCTPTests is ForkTestBase {

    event DepositForBurn(
        uint64  indexed nonce,
        address indexed burnToken,
        uint256 amount,
        address indexed depositor,
        bytes32 mintRecipient,
        uint32  destinationDomain,
        bytes32 destinationTokenMessenger,
        bytes32 destinationCaller
    );

    function test_transferUSDCToCCTP() external {
        deal(address(usdc), address(almProxy), 1e6);

        assertEq(usdc.balanceOf(address(almProxy)),          1e6);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.totalSupply(),                         USDC_SUPPLY);

        assertEq(nst.allowance(address(almProxy), CCTP_MESSENGER),  0);

        // NOTE: Focusing on burnToken, amount, depositor, mintRecipient, and destinationDomain
        //       for assertions
        vm.expectEmit(CCTP_MESSENGER);
        emit DepositForBurn(
            94773,
            address(usdc),
            1e6,
            address(almProxy),
            mainnetController.mintRecipients(DOMAIN_ID_CIRCLE_OPTIMISM),
            DOMAIN_ID_CIRCLE_OPTIMISM,
            bytes32(0x0000000000000000000000002b4069517957735be00cee0fadae88a26365528f),
            bytes32(0x0000000000000000000000000000000000000000000000000000000000000000)
        );

        vm.prank(relayer);
        mainnetController.transferUSDCToCCTP(1e6, DOMAIN_ID_CIRCLE_OPTIMISM);

        assertEq(usdc.balanceOf(address(almProxy)),          0);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.totalSupply(),                         USDC_SUPPLY - 1e6);

        assertEq(nst.allowance(address(almProxy), CCTP_MESSENGER),  0);
    }

}
