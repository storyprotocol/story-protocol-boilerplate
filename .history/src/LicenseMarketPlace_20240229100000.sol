// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IP} from "@story-protocol/protocol-core/contracts/lib/IP.sol";
import {IPAssetRegistry} from "@story-protocol/protocol-core/contracts/registries/IPAssetRegistry.sol";
import {IPResolver} from "@story-protocol/protocol-core/contracts/resolvers/IPResolver.sol";
import {LicenseRegistry} from "@story-protocol/protocol-core/contracts/registries/LicenseRegistry.sol";
import {ILicenseMarketPlace} from "./ILicenseMarketPlace.sol";
import { SPG } from "@story-protocol/protocol-core/contracts/gateways/StoryProtocolGateway.sol";


contract LicenseMarketPlace is ILicenseMarketPlace {
    address public immutable NFT;
    address public immutable IP_RESOLVER;
    IPAssetRegistry public immutable IPA_REGISTRY;
    LicenseRegistry public immutable LICENSE_REGISTRY;
    // StoryProtocolGateway public SPG;

    event Trade(address trader, address subject, bool isBuy, uint256 shareAmount, uint256 ethAmount, uint256 protocolEthAmount, uint256 subjectEthAmount, uint256 supply);
    
    address public protocolFeeDestination;
    uint256 public protocolFeePercent;
    uint256 public subjectFeePercent;

    // We will need to have a mapping of the IP id to 

    // SharesSubject => (Holder => Balance)
    mapping(address => mapping(address => uint256)) public sharesBalance;

    // SharesSubject => Supply
    mapping(address => LicenseStatistics) public sharesStatistics;

    constructor(
        address licenseRegistryAddress,
        address ipAssetRegistry,
        address resolver,
        address nft
    ) {
        LicenseRegistry = LicenseRegistry(licenseRegistryAddress);
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
        return
            IPA_REGISTRY.register(
                block.chainid,
                NFT,
                tokenId,
                IP_RESOLVER,
                true,
                metadata
            );
    }

    function buyKey(
        address ipAssetAddress,
        uint256 amount
    ) public payable {
        uint256 supply = sharesStatistics[ipAssetAddress];
        require(supply > 0 || ipAssetAddress == msg.sender, "Only the shares' subject can buy the first share");
        uint256 price = getPrice(supply, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        require(msg.value >= price + protocolFee + subjectFee, "Insufficient payment");
        sharesBalance[ipAssetAddress][msg.sender] = sharesBalance[ipAssetAddress][msg.sender] + amount;
        sharesStatistics[ipAssetAddress] = supply + amount;
        emit Trade(msg.sender, ipAssetAddress, true, amount, price, protocolFee, subjectFee, supply + amount);
        (bool success1, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2, ) = ipAssetAddress.call{value: subjectFee}("");
        require(success1 && success2, "Unable to send funds");

        LicenseRegistry.mintLicense(

        );
    }

    // So youre NFT can own items as well as you
    function sellKey(
        address ipAssetAddress,
        uint256 amount
    ) public payable {
        uint256 supply = sharesStatistics[ipAssetAddress];
        require(supply > amount, "Cannot sell the last share");
        uint256 price = getPrice(supply - amount, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        require(sharesBalance[ipAssetAddress][msg.sender] >= amount, "Insufficient shares");
        sharesBalance[ipAssetAddress][msg.sender] = sharesBalance[ipAssetAddress][msg.sender] - amount;
        sharesStatistics[ipAssetAddress] = supply - amount;
        emit Trade(msg.sender, ipAssetAddress, false, amount, price, protocolFee, subjectFee, supply - amount);
        (bool success1, ) = msg.sender.call{value: price - protocolFee - subjectFee}("");
        (bool success2, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success3, ) = ipAssetAddress.call{value: subjectFee}("");
        require(success1 && success2 && success3, "Unable to send funds");

        LicenseRegistry.burnLicenses(
            msg.sender,
            ipAssetAddress,
            1,
            ROYATY_CONTEXT,
            MINTING_FEE,
            MINTING_FEE_TOKNE
        );
    }

    function getPrice(LicenseStatistics calldata supply, uint256 amount) public pure returns (uint256) {
        uint256 sum1 = supply == 0 ? 0 : (supply - 1 )* (supply) * (2 * (supply - 1) + 1) / 6;
        uint256 sum2 = supply == 0 && amount == 1 ? 0 : (supply - 1 + amount) * (supply + amount) * (2 * (supply - 1 + amount) + 1) / 6;
        uint256 summation = sum2 - sum1;
        return summation * 1 ether / 16000;
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
