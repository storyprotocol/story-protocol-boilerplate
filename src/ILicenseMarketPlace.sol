// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

interface ILicenseMarketPlace {

	struct LicenseMetadata {
        uint256 totalSupply;
        uint256 numDerivatives;
		uint256 licenseId;
    } // The number of supply and derivatives. 

	// 	Registers an ipAsset that is registered on storyProtocol to the marketplace
	// function registerIpAsset(address storyProtocolIpId, uint256 setFee) external view returns (address);
	function registerIpAsset(address storyProtocolIpId) external returns (uint256);
	
	// Allows a user to buy a key for a specific world based on it's ip address
	function buyKey(address sourceIpAssetAddress, address targeIpAssetAddress, uint256 amount) external payable;

	// Allows a user to sell their key for a specific world.
	function sellKey(address sourceIpAssetAddress, address targeIpAssetAddress, uint256 amount) external payable;

	// function claimRoyalties(uint256 owner, uint256 storyProtocolIpId, uint256 tokenAmount) external view returns (address);

	// function distributeRoyalties(uint256 owner, uint256 storyProtocolIpId, uint256 tokenAmount) external view returns (address);
}

