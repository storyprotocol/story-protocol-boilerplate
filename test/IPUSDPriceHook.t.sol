// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import { Test, console } from "forge-std/Test.sol";
// for testing purposes only
import { MockIPGraph } from "@storyprotocol/test/mocks/MockIPGraph.sol";
import { IIPAssetRegistry } from "@storyprotocol/core/interfaces/registries/IIPAssetRegistry.sol";
import { IPILicenseTemplate } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { ILicensingModule } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingModule.sol";
import { ILicenseToken } from "@storyprotocol/core/interfaces/ILicenseToken.sol";
import { RoyaltyPolicyLAP } from "@storyprotocol/core/modules/royalty/policies/LAP/RoyaltyPolicyLAP.sol";
import { PILFlavors } from "@storyprotocol/core/lib/PILFlavors.sol";
import { PILTerms } from "@storyprotocol/core/interfaces/modules/licensing/IPILicenseTemplate.sol";
import { Licensing } from "@storyprotocol/core/lib/Licensing.sol";
import { ModuleRegistry } from "@storyprotocol/core/registries/ModuleRegistry.sol";
import { MockERC20 } from "@storyprotocol/test/mocks/token/MockERC20.sol";
import { AccessController } from "@storyprotocol/core/access/AccessController.sol";
import { MockPyth } from "@pythnetwork/pyth-sdk-solidity/MockPyth.sol";

import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";
import { IPUSDPriceHook } from "../src/IPUSDPriceHook.sol";

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/IPUSDPriceHook.t.sol
contract IPUSDPriceHookTest is Test {
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
    // Protocol Core - LicenseToken
    ILicenseToken internal LICENSE_TOKEN = ILicenseToken(0xFe3838BFb30B34170F00030B52eA4893d8aAC6bC);
    // Protocol Core - AccessController
    address internal ACCESS_CONTROLLER = 0xcCF37d0a503Ee1D4C11208672e622ed3DFB2275a;
    // Protocol Core - ModuleRegistry
    ModuleRegistry internal MODULE_REGISTRY = ModuleRegistry(0x022DBAAeA5D8fB31a0Ad793335e39Ced5D631fa5);
    // Protocol Core - RoyaltyModule
    address internal ROYALTY_MODULE = 0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086;
    // Revenue Token - MERC20
    MockERC20 internal MERC20 = MockERC20(0xF2104833d386a2734a4eB3B8ad6FC6812F29E38E);
    // Pyth - Price Feed ID
    bytes32 internal PRICE_FEED_ID = 0xb620ba83044577029da7e4ded7a2abccf8e6afc2a0d4d26d89ccdd39ec109025;

    uint256 IP_TO_WEI = 1e18;

    IPUSDPriceHook public IPUSD_PRICE_HOOK;
    SimpleNFT public SIMPLE_NFT;
    MockPyth public pyth;
    uint256 public tokenId;
    address public ipId;
    uint256 public licenseTermsId;

    function setUp() public {
        // this is only for testing purposes
        // due to our IPGraph precompile not being
        // deployed on the fork
        vm.etch(address(0x0101), address(new MockIPGraph()).code);

        pyth = new MockPyth(60, 1);
        IPUSD_PRICE_HOOK = new IPUSDPriceHook(
            ACCESS_CONTROLLER,
            address(IP_ASSET_REGISTRY),
            address(pyth),
            PRICE_FEED_ID
        );

        // Make the registry *think* the hook is registered everywhere in this test
        vm.mockCall(
            address(MODULE_REGISTRY),
            abi.encodeWithSelector(ModuleRegistry.isRegistered.selector, address(IPUSD_PRICE_HOOK)),
            abi.encode(true)
        );

        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");
        tokenId = SIMPLE_NFT.mint(alice);
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);

        licenseTermsId = PIL_TEMPLATE.registerLicenseTerms(
            PILFlavors.commercialRemix({
                mintingFee: 0,
                commercialRevShare: 0,
                royaltyPolicy: ROYALTY_POLICY_LAP,
                currencyToken: address(MERC20)
            })
        );

        Licensing.LicensingConfig memory licensingConfig = Licensing.LicensingConfig({
            isSet: true,
            mintingFee: 0,
            licensingHook: address(IPUSD_PRICE_HOOK),
            hookData: "",
            commercialRevShare: 0,
            disabled: false,
            expectMinimumGroupRewardShare: 0,
            expectGroupRewardPool: address(0)
        });

        vm.startPrank(alice);
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), licenseTermsId);
        LICENSING_MODULE.setLicensingConfig(ipId, address(PIL_TEMPLATE), licenseTermsId, licensingConfig);
        // sets the price to 1 USD
        IPUSD_PRICE_HOOK.setLicensePrice(ipId, address(PIL_TEMPLATE), licenseTermsId, IP_TO_WEI);
        vm.stopPrank();

        /// Royalty Module Setup
        // We deposit 0.01 $MERC20 to the contract.
        MERC20.mint(address(this), IP_TO_WEI / 100);
        // We approve the Royalty Module to spend MERC20 on our behalf, which
        // it will do using `payRoyaltyOnBehalf`.
        MERC20.approve(address(ROYALTY_MODULE), IP_TO_WEI / 100);
    }

    /// @notice Creates mock IP update data for testing.
    /// @param ipPrice The IP price in USD.
    /// @return updateData The mock IP update data.
    function createIpUpdate(int64 ipPrice) private view returns (bytes[] memory) {
        bytes[] memory updateData = new bytes[](1);
        updateData[0] = pyth.createPriceFeedUpdateData(
            PRICE_FEED_ID,
            ipPrice * 100000, // price
            10 * 100000, // confidence
            -5, // exponent
            ipPrice * 100000, // emaPrice
            10 * 100000, // emaConfidence
            uint64(block.timestamp), // publishTime
            uint64(block.timestamp) // prevPublishTime
        );

        return updateData;
    }

    /// @notice Sets the IP price.
    /// @param ipPrice The IP price in USD.
    function setIpPrice(int64 ipPrice) private {
        bytes[] memory updateData = createIpUpdate(ipPrice);
        uint256 value = pyth.getUpdateFee(updateData);
        vm.deal(address(this), value);
        pyth.updatePriceFeeds{ value: value }(updateData);
    }

    /// @notice Mints license tokens for an IP Asset.
    /// We set the IP price to $100 USD. The license token
    /// costs 1 $USD.
    function test_mintLicenseToken() public {
        /// Pyth Oracle Price Setup
        setIpPrice(100); // sets IP to $100 USD

        /// Mint License Token
        uint256 startLicenseTokenId = LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: licenseTermsId,
            amount: 1,
            receiver: bob,
            royaltyContext: "", // for PIL, royaltyContext is empty string
            maxMintingFee: 0,
            maxRevenueShare: 0
        });

        assertEq(LICENSE_TOKEN.ownerOf(startLicenseTokenId), bob);
    }

    /// @notice Mints license tokens for an IP Asset.
    /// Anyone can mint a license token.
    function test_mintLicenseTokenRevert() public {
        /// Pyth Oracle Price Setup
        setIpPrice(99); // sets IP to $99 USD

        /// Mint License Token
        vm.expectRevert();
        uint256 startLicenseTokenId = LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: licenseTermsId,
            amount: 1,
            receiver: bob,
            royaltyContext: "", // for PIL, royaltyContext is empty string
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
    }

    function test_mintLicenseTokenStalePrice() public {
        setIpPrice(100);

        skip(120); // skip forward 120 seconds, which is past the 60 second stale price threshold

        vm.expectRevert();
        uint256 startLicenseTokenId = LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: licenseTermsId,
            amount: 1,
            receiver: bob,
            royaltyContext: "", // for PIL, royaltyContext is empty string
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
    }

    /// @notice Mints license tokens for an IP Asset.
    /// Anyone can mint a license token.
    function test_updateAndMintLicenseToken() public {
        bytes[] memory updateData = createIpUpdate(100);

        vm.deal(address(this), IP_TO_WEI);
        IPUSD_PRICE_HOOK.updateIpPrice{ value: IP_TO_WEI / 100 }(updateData);

        /// Mint License Token
        uint256 startLicenseTokenId = LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: licenseTermsId,
            amount: 1,
            receiver: bob,
            royaltyContext: "", // for PIL, royaltyContext is empty string
            maxMintingFee: 0,
            maxRevenueShare: 0
        });
    }
}
