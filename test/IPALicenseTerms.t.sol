// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { LicenseRegistry } from "@storyprotocol/core/registries/LicenseRegistry.sol";

import { IPALicenseTerms } from "../src/IPALicenseTerms.sol";
import { SimpleNFT } from "../src/SimpleNFT.sol";

contract IPALicenseTermsTest is Test {
    address internal alice = address(0xa11ce);

    // Protocol Core v1 addresses
    // (see https://docs.storyprotocol.xyz/docs/deployed-smart-contracts)
    address internal ipAssetRegistryAddr = 0xd43fE0d865cb5C26b1351d3eAf2E3064BE3276F6;
    address internal licensingModuleAddr = 0xe89b0EaA8a0949738efA80bB531a165FB3456CBe;
    address internal licenseRegistryAddr = 0x4f4b1bf7135C7ff1462826CCA81B048Ed19562ed;
    address internal pilTemplateAddr = 0x260B6CB6284c89dbE660c0004233f7bB99B5edE7;

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
        uint256 expectedLicenseTermsId = 1;

        vm.prank(alice);
        (address ipId, uint256 tokenId) = ipaLicenseTerms.attachLicenseTerms();

        assertEq(ipId, expectedIpId);
        assertEq(tokenId, expectedTokenId);
        assertEq(simpleNft.ownerOf(tokenId), alice);

        assertTrue(licenseRegistry.hasIpAttachedLicenseTerms(ipId, expectedLicenseTemplate, expectedLicenseTermsId));
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId), 1);

        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms({
            ipId: ipId,
            index: 0
        });
        assertEq(licenseTemplate, expectedLicenseTemplate);
        assertEq(licenseTermsId, expectedLicenseTermsId);
    }
}
