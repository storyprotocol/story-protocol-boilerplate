import { StoryProtocolGateway } from "@storyprotocol/periphery/StoryProtocolGateway.sol";
import { Metadata } from "@storyprotocol/periphery/lib/Metadata.sol";

contract ExampleSPGBundledMintAndRemixing {
  
  uint256 public constant MIN_ROYALTY = 10;
  uint256 public immutable DEFAULT_LICENSE;
  StoryProtocolGateway public immutable SPG;
  address public immutable DEFAULT_SPG_NFT;
  
  constructor(address spg, address defaultCollection, uint256 defaultLicense) {
    SPG = StoryProtocolGateway(spg);
    DEFAULT_SPG_NFT = defaultCollection;
    DEFAULT_LICENSE = defaultLicense;
  }
  
  function remix(
  	uint256[] licenseIds,
  	string calldata nftName,
    string calldata nftDescription,
    string calldata nftUrl,
    string calldata nftImage
	) {
    
    // Setup metadata attribution related to the NFT itself.
    Metadata.Attribute[] memory nftAttributes = new Metadata.Attribute[](1);
    nftAttributes[0] = Attribute({key: "Shirt-size", value: "XL"});
    bytes memory nftMetadata = abi.encode(
        Metadata.TokenData({
          name: nftName,
          description: nftDescription,
          externalUrl: nftUrl,
          image: nftImage,
          attributes: nftAttributes
        })
      );
      
      // Setup metadata attribution related to the IP semantics.
      Metadata.Attribute[] memory ipAttributes = new Metadata.Attribute[](1);
      ipAttributes[0] = Attribute({key: "trademarkType", value: "merchandising"});
    	Metadata.IPMetadata memory ipMetadata = Metadata.IPMetadata({
          name: "name for your IP asset",
          hash: bytes32("your IP asset content hash"),
          url:  "https://yourip.xyz/metadata-regarding-its-ip",
          customMetadata: ipAttributes
      });
      
      uint256 ipId = SPG.mintAndRegisterDerivativeIp(
        licenseIds,
        // ROYALTY_CONTEXT, or MIN_ROYALTY ? 
        DEFAULT_LICENSE,
        DEFAULT_SPG_NFT,
        nftMetadata,
        ipMetadata
      );
  }
}