// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test, console } from "forge-std/Test.sol";
// for testing purposes only
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { ILicenseToken } from "@storyprotocol/core/interfaces/ILicenseToken.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IRoyaltyModule } from "@storyprotocol/core/interfaces/modules/royalty/IRoyaltyModule.sol";

import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";
import { DebridgeLicenseTokenMinter } from "../src/DebridgeMintLicenseToken.sol";

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/8_MintLicenseTokenMulticall.t.sol
contract DebridgeLicenseTokenTest is Test {
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
    // Protocol Core - LicenseToken
    ILicenseToken internal LICENSE_TOKEN = ILicenseToken(0xFe3838BFb30B34170F00030B52eA4893d8aAC6bC);

    // WIP Token
    address internal constant WIP = 0x1514000000000000000000000000000000000000;

    SimpleNFT public SIMPLE_NFT;
    DebridgeLicenseTokenMinter public DEBRIDGE_MINTER;
    address public ipId;
    uint256 public licenseTermsId;

    function setUp() public {
        // this is only for testing purposes
        // due to our IPGraph precompile not being
        // deployed on the fork
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        // Deploy contracts
        DEBRIDGE_MINTER = new DebridgeLicenseTokenMinter();
        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");

        // Create parent IP (Alice)
        uint256 tokenId = SIMPLE_NFT.mint(alice);
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        // Register license terms with minting fee
        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialUse({ mintingFee: 1 ether, royaltyPolicy: ROYALTY_POLICY_LAP, currencyToken: WIP })
        );

        // Attach license terms to parent IP
        vm.prank(alice);
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);
    }

    /// @notice Test cross-chain license token minting via multicall
    function test_mintLicenseTokensCrossChain() public {
        uint256 ethAmount = 1 ether;

        // Fund the test contract with ETH to simulate cross-chain payment
        vm.deal(address(this), ethAmount);

        console.log("Initial ETH balance:", address(this).balance);
        console.log("Initial Bob's license token balance:", LICENSE_TOKEN.balanceOf(bob));

        // Simulate cross-chain license token minting
        DEBRIDGE_MINTER.mintLicenseTokensCrossChain{ value: ethAmount }(ipId, licenseTermsId, 1, bob);

        console.log("Final Bob's license token balance:", LICENSE_TOKEN.balanceOf(bob));
        console.log("Alice's IP WIP balance:", IERC20(WIP).balanceOf(ipId));

        // Verify license tokens were minted to Bob
        assertEq(LICENSE_TOKEN.balanceOf(bob), 1, "Bob should have received license tokens");
        // Verify royalty was paid to vault
        uint256 vaultBalance = IERC20(WIP).balanceOf(ROYALTY_MODULE.ipRoyaltyVaults(ipId));
        console.log("Final IP royalty vault balance:", vaultBalance);
        assertGt(vaultBalance, 0, "Royalty vault should have received WIP tokens");
    }

    receive() external payable {}
}
