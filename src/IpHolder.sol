// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IPAssetRegistry} from "@story-protocol/protocol-core/contracts/registries/IPAssetRegistry.sol";
import { IStoryProtocolGateway } from "@story-protocol/protocol-periphery/contracts/interfaces/IStoryProtocolGateway.sol";
import { SPG } from "@story-protocol/protocol-periphery/contracts/lib/SPG.sol";
import { Metadata } from "@story-protocol/protocol-periphery/contracts/lib/Metadata.sol";


interface IERC1271 {
    function isValidSignature(bytes32 _hash, bytes memory _signature) external view returns (bytes4);
}

contract IPHolder is IERC165, IERC1271, IERC721Receiver, IERC1155Receiver {
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;
    IStoryProtocolGateway public spg;
    IPAssetRegistry public ipAssetRegistry;

    event HashSigned(bytes32 indexed hash);

    constructor(address ipAssetRegistry_, address spg_) {
        spg = IStoryProtocolGateway(spg_);
        ipAssetRegistry = IPAssetRegistry(ipAssetRegistry_);
    }

    function register(uint256 policyId, address tokenContract, uint256 tokenId) public returns (address ipId) {
        Metadata.Attribute[] memory attributes = new Metadata.Attribute[](1);
        attributes[0] = Metadata.Attribute({ key: "copyrightType", value: "literaryWork" });
        Metadata.IPMetadata memory ipMetadata = Metadata.IPMetadata({
            name: "name for your IP asset",
            hash: bytes32("your IP asset content hash"),
            url: "https://yourip.xyz/metadata-regarding-its-ip",
            customMetadata: attributes
        });
        SPG.Signature memory signature = SPG.Signature({
            signer: address(this),
            deadline: block.timestamp + 1000,
            signature: ""
        });
        ipId = spg.registerIpWithSig(policyId, tokenContract, tokenId, ipMetadata, signature);
    }

    function mintAndRegisterIp(
        uint256 policyId,
        address tokenContract,
        bytes calldata tokenMetadata,
        Metadata.IPMetadata calldata ipMetadata
    ) public returns (uint256 tokenId, address ipId) {
        ipAssetRegistry.setApprovalForAll(address(spg), true);
        SPG.Signature memory signature = SPG.Signature({
            signer: address(this),
            deadline: block.timestamp + 1000,
            signature: ""
        });
        (tokenId, ipId) = spg.mintAndRegisterIpWithSig(policyId, tokenContract, tokenMetadata, ipMetadata, signature);
    }

    // EIP-1271 compliance
    function isValidSignature(bytes32 _hash, bytes memory _signature) external view override returns (bytes4) {
        return MAGICVALUE;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return (interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId);
    }
    /// @inheritdoc IERC721Receiver
    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @inheritdoc IERC1155Receiver
    function onERC1155Received(address, address, uint256, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /// @inheritdoc IERC1155Receiver
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}
