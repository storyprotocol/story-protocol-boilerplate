// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { LicenseRegistry } from "@storyprotocol/core/registries/LicenseRegistry.sol";

import { Example } from "../src/Example.sol";
import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";

// Run this test:
// forge test --fork-url https://testnet.storyrpc.io/ --match-path test/Example.t.sol
contract ExampleTest is Test {
    address internal alice = address(0xa11ce);

    // For addresses, see https://docs.story.foundation/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    address internal ipAssetRegistry = 0x14CAB45705Fe73EC6d126518E59Fe3C61a181E40;
    // Protocol Core - LicenseRegistry
    address internal licenseRegistry = 0x4D71a082DE74B40904c1d89d9C3bfB7079d4c542;
    // Protocol Core - LicensingModule
    address internal licensingModule = 0xC8f165950411504eA130692B87A7148e469f7090;
    // Protocol Core - PILicenseTemplate
    address internal pilTemplate = 0xbB7ACFBE330C56aA9a3aEb84870743C3566992c3;
    // Protocol Core - RoyaltyPolicyLAP
    address internal royaltyPolicyLAP = 0x793Df8d32c12B0bE9985FFF6afB8893d347B6686;
    // Mock - SUSD
    address internal susd = 0x91f6F05B08c16769d3c85867548615d270C42fC7;

    SimpleNFT public SIMPLE_NFT;
    Example public EXAMPLE;

    function setUp() public {
        EXAMPLE = new Example(ipAssetRegistry, licensingModule, pilTemplate, royaltyPolicyLAP, susd);
        SIMPLE_NFT = SimpleNFT(EXAMPLE.SIMPLE_NFT());
    }

    function test_mintAndRegisterAndCreateTermsAndAttach() public {
        LicenseRegistry LICENSE_REGISTRY = LicenseRegistry(licenseRegistry);
        IPAssetRegistry IP_ASSET_REGISTRY = IPAssetRegistry(ipAssetRegistry);

        uint256 expectedTokenId = SIMPLE_NFT.nextTokenId();
        address expectedIpId = IP_ASSET_REGISTRY.ipId(block.chainid, address(SIMPLE_NFT), expectedTokenId);

        (address ipId, uint256 tokenId, uint256 licenseTermsId) = EXAMPLE.mintAndRegisterAndCreateTermsAndAttach(alice);

        assertEq(tokenId, expectedTokenId);
        assertEq(ipId, expectedIpId);
        assertEq(SIMPLE_NFT.ownerOf(tokenId), alice);

        assertTrue(LICENSE_REGISTRY.hasIpAttachedLicenseTerms(ipId, pilTemplate, licenseTermsId));
        // We expect 2 because the IPA has the default license terms (licenseTermsId = 1)
        // and the one we attached.
        assertEq(LICENSE_REGISTRY.getAttachedLicenseTermsCount(ipId), 2);
        // Although an IP Asset has default license terms, index 0 is
        // still the one we attached.
        (address licenseTemplate, uint256 attachedLicenseTermsId) = LICENSE_REGISTRY.getAttachedLicenseTerms({
            ipId: ipId,
            index: 0
        });
        assertEq(licenseTemplate, pilTemplate);
        assertEq(attachedLicenseTermsId, licenseTermsId);
    }
}
