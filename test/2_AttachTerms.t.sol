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

import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";
import { SUSD } from "../src/mocks/SUSD.sol";

// Run this test:
// forge test --fork-url https://testnet.storyrpc.io/ --match-path test/2_AttachTerms.t.sol
contract AttachTermsTest is Test {
    address internal alice = address(0xa11ce);

    // For addresses, see https://docs.story.foundation/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    IPAssetRegistry public immutable IP_ASSET_REGISTRY = IPAssetRegistry(0x14CAB45705Fe73EC6d126518E59Fe3C61a181E40);
    // Protocol Core - LicenseRegistry
    LicenseRegistry public immutable LICENSE_REGISTRY = LicenseRegistry(0x4D71a082DE74B40904c1d89d9C3bfB7079d4c542);
    // Protocol Core - LicensingModule
    ILicensingModule public immutable LICENSING_MODULE = ILicensingModule(0xC8f165950411504eA130692B87A7148e469f7090);
    // Protocol Core - PILicenseTemplate
    PILicenseTemplate public immutable PIL_TEMPLATE = PILicenseTemplate(0xbB7ACFBE330C56aA9a3aEb84870743C3566992c3);
    // Protocol Core - RoyaltyPolicyLAP
    RoyaltyPolicyLAP public immutable ROYALTY_POLICY_LAP = RoyaltyPolicyLAP(0x793Df8d32c12B0bE9985FFF6afB8893d347B6686);
    // Mock - SUSD
    SUSD public immutable SUSD_TOKEN = SUSD(0x91f6F05B08c16769d3c85867548615d270C42fC7);

    SimpleNFT public SIMPLE_NFT;
    uint256 public tokenId;
    address public ipId;
    uint256 public licenseTermsId;

    function setUp() public {
        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");
        tokenId = SIMPLE_NFT.mint(alice);
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        // Register random Commercial Remixterms so we can attach them later
        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10 * 10 ** 6, // 10%
                royaltyPolicy: address(ROYALTY_POLICY_LAP),
                currencyToken: address(SUSD_TOKEN)
            })
        );
    }

    /// @notice Attaches license terms to an IP Asset.
    /// @dev Only the owner of an IP Asset can attach license terms to it.
    /// So in this case, alice has to be the caller of the function because
    /// she owns the NFT associated with the IP Asset.
    function test_attachLicenseTerms() public {
        vm.prank(alice);
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);

        assertTrue(LICENSE_REGISTRY.hasIpAttachedLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId));
        // We expect 2 because the IPA has the default license terms (licenseTermsId = 1)
        // and the one we attached.
        assertEq(LICENSE_REGISTRY.getAttachedLicenseTermsCount(ipId), 2);
        // Although an IP Asset has default license terms, index 0 is
        // still the one we attached.
        (address licenseTemplate, uint256 attachedLicenseTermsId) = LICENSE_REGISTRY.getAttachedLicenseTerms({
            ipId: ipId,
            index: 0
        });
        assertEq(licenseTemplate, address(PIL_TEMPLATE));
        assertEq(attachedLicenseTermsId, licenseTermsId);
    }
}
