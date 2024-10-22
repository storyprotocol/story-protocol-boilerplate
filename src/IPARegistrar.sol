// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { RegistrationWorkflows } from "@storyprotocol/periphery/workflows/RegistrationWorkflows.sol";
import { WorkflowStructs } from "@storyprotocol/periphery/lib/WorkflowStructs.sol";
import { ISPGNFT } from "@storyprotocol/periphery/interfaces/ISPGNFT.sol";

import { SimpleNFT } from "./mocks/SimpleNFT.sol";

/// @notice Register an NFT as an IP Account.
contract IPARegistrar {
    IPAssetRegistry public immutable IP_ASSET_REGISTRY;
    RegistrationWorkflows public immutable REGISTRATION_WORKFLOWS;
    SimpleNFT public immutable SIMPLE_NFT;
    ISPGNFT public immutable SPG_NFT;

    constructor(address ipAssetRegistry, address registrationWorkflows) {
        IP_ASSET_REGISTRY = IPAssetRegistry(ipAssetRegistry);
        REGISTRATION_WORKFLOWS = RegistrationWorkflows(registrationWorkflows);
        // Create a new Simple NFT collection
        SIMPLE_NFT = new SimpleNFT("Simple IP NFT", "SIM");
        // Create a new NFT collection via SPG
        SPG_NFT = ISPGNFT(
            REGISTRATION_WORKFLOWS.createCollection(
                ISPGNFT.InitParams({
                    name: "Test Collection",
                    symbol: "TEST",
                    baseURI: "",
                    contractURI: "",
                    maxSupply: 100,
                    mintFee: 0,
                    mintFeeToken: address(0),
                    mintFeeRecipient: address(this),
                    owner: address(this),
                    mintOpen: true,
                    isPublicMinting: false
                })
            )
        );
    }

    /// @notice Mint an IP NFT and register it as an IP Account via Story Protocol core.
    /// @return ipId The address of the IP Account.
    /// @return tokenId The token ID of the IP NFT.
    function mintIp() external returns (address ipId, uint256 tokenId) {
        tokenId = SIMPLE_NFT.mint(msg.sender);
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(SIMPLE_NFT), tokenId);
    }

    /// @notice Mint an IP NFT and register it as an IP Account via Story Protocol Gateway (periphery).
    /// @dev Requires the collection to be created via SPG (createCollection).
    function spgMintIp() external returns (address ipId, uint256 tokenId) {
        (ipId, tokenId) = REGISTRATION_WORKFLOWS.mintAndRegisterIp(
            address(SPG_NFT),
            msg.sender,
            WorkflowStructs.IPMetadata({
                ipMetadataURI: "https://ipfs.io/ipfs/QmZHfQdFA2cb3ASdmeGS5K6rZjz65osUddYMURDx21bT73",
                ipMetadataHash: keccak256(
                    abi.encodePacked(
                        "{'title':'My IP Asset','description':'This is a test IP asset','ipType':'','relationships':[],'createdAt':'','watermarkImg':'https://picsum.photos/200','creators':[],'media':[],'attributes':[{'key':'Rarity','value':'Legendary'}],'tags':[]}"
                    )
                ),
                nftMetadataURI: "https://ipfs.io/ipfs/QmRL5PcK66J1mbtTZSw1nwVqrGxt98onStx6LgeHTDbEey",
                nftMetadataHash: keccak256(
                    abi.encodePacked(
                        "{'name':'Test NFT','description':'This is a test NFT','image':'https://picsum.photos/200'}"
                    )
                )
            })
        );
    }
}
