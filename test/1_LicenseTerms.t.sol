// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test } from "forge-std/Test.sol";
import { PILicenseTemplate } from "@storyprotocol/core/modules/licensing/PILicenseTemplate.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { RoyaltyPolicyLAP } from "@storyprotocol/core/modules/royalty/policies/LAP/RoyaltyPolicyLAP.sol";
import { SUSD } from "../src/mocks/SUSD.sol";

// Run this test:
// forge test --fork-url https://testnet.storyrpc.io/ --match-path test/1_LicenseTerms.t.sol
contract LicenseTermsTest is Test {
    address internal alice = address(0xa11ce);

    // For addresses, see https://docs.story.foundation/docs/deployed-smart-contracts
    // Protocol Core - PILicenseTemplate
    PILicenseTemplate public immutable PIL_TEMPLATE = PILicenseTemplate(0xbB7ACFBE330C56aA9a3aEb84870743C3566992c3);
    // Protocol Core - RoyaltyPolicyLAP
    RoyaltyPolicyLAP public immutable ROYALTY_POLICY_LAP = RoyaltyPolicyLAP(0x793Df8d32c12B0bE9985FFF6afB8893d347B6686);
    // Mock - SUSD
    SUSD public immutable SUSD_TOKEN = SUSD(0x91f6F05B08c16769d3c85867548615d270C42fC7);

    function setUp() public {}

    /// @notice Registers new PIL Terms. Anyone can register PIL Terms.
    function test_registerPILTerms() public {
        PILTerms memory pilTerms = PILTerms({
            transferable: true,
            royaltyPolicy: address(ROYALTY_POLICY_LAP),
            defaultMintingFee: 0,
            expiration: 0,
            commercialUse: true,
            commercialAttribution: true,
            commercializerChecker: address(0),
            commercializerCheckerData: "",
            commercialRevShare: 0,
            commercialRevCeiling: 0,
            derivativesAllowed: true,
            derivativesAttribution: true,
            derivativesApproval: true,
            derivativesReciprocal: true,
            derivativeRevCeiling: 0,
            currency: address(SUSD_TOKEN),
            uri: ""
        });
        uint256 licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(pilTerms);

        uint256 selectedLicenseTermsId = PIL_TEMPLATE.getLicenseTermsId(pilTerms);
        assertEq(licenseTermsId, selectedLicenseTermsId);
    }
}
