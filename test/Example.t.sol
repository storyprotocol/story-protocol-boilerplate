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
// forge test --fork-url https://odyssey.storyrpc.io/ --match-path test/Example.t.sol
contract ExampleTest is Test {
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);
    // For addresses, see https://docs.story.foundation/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    address internal ipAssetRegistry = 0x28E59E91C0467e89fd0f0438D47Ca839cDfEc095;
    // Protocol Core - LicenseRegistry
    address internal licenseRegistry = 0xBda3992c49E98392e75E78d82B934F3598bA495f;
    // Protocol Core - LicensingModule
    address internal licensingModule = 0x5a7D9Fa17DE09350F481A53B470D798c1c1aabae;
    // Protocol Core - PILicenseTemplate
    address internal pilTemplate = 0x58E2c909D557Cd23EF90D14f8fd21667A5Ae7a93;
    // Protocol Core - RoyaltyPolicyLAP
    address internal royaltyPolicyLAP = 0x28b4F70ffE5ba7A26aEF979226f77Eb57fb9Fdb6;
    // Mock - SUSD
    address internal susd = 0xC0F6E387aC0B324Ec18EAcf22EE7271207dCE3d5;

    SimpleNFT public SIMPLE_NFT;
    Example public EXAMPLE;

    function setUp() public {
        // this is only for testing purposes
        // due to our IPGraph precompile not being
        // deployed on the fork
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

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

    function test_mintLicenseTokenAndRegisterDerivative() public {
        LicenseRegistry LICENSE_REGISTRY = LicenseRegistry(licenseRegistry);
        IPAssetRegistry IP_ASSET_REGISTRY = IPAssetRegistry(ipAssetRegistry);

        (address parentIpId, uint256 parentTokenId, uint256 licenseTermsId) = EXAMPLE
            .mintAndRegisterAndCreateTermsAndAttach(alice);

        (address childIpId, uint256 childTokenId, uint256 licenseTokenId) = EXAMPLE
            .mintLicenseTokenAndRegisterDerivative(parentIpId, licenseTermsId, bob);

        assertTrue(LICENSE_REGISTRY.hasDerivativeIps(parentIpId));
        assertTrue(LICENSE_REGISTRY.isParentIp(parentIpId, childIpId));
        assertTrue(LICENSE_REGISTRY.isDerivativeIp(childIpId));
        assertEq(LICENSE_REGISTRY.getDerivativeIpCount(parentIpId), 1);
        assertEq(LICENSE_REGISTRY.getParentIpCount(childIpId), 1);
        assertEq(LICENSE_REGISTRY.getParentIp({ childIpId: childIpId, index: 0 }), parentIpId);
        assertEq(LICENSE_REGISTRY.getDerivativeIp({ parentIpId: parentIpId, index: 0 }), childIpId);
    }
}
