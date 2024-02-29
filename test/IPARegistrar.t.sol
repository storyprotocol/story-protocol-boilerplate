// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { stdJson } from "forge-std/Script.sol";
import { Test } from "forge-std/Test.sol";

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { IPResolver } from "@storyprotocol/core/resolvers/IPResolver.sol";

import { IPARegistrar } from "../src/IPARegistrar.sol";

contract MockERC721 is ERC721 {
    uint256 public totalSupply = 0;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mint() external returns (uint256 id) {
        id = totalSupply++;
        _mint(msg.sender, id);
    }
}

contract IPARegistrarTest is Test {

    using stdJson for string;

    address internal ipAssetRegistryAddr;
    address internal licensingModuleAddr;
    address internal ipResolverAddr;

    MockERC721 public NFT;
    IPARegistrar public ipaRegistrar;

    function setUp() public {
        _readProtocolAddresses();
        NFT = new MockERC721("Story Mock NFT", "STORY");
        ipaRegistrar = new IPARegistrar(
            ipAssetRegistryAddr,
            ipResolverAddr,
            address(NFT)
        );
    }

    function test_IPARegistration() public {
        vm.startPrank(address(ipaRegistrar));
        uint256 tokenId = NFT.mint();
        address ipId = ipaRegistrar.register("test", tokenId);
    }

    function _readProtocolAddresses() internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/node_modules/@story-protocol/protocol-core/deploy-out/deployment-11155111.json");
        string memory json = vm.readFile(path);
        ipAssetRegistryAddr = json.readAddress(".main.IPAssetRegistry");
        ipResolverAddr = json.readAddress(".main.IPResolver");

    }
}
