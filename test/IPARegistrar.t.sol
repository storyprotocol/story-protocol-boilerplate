// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { ISPGNFT } from "@storyprotocol/periphery/interfaces/ISPGNFT.sol";

import { IPARegistrar } from "../src/IPARegistrar.sol";
import { SimpleNFT } from "../src/mocks/SimpleNFT.sol";

// Run this test: forge test --fork-url https://testnet.storyrpc.io/ --match-path test/IPARegistrar.t.sol
contract IPARegistrarTest is Test {
    address internal alice = address(0xa11ce);

    // For addresses, see https://docs.storyprotocol.xyz/docs/deployed-smart-contracts
    // Protocol Core - IPAssetRegistry
    address internal ipAssetRegistryAddr = 0x14CAB45705Fe73EC6d126518E59Fe3C61a181E40;
    // Protocol Periphery - RegistrationWorkflows
    address internal registrationWorkflowsAddr = 0xF403fcCAAE6C503D0CC1D25904A0B2cCd5B96C6F;

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
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(spgNft), expectedTokenId);

        vm.prank(alice);
        (address ipId, uint256 tokenId) = ipaRegistrar.spgMintIp();

        assertEq(ipId, expectedIpId);
        assertEq(tokenId, expectedTokenId);
        assertEq(spgNft.ownerOf(tokenId), alice);
    }
}
