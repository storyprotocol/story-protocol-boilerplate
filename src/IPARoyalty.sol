// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { RoyaltyPolicyLAP } from "@storyprotocol/core/modules/royalty/policies/LAP/RoyaltyPolicyLAP.sol";
import { IRoyaltyWorkflows } from "@storyprotocol/periphery/interfaces/workflows/IRoyaltyWorkflows.sol";
import { SUSD } from "./mocks/SUSD.sol";

/// @notice Mint a License Token from Programmable IP License Terms attached to an IP Account.
contract IPARoyalty {
    RoyaltyPolicyLAP public immutable ROYALTY_POLICY_LAP;
    IRoyaltyWorkflows public immutable ROYALTY_WORKFLOWS;
    SUSD public immutable SUSD_TOKEN;

    constructor(address royaltyPolicyLAP, address royaltyWorkflows, address susd) {
        ROYALTY_POLICY_LAP = RoyaltyPolicyLAP(royaltyPolicyLAP);
        ROYALTY_WORKFLOWS = IRoyaltyWorkflows(royaltyWorkflows);
        SUSD_TOKEN = SUSD(susd);
    }

    function claimRoyalty(
        address ancestorIpId,
        address childIpId,
        uint256 amount
    ) external returns (uint256 snapshotId, uint256[] memory amountsClaimed) {
        // now that child has been paid, parent must claim
        IRoyaltyWorkflows.RoyaltyClaimDetails[] memory claimDetails = new IRoyaltyWorkflows.RoyaltyClaimDetails[](1);
        claimDetails[0] = IRoyaltyWorkflows.RoyaltyClaimDetails({
            childIpId: childIpId,
            royaltyPolicy: address(ROYALTY_POLICY_LAP),
            currencyToken: address(SUSD_TOKEN),
            amount: amount
        });
        (uint256 snapshotId, uint256[] memory amountsClaimed) = ROYALTY_WORKFLOWS
            .transferToVaultAndSnapshotAndClaimByTokenBatch({
                ancestorIpId: ancestorIpId,
                claimer: ancestorIpId,
                royaltyClaimDetails: claimDetails
            });

        return (snapshotId, amountsClaimed);
    }
}
