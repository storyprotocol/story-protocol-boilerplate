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

import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";
import { SUSD } from "../src/mocks/SUSD.sol";

// Run this test:
// forge test --fork-url https://testnet.storyrpc.io/ --match-path test/3_LicenseToken.t.sol
contract LicenseTokenTest is Test {
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
    // Mock - SUSD
    SUSD internal SUSD_TOKEN = SUSD(0x91f6F05B08c16769d3c85867548615d270C42fC7);

    SimpleNFT public SIMPLE_NFT;
    uint256 public tokenId;
    address public ipId;
    uint256 public licenseTermsId;

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
    }

    /// @notice Mints license tokens for an IP Asset.
    /// Anyone can mint a license token.
    function test_mintLicenseToken() public {
        uint256 startLicenseTokenId = LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: licenseTermsId,
            amount: 2,
            receiver: bob,
            royaltyContext: "" // for PIL, royaltyContext is empty string
        });

        assertEq(LICENSE_TOKEN.ownerOf(startLicenseTokenId), bob);
        assertEq(LICENSE_TOKEN.ownerOf(startLicenseTokenId + 1), bob);
    }
}
