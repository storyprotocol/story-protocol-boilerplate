// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IP } from "@storyprotocol/core/lib/IP.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { IPResolver } from "@storyprotocol/core/resolvers/IPResolver.sol";
import { ILicenseMarketPlace } from "./ILicenseMarketPlace.sol";

contract LicenseMarketPlace {
    address public immutable NFT;
    address public immutable IP_RESOLVER;
    IPAssetRegistry public immutable IPA_REGISTRY;
      StoryProtocolGateway public SPG;


    constructor(
        address ipAssetRegistry,
        address resolver,
        address nft
    ) {
        IPA_REGISTRY = IPAssetRegistry(ipAssetRegistry);
        IP_RESOLVER = resolver;
        NFT = nft;
    }

    function registerIpAsset(
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
        return IPA_REGISTRY.register(block.chainid, NFT, tokenId, IP_RESOLVER, true, metadata);
    }

    function buyKey(
        address buyer,
        uint256 storyProtocolIpId,
        uint256 amount
    ) external view returns (address) {
        return buyer;
    }

    function sellKey(
        address seller,
        uint256 storyProtocolIpId,
        uint256 amount
    ) external view returns (address) {
        return seller;
    }

    function claimRoyalties(
        address owner,
        uint256 storyProtocolIpId,
        uint256 tokenAmount
    ) external view returns (address) {
        return address(owner);
    }

    function distributeRoyalties(
        address owner,
        uint256 storyProtocolIpId,
        uint256 tokenAmount
    ) external view returns (address) {
        return address(owner);
    }
}

