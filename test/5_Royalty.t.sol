// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
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
                commercialRevShare: 10 * 10 ** 6, // 10%
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

    /// @notice Pays MERC20 to Bob's IP. Some of this MERC20 is then claimable
    /// by Alice's IP.
    /// @dev In this case, this contract will act as the 3rd party paying MERC20
    /// to Bob (the child IP).
    function test_claimAllRevenue() public {
        // ADMIN SETUP
        // We mint 100 MERC20 to this contract so it has some money to pay.
        MERC20.mint(address(this), 100);
        // We approve the Royalty Module to spend MERC20 on our behalf, which
        // it will do using `payRoyaltyOnBehalf`.
        MERC20.approve(address(ROYALTY_MODULE), 10);

        // This contract pays 10 MERC20 to Bob's IP.
        ROYALTY_MODULE.payRoyaltyOnBehalf(childIpId, address(0), address(MERC20), 10);

        // Now that Bob's IP has been paid, Alice can claim her share (1 MERC20, which
        // is 10% as specified in the license terms)
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

        // Check that 1 MERC20 was claimed by Alice's IP Account
        assertEq(amountsClaimed[0], 1);
        // Check that Alice's IP Account now has 1 MERC20 in its balance.
        assertEq(MERC20.balanceOf(ipId), 1);
        // Check that Bob's IP now has 9 MERC20 in its Royalty Vault, which it
        // can claim to its IP Account at a later point if he wants.
        assertEq(MERC20.balanceOf(ROYALTY_MODULE.ipRoyaltyVaults(childIpId)), 9);
    }
}
