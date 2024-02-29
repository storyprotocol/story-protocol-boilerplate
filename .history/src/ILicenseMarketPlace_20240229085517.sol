// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

interface ILicenseMarketPlace {

	struct LicenseStatistics {
        uint256 totalSupply;
        uint256 numDerivatives;
    } // The number of supply and derivatives. 

	// 	Registers an ipAsset that is registered on storyProtocol to the marketplace
	function registerIpAsset(address storyProtocolIpId, uint256 setFee) external view returns (address);
	
	// Allows a user to buy a key for a specific world based on it's ip address
	function buyKey(address buyer, uint256 storyProtocolIpId, uint256 amount) external view returns (address);

	// Allows a user to sell their key for a specific world.
	function sellKey(address seller, uint256 storyProtocolIpId, uint256 amount) external view returns (address);

	function claimRoyalties(uint256 owner, uint256 storyProtocolIpId, uint256 tokenAmount) external view returns (address);

	function distributeRoyalties(uint256 owner, uint256 storyProtocolIpId, uint256 tokenAmount) external view returns (address);
}

