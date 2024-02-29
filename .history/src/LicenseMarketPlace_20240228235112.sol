// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IP} from "@storyprotocol/core/lib/IP.sol";
import {IPAssetRegistry} from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import {IPResolver} from "@storyprotocol/core/resolvers/IPResolver.sol";
import {StoryProtocolGateway} from "@storyprotocol/periphery/StoryProtocolGateway.sol";
import {ILicenseMarketPlace} from "./ILicenseMarketPlace.sol";

contract LicenseMarketPlace {
    address public immutable NFT;
    address public immutable IP_RESOLVER;
    IPAssetRegistry public immutable IPA_REGISTRY;
    LicenseRegistry public immutable LICENSE_REGISTRY;
    StoryProtocolGateway public SPG;
    
    address public protocolFeeDestination;
    uint256 public protocolFeePercent;
    uint256 public subjectFeePercent;

    // We will need to have a mapping of the IP id to 

    // SharesSubject => (Holder => Balance)
    mapping(address => mapping(address => uint256)) public sharesBalance;

    // SharesSubject => Supply
    mapping(address => uint256) public sharesSupply;

    

    constructor(
        address spg,
        address ipAssetRegistry,
        address resolver,
        address nft
    ) {
        SPG = spg;
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
        uint256 licensorIpId,
        uint256 amount
    ) public payable {

        uint256 supply = sharesSupply[sharesSubject];
        require(supply > 0 || sharesSubject == msg.sender, "Only the shares' subject can buy the first share");
        uint256 price = getPrice(supply, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        require(msg.value >= price + protocolFee + subjectFee, "Insufficient payment");
        sharesBalance[sharesSubject][msg.sender] = sharesBalance[sharesSubject][msg.sender] + amount;
        sharesSupply[sharesSubject] = supply + amount;
        emit Trade(msg.sender, sharesSubject, true, amount, price, protocolFee, subjectFee, supply + amount);
        (bool success1, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2, ) = sharesSubject.call{value: subjectFee}("");
        require(success1 && success2, "Unable to send funds");
        

        SPG.mintLicensePIL(
            pilPolicy,
            licensorIpId,
            1,
            ROYATY_CONTEXT,
            MINTING_FEE,
            MINTING_FEE_TOKNE
        );

        return buyer;
    }

    function sellKey(
        address seller,
        uint256 storyProtocolIpId,
        uint256 amount
    ) external view returns (address) {
        uint256 supply = sharesSupply[sharesSubject];
        require(supply > amount, "Cannot sell the last share");
        uint256 price = getPrice(supply - amount, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        require(sharesBalance[sharesSubject][msg.sender] >= amount, "Insufficient shares");
        sharesBalance[sharesSubject][msg.sender] = sharesBalance[sharesSubject][msg.sender] - amount;
        sharesSupply[sharesSubject] = supply - amount;
        emit Trade(msg.sender, sharesSubject, false, amount, price, protocolFee, subjectFee, supply - amount);
        (bool success1, ) = msg.sender.call{value: price - protocolFee - subjectFee}("");
        (bool success2, ) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success3, ) = sharesSubject.call{value: subjectFee}("");
        require(success1 && success2 && success3, "Unable to send funds");
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
