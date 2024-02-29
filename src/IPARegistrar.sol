// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IP } from "@story-protocol/protocol-core/contracts/lib/IP.sol";
import { IPAssetRegistry } from "@story-protocol/protocol-core/contracts/registries/IPAssetRegistry.sol";
import { IPResolver } from "@story-protocol/protocol-core/contracts/resolvers/IPResolver.sol";

contract IPARegistrar {
    address public immutable NFT;
    address public immutable IP_RESOLVER;
    IPAssetRegistry public immutable IPA_REGISTRY;

    constructor(
        address ipAssetRegistry,
        address resolver,
        address nft
    ) {
        IPA_REGISTRY = IPAssetRegistry(ipAssetRegistry);
        IP_RESOLVER = resolver;
        NFT = nft;
    }

    function register(
        string memory ipName,
        uint256 tokenId 
    ) external returns (address) {
        bytes memory metadata = abi.encode(
            IP.MetadataV1({
                name: ipName,
                hash: "",
                registrationDate: uint64(block.timestamp),
                registrant: msg.sender,
                uri: ""
            })
        );
        return IPA_REGISTRY.register(
            block.chainid,
            NFT,
            tokenId,
            IP_RESOLVER,
            true,
            metadata
        );
    }
}
