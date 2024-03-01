// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IP} from "@story-protocol/protocol-core/contracts/lib/IP.sol";
import {IPAssetRegistry} from "@story-protocol/protocol-core/contracts/registries/IPAssetRegistry.sol";
import {IPResolver} from "@story-protocol/protocol-core/contracts/resolvers/IPResolver.sol";
import {ILicenseRegistry} from "@story-protocol/protocol-core/contracts/interfaces/registries/ILicenseRegistry.sol";
import {ILicenseMarketPlace} from "./ILicenseMarketPlace.sol";
import {IERC6551Account} from "erc6551/interfaces/IERC6551Account.sol";
import {IIPAccount} from "@story-protocol/protocol-core/contracts/interfaces/IIPAccount.sol";
import {IStoryProtocolGateway} from "@story-protocol/protocol-periphery/contracts/StoryProtocolGateway.sol";
import {SPG} from "@story-protocol/protocol-periphery/contracts/lib/SPG.sol";
import {Metadata} from "@story-protocol/protocol-periphery/contracts/lib/Metadata.sol";

contract LicenseMarketPlace is ILicenseMarketPlace {
    address public immutable NFT;
    address public immutable IP_RESOLVER;
    IPAssetRegistry public immutable IPA_REGISTRY;
    ILicenseRegistry public immutable LICENSE_REGISTRY;
    uint256 public immutable POLICY_ID;
    IStoryProtocolGateway public spg;
    address public immutable DEFAULT_SPG_NFT;

    event Trade(
        address trader,
        address subject,
        bool isBuy,
        uint256 shareAmount,
        uint256 ethAmount,
        uint256 protocolEthAmount,
        uint256 subjectEthAmount,
        uint256 supply
    );

    address public protocolFeeDestination;
    uint256 public protocolFeePercent;
    uint256 public subjectFeePercent;

    // We will need to have a mapping of the IP id to

    // SharesSubject => (Holder => Balance)
    mapping(address => mapping(address => uint256)) public sharesBalance;

    // SharesSubject => Supply
    mapping(address => LicenseMetadata) public sharesMetadata;

    mapping(uint256 => address) public licenseIdToAddress;

    constructor(
        address licenseRegistryAddress,
        address ipAssetRegistry,
        address resolver,
        address nft,
        uint256 policyId
    ) {
        LICENSE_REGISTRY = ILicenseRegistry(licenseRegistryAddress);
        IPA_REGISTRY = IPAssetRegistry(ipAssetRegistry);
        IP_RESOLVER = resolver;
        NFT = nft;
        POLICY_ID = policyId;
    }

    function _registerIpAsset(
        address storyProtocolIpId
    ) internal returns (uint256) {
        // Construct a license with the policy id
        require(
            storyProtocolIpId != address(0) &&
                sharesBalance[storyProtocolIpId][storyProtocolIpId] <= 0,
            "Already Registered"
        );
        uint256 licenseId = LICENSE_REGISTRY.mintLicense(
            POLICY_ID,
            storyProtocolIpId,
            true,
            1,
            storyProtocolIpId
        );
        sharesBalance[storyProtocolIpId][storyProtocolIpId] = 1;
        LicenseMetadata memory licenseMetadata = LicenseMetadata({
            totalSupply: 1,
            numDerivatives: 0,
            licenseId: licenseId
        });
        sharesMetadata[storyProtocolIpId] = licenseMetadata;
        return licenseId;
    }

    function registerIpAsset(
        address storyProtocolIpId
    ) external returns (uint256) {
        return _registerIpAsset(storyProtocolIpId);
    }

    function _generateMetadata(
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        address registrant,
        string calldata ip_name,
        string calldata url
    ) internal view returns (bytes memory) {
        bytes32 hash = keccak256(abi.encode(chainId, tokenContract, tokenId));
        return
            abi.encode(
                IP.MetadataV1({
                    name: ip_name,
                    hash: hash,
                    registrationDate: uint64(block.timestamp),
                    registrant: registrant,
                    uri: url
                })
            );
    }

    function registerExistingNFT(
        address tokenContract,
        uint256 tokenId,
        string calldata ip_name,
        bytes32 ip_content_hash,
        string calldata ip_url
    ) external returns (uint256) {
        Metadata.Attribute[] memory attributes = new Metadata.Attribute[](0);
        Metadata.IPMetadata memory ipMetadata = Metadata.IPMetadata({
            name: ip_name,
            hash: ip_content_hash,
            url: ip_url,
            customMetadata: attributes
        });
        SPG.Signature memory signature = SPG.Signature({
            signer: address(this),
            deadline: block.timestamp + 1000,
            signature: ""
        });
        address nftAccountAddr = spg.registerIpWithSig(
            POLICY_ID,
            tokenContract,
            tokenId,
            ipMetadata,
            signature
        );

        return _registerIpAsset(nftAccountAddr);
    }

    function registerNewNFT(
        string calldata nftName,
        string calldata nftDescription,
        string calldata nftUrl
    ) external returns (uint256 tokenId, address tokenAddress) {
        // Setup metadata attribution related to the NFT itself.
        Metadata.Attribute[] memory nftAttributes = new Metadata.Attribute[](1);
        bytes memory nftMetadata = abi.encode(
            Metadata.TokenMetadata({
                name: nftName,
                description: nftDescription,
                externalUrl: nftUrl,
                image: "pic",
                attributes: nftAttributes
            })
        );

        // Setup metadata attribution related to the IP semantics.
        Metadata.Attribute[] memory ipAttributes = new Metadata.Attribute[](1);
        ipAttributes[0] = Metadata.Attribute({
            key: "trademarkType",
            value: "merchandising"
        });
        Metadata.IPMetadata memory ipMetadata = Metadata.IPMetadata({
            name: "name for your IP asset",
            hash: bytes32("your IP asset content hash"),
            url: nftUrl,
            customMetadata: ipAttributes
        });

        SPG.Signature memory signature = SPG.Signature({
            signer: address(this),
            deadline: block.timestamp + 1000,
            signature: ""
        });

        (tokenId, tokenAddress) = spg.mintAndRegisterIpWithSig(
            POLICY_ID,
            DEFAULT_SPG_NFT,
            nftMetadata,
            ipMetadata,
            signature
        );

        _registerIpAsset(tokenAddress);

        return (tokenId, tokenAddress);
    }

    function _verifyOwner(
        address ownerAddr,
        address nftAcctAddr
    ) internal view returns (bool) {
        IIPAccount ipAccount = IIPAccount(payable(nftAcctAddr));
        address queriedOwner = ipAccount.owner();
        return queriedOwner == ownerAddr;
    }

    /**
     * Allows a user to buy a key from the marketplace.
     * @param sourceIpAssetAddress The address of the IPAsset's license that you want to buy. It's required that you own the address
     * @param targeIpAssetAddress The address of the IPAsset that you want to receive.
     * @param amount The amount of the key to buy.
     */
    function buyKey(
        address sourceIpAssetAddress,
        address targeIpAssetAddress,
        uint256 amount
    ) public payable {
        // function implementation goes here
        uint256 supply = sharesBalance[sourceIpAssetAddress][
            targeIpAssetAddress
        ];
        require(
            supply > 0 || _verifyOwner(msg.sender, sourceIpAssetAddress),
            "Only the IPAccount owner can buy the first share"
        );

        uint256 price = getPrice(
            supply,
            sharesMetadata[sourceIpAssetAddress].numDerivatives,
            amount
        );
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        uint256 subjectFee = (price * subjectFeePercent) / 1 ether;
        require(
            msg.value >= price + protocolFee + subjectFee,
            "Insufficient payment"
        );
        sharesBalance[sourceIpAssetAddress][targeIpAssetAddress] =
            sharesBalance[sourceIpAssetAddress][targeIpAssetAddress] +
            amount;
        sharesMetadata[sourceIpAssetAddress].totalSupply = supply + amount;
        emit Trade(
            targeIpAssetAddress,
            sourceIpAssetAddress,
            true,
            amount,
            price,
            protocolFee,
            subjectFee,
            supply + amount
        );
        (bool success1, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2, ) = sourceIpAssetAddress.call{value: subjectFee}("");
        require(success1 && success2, "Unable to send funds");

        LICENSE_REGISTRY.mintLicense(
            POLICY_ID,
            sourceIpAssetAddress,
            true,
            amount,
            targeIpAssetAddress
        );
    }

    // So youre NFT can own items as well as you
    function sellKey(
        address sourceIpAssetAddress,
        address targeIpAssetAddress,
        uint256 amount
    ) public payable {
        uint256 supply = sharesMetadata[sourceIpAssetAddress].totalSupply;
        require(supply > amount, "Cannot sell the last share");

        uint256 price = getPrice(
            supply,
            sharesMetadata[sourceIpAssetAddress].numDerivatives,
            amount
        );
        uint256 protocolFee = (price * protocolFeePercent) / 1 ether;
        uint256 subjectFee = (price * subjectFeePercent) / 1 ether;

        IIPAccount ipAccount = IIPAccount(payable(sourceIpAssetAddress));
        address owner = ipAccount.owner();
        require(
            supply > 0 || _verifyOwner(msg.sender, targeIpAssetAddress),
            "Only the IPAccount owner can buy the first share"
        );

        require(
            sharesBalance[sourceIpAssetAddress][targeIpAssetAddress] >= amount,
            "Insufficient shares"
        );
        sharesBalance[sourceIpAssetAddress][targeIpAssetAddress] =
            sharesBalance[sourceIpAssetAddress][targeIpAssetAddress] -
            amount;
        sharesMetadata[sourceIpAssetAddress].totalSupply = supply - amount;
        emit Trade(
            targeIpAssetAddress,
            sourceIpAssetAddress,
            false,
            amount,
            price,
            protocolFee,
            subjectFee,
            supply - amount
        );
        (bool success1, ) = msg.sender.call{
            value: price - protocolFee - subjectFee
        }("");
        (bool success2, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success3, ) = targeIpAssetAddress.call{value: subjectFee}("");
        require(success1 && success2 && success3, "Unable to send funds");
        for (uint256 i = 0; i < amount; i++) {
            uint256[] memory licenses_to_burn = new uint256[](1); // fixed-size array with values
            licenses_to_burn[0] = sharesMetadata[sourceIpAssetAddress]
                .licenseId;
            LICENSE_REGISTRY.burnLicenses(
                targeIpAssetAddress,
                licenses_to_burn
            );
        }
    }

    function getPrice(
        uint256 totalCirculating,
        uint256 numBurned,
        uint256 amount
    ) public pure returns (uint256) {
        uint256 totalSupplyAndBurned = totalCirculating + numBurned;
        uint256 sum1 = totalSupplyAndBurned == 0
            ? 0
            : ((totalSupplyAndBurned - 1) *
                (totalSupplyAndBurned) *
                (2 * (totalSupplyAndBurned - 1) + 1)) / 6;
        uint256 sum2 = totalSupplyAndBurned == 0 && amount == 1
            ? 0
            : ((totalSupplyAndBurned - 1 + amount) *
                (totalSupplyAndBurned + amount) *
                (2 * (totalSupplyAndBurned - 1 + amount) + 1)) / 6;
        uint256 summation = sum2 - sum1;
        return (summation * 1 ether) / 16000;
    }

    // function claimRoyalties(
    //     address owner,
    //     uint256 storyProtocolIpId,
    //     uint256 tokenAmount
    // ) external view returns (address) {
    //     return address(owner);
    // }

    // function distributeRoyalties(
    //     address owner,
    //     uint256 storyProtocolIpId,
    //     uint256 tokenAmount
    // ) external view returns (address) {
    //     return address(owner);
    // }
}
