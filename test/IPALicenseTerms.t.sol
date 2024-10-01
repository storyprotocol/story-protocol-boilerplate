// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { LicenseRegistry } from "@storyprotocol/core/registries/LicenseRegistry.sol";

import { IPALicenseTerms } from "../src/IPALicenseTerms.sol";
import { SimpleNFT } from "../src/SimpleNFT.sol";

// Run this test: forge test --fork-url https://testnet.storyrpc.io/ --match-path test/IPALicenseTerms.t.sol
contract IPALicenseTermsTest is Test {
    address internal alice = address(0xa11ce);

    // For addresses, see https://docs.storyprotocol.xyz/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    address internal ipAssetRegistryAddr = 0x1a9d0d28a0422F26D31Be72Edc6f13ea4371E11B;
    // Protocol Core - LicensingModule
    address internal licensingModuleAddr = 0xd81fd78f557b457b4350cB95D20b547bFEb4D857;
    // Protocol Core - LicenseRegistry
    address internal licenseRegistryAddr = 0xedf8e338F05f7B1b857C3a8d3a0aBB4bc2c41723;
    // Protocol Core - PILicenseTemplate
    address internal pilTemplateAddr = 0x0752f61E59fD2D39193a74610F1bd9a6Ade2E3f9;

    IPAssetRegistry public ipAssetRegistry;
    LicenseRegistry public licenseRegistry;

    IPALicenseTerms public ipaLicenseTerms;
    SimpleNFT public simpleNft;

    function setUp() public {
        ipAssetRegistry = IPAssetRegistry(ipAssetRegistryAddr);
        licenseRegistry = LicenseRegistry(licenseRegistryAddr);
        ipaLicenseTerms = new IPALicenseTerms(ipAssetRegistryAddr, licensingModuleAddr, pilTemplateAddr);
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
        // This is the license terms that we are attaching in the IPALicenseTerms contract.
        uint256 expectedLicenseTermsId = 2;

        vm.prank(alice);
        (address ipId, uint256 tokenId) = ipaLicenseTerms.attachLicenseTerms();

        assertEq(ipId, expectedIpId);
        assertEq(tokenId, expectedTokenId);
        assertEq(simpleNft.ownerOf(tokenId), alice);

        assertTrue(licenseRegistry.hasIpAttachedLicenseTerms(ipId, expectedLicenseTemplate, expectedLicenseTermsId));
        // We expect 2 because the IPA has the default license terms (licenseTermsId = 1)
        // and the one we attached (licenseTermsId = 2).
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId), 2);

        // Although an IP Asset has default license terms, index 0 is still the one we attached.
        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms({
            ipId: ipId,
            index: 0
        });
        assertEq(licenseTemplate, expectedLicenseTemplate);
        assertEq(licenseTermsId, expectedLicenseTermsId);
    }
}
