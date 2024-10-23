// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";

import { LicensingModule } from "@storyprotocol/core/modules/licensing/LicensingModule.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { RoyaltyModule } from "@storyprotocol/core/modules/royalty/RoyaltyModule.sol";

import { IPALicenseToken } from "../src/IPALicenseToken.sol";
import { IPALicenseTerms } from "../src/IPALicenseTerms.sol";
import { IPARoyalty } from "../src/IPARoyalty.sol";
import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";
import { SUSD } from "../src/mocks/SUSD.sol";

// Run this test: forge test --fork-url https://testnet.storyrpc.io/ --match-path test/IPARoyalty.t.sol
contract IPARoyaltyTest is Test {
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);

    // For addresses, see https://docs.storyprotocol.xyz/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    address internal ipAssetRegistryAddr = 0x14CAB45705Fe73EC6d126518E59Fe3C61a181E40;
    // Protocol Core - LicensingModule
    address internal licensingModuleAddr = 0xC8f165950411504eA130692B87A7148e469f7090;
    // Protocol Core - PILicenseTemplate
    address internal pilTemplateAddr = 0xbB7ACFBE330C56aA9a3aEb84870743C3566992c3;
    // Protocol Periphery - RoyaltyWorkflows
    address internal royaltyWorkflowsAddr = 0xc757921ee0f7c8E935d44BFBDc2602786e0eda6C;
    // Protocol Core - RoyaltyPolicyLAP
    address internal royaltyPolicyLAPAddr = 0x793Df8d32c12B0bE9985FFF6afB8893d347B6686;
    // Protocol Core - RoyaltyModule
    address internal royaltyModuleAddr = 0xaCb5764E609aa3a5ED36bA74ba59679246Cb0963;
    // Protocol Core - SUSD
    address internal susdAddr = 0x91f6F05B08c16769d3c85867548615d270C42fC7;

    IPAssetRegistry public ipAssetRegistry;
    LicensingModule public licensingModule;
    RoyaltyModule public royaltyModule;

    SimpleNFT public simpleNft;
    SUSD public susd;
    IPARoyalty public ipaRoyalty;
    IPALicenseToken public ipaLicenseToken;
    IPALicenseTerms public ipaLicenseTerms;

    function setUp() public {
        ipAssetRegistry = IPAssetRegistry(ipAssetRegistryAddr);
        licensingModule = LicensingModule(licensingModuleAddr);
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
        vm.label(address(royaltyModuleAddr), "RoyaltyModule");
        vm.label(address(susdAddr), "SUSD");
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
        // you have to approve the royalty module to spend on your behalf,
        // which we did at the top of this function
        royaltyModule.payRoyaltyOnBehalf(childIpId, address(0), address(susd), 10);

        // now that child has been paid, parent must claim
        (uint256 snapshotId, uint256[] memory amountsClaimed) = ipaRoyalty.claimRoyalty(ancestorIpId, childIpId, 1);

        assertEq(amountsClaimed[0], 1);
        assertEq(susd.balanceOf(ancestorIpId), 1);
        assertEq(susd.balanceOf(royaltyModule.ipRoyaltyVaults(childIpId)), 9);
    }
}
