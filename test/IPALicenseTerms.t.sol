// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { LicenseRegistry } from "@storyprotocol/core/registries/LicenseRegistry.sol";

import { IPALicenseTerms } from "../src/IPALicenseTerms.sol";
import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";

// Run this test: forge test --fork-url https://testnet.storyrpc.io/ --match-path test/IPALicenseTerms.t.sol
contract IPALicenseTermsTest is Test {
    address internal alice = address(0xa11ce);

    // For addresses, see https://docs.storyprotocol.xyz/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    address internal ipAssetRegistryAddr = 0x14CAB45705Fe73EC6d126518E59Fe3C61a181E40;
    // Protocol Core - LicensingModule
    address internal licensingModuleAddr = 0xC8f165950411504eA130692B87A7148e469f7090;
    // Protocol Core - LicenseRegistry
    address internal licenseRegistryAddr = 0x4D71a082DE74B40904c1d89d9C3bfB7079d4c542;
    // Protocol Core - PILicenseTemplate
    address internal pilTemplateAddr = 0xbB7ACFBE330C56aA9a3aEb84870743C3566992c3;
    // Protocol Core - RoyaltyPolicyLAP
    address internal royaltyPolicyLAPAddr = 0x793Df8d32c12B0bE9985FFF6afB8893d347B6686;
    // Protocol Core - SUSD
    address internal susdAddr = 0x91f6F05B08c16769d3c85867548615d270C42fC7;

    IPAssetRegistry public ipAssetRegistry;
    LicenseRegistry public licenseRegistry;

    IPALicenseTerms public ipaLicenseTerms;
    SimpleNFT public simpleNft;

    function setUp() public {
        ipAssetRegistry = IPAssetRegistry(ipAssetRegistryAddr);
        licenseRegistry = LicenseRegistry(licenseRegistryAddr);
        ipaLicenseTerms = new IPALicenseTerms(
            ipAssetRegistryAddr,
            licensingModuleAddr,
            pilTemplateAddr,
            royaltyPolicyLAPAddr,
            susdAddr
        );
        simpleNft = SimpleNFT(ipaLicenseTerms.SIMPLE_NFT());

        vm.label(address(ipAssetRegistryAddr), "IPAssetRegistry");
        vm.label(address(licensingModuleAddr), "LicensingModule");
        vm.label(address(licenseRegistryAddr), "LicenseRegistry");
        vm.label(address(pilTemplateAddr), "PILicenseTemplate");
        vm.label(address(simpleNft), "SimpleNFT");
        vm.label(address(0x000000006551c19487814612e58FE06813775758), "ERC6551Registry");
    }

    function test_attachLicenseTerms() public {
        uint256 expectedTokenId = simpleNft.nextTokenId();
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(simpleNft), expectedTokenId);

        address expectedLicenseTemplate = pilTemplateAddr;

        vm.prank(alice);
        (address ipId, uint256 tokenId, uint256 expectedLicenseTermsId) = ipaLicenseTerms.attachLicenseTerms();

        assertEq(ipId, expectedIpId);
        assertEq(tokenId, expectedTokenId);
        assertEq(simpleNft.ownerOf(tokenId), alice);

        assertTrue(licenseRegistry.hasIpAttachedLicenseTerms(ipId, expectedLicenseTemplate, expectedLicenseTermsId));
        // We expect 2 because the IPA has the default license terms (licenseTermsId = 1)
        // and the one we attached (expectedLicenseTermsId).
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId), 2);

        // Although an IP Asset has default license terms, index 0 is still the one we attached.
        (address licenseTemplate, uint256 attachedLicenseTermsId) = licenseRegistry.getAttachedLicenseTerms({
            ipId: ipId,
            index: 0
        });
        assertEq(licenseTemplate, expectedLicenseTemplate);
        assertEq(attachedLicenseTermsId, expectedLicenseTermsId);
    }
}
