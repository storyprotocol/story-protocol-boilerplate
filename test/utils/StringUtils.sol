// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library StringUtils {
    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a signed integer to string
     */
    function toString(int256 value) internal pure returns (string memory) {
        string memory _uintAsString = toString(abs(value));
        if (value >= 0) {
            return _uintAsString;
        }
        return string(abi.encodePacked("-", _uintAsString));
    }

    /**
     * @dev Returns the absolute value of a signed integer
     */
    function abs(int256 value) internal pure returns (uint256) {
        return value >= 0 ? uint256(value) : uint256(-value);
    }

    /**
     * @dev Concatenate two strings
     */
    function concat(string memory a, string memory b) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }

    /**
     * @dev Compare two strings for equality
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
} 