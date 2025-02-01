// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
// for testing purposes only
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { LicenseRegistry } from "@storyprotocol/core/registries/LicenseRegistry.sol";

import { Example } from "../src/Example.sol";
import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";

// Run this test:
// forge test --fork-url https://rpc.odyssey.storyrpc.io/ --match-path test/Example.t.sol
contract ExampleTest is Test {
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);
    // For addresses, see https://docs.story.foundation/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    address internal ipAssetRegistry = 0x77319B4031e6eF1250907aa00018B8B1c67a244b;
    // Protocol Core - LicenseRegistry
    address internal licenseRegistry = 0x529a750E02d8E2f15649c13D69a465286a780e24;
    // Protocol Core - LicensingModule
    address internal licensingModule = 0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f;
    // Protocol Core - PILicenseTemplate
    address internal pilTemplate = 0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316;
    // Protocol Core - RoyaltyPolicyLAP
    address internal royaltyPolicyLAP = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
    // Mock - MERC20
    address internal merc20 = 0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E;

    SimpleNFT public SIMPLE_NFT;
    Example public EXAMPLE;

    function setUp() public {
        // this is only for testing purposes
        // due to our IPGraph precompile not being
        // deployed on the fork
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        EXAMPLE = new Example(ipAssetRegistry, licensingModule, pilTemplate, royaltyPolicyLAP, merc20);
        SIMPLE_NFT = SimpleNFT(EXAMPLE.SIMPLE_NFT());
    }

    function test_mintAndRegisterAndCreateTermsAndAttach() public {
        LicenseRegistry LICENSE_REGISTRY = LicenseRegistry(licenseRegistry);
        IPAssetRegistry IP_ASSET_REGISTRY = IPAssetRegistry(ipAssetRegistry);

        uint256 expectedTokenId = SIMPLE_NFT.nextTokenId();
        address expectedIpId = IP_ASSET_REGISTRY.ipId(block.chainid, address(SIMPLE_NFT), expectedTokenId);

        (uint256 tokenId, address ipId, uint256 licenseTermsId) = EXAMPLE.mintAndRegisterAndCreateTermsAndAttach(alice);

        assertEq(tokenId, expectedTokenId);
        assertEq(ipId, expectedIpId);
        assertEq(SIMPLE_NFT.ownerOf(tokenId), alice);

        assertTrue(LICENSE_REGISTRY.hasIpAttachedLicenseTerms(ipId, pilTemplate, licenseTermsId));
        assertEq(LICENSE_REGISTRY.getAttachedLicenseTermsCount(ipId), 1);
        (address licenseTemplate, uint256 attachedLicenseTermsId) = LICENSE_REGISTRY.getAttachedLicenseTerms({
            ipId: ipId,
            index: 0
        });
        assertEq(licenseTemplate, pilTemplate);
        assertEq(attachedLicenseTermsId, licenseTermsId);
    }

    function test_mintLicenseTokenAndRegisterDerivative() public {
        LicenseRegistry LICENSE_REGISTRY = LicenseRegistry(licenseRegistry);
        IPAssetRegistry IP_ASSET_REGISTRY = IPAssetRegistry(ipAssetRegistry);

        (uint256 parentTokenId, address parentIpId, uint256 licenseTermsId) = EXAMPLE
            .mintAndRegisterAndCreateTermsAndAttach(alice);

        (uint256 childTokenId, address childIpId) = EXAMPLE.mintLicenseTokenAndRegisterDerivative(
            parentIpId,
            licenseTermsId,
            bob
        );

        assertTrue(LICENSE_REGISTRY.hasDerivativeIps(parentIpId));
        assertTrue(LICENSE_REGISTRY.isParentIp(parentIpId, childIpId));
        assertTrue(LICENSE_REGISTRY.isDerivativeIp(childIpId));
        assertEq(LICENSE_REGISTRY.getDerivativeIpCount(parentIpId), 1);
        assertEq(LICENSE_REGISTRY.getParentIpCount(childIpId), 1);
        assertEq(LICENSE_REGISTRY.getParentIp({ childIpId: childIpId, index: 0 }), parentIpId);
        assertEq(LICENSE_REGISTRY.getDerivativeIp({ parentIpId: parentIpId, index: 0 }), childIpId);
    }
}
