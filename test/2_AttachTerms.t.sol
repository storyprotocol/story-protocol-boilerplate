// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { LicenseRegistry } from "@storyprotocol/core/registries/LicenseRegistry.sol";
import { PILicenseTemplate } from "@storyprotocol/core/modules/licensing/PILicenseTemplate.sol";
import { RoyaltyPolicyLAP } from "@storyprotocol/core/modules/royalty/policies/LAP/RoyaltyPolicyLAP.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { LicensingModule } from "@storyprotocol/core/modules/licensing/LicensingModule.sol";

import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";
import { SUSD } from "../src/mocks/SUSD.sol";

// Run this test:
// forge test --fork-url https://testnet.storyrpc.io/ --match-path test/2_AttachTerms.t.sol
contract AttachTermsTest is Test {
    address internal alice = address(0xa11ce);

    // For addresses, see https://docs.story.foundation/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    IPAssetRegistry public immutable IP_ASSET_REGISTRY = IPAssetRegistry(0x28E59E91C0467e89fd0f0438D47Ca839cDfEc095);
    // Protocol Core - LicenseRegistry
    LicenseRegistry public immutable LICENSE_REGISTRY = LicenseRegistry(0xBda3992c49E98392e75E78d82B934F3598bA495f);
    // Protocol Core - LicensingModule
    LicensingModule public immutable LICENSING_MODULE = LicensingModule(0x5a7D9Fa17DE09350F481A53B470D798c1c1aabae);
    // Protocol Core - PILicenseTemplate
    PILicenseTemplate public immutable PIL_TEMPLATE = PILicenseTemplate(0x58E2c909D557Cd23EF90D14f8fd21667A5Ae7a93);
    // Protocol Core - RoyaltyPolicyLAP
    RoyaltyPolicyLAP public immutable ROYALTY_POLICY_LAP = RoyaltyPolicyLAP(0x28b4F70ffE5ba7A26aEF979226f77Eb57fb9Fdb6);
    // Mock - SUSD
    SUSD public immutable SUSD_TOKEN = SUSD(0xC0F6E387aC0B324Ec18EAcf22EE7271207dCE3d5);

    SimpleNFT public SIMPLE_NFT;
    uint256 public tokenId;
    address public ipId;
    uint256 public licenseTermsId;

    function setUp() public {
        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");
        tokenId = SIMPLE_NFT.mint(alice);
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        // Register random Commercial Remix terms so we can attach them later
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
