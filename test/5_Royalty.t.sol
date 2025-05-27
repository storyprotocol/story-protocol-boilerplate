// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test, console } from "forge-std/Test.sol";
// for testing purposes only
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IRoyaltyWorkflows } from "@storyprotocol/periphery/interfaces/workflows/IRoyaltyWorkflows.sol";
import { IRoyaltyModule } from "@storyprotocol/core/interfaces/modules/royalty/IRoyaltyModule.sol";
import { RoyaltyPolicyLAP } from "@storyprotocol/core/modules/royalty/policies/LAP/RoyaltyPolicyLAP.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { MockERC20 } from "@storyprotocol/test/mocks/token/MockERC20.sol";

import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";

// Interface for Multicall3
interface IMulticall3 {
    struct Call3 {
        address target;
        bool allowFailure;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }
    function aggregate3(Call3[] calldata calls) external payable returns (Result[] memory returnData);
}

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/5_Royalty.t.sol
contract RoyaltyTest is Test {
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);

    // For addresses, see https://docs.story.foundation/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    IIPAssetRegistry internal IP_ASSET_REGISTRY = IIPAssetRegistry(0x77319B4031e6eF1250907aa00018B8B1c67a244b);
    // Protocol Core - LicensingModule
    ILicensingModule internal LICENSING_MODULE = ILicensingModule(0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f);
    // Protocol Core - PILicenseTemplate
    IPILicenseTemplate internal PIL_TEMPLATE = IPILicenseTemplate(0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316);
    // Protocol Core - RoyaltyPolicyLAP
    address internal ROYALTY_POLICY_LAP = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
    // Protocol Core - RoyaltyModule
    IRoyaltyModule internal ROYALTY_MODULE = IRoyaltyModule(0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086);
    // Protocol Periphery - RoyaltyWorkflows
    IRoyaltyWorkflows internal ROYALTY_WORKFLOWS = IRoyaltyWorkflows(0x9515faE61E0c0447C6AC6dEe5628A2097aFE1890);
    // Revenue Token - MERC20
    MockERC20 internal MERC20 = MockERC20(0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E);

    address constant MULTICALL_ADDRESS = 0xcA11bde05977b3631167028862bE2a173976CA11;
    IMulticall3 internal multicall = IMulticall3(MULTICALL_ADDRESS);

    SimpleNFT public SIMPLE_NFT;
    uint256 public tokenId;
    address public ipId;
    uint256 public licenseTermsId;
    uint256 public startLicenseTokenId;
    address public childIpId;

    function setUp() public {
        // this is only for testing purposes
        // due to our IPGraph precompile not being
        // deployed on the fork
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");
        tokenId = SIMPLE_NFT.mint(alice);
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 20 * 10 ** 6, // 20%
                royaltyPolicy: ROYALTY_POLICY_LAP,
                currencyToken: address(MERC20)
            })
        );

        vm.prank(alice);
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);
        startLicenseTokenId = LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: licenseTermsId,
            amount: 2,
            receiver: bob,
            royaltyContext: "", // for PIL, royaltyContext is empty string
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        // Registers a child IP (owned by Bob) as a derivative of Alice's IP.
        uint256 childTokenId = SIMPLE_NFT.mint(bob);
        childIpId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), childTokenId);

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;

        vm.prank(bob);
        LICENSING_MODULE.registerDerivativeWithLicenseTokens({
            childIpId: childIpId,
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "", // empty for PIL
            maxRts: 0
        });
    }

    /// @notice Pays MERC20 to Bob's IP using Multicall3. Some of this MERC20 is then claimable
    /// by Alice's IP.
    /// @dev Multicall3 acts as the 3rd party paying MERC20 to Bob (the child IP).
    function test_claimAllRevenue() public {
        // SETUP: Simulate deBridge delivering 10 MERC20 to the Multicall3 contract.
        uint256 paymentAmount = 10;
        MERC20.mint(MULTICALL_ADDRESS, paymentAmount);
        // console.log("Initial MERC20 balance of Multicall contract: ", MERC20.balanceOf(MULTICALL_ADDRESS));

        // Prepare calls for Multicall3
        IMulticall3.Call3[] memory calls = new IMulticall3.Call3[](2);

        // Call 1: Multicall3 approves RoyaltyModule to spend its MERC20
        calls[0] = IMulticall3.Call3({
            target: address(MERC20),
            allowFailure: false,
            callData: abi.encodeWithSelector(
                bytes4(keccak256("approve(address,uint256)")),
                address(ROYALTY_MODULE),
                paymentAmount
            )
        });

        // Call 2: Multicall3 calls payRoyaltyOnBehalf
        // payerIpId is address(0) as in the original test, meaning the payment isn't tagged to a specific IP Payer
        // but the funds are coming from Multicall3.
        calls[1] = IMulticall3.Call3({
            target: address(ROYALTY_MODULE),
            allowFailure: false,
            callData: abi.encodeWithSelector(
                IRoyaltyModule.payRoyaltyOnBehalf.selector,
                childIpId,          // receiverIpId
                address(0),         // payerIpId (could be the original user's IP ID if passed through)
                address(MERC20),    // token
                paymentAmount       // amount
            )
        });
        
        // Execute the multicall
        // The internal calls will execute with MULTICALL_ADDRESS as msg.sender
        IMulticall3.Result[] memory results = multicall.aggregate3(calls);

        // Check multicall results (optional, but good practice)
        assertTrue(results[0].success, "Multicall: MERC20.approve call failed");
        assertTrue(results[1].success, "Multicall: ROYALTY_MODULE.payRoyaltyOnBehalf call failed");
        
        // console.log("Multicall executed successfully.");
        // console.log("MERC20 balance of Multicall contract after operations: ", MERC20.balanceOf(MULTICALL_ADDRESS));

        // Now that Bob's IP has been paid (via Multicall3), Alice can claim her share (2 MERC20, which
        // is 20% as specified in the license terms)
        address[] memory childIpIds = new address[](1);
        address[] memory royaltyPolicies = new address[](1);
        address[] memory currencyTokens = new address[](1);
        childIpIds[0] = childIpId;
        royaltyPolicies[0] = ROYALTY_POLICY_LAP;
        currencyTokens[0] = address(MERC20);

        uint256[] memory amountsClaimed = ROYALTY_WORKFLOWS.claimAllRevenue({
            ancestorIpId: ipId,
            claimer: ipId,
            childIpIds: childIpIds,
            royaltyPolicies: royaltyPolicies,
            currencyTokens: currencyTokens
        });

        // Check that 2 MERC20 was claimed by Alice's IP Account
        assertEq(amountsClaimed[0], 2);
        // Check that Alice's IP Account now has 2 MERC20 in its balance.
        assertEq(MERC20.balanceOf(ipId), 2);
        // Check that Bob's IP now has 8 MERC20 in its Royalty Vault, which it
        // can claim to its IP Account at a later point if he wants.
        assertEq(MERC20.balanceOf(ROYALTY_MODULE.ipRoyaltyVaults(childIpId)), 8);
        assertEq(MERC20.balanceOf(MULTICALL_ADDRESS), 0, "Multicall should have 0 MERC20 left");
    }

    /// @notice Shows an example of paying a minting fee
    function test_payMintingFee() public {
        // ADMIN SETUP
        // We mint 1 MERC20 to Bob so he has some money to pay the minting fee.
        MERC20.mint(bob, 1);

        // Create commercial use terms with a mint fee to test
        uint256 commercialUseLicenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 1, // 1 MERC20
                royaltyPolicy: ROYALTY_POLICY_LAP,
                currencyToken: address(MERC20)
            })
        );

        // attach the terms to the ip asset
        vm.prank(alice);
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), commercialUseLicenseTermsId);

        // Bob approves the Royalty Module to spend his MERC20 for the minting fee
        vm.prank(bob);
        MERC20.approve(address(ROYALTY_MODULE), 1);

        // pay the mint fee
        vm.prank(bob); // Bob is the receiver of the license token
        LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: commercialUseLicenseTermsId,
            amount: 1,
            receiver: bob,
            royaltyContext: "", // for PIL, royaltyContext is empty string
            maxMintingFee: 1 ether, // Allow up to 1 MERC20 (scaled) if fee is dynamic
            maxRevenueShare: 0
        });

        // Now that the minting fee has been paid to Alice's IP, Alice can claim her share (1 MERC20, which
        // is the full minting fee as specified in the license terms)
        address[] memory childIpIds = new address[](0);
        address[] memory royaltyPolicies = new address[](0);
        address[] memory currencyTokens = new address[](1);
        currencyTokens[0] = address(MERC20);

        uint256[] memory amountsClaimed = ROYALTY_WORKFLOWS.claimAllRevenue({
            ancestorIpId: ipId,
            claimer: ipId,
            childIpIds: childIpIds,
            royaltyPolicies: royaltyPolicies,
            currencyTokens: currencyTokens
        });

        // Check that 1 MERC20 was claimed by Alice's IP Account
        assertEq(amountsClaimed[0], 1);
        // Check that Alice's IP Account now has 1 MERC20 in its balance.
        assertEq(MERC20.balanceOf(ipId), 1);
    }
}