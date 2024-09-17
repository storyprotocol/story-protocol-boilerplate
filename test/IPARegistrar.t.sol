// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { IPAssetRegistry } from "@storyprotocol/core/registries/IPAssetRegistry.sol";
import { ISPGNFT } from "@storyprotocol/periphery/interfaces/ISPGNFT.sol";

import { IPARegistrar } from "../src/IPARegistrar.sol";
import { SimpleNFT } from "../src/SimpleNFT.sol";

contract IPARegistrarTest is Test {
    address internal alice = address(0xa11ce);

    // Protocol Core v1 addresses
    // (see https://docs.storyprotocol.xyz/docs/deployed-smart-contracts)
    address internal ipAssetRegistryAddr = 0xe34A78B3d658aF7ad69Ff1EFF9012ECa025a14Be;
    // Protocol Periphery v1 addresses
    // (see https://github.com/storyprotocol/protocol-periphery-v1/blob/main/deploy-out/deployment-11155111.json)
    address internal storyProtocolGatewayAddr = 0xAceb5E631d743AF76aF69414eC8D356c13435E59;

    IPAssetRegistry public ipAssetRegistry;
    ISPGNFT public spgNft;

    IPARegistrar public ipaRegistrar;
    SimpleNFT public simpleNft;

    function setUp() public {
        ipAssetRegistry = IPAssetRegistry(ipAssetRegistryAddr);
        ipaRegistrar = new IPARegistrar(ipAssetRegistryAddr, storyProtocolGatewayAddr);
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
