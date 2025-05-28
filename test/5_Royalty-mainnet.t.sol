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
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

// Interface for WIP token operations
interface IWIP {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

// Run this test:
// forge test --fork-url https://mainnet.storyrpc.io/ --match-path test/5_Royalty-mainnet.t.sol
contract RoyaltyTest is Test {
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);

    // Updated mainnet addresses from the provided JSON
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
    // WIP Token (Story's native token) - whitelisted for royalties
    IWIP internal WIP_TOKEN = IWIP(0x1514000000000000000000000000000000000000);

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

        // Updated to use WIP token instead of MERC20
        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 20 * 10 ** 6, // 20%
                royaltyPolicy: ROYALTY_POLICY_LAP,
                currencyToken: address(WIP_TOKEN) // Using WIP token
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

    /// @notice Pays WIP to Bob's IP using Multicall3. Some of this WIP is then claimable
    /// by Alice's IP.
    /// @dev Multicall3 acts as the 3rd party paying WIP to Bob (the child IP).
    function test_claimAllRevenue() public {
        // SETUP: Simulate deBridge delivering 10 WIP to the Multicall3 contract.
        uint256 paymentAmount = 10 * 10**18; // 10 WIP tokens
        // We need to deal WIP tokens to Multicall3 since we can't mint WIP directly
        vm.deal(MULTICALL_ADDRESS, 0); // Clear any ETH first
        deal(address(WIP_TOKEN), MULTICALL_ADDRESS, paymentAmount);
        
        console.log("Initial WIP balance of Multicall contract: ", WIP_TOKEN.balanceOf(MULTICALL_ADDRESS));

        // Prepare calls for Multicall3
        IMulticall3.Call3[] memory calls = new IMulticall3.Call3[](2);

        // Call 1: Multicall3 approves RoyaltyModule to spend its WIP
        calls[0] = IMulticall3.Call3({
            target: address(WIP_TOKEN),
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
                address(WIP_TOKEN), // token
                paymentAmount       // amount
            )
        });
        
        // Execute the multicall
        // The internal calls will execute with MULTICALL_ADDRESS as msg.sender
        IMulticall3.Result[] memory results = multicall.aggregate3(calls);

        // Check multicall results (optional, but good practice)
        assertTrue(results[0].success, "Multicall: WIP.approve call failed");
        assertTrue(results[1].success, "Multicall: ROYALTY_MODULE.payRoyaltyOnBehalf call failed");
        
        console.log("Multicall executed successfully.");
        console.log("WIP balance of Multicall contract after operations: ", WIP_TOKEN.balanceOf(MULTICALL_ADDRESS));

        // Now that Bob's IP has been paid (via Multicall3), Alice can claim her share (2 WIP, which
        // is 20% as specified in the license terms)
        address[] memory childIpIds = new address[](1);
        address[] memory royaltyPolicies = new address[](1);
        address[] memory currencyTokens = new address[](1);
        childIpIds[0] = childIpId;
        royaltyPolicies[0] = ROYALTY_POLICY_LAP;
        currencyTokens[0] = address(WIP_TOKEN);

        uint256[] memory amountsClaimed = ROYALTY_WORKFLOWS.claimAllRevenue({
            ancestorIpId: ipId,
            claimer: ipId,
            childIpIds: childIpIds,
            royaltyPolicies: royaltyPolicies,
            currencyTokens: currencyTokens
        });

        // Check that 2 WIP was claimed by Alice's IP Account
        assertEq(amountsClaimed[0], 2 * 10**18);
        // Check that Alice's IP Account now has 2 WIP in its balance.
        assertEq(WIP_TOKEN.balanceOf(ipId), 2 * 10**18);
        // Check that Bob's IP now has 8 WIP in its Royalty Vault, which it
        // can claim to its IP Account at a later point if he wants.
        assertEq(WIP_TOKEN.balanceOf(ROYALTY_MODULE.ipRoyaltyVaults(childIpId)), 8 * 10**18);
        assertEq(WIP_TOKEN.balanceOf(MULTICALL_ADDRESS), 0, "Multicall should have 0 WIP left");
    }

    /// @notice Shows an example of paying a minting fee
    function test_payMintingFee() public {
        // ADMIN SETUP
        // We deal 1 WIP to Bob so he has some money to pay the minting fee.
        deal(address(WIP_TOKEN), bob, 1 * 10**18);

        // Create commercial use terms with a mint fee to test
        uint256 commercialUseLicenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialUse({
                mintingFee: 1 * 10**18, // 1 WIP
                royaltyPolicy: ROYALTY_POLICY_LAP,
                currencyToken: address(WIP_TOKEN)
            })
        );

        // attach the terms to the ip asset
        vm.prank(alice);
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), commercialUseLicenseTermsId);

        // Bob approves the Royalty Module to spend his WIP for the minting fee
        vm.prank(bob);
        WIP_TOKEN.approve(address(ROYALTY_MODULE), 1 * 10**18);

        // pay the mint fee
        vm.prank(bob); // Bob is the receiver of the license token
        LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: commercialUseLicenseTermsId,
            amount: 1,
            receiver: bob,
            royaltyContext: "", // for PIL, royaltyContext is empty string
            maxMintingFee: 1 * 10**18, // Allow up to 1 WIP for minting fee
            maxRevenueShare: 0
        });

        // Now that the minting fee has been paid to Alice's IP, Alice can claim her share (1 WIP, which
        // is the full minting fee as specified in the license terms)
        address[] memory childIpIds = new address[](0);
        address[] memory royaltyPolicies = new address[](0);
        address[] memory currencyTokens = new address[](1);
        currencyTokens[0] = address(WIP_TOKEN);

        uint256[] memory amountsClaimed = ROYALTY_WORKFLOWS.claimAllRevenue({
            ancestorIpId: ipId,
            claimer: ipId,
            childIpIds: childIpIds,
            royaltyPolicies: royaltyPolicies,
            currencyTokens: currencyTokens
        });

        // Check that 1 WIP was claimed by Alice's IP Account
        assertEq(amountsClaimed[0], 1 * 10**18);
        // Check that Alice's IP Account now has 1 WIP in its balance.
        assertEq(WIP_TOKEN.balanceOf(ipId), 1 * 10**18);
    }

    /// @notice Test paying royalties to a real child IP using Multicall3
    /// @dev This test uses an actual IP asset that exists on Story mainnet
    function test_payRoyaltyToRealChildIP() public {
        // Use the real child IP address provided by the user
        address realChildIpId = 0xB1D831271A68Db5c18c8F0B69327446f7C8D0A42;
        
        console.log("Testing with real child IP:", realChildIpId);
        
        // SETUP: Simulate deBridge delivering 5 WIP to the Multicall3 contract for royalty payment
        uint256 paymentAmount = 5 * 10**18; // 5 WIP tokens
        deal(address(WIP_TOKEN), MULTICALL_ADDRESS, paymentAmount);
        
        console.log("Initial WIP balance of Multicall contract:", WIP_TOKEN.balanceOf(MULTICALL_ADDRESS));
        console.log("Real child IP initial WIP balance:", WIP_TOKEN.balanceOf(realChildIpId));
        
        // Get the royalty vault address for this IP before payment
        address royaltyVaultBefore = ROYALTY_MODULE.ipRoyaltyVaults(realChildIpId);
        uint256 vaultBalanceBefore = WIP_TOKEN.balanceOf(royaltyVaultBefore);
        console.log("Child IP royalty vault before payment:", royaltyVaultBefore);
        console.log("Vault balance before payment:", vaultBalanceBefore);

        // Prepare calls for Multicall3
        IMulticall3.Call3[] memory calls = new IMulticall3.Call3[](2);

        // Call 1: Multicall3 approves RoyaltyModule to spend its WIP
        calls[0] = IMulticall3.Call3({
            target: address(WIP_TOKEN),
            allowFailure: false,
            callData: abi.encodeWithSelector(
                bytes4(keccak256("approve(address,uint256)")),
                address(ROYALTY_MODULE),
                paymentAmount
            )
        });

        // Call 2: Multicall3 calls payRoyaltyOnBehalf to the real child IP
        calls[1] = IMulticall3.Call3({
            target: address(ROYALTY_MODULE),
            allowFailure: false,
            callData: abi.encodeWithSelector(
                IRoyaltyModule.payRoyaltyOnBehalf.selector,
                realChildIpId,      // receiverIpId: the real child IP
                address(0),         // payerIpId: external payer (not tagged to specific IP)
                address(WIP_TOKEN), // token: WIP
                paymentAmount       // amount: 5 WIP
            )
        });
        
        // Execute the multicall
        IMulticall3.Result[] memory results = multicall.aggregate3(calls);

        // Check multicall results
        assertTrue(results[0].success, "Multicall: WIP.approve call failed");
        assertTrue(results[1].success, "Multicall: ROYALTY_MODULE.payRoyaltyOnBehalf call failed");
        
        console.log("Multicall executed successfully!");
        
        // Verify the payment was processed
        assertEq(WIP_TOKEN.balanceOf(MULTICALL_ADDRESS), 0, "Multicall should have 0 WIP left");
        
        // Check that the royalty was paid to the child IP's vault
        address royaltyVaultAfter = ROYALTY_MODULE.ipRoyaltyVaults(realChildIpId);
        uint256 vaultBalanceAfter = WIP_TOKEN.balanceOf(royaltyVaultAfter);
        
        console.log("Vault balance after payment:", vaultBalanceAfter);
        
        // The vault should have received the payment
        assertEq(vaultBalanceAfter, vaultBalanceBefore + paymentAmount, "Royalty vault should have received the payment");
        
        console.log("[SUCCESS] Successfully paid", paymentAmount / 10**18, "WIP to real child IP via Multicall3");
        
        // Note: This child IP might have parent IPs that could claim revenue shares
        // but we're just testing the basic payment functionality here
    }
}