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
    PILicenseTemplate public immutable PIL_TEMPLATE = PILicenseTemplate(0x58E2c909D557Cd23EF90D14f8fd21667A5Ae7a93);
    // Protocol Core - RoyaltyPolicyLAP
    RoyaltyPolicyLAP public immutable ROYALTY_POLICY_LAP = RoyaltyPolicyLAP(0x28b4F70ffE5ba7A26aEF979226f77Eb57fb9Fdb6);
    // Mock - SUSD
    SUSD public immutable SUSD_TOKEN = SUSD(0xC0F6E387aC0B324Ec18EAcf22EE7271207dCE3d5);

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
