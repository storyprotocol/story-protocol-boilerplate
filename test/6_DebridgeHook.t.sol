// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title deBridge + Story Protocol Integration Test
 * @author Story Protocol Team
 * @notice Demonstrates cross-chain royalty payments using deBridge DLN and Story Protocol
 * @dev This integration enables users to pay IP asset royalties from any supported blockchain
 *      to Story mainnet using deBridge as the cross-chain bridge infrastructure.
 *
 * INTEGRATION OVERVIEW:
 * ├── Source Chain (e.g., Ethereum): User initiates payment with ETH
 * ├── deBridge DLN: Swaps ETH → WIP and bridges to Story mainnet
 * ├── Auto-Approval: deBridge approves WIP to RoyaltyModule
 * └── Hook Execution: Direct call to RoyaltyModule.payRoyaltyOnBehalf()
 *
 * KEY FEATURES:
 * • Automatic token approval via deBridge
 * • Direct contract calls for maximum efficiency
 * • Production-ready API integration
 * • Real Story Protocol mainnet addresses
 *
 * SUPPORTED NETWORKS:
 * • Source: Ethereum mainnet (chainId: 1)
 * • Destination: Story mainnet (chainId: 100000013)
 * • Bridge: ETH → WIP token
 */

// Run this test:
// forge test --fork-url https://aeneid.storyrpc.io/ --match-path test/6_DebridgeHook.t.sol
import { Test, console } from "forge-std/Test.sol";
import { HexUtils } from "./utils/HexUtils.sol";
import { StringUtils } from "./utils/StringUtils.sol";

/**
 * @notice Minimal interface for Story Protocol RoyaltyModule
 * @dev Only includes the payRoyaltyOnBehalf function needed for cross-chain payments
 */
interface IRoyaltyModule {
    /**
     * @notice Pay royalties on behalf of an IP asset
     * @param receiverIpId The IP asset receiving royalties
     * @param payerIpId The IP asset paying royalties (0x0 for external payers)
     * @param token The payment token address
     * @param amount The payment amount
     */
    function payRoyaltyOnBehalf(address receiverIpId, address payerIpId, address token, uint256 amount) external;
}

/**
 * @title Cross-Chain Royalty Payment Integration Test
 * @notice Tests the complete flow of paying Story Protocol royalties via deBridge
 */
contract DebridgeStoryIntegrationTest is Test {
    using HexUtils for bytes;
    using HexUtils for address;
    using StringUtils for string;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Story Protocol RoyaltyModule on Story mainnet
    address public constant ROYALTY_MODULE = 0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086;

    /// @notice WIP (Wrapped IP) token on Story mainnet
    address public constant WIP_TOKEN = 0x1514000000000000000000000000000000000000;

    /// @notice deBridge API endpoint for order creation
    string public constant DEBRIDGE_API = "https://dln.debridge.finance/v1.0/dln/order/create-tx";

    uint256 public constant PAYMENT_AMOUNT = 1e18; // 1 WIP token

    /*//////////////////////////////////////////////////////////////
                              MAIN TEST
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Tests the complete cross-chain royalty payment flow
     * @dev Demonstrates API integration and validates successful hook parsing
     */
    function test_crossChainRoyaltyPayment() public {
        // Build hook payload for direct RoyaltyModule call
        string memory dlnHookJson = _buildRoyaltyPaymentHook();

        // Create deBridge API request
        string memory apiUrl = _buildApiRequest(dlnHookJson);

        // Execute API call and validate response
        string memory response = _executeApiCall(apiUrl);
        _validateApiResponse(response);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructs the deBridge hook payload for royalty payment
     * @return dlnHookJson The JSON-encoded hook payload
     */
    function _buildRoyaltyPaymentHook() internal pure returns (string memory dlnHookJson) {
        // Payment configuration
        address ipAssetId = 0xB1D831271A68Db5c18c8F0B69327446f7C8D0A42; // Example IP asset

        // Encode the direct RoyaltyModule call
        // Note: deBridge ExternalCallExecutor automatically approves tokens before execution
        bytes memory calldata_ = abi.encodeCall(
            IRoyaltyModule.payRoyaltyOnBehalf,
            (
                ipAssetId, // IP asset receiving royalties
                address(0), // External payer (0x0)
                WIP_TOKEN, // Payment token (WIP)
                PAYMENT_AMOUNT // Payment amount
            )
        );

        // Construct deBridge hook JSON
        dlnHookJson = string.concat(
            '{"type":"evm_transaction_call",',
            '"data":{"to":"',
            _addressToHex(ROYALTY_MODULE),
            '",',
            '"calldata":"',
            calldata_.toHexString(),
            '",',
            '"gas":0}}'
        );
    }

    /**
     * @notice Builds the complete deBridge API request URL
     * @param dlnHookJson The hook payload to include in the request
     * @return apiUrl The complete API request URL
     */
    function _buildApiRequest(string memory dlnHookJson) internal pure returns (string memory apiUrl) {
        address senderAddress = 0xcf0a36dEC06E90263288100C11CF69828338E826; // Example sender

        apiUrl = string.concat(
            DEBRIDGE_API,
            "?srcChainId=1", // Ethereum mainnet
            "&srcChainTokenIn=",
            _addressToHex(address(0)), // ETH (native token)
            "&srcChainTokenInAmount=auto", // 0.01 ETH
            "&dstChainId=100000013", // Story mainnet
            "&dstChainTokenOut=",
            _addressToHex(WIP_TOKEN), // WIP token
            "&dstChainTokenOutAmount=",
            StringUtils.toString(PAYMENT_AMOUNT),
            "&dstChainTokenOutRecipient=",
            _addressToHex(senderAddress),
            "&senderAddress=",
            _addressToHex(senderAddress),
            "&srcChainOrderAuthorityAddress=",
            _addressToHex(senderAddress),
            "&dstChainOrderAuthorityAddress=",
            _addressToHex(senderAddress),
            "&enableEstimate=true", // Enable simulation
            "&dlnHook=",
            _urlEncode(dlnHookJson) // URL-encoded hook
        );
    }

    /**
     * @notice Executes the API call to deBridge
     * @param apiUrl The API request URL
     * @return response The API response
     */
    function _executeApiCall(string memory apiUrl) internal returns (string memory response) {
        // Log API request for debugging
        console.log("deBridge API Request:");
        console.log(apiUrl);
        console.log("");

        // Execute HTTP request via Foundry's ffi
        string[] memory curlCommand = new string[](3);
        curlCommand[0] = "curl";
        curlCommand[1] = "-s";
        curlCommand[2] = apiUrl;

        bytes memory responseBytes = vm.ffi(curlCommand);
        response = string(responseBytes);

        // Log API response for debugging
        console.log("deBridge API Response:");
        console.log(response);
        console.log("");
    }

    /**
     * @notice Validates the deBridge API response
     * @param response The API response to validate
     */
    function _validateApiResponse(string memory response) internal pure {
        require(bytes(response).length > 0, "Empty API response");

        // Validate successful response
        require(_contains(response, '"estimation"'), "Missing estimation field");
        require(_contains(response, '"tx"'), "Missing transaction field");
        require(_contains(response, '"orderId"'), "Missing order ID");
        require(_contains(response, '"dstChainTokenOut"'), "Missing destination token info");

        // Verify hook integration
        require(
            _contains(response, "d2577f3b"), // payRoyaltyOnBehalf selector
            "Hook not properly integrated in transaction"
        );

        // Verify WIP token configuration
        require(
            _contains(_toLower(response), _toLower(_addressToHex(WIP_TOKEN))),
            "WIP token address not found in response"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Converts address to hex string
     */
    function _addressToHex(address addr) internal pure returns (string memory) {
        return abi.encodePacked(addr).toHexString();
    }

    /**
     * @notice Converts string to lowercase
     */
    function _toLower(string memory str) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        for (uint i = 0; i < strBytes.length; i++) {
            if (strBytes[i] >= 0x41 && strBytes[i] <= 0x5A) {
                strBytes[i] = bytes1(uint8(strBytes[i]) + 32);
            }
        }
        return string(strBytes);
    }

    /**
     * @notice Checks if string contains substring
     */
    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory haystackBytes = bytes(haystack);
        bytes memory needleBytes = bytes(needle);

        if (needleBytes.length > haystackBytes.length) return false;

        for (uint i = 0; i <= haystackBytes.length - needleBytes.length; i++) {
            bool found = true;
            for (uint j = 0; j < needleBytes.length; j++) {
                if (haystackBytes[i + j] != needleBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }

    /**
     * @notice URL encodes a string for API requests
     */
    function _urlEncode(string memory input) internal pure returns (string memory) {
        bytes memory inputBytes = bytes(input);
        bytes memory output = new bytes(inputBytes.length * 3);
        uint outputLength = 0;

        for (uint i = 0; i < inputBytes.length; i++) {
            uint8 char = uint8(inputBytes[i]);

            // Characters that don't need encoding: A-Z, a-z, 0-9, -, ., _, ~
            if (
                (char >= 0x30 && char <= 0x39) ||
                (char >= 0x41 && char <= 0x5A) ||
                (char >= 0x61 && char <= 0x7A) ||
                char == 0x2D ||
                char == 0x2E ||
                char == 0x5F ||
                char == 0x7E
            ) {
                output[outputLength++] = inputBytes[i];
            } else {
                // URL encode the character
                output[outputLength++] = "%";
                output[outputLength++] = bytes1(_toHexChar(char >> 4));
                output[outputLength++] = bytes1(_toHexChar(char & 0x0F));
            }
        }

        // Trim output to actual length
        bytes memory result = new bytes(outputLength);
        for (uint i = 0; i < outputLength; i++) {
            result[i] = output[i];
        }
        return string(result);
    }

    /**
     * @notice Converts hex digit to character
     */
    function _toHexChar(uint8 value) internal pure returns (uint8) {
        return value < 10 ? (0x30 + value) : (0x41 + value - 10);
    }
}
