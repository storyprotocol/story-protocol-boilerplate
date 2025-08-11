// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test, console } from "forge-std/Test.sol";
// for testing purposes only
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { IRoyaltyWorkflows } from "@storyprotocol/periphery/interfaces/workflows/IRoyaltyWorkflows.sol";
import { IRoyaltyModule } from "@storyprotocol/core/interfaces/modules/royalty/IRoyaltyModule.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";
import { DebridgeRoyaltyRelayer } from "../src/DebridgeRoyaltyRelayer.sol";

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/7_PayRoyaltyMulticall.t.sol
contract DebridgeRoyaltyTest is Test {
    address internal alice = address(0xa11ce);
    address internal bob = address(0xb0b);

    // For addresses, see https://docs.story.foundation/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    IIPAssetRegistry internal IP_ASSET_REGISTRY = IIPAssetRegistry(0x77319B4031e6eF1250907aa00018B8B1c67a244b);
    // Protocol Core - LicensingModule
    ILicensingModule internal LICENSING_MODULE = ILicensingModule(0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f);
    // Protocol Core - PILicenseTemplate
    IPILicenseTemplate internal PIL_TEMPLATE = IPILicenseTemplate(0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316);
    // Protocol Core - RoyaltyPolicyLAP
    address internal ROYALTY_POLICY_LAP = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
    // Protocol Core - RoyaltyModule
    IRoyaltyModule internal ROYALTY_MODULE = IRoyaltyModule(0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086);
    // Protocol Periphery - RoyaltyWorkflows
    IRoyaltyWorkflows internal ROYALTY_WORKFLOWS = IRoyaltyWorkflows(0x9515faE61E0c0447C6AC6dEe5628A2097aFE1890);

    // WIP Token
    address internal constant WIP = 0x1514000000000000000000000000000000000000;

    SimpleNFT public SIMPLE_NFT;
    DebridgeRoyaltyRelayer public DEBRIDGE_RELAYER;
    address public ipId;
    address public childIpId;

    function setUp() public {
        // this is only for testing purposes
        // due to our IPGraph precompile not being
        // deployed on the fork
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        // Deploy contracts
        DEBRIDGE_RELAYER = new DebridgeRoyaltyRelayer();
        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");

        // Create parent IP (Alice)
        uint256 tokenId = SIMPLE_NFT.mint(alice);
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        // Register license terms with 20% royalty share
        uint256 licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 20 * 10 ** 6, // 20%
                royaltyPolicy: ROYALTY_POLICY_LAP,
                currencyToken: WIP
            })
        );

        // Attach license terms to parent IP
        vm.prank(alice);
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);

        // Mint license tokens
        uint256 startLicenseTokenId = LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: licenseTermsId,
            amount: 1,
            receiver: bob,
            royaltyContext: "",
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        // Create child IP (Bob) as derivative
        uint256 childTokenId = SIMPLE_NFT.mint(bob);
        childIpId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), childTokenId);

        uint256[] memory licenseTokenIds = new uint256[](1);
        licenseTokenIds[0] = startLicenseTokenId;

        vm.prank(bob);
        LICENSING_MODULE.registerDerivativeWithLicenseTokens({
            childIpId: childIpId,
            licenseTokenIds: licenseTokenIds,
            royaltyContext: "",
            maxRts: 0
        });
    }

    /// @notice Test cross-chain royalty payment via multicall
    function test_settleRoyaltiesCrossChain() public {
        uint256 royaltyAmount = 1 ether;
        bytes32 uniqueSalt = keccak256("test-salt");

        // Fund the test contract with ETH to simulate cross-chain payment
        vm.deal(address(this), royaltyAmount);

        console.log("Initial ETH balance:", address(this).balance);
        console.log(
            "Initial child IP royalty vault balance:",
            IERC20(WIP).balanceOf(ROYALTY_MODULE.ipRoyaltyVaults(childIpId))
        );

        // Simulate cross-chain payment
        DEBRIDGE_RELAYER.settleRoyalties{ value: royaltyAmount }(uniqueSalt, childIpId, address(0));

        // Verify royalty was paid to vault
        uint256 vaultBalance = IERC20(WIP).balanceOf(ROYALTY_MODULE.ipRoyaltyVaults(childIpId));
        console.log("Final child IP royalty vault balance:", vaultBalance);
        assertGt(vaultBalance, 0, "Royalty vault should have received WIP tokens");

        // Alice claims her 20% share
        address[] memory childIpIds = new address[](1);
        address[] memory royaltyPolicies = new address[](1);
        address[] memory currencyTokens = new address[](1);
        childIpIds[0] = childIpId;
        royaltyPolicies[0] = ROYALTY_POLICY_LAP;
        currencyTokens[0] = WIP;

        uint256[] memory amountsClaimed = ROYALTY_WORKFLOWS.claimAllRevenue({
            ancestorIpId: ipId,
            claimer: ipId,
            childIpIds: childIpIds,
            royaltyPolicies: royaltyPolicies,
            currencyTokens: currencyTokens
        });

        console.log("Amount claimed by Alice:", amountsClaimed[0]);
        console.log("Alice's final WIP balance:", IERC20(WIP).balanceOf(ipId));

        // Verify Alice received her share
        assertGt(amountsClaimed[0], 0, "Alice should have claimed some royalty");
        assertGt(IERC20(WIP).balanceOf(ipId), 0, "Alice's IP should have WIP tokens");
    }
}
