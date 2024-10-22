// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { LicenseToken } from "@storyprotocol/core/LicenseToken.sol";
import { LicensingModule } from "@storyprotocol/core/modules/licensing/LicensingModule.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { LicenseRegistry } from "@storyprotocol/core/registries/LicenseRegistry.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILicenseTemplate } from "@storyprotocol/core/modules/licensing/PILicenseTemplate.sol";
import { RoyaltyModule } from "@storyprotocol/core/modules/royalty/RoyaltyModule.sol";
import { IRoyaltyWorkflows } from "@storyprotocol/periphery/interfaces/workflows/IRoyaltyWorkflows.sol";
import { RoyaltyWorkflows } from "@storyprotocol/periphery/workflows/RoyaltyWorkflows.sol";
import { LicenseAttachmentWorkflows } from "@storyprotocol/periphery/workflows/LicenseAttachmentWorkflows.sol";
import { IpRoyaltyVault } from "@storyprotocol/core/modules/royalty/policies/IpRoyaltyVault.sol";
import { IPALicenseToken } from "../src/IPALicenseToken.sol";
import { IPALicenseTerms } from "../src/IPALicenseTerms.sol";
import { IPARoyalty } from "../src/IPARoyalty.sol";
import { SimpleNFT } from "../src/SimpleNFT.sol";
import { SUSD } from "../src/SUSD.sol";

// Run this test: forge test --fork-url https://testnet.storyrpc.io/ --match-path test/IPARoyalty.t.sol
contract IPARoyaltyTest is Test {
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);

    // For addresses, see https://docs.storyprotocol.xyz/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    address internal ipAssetRegistryAddr = 0x14CAB45705Fe73EC6d126518E59Fe3C61a181E40;
    // Protocol Core - LicensingModule
    address internal licensingModuleAddr = 0xC8f165950411504eA130692B87A7148e469f7090;
    // Protocol Core - LicenseRegistry
    address internal licenseRegistryAddr = 0x4D71a082DE74B40904c1d89d9C3bfB7079d4c542;
    // Protocol Core - LicenseToken
    address internal licenseTokenAddr = 0xd8aEF404432a2b3363479A6157285926B6B3b743;
    // Protocol Core - PILicenseTemplate
    address internal pilTemplateAddr = 0xbB7ACFBE330C56aA9a3aEb84870743C3566992c3;
    // Protocol Periphery - RoyaltyWorkflows
    address internal royaltyWorkflowsAddr = 0xc757921ee0f7c8E935d44BFBDc2602786e0eda6C;
    // Protocol Periphery - LicenseAttachmentWorkflows
    address internal licenseAttachmentWorkflowsAddr = 0x1B95144b62B4566501482e928aa435Dd205fE71B;
    // Protocol Core - RoyaltyPolicyLAP
    address internal royaltyPolicyLAPAddr = 0x793Df8d32c12B0bE9985FFF6afB8893d347B6686;
    // Protocol Core - RoyaltyModule
    address internal royaltyModuleAddr = 0xaCb5764E609aa3a5ED36bA74ba59679246Cb0963;
    // Protocol Core - SUSD
    address internal susdAddr = 0x91f6F05B08c16769d3c85867548615d270C42fC7;

    IPAssetRegistry public ipAssetRegistry;
    LicensingModule public licensingModule;
    LicenseRegistry public licenseRegistry;
    LicenseToken public licenseToken;
    RoyaltyWorkflows public royaltyWorkflows;
    LicenseAttachmentWorkflows public licenseAttachmentWorkflows;
    RoyaltyModule public royaltyModule;
    PILicenseTemplate public pilTemplate;

    SimpleNFT public simpleNft;
    SUSD public susd;
    IPARoyalty public ipaRoyalty;
    IPALicenseToken public ipaLicenseToken;
    IPALicenseTerms public ipaLicenseTerms;

    function setUp() public {
        ipAssetRegistry = IPAssetRegistry(ipAssetRegistryAddr);
        licensingModule = LicensingModule(licensingModuleAddr);
        licenseRegistry = LicenseRegistry(licenseRegistryAddr);
        licenseToken = LicenseToken(licenseTokenAddr);
        royaltyWorkflows = RoyaltyWorkflows(royaltyWorkflowsAddr);
        licenseAttachmentWorkflows = LicenseAttachmentWorkflows(licenseAttachmentWorkflowsAddr);
        pilTemplate = PILicenseTemplate(pilTemplateAddr);
        royaltyModule = RoyaltyModule(royaltyModuleAddr);
        ipaRoyalty = new IPARoyalty(royaltyPolicyLAPAddr, royaltyWorkflowsAddr, susdAddr);
        ipaLicenseTerms = new IPALicenseTerms(
            ipAssetRegistryAddr,
            licensingModuleAddr,
            pilTemplateAddr,
            royaltyPolicyLAPAddr,
            susdAddr
        );
        ipaLicenseToken = new IPALicenseToken(licensingModuleAddr, pilTemplateAddr);
        simpleNft = SimpleNFT(ipaLicenseTerms.SIMPLE_NFT());

        susd = SUSD(susdAddr);

        vm.label(address(ipAssetRegistryAddr), "IPAssetRegistry");
        vm.label(address(licensingModuleAddr), "LicensingModule");
        vm.label(address(licenseRegistryAddr), "LicenseRegistry");
        vm.label(address(licenseTokenAddr), "LicenseToken");
        vm.label(address(pilTemplateAddr), "PILicenseTemplate");
        vm.label(address(royaltyWorkflowsAddr), "RoyaltyWorkflows");
        vm.label(address(royaltyModuleAddr), "RoyaltyModule");
        vm.label(address(susdAddr), "SUSD");
        vm.label(address(licenseAttachmentWorkflowsAddr), "LicenseAttachmentWorkflows");
        vm.label(address(simpleNft), "SimpleNFT");
        vm.label(address(0x000000006551c19487814612e58FE06813775758), "ERC6551Registry");
    }

    function test_royaltyIp() public {
        // ADMIN SETUP
        susd.mint(address(this), 100);
        susd.approve(address(royaltyModule), 10);

        vm.prank(alice);
        (address ancestorIpId, uint256 tokenId, uint256 licenseTermsId) = ipaLicenseTerms.attachLicenseTerms();

        uint256 startLicenseTokenId = ipaLicenseToken.mintLicenseToken({
            ipId: ancestorIpId,
            licenseTermsId: licenseTermsId,
            ltAmount: 2,
            ltRecipient: bob
        });

        // this contract mints to bob
        vm.prank(address(ipaLicenseTerms)); // need to prank to mint simpleNft
        uint256 childTokenId = simpleNft.mint(bob);
        address childIpId = ipAssetRegistry.register(block.chainid, address(simpleNft), childTokenId);

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;

        vm.prank(bob);
        licensingModule.registerDerivativeWithLicenseTokens({
            childIpId: childIpId,
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "" // empty for PIL
        });

        // now that it is derivative, we must give bob's ip Asset 10 susd for this example
        // need to use payRoyaltyOnBehalf
        //
        // you have to approve the royalty module to spend on your behalf
        royaltyModule.payRoyaltyOnBehalf(childIpId, address(0), address(susd), 10);

        // now that child has been paid, parent must claim
        (uint256 snapshotId, uint256[] memory amountsClaimed) = ipaRoyalty.claimRoyalty(ancestorIpId, childIpId, 1);

        assertEq(amountsClaimed[0], 1);
        assertEq(susd.balanceOf(ancestorIpId), 1);
        assertEq(susd.balanceOf(royaltyModule.ipRoyaltyVaults(childIpId)), 9);
    }
}
