// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { LicenseToken } from "@storyprotocol/core/LicenseToken.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";

import { IPALicenseToken } from "../src/IPALicenseToken.sol";
import { SimpleNFT } from "../src/SimpleNFT.sol";

// Run this test: forge test --fork-url https://testnet.storyrpc.io/ --match-path test/IPALicenseToken.t.sol
contract IPALicenseTokenTest is Test {
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);

    // For addresses, see https://docs.storyprotocol.xyz/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    address internal ipAssetRegistryAddr = 0x1a9d0d28a0422F26D31Be72Edc6f13ea4371E11B;
    // Protocol Core - LicensingModule
    address internal licensingModuleAddr = 0xd81fd78f557b457b4350cB95D20b547bFEb4D857;
    // Protocol Core - LicenseToken
    address internal licenseTokenAddr = 0xc7A302E03cd7A304394B401192bfED872af501BE;
    // Protocol Core - PILicenseTemplate
    address internal pilTemplateAddr = 0x0752f61E59fD2D39193a74610F1bd9a6Ade2E3f9;

    IPAssetRegistry public ipAssetRegistry;
    LicenseToken public licenseToken;

    IPALicenseToken public ipaLicenseToken;
    SimpleNFT public simpleNft;

    function setUp() public {
        ipAssetRegistry = IPAssetRegistry(ipAssetRegistryAddr);
        licenseToken = LicenseToken(licenseTokenAddr);
        ipaLicenseToken = new IPALicenseToken(ipAssetRegistryAddr, licensingModuleAddr, pilTemplateAddr);
        simpleNft = SimpleNFT(ipaLicenseToken.SIMPLE_NFT());

        vm.label(address(ipAssetRegistryAddr), "IPAssetRegistry");
        vm.label(address(licensingModuleAddr), "LicensingModule");
        vm.label(address(licenseTokenAddr), "LicenseToken");
        vm.label(address(pilTemplateAddr), "PILicenseTemplate");
        vm.label(address(simpleNft), "SimpleNFT");
        vm.label(address(0x000000006551c19487814612e58FE06813775758), "ERC6551Registry");
    }

    function test_mintLicenseToken() public {
        uint256 expectedTokenId = simpleNft.nextTokenId();
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(simpleNft), expectedTokenId);

        vm.prank(alice);
        (address ipId, uint256 tokenId, uint256 startLicenseTokenId) = ipaLicenseToken.mintLicenseToken({
            ltAmount: 2,
            ltRecipient: bob
        });

        assertEq(ipId, expectedIpId);
        assertEq(tokenId, expectedTokenId);
        assertEq(simpleNft.ownerOf(tokenId), alice);

        assertEq(licenseToken.ownerOf(startLicenseTokenId), bob);
        assertEq(licenseToken.ownerOf(startLicenseTokenId + 1), bob);
    }
}
