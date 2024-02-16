// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IP } from "@storyprotocol/contracts/lib/IP.sol";
import { IPAssetRegistry } from "@storyprotocol/contracts/registries/IPAssetRegistry.sol";
import { IPResolver } from "@storyprotocol/contracts/resolvers/IPResolver.sol";

import { IERC721Mintable } from "./interfaces/IERC721Mintable.sol";

contract IPARegistrar {


    IERC721Mintable public immutable NFT;
    address public immutable IP_RESOLVER;
    IPAssetRegistry public immutable IPA_REGISTRY;

    constructor(
        address ipAssetRegistry,
        address resolver,
        address nft
    ) {
        IPA_REGISTRY = IPAssetRegistry(ipAssetRegistry);
        IP_RESOLVER = resolver;
        NFT = IERC721Mintable(nft);
    }

    function register(
        string memory ipName
    ) external returns (address) {
        uint256 tokenId = NFT.mint();
        bytes memory metadata = abi.encode(
            IP.MetadataV1({
                name: ipName,
                hash: "",
                registrationDate: uint64(block.timestamp),
                registrant: msg.sender,
                uri: ""
            })
        );
        return IPA_REGISTRY.register(block.chainid, address(NFT), tokenId, IP_RESOLVER, true, metadata);
    }
}
