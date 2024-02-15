import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @notice Mock ERC721 for used for testing IP registration.
contract MockERC721 is ERc721 {

    uint256 totalSupply = 0;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    function mint() external returns (uint256 id) {
        id = totalSupply++;
        _mint(msg.sender, id);
    }
}
