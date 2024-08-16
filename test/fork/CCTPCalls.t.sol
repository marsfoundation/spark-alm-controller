// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/fork/ForkTestBase.t.sol";

contract MainnetControllerTransferUSDCToCTTPTests is ForkTestBase {

    bytes32 mintRecipient     = bytes32(uint256(uint160(makeAddr("mintRecipient"))));
    bytes32 destinationCaller = bytes32(uint256(uint160(makeAddr("destinationCaller"))));

    uint32 constant internal DOMAIN_ID_CIRCLE_OPTIMISM = 2;

    function test_transferUSDCToCCTP() external {
        deal(address(usdc), address(almProxy), 1e6);

        assertEq(usdc.balanceOf(address(almProxy)),          1e6);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.totalSupply(),                         USDC_SUPPLY);

        assertEq(nst.allowance(address(almProxy), address(CCTP_MESSENGER)),  0);

        vm.prank(relayer);
        mainnetController.transferUSDCToCCTP({
            usdcAmount        : 1e6,
            destinationDomain : DOMAIN_ID_CIRCLE_OPTIMISM,
            mintRecipient     : mintRecipient,
            destinationCaller : destinationCaller
        });

        assertEq(usdc.balanceOf(address(almProxy)),          0);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.totalSupply(),                         USDC_SUPPLY - 1e6);

        assertEq(nst.allowance(address(almProxy), address(CCTP_MESSENGER)),  0);
    }

}
