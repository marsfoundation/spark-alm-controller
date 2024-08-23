// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity >=0.8.0;

import "test/mainnet-fork/ForkTestBase.t.sol";

import { IERC20 } from "lib/forge-std/src/interfaces/IERC20.sol";

import { ERC20Mock } from "openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";

import { PSM3Deploy }       from "spark-psm/deploy/PSM3Deploy.sol";
import { IPSM3 }            from "spark-psm/src/PSM3.sol";
import { MockRateProvider } from "spark-psm/test/mocks/MockRateProvider.sol";

import { CCTPBridgeTesting } from "xchain-helpers/src/testing/bridges/CCTPBridgeTesting.sol";
import { CCTPForwarder }     from "xchain-helpers/src/forwarders/CCTPForwarder.sol";

import { ALMProxy }          from "src/ALMProxy.sol";
import { ForeignController } from "src/ForeignController.sol";

contract MainnetControllerTransferUSDCToCCTPFailureTests is ForkTestBase {

    uint32 constant DOMAIN_ID_CIRCLE_ARBITRUM = 3;

    function test_transferUSDCToCCTP_notRelayer() external {
        vm.expectRevert(abi.encodeWithSignature(
            "AccessControlUnauthorizedAccount(address,bytes32)",
            address(this),
            RELAYER
        ));
        mainnetController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
    }

    function test_transferUSDCToCCTP_frozen() external {
        vm.prank(freezer);
        mainnetController.freeze();

        vm.prank(relayer);
        vm.expectRevert("MainnetController/not-active");
        mainnetController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);
    }

    function test_transferUSDCToCCTP_invalidMintRecipient() external {
        vm.prank(relayer);
        vm.expectRevert("MainnetController/domain-not-configured");
        mainnetController.transferUSDCToCCTP(1e6, DOMAIN_ID_CIRCLE_ARBITRUM);
    }

}

// TODO: Figure out finalized structure for this repo/testing structure wise
contract TransferUSDCToCCTPIntegrationTests is ForkTestBase {

    using DomainHelpers     for *;
    using CCTPBridgeTesting for Bridge;

    address admin = makeAddr("admin");

    /**********************************************************************************************/
    /*** Base addresses                                                                         ***/
    /**********************************************************************************************/

    address USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    /**********************************************************************************************/
    /*** ALM system deployments                                                                 ***/
    /**********************************************************************************************/

    ALMProxy          foreignAlmProxy;
    ForeignController foreignController;

    /**********************************************************************************************/
    /*** Casted addresses for testing                                                           ***/
    /**********************************************************************************************/

    IERC20 nstBase;
    IERC20 snstBase;
    IERC20 usdcBase;

    MockRateProvider rateProvider;

    IPSM3 psmBase;

    function setUp() public override {
        super.setUp();

        destination = getChain("base").createSelectFork(18181500);  // August 8, 2024

        nstBase  = IERC20(address(new ERC20Mock()));
        snstBase = IERC20(address(new ERC20Mock()));
        usdcBase = IERC20(USDC_BASE);

        rateProvider = new MockRateProvider();

        rateProvider.__setConversionRate(1.25e27);

        deal(address(nstBase), address(this), 1e18);  // For seeding PSM during deployment

        psmBase = IPSM3(PSM3Deploy.deploy(
            address(nstBase), USDC_BASE, address(snstBase), address(rateProvider)
        ));

        foreignAlmProxy = new ALMProxy(admin);

        foreignController = new ForeignController({
            admin_ : admin,
            proxy_ : address(foreignAlmProxy),
            psm_   : address(psmBase),
            nst_   : address(nstBase),
            usdc_  : USDC_BASE,
            snst_  : address(snstBase)
        });

        // NOTE: FREEZER, RELAYER, and CONTROLLER are taken from super.setUp()

        vm.startPrank(admin);

        foreignController.grantRole(FREEZER, freezer);
        foreignController.grantRole(RELAYER, relayer);

        foreignAlmProxy.grantRole(CONTROLLER, address(foreignController));

        vm.stopPrank();

        source.selectFork();

        bridge = CCTPBridgeTesting.createCircleBridge(source, destination);

        vm.prank(SPARK_PROXY);
        mainnetController.setMintRecipient(
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            bytes32(uint256(uint160(address(foreignAlmProxy))))
        );
    }

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
            mainnetController.mintRecipients(CCTPForwarder.DOMAIN_ID_CIRCLE_BASE),
            CCTPForwarder.DOMAIN_ID_CIRCLE_BASE,
            bytes32(0x0000000000000000000000001682ae6375c4e4a97e4b583bc394c861a46d8962),
            bytes32(0x0000000000000000000000000000000000000000000000000000000000000000)
        );

        vm.prank(relayer);
        mainnetController.transferUSDCToCCTP(1e6, CCTPForwarder.DOMAIN_ID_CIRCLE_BASE);

        assertEq(usdc.balanceOf(address(almProxy)),          0);
        assertEq(usdc.balanceOf(address(mainnetController)), 0);
        assertEq(usdc.totalSupply(),                         USDC_SUPPLY - 1e6);

        assertEq(nst.allowance(address(almProxy), CCTP_MESSENGER),  0);

        destination.selectFork();

        uint256 usdcBaseTotalSupply = usdcBase.totalSupply();

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   0);
        assertEq(usdcBase.balanceOf(address(foreignController)), 0);
        assertEq(usdcBase.totalSupply(),                         usdcBaseTotalSupply);

        bridge.relayMessagesToDestination(true);

        assertEq(usdcBase.balanceOf(address(foreignAlmProxy)),   1e6);
        assertEq(usdcBase.balanceOf(address(foreignController)), 0);
        assertEq(usdcBase.totalSupply(),                         usdcBaseTotalSupply + 1e6);
    }

}
