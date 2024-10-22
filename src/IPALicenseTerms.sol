// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { LicensingModule } from "@storyprotocol/core/modules/licensing/LicensingModule.sol";
import { PILicenseTemplate } from "@storyprotocol/core/modules/licensing/PILicenseTemplate.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { RoyaltyPolicyLAP } from "@storyprotocol/core/modules/royalty/policies/LAP/RoyaltyPolicyLAP.sol";
import { SUSD } from "./mocks/SUSD.sol";

import { SimpleNFT } from "./mocks/SimpleNFT.sol";

/// @notice Attach a Selected Programmable IP License Terms to an IP Account.
contract IPALicenseTerms {
    IPAssetRegistry public immutable IP_ASSET_REGISTRY;
    LicensingModule public immutable LICENSING_MODULE;
    PILicenseTemplate public immutable PIL_TEMPLATE;
    RoyaltyPolicyLAP public immutable ROYALTY_POLICY_LAP;
    SUSD public immutable SUSD_TOKEN;
    SimpleNFT public immutable SIMPLE_NFT;

    constructor(
        address ipAssetRegistry,
        address licensingModule,
        address pilTemplate,
        address royaltyPolicyLAP,
        address susd
    ) {
        IP_ASSET_REGISTRY = IPAssetRegistry(ipAssetRegistry);
        LICENSING_MODULE = LicensingModule(licensingModule);
        PIL_TEMPLATE = PILicenseTemplate(pilTemplate);
        ROYALTY_POLICY_LAP = RoyaltyPolicyLAP(royaltyPolicyLAP);
        SUSD_TOKEN = SUSD(susd);
        // Create a new Simple NFT collection
        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");
    }

    function attachLicenseTerms() external returns (address ipId, uint256 tokenId, uint256 licenseTermsId) {
        // First, mint an NFT and register it as an IP Account.
        // Note that first we mint the NFT to this contract for ease of attaching license terms.
        // We will transfer the NFT to the msg.sender at last.
        tokenId = SIMPLE_NFT.mint(address(this));
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 10 * 10 ** 6, // 10%
                royaltyPolicy: address(ROYALTY_POLICY_LAP),
                currencyToken: address(SUSD_TOKEN)
            })
        );

        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);

        // Finally, transfer the NFT to the msg.sender.
        SIMPLE_NFT.transferFrom(address(this), msg.sender, tokenId);
    }
}
