// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { LicensingModule } from "@storyprotocol/core/modules/licensing/LicensingModule.sol";
import { PILicenseTemplate } from "@storyprotocol/core/modules/licensing/PILicenseTemplate.sol";

/// @notice Mint a License Token from Programmable IP License Terms attached to an IP Account.
contract IPALicenseToken {
    LicensingModule public immutable LICENSING_MODULE;
    PILicenseTemplate public immutable PIL_TEMPLATE;

    constructor(address licensingModule, address pilTemplate) {
        LICENSING_MODULE = LicensingModule(licensingModule);
        PIL_TEMPLATE = PILicenseTemplate(pilTemplate);
    }

    function mintLicenseToken(
        address ipId,
        uint256 licenseTermsId,
        uint256 ltAmount,
        address ltRecipient
    ) external returns (uint256 startLicenseTokenId) {
        // Then, mint a License Token from the attached license terms.
        // Note that the License Token is minted to the ltRecipient.
        startLicenseTokenId = LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: licenseTermsId,
            amount: ltAmount,
            receiver: ltRecipient,
            royaltyContext: "" // for PIL, royaltyContext is empty string
        });
    }
}
