// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { ISPGNFT } from "@storyprotocol/periphery/interfaces/ISPGNFT.sol";

import { IPARegistrar } from "../src/IPARegistrar.sol";
import { SimpleNFT } from "../src/SimpleNFT.sol";

// Run this test: forge test --fork-url https://testnet.storyrpc.io/ --match-path test/IPARegistrar.t.sol
contract IPARegistrarTest is Test {
    address internal alice = address(0xa11ce);

    // For addresses, see https://docs.storyprotocol.xyz/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    address internal ipAssetRegistryAddr = 0x1a9d0d28a0422F26D31Be72Edc6f13ea4371E11B;
    // Protocol Periphery - RegistrationWorkflows
    address internal registrationWorkflowsAddr = 0x601C24bFA5Ae435162A5dC3cd166280C471d16c8;

    IPAssetRegistry public ipAssetRegistry;
    ISPGNFT public spgNft;

    IPARegistrar public ipaRegistrar;
    SimpleNFT public simpleNft;

    function setUp() public {
        ipAssetRegistry = IPAssetRegistry(ipAssetRegistryAddr);
        ipaRegistrar = new IPARegistrar(ipAssetRegistryAddr, registrationWorkflowsAddr);
        simpleNft = SimpleNFT(ipaRegistrar.SIMPLE_NFT());
        spgNft = ISPGNFT(ipaRegistrar.SPG_NFT());

        vm.label(address(ipAssetRegistry), "IPAssetRegistry");
        vm.label(address(simpleNft), "SimpleNFT");
        vm.label(address(spgNft), "SPGNFT");
        vm.label(address(0x000000006551c19487814612e58FE06813775758), "ERC6551Registry");
    }

    function test_mintIp() public {
        uint256 expectedTokenId = simpleNft.nextTokenId();
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(simpleNft), expectedTokenId);

        vm.prank(alice);
        (address ipId, uint256 tokenId) = ipaRegistrar.mintIp();

        assertEq(ipId, expectedIpId);
        assertEq(tokenId, expectedTokenId);
        assertEq(simpleNft.ownerOf(tokenId), alice);
    }

    function test_spgMintIp() public {
        uint256 expectedTokenId = spgNft.totalSupply() + 1;
        emit log_named_uint("chain id", block.chainid);
        emit log_named_address("spg address", address(spgNft));
        emit log_named_uint("expected token id", expectedTokenId);
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(spgNft), expectedTokenId);

        vm.prank(alice);
        (address ipId, uint256 tokenId) = ipaRegistrar.spgMintIp();

        assertEq(ipId, expectedIpId);
        assertEq(tokenId, expectedTokenId);
        assertEq(spgNft.ownerOf(tokenId), alice);
    }
}
