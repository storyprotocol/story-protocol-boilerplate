import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @notice Interface for mintable ERC721s
interface IERC721Mintable is IERC721 {

    /// @notice Function for minting an arbitrary NFT to the sender.
    function mint() external returns(uint256);
}
