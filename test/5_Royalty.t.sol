// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { LicenseRegistry } from "@storyprotocol/core/registries/LicenseRegistry.sol";
import { PILicenseTemplate } from "@storyprotocol/core/modules/licensing/PILicenseTemplate.sol";
import { RoyaltyPolicyLAP } from "@storyprotocol/core/modules/royalty/policies/LAP/RoyaltyPolicyLAP.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { LicenseToken } from "@storyprotocol/core/LicenseToken.sol";
import { IRoyaltyWorkflows } from "@storyprotocol/periphery/interfaces/workflows/IRoyaltyWorkflows.sol";
import { RoyaltyModule } from "@storyprotocol/core/modules/royalty/RoyaltyModule.sol";

import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";
import { SUSD } from "../src/mocks/SUSD.sol";

// Run this test:
// forge test --fork-url https://testnet.storyrpc.io/ --match-path test/5_Royalty.t.sol
contract RoyaltyTest is Test {
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);

    // For addresses, see https://docs.story.foundation/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    IPAssetRegistry internal IP_ASSET_REGISTRY = IPAssetRegistry(0x14CAB45705Fe73EC6d126518E59Fe3C61a181E40);
    // Protocol Core - LicenseRegistry
    LicenseRegistry internal LICENSE_REGISTRY = LicenseRegistry(0x4D71a082DE74B40904c1d89d9C3bfB7079d4c542);
    // Protocol Core - LicensingModule
    ILicensingModule internal LICENSING_MODULE = ILicensingModule(0xC8f165950411504eA130692B87A7148e469f7090);
    // Protocol Core - PILicenseTemplate
    PILicenseTemplate internal PIL_TEMPLATE = PILicenseTemplate(0xbB7ACFBE330C56aA9a3aEb84870743C3566992c3);
    // Protocol Core - RoyaltyPolicyLAP
    RoyaltyPolicyLAP internal ROYALTY_POLICY_LAP = RoyaltyPolicyLAP(0x793Df8d32c12B0bE9985FFF6afB8893d347B6686);
    // Protocol Core - LicenseToken
    LicenseToken internal LICENSE_TOKEN = LicenseToken(0xd8aEF404432a2b3363479A6157285926B6B3b743);
    // Protocol Periphery - RoyaltyModule
    RoyaltyModule internal ROYALTY_MODULE = RoyaltyModule(0xaCb5764E609aa3a5ED36bA74ba59679246Cb0963);
    // Protocol Periphery - RoyaltyWorkflows
    IRoyaltyWorkflows internal ROYALTY_WORKFLOWS = IRoyaltyWorkflows(0xc757921ee0f7c8E935d44BFBDc2602786e0eda6C);
    // Mock - SUSD
    SUSD internal SUSD_TOKEN = SUSD(0x91f6F05B08c16769d3c85867548615d270C42fC7);

    SimpleNFT public SIMPLE_NFT;
    uint256 public tokenId;
    address public ipId;
    uint256 public licenseTermsId;
    uint256 public startLicenseTokenId;
    address public childIpId;

    function setUp() public {
        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");
        tokenId = SIMPLE_NFT.mint(alice);
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10 * 10 ** 6, // 10%
                royaltyPolicy: address(ROYALTY_POLICY_LAP),
                currencyToken: address(SUSD_TOKEN)
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
            royaltyContext: "" // for PIL, royaltyContext is empty string
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
            royaltyContext: "" // empty for PIL
        });
    }

    /// @notice Pays SUSD to Bob's IP. Some of this SUSD is then claimable
    /// by Alice's IP.
    /// @dev In this case, this contract will act as the 3rd party paying SUSD
    /// to Bob (the child IP).
    function test_transferToVaultAndSnapshotAndClaimByTokenBatch() public {
        // ADMIN SETUP
        // We mint 100 SUSD to this contract so it has some money to pay.
        SUSD_TOKEN.mint(address(this), 100);
        // We approve the Royalty Module to spend SUSD on our behalf, which
        // it will do using `payRoyaltyOnBehalf`.
        SUSD_TOKEN.approve(address(ROYALTY_MODULE), 10);

        // This contract pays 10 SUSD to Bob's IP.
        ROYALTY_MODULE.payRoyaltyOnBehalf(childIpId, address(0), address(SUSD_TOKEN), 10);

        // Now that Bob's IP has been paid, Alice can claim her share (1 SUSD, which
        // is 10% as specified in the license terms)
        IRoyaltyWorkflows.RoyaltyClaimDetails[] memory claimDetails = new IRoyaltyWorkflows.RoyaltyClaimDetails[](1);
        claimDetails[0] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: childIpId,
            royaltyPolicy: address(ROYALTY_POLICY_LAP),
            currencyToken: address(SUSD_TOKEN),
            amount: 1
        });
        (uint256 snapshotId, uint256[] memory amountsClaimed) = ROYALTY_WORKFLOWS
            .transferToVaultAndSnapshotAndClaimByTokenBatch({
                ancestorIpId: ipId,
                claimer: ipId,
                royaltyClaimDetails: claimDetails
            });

        // Check that 1 SUSD was claimed by Alice's IP Account
        assertEq(amountsClaimed[0], 1);
        // Check that Alice's IP Account now has 1 SUSD in its balance.
        assertEq(SUSD_TOKEN.balanceOf(ipId), 1);
        // Check that Bob's IP now has 9 SUSD in its Royalty Vault, which it
        // can claim to its IP Account at a later point if he wants.
        assertEq(SUSD_TOKEN.balanceOf(ROYALTY_MODULE.ipRoyaltyVaults(childIpId)), 9);
    }
}
