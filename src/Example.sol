// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { LicenseRegistry } from "@storyprotocol/core/registries/LicenseRegistry.sol";
import { LicensingModule } from "@storyprotocol/core/modules/licensing/LicensingModule.sol";
import { PILicenseTemplate } from "@storyprotocol/core/modules/licensing/PILicenseTemplate.sol";
import { RoyaltyPolicyLAP } from "@storyprotocol/core/modules/royalty/policies/LAP/RoyaltyPolicyLAP.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { MockERC20 } from "@storyprotocol/test/mocks/token/MockERC20.sol";

import { SimpleNFT } from "./mocks/SimpleNFT.sol";

import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

/// @notice Register an NFT as an IP Account.
contract Example is ERC721Holder {
    IPAssetRegistry public immutable IP_ASSET_REGISTRY;
    LicenseRegistry public immutable LICENSE_REGISTRY;
    LicensingModule public immutable LICENSING_MODULE;
    PILicenseTemplate public immutable PIL_TEMPLATE;
    RoyaltyPolicyLAP public immutable ROYALTY_POLICY_LAP;
    MockERC20 public immutable MERC20;
    SimpleNFT public immutable SIMPLE_NFT;

    constructor(
        address ipAssetRegistry,
        address licensingModule,
        address pilTemplate,
        address royaltyPolicyLAP,
        address merc20
    ) {
        IP_ASSET_REGISTRY = IPAssetRegistry(ipAssetRegistry);
        LICENSING_MODULE = LicensingModule(licensingModule);
        PIL_TEMPLATE = PILicenseTemplate(pilTemplate);
        ROYALTY_POLICY_LAP = RoyaltyPolicyLAP(royaltyPolicyLAP);
        MERC20 = MockERC20(merc20);
        // Create a new Simple NFT collection
        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");
    }

    /// @notice Mint an NFT, register it as an IP Asset, and attach License Terms to it.
    /// @param receiver The address that will receive the NFT/IPA.
    /// @return tokenId The token ID of the NFT representing ownership of the IPA.
    /// @return ipId The address of the IP Account.
    /// @return licenseTermsId The ID of the license terms.
    function mintAndRegisterAndCreateTermsAndAttach(
        address receiver
    ) external returns (uint256 tokenId, address ipId, uint256 licenseTermsId) {
        // We mint to this contract so that it has permissions
        // to attach license terms to the IP Asset.
        // We will later transfer it to the intended `receiver`
        tokenId = SIMPLE_NFT.mint(address(this));
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        // register license terms so we can attach them later
        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10 * 10 ** 6, // 10%
                royaltyPolicy: address(ROYALTY_POLICY_LAP),
                currencyToken: address(MERC20)
            })
        );

        // attach the license terms to the IP Asset
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);

        // transfer the NFT to the receiver so it owns the IPA
        SIMPLE_NFT.transferFrom(address(this), receiver, tokenId);
    }

    /// @notice Mint and register a new child IPA, mint a License Token
    /// from the parent, and register it as a derivative of the parent.
    /// @param parentIpId The ipId of the parent IPA.
    /// @param licenseTermsId The ID of the license terms you will
    /// mint a license token from.
    /// @param receiver The address that will receive the NFT/IPA.
    /// @return childTokenId The token ID of the NFT representing ownership of the child IPA.
    /// @return childIpId The address of the child IPA.
    function mintLicenseTokenAndRegisterDerivative(
        address parentIpId,
        uint256 licenseTermsId,
        address receiver
    ) external returns (uint256 childTokenId, address childIpId) {
        // We mint to this contract so that it has permissions
        // to register itself as a derivative of another
        // IP Asset.
        // We will later transfer it to the intended `receiver`
        childTokenId = SIMPLE_NFT.mint(address(this));
        childIpId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), childTokenId);

        // mint a license token from the parent
        uint256 licenseTokenId = LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: parentIpId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: licenseTermsId,
            amount: 1,
            // mint the license token to this contract so it can
            // use it to register as a derivative of the parent
            receiver: address(this),
            royaltyContext: "", // for PIL, royaltyContext is empty string
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = licenseTokenId;

        // register the new child IPA as a derivative
        // of the parent
        LICENSING_MODULE.registerDerivativeWithLicenseTokens({
            childIpId: childIpId,
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "", // empty for PIL
            maxRts: 0
        });

        // transfer the NFT to the receiver so it owns the child IPA
        SIMPLE_NFT.transferFrom(address(this), receiver, childTokenId);
    }
}
