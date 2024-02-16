// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";

import { IPAssetRegistry } from "@storyprotocol/contracts/registries/IPAssetRegistry.sol";
import { IPResolver } from "@storyprotocol/contracts/resolvers/IPResolver.sol";

import { IPARegistrar } from "../contracts/IPARegistrar.sol";
import { MockERC721 } from "./mocks/MockERC721.sol";

contract IPARegistrarTest is Test {

    address public constant IPA_REGISTRY_ADDR = address(0x7567ea73697De50591EEc317Fe2b924252c41608);
    address public constant IP_RESOLVER_ADDR = address(0xEF808885355B3c88648D39c9DB5A0c08D99C6B71);

    MockERC721 public nft;
    IPARegistrar public registrar;

    function setUp() public {
        nft = new MockERC721("Story Mock NFT", "STORY");
        registrar = new IPARegistrar(
            IPA_REGISTRY_ADDR,
            IP_RESOLVER_ADDR,
            address(nft)
        );
    }

    function test_IPARegistration() public {
        address ipId = registrar.register("test");
        assertTrue(IPAssetRegistry(IPA_REGISTRY_ADDR).isRegistered(ipId));
    }

}
