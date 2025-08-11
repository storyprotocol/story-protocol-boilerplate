// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { BaseModule } from "@storyprotocol/core/modules/BaseModule.sol";
import { AccessControlled } from "@storyprotocol/core/access/AccessControlled.sol";
import { ILicensingHook } from "@storyprotocol/core/interfaces/modules/licensing/ILicensingHook.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

/// @title IP USD Price Hook
/// @notice This hook is used to set the base price in USD for each license terms ID.
///         The price is fetched from the Pyth price feed.
///         The price is stored in the licensePriceUSD mapping.
///         The price is used to calculate the minting fee for the license tokens.
///         The price is updated by the setLicensePrice function.
contract IPUSDPriceHook is BaseModule, AccessControlled, ILicensingHook {
    string public constant override name = "IP_USD_PRICE_HOOK";
    IPyth public immutable pythContract;
    bytes32 public immutable priceFeedId;

    /// @notice Stores the base price in USD for each license terms ID.
    /// @dev The key is keccak256(licensorIpId, licenseTemplate, licenseTermsId).
    /// @dev The value is the base price in USD with 18 decimals.
    mapping(bytes32 => uint256) public licensePriceUSD;

    /// @notice Emitted when the IP USD price is set
    /// @param licensorIpId The licensor IP id
    /// @param licenseTemplate The license template address
    /// @param licenseTermsId The license terms id
    /// @param priceUSD The base price in USD with 18 decimals
    event SetIPUSDPrice(
        address indexed licensorIpId,
        address indexed licenseTemplate,
        uint256 indexed licenseTermsId,
        uint256 priceUSD
    );

    error PriceFeedNotSet();
    error PriceNotSet();
    error InvalidOraclePrice();
    error PriceMustBeGreaterThanZero();

    constructor(
        address accessController,
        address ipAssetRegistry,
        address _pythContract,
        bytes32 _priceFeedId
    ) AccessControlled(accessController, ipAssetRegistry) {
        if (_priceFeedId == bytes32(0)) revert PriceFeedNotSet();
        pythContract = IPyth(_pythContract);
        priceFeedId = _priceFeedId;
    }

    /// @notice Set the license price in USD for a specific license
    /// @param licensorIpId The licensor IP id
    /// @param licenseTemplate The license template address
    /// @param licenseTermsId The license terms id
    /// @param price The price in USD for the license terms with 18 decimals
    function setLicensePrice(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 price
    ) external verifyPermission(licensorIpId) {
        if (price == 0) revert PriceMustBeGreaterThanZero();
        bytes32 key = keccak256(abi.encodePacked(licensorIpId, licenseTemplate, licenseTermsId));
        licensePriceUSD[key] = price;
        emit SetIPUSDPrice(licensorIpId, licenseTemplate, licenseTermsId, price);
    }

    /// @notice This function is called when the LicensingModule mints license tokens.
    /// @dev The hook can be used to implement various checks and determine the minting price.
    /// The hook should revert if the minting is not allowed.
    /// @param caller The address of the caller who calling the mintLicenseTokens() function.
    /// @param licensorIpId The ID of licensor IP from which issue the license tokens.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms within the license template,
    /// which is used to mint license tokens.
    /// @param amount The amount of license tokens to mint.
    /// @param receiver The address of the receiver who receive the license tokens.
    /// @param hookData The data to be used by the licensing hook.
    /// @return totalMintingFee The total minting fee to be paid when minting amount of license tokens.
    function beforeMintLicenseTokens(
        address caller,
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount,
        address receiver,
        bytes calldata hookData
    ) external returns (uint256 totalMintingFee) {
        totalMintingFee = _calculateFee(licensorIpId, licenseTemplate, licenseTermsId, amount);
    }

    /// @notice This function is called before finalizing LicensingModule.registerDerivative(), after calling
    /// LicenseRegistry.registerDerivative().
    /// @dev The hook can be used to implement various checks and determine the minting price.
    /// The hook should revert if the registering of derivative is not allowed.
    /// @param childIpId The derivative IP ID.
    /// @param parentIpId The parent IP ID.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms within the license template.
    /// @param hookData The data to be used by the licensing hook.
    /// @return mintingFee The minting fee to be paid when register child IP to the parent IP as derivative.
    function beforeRegisterDerivative(
        address caller,
        address childIpId,
        address parentIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        bytes calldata hookData
    ) external returns (uint256 mintingFee) {
        return _calculateFee(parentIpId, licenseTemplate, licenseTermsId, 1);
    }

    /// @notice This function is called when the LicensingModule calculates/predict the minting fee for license tokens.
    /// @dev The hook should guarantee the minting fee calculation is correct and return the minting fee which is
    /// the exact same amount with returned by beforeMintLicenseTokens().
    /// The hook should revert if the minting fee calculation is not allowed.
    /// @param caller The address of the caller who calling the mintLicenseTokens() function.
    /// @param licensorIpId The ID of licensor IP from which issue the license tokens.
    /// @param licenseTemplate The address of the license template.
    /// @param licenseTermsId The ID of the license terms within the license template,
    /// which is used to mint license tokens.
    /// @param amount The amount of license tokens to mint.
    /// @param receiver The address of the receiver who receive the license tokens.
    /// @param hookData The data to be used by the licensing hook.
    /// @return totalMintingFee The total minting fee to be paid when minting amount of license tokens.
    function calculateMintingFee(
        address caller,
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount,
        address receiver,
        bytes calldata hookData
    ) external view returns (uint256 totalMintingFee) {
        totalMintingFee = _calculateFee(licensorIpId, licenseTemplate, licenseTermsId, amount);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseModule, IERC165) returns (bool) {
        return interfaceId == type(ILicensingHook).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @dev calculates the minting fee for a given license
    /// @param licenseTemplate The license template address
    /// @param licenseTermsId The license terms id
    /// @param amount The amount of license tokens to mint
    /// @return totalMintingFee The total minting fee to be paid when minting amount of license tokens
    function _calculateFee(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount
    ) internal view returns (uint256 totalMintingFee) {
        bytes32 key = keccak256(abi.encodePacked(licensorIpId, licenseTemplate, licenseTermsId));
        uint256 _licensePriceUSD = licensePriceUSD[key];

        if (_licensePriceUSD == 0) revert PriceNotSet();

        // Get current IP/USD price from Pyth
        // TODO: pyth.getPriceNoOlderThan() is always return error in testnet,
        // so we use pyth.getPriceUnsafe() instead.
        PythStructs.Price memory price = pythContract.getPriceUnsafe(priceFeedId);

        // Get the IP token amount for the given USD price
        uint256 ipTokenAmount = _getIPTokenAmountForUSD(_licensePriceUSD, price.price, price.expo);

        // Calculate: (_licensePriceUSD * amount) / normalizedPrice
        return ipTokenAmount * amount;
    }

    /**
     * @dev Converts USD price into token amount using Pyth price feed.
     * @param _licensePriceUSD License price in USD (18 decimals)
     * @param _pythPrice Raw Pyth price value (int64)
     * @param _pythExpo Pyth price exponent (usually -8 for USD feeds)
     * @return tokenAmount IP token amount in 18 decimals
     */
    function _getIPTokenAmountForUSD(
        uint256 _licensePriceUSD,
        int64 _pythPrice,
        int32 _pythExpo
    ) internal pure returns (uint256) {
        if (_pythPrice <= 0) revert InvalidOraclePrice();

        // Normalize price to 18 decimals: price * 10^(18 + expo)
        uint256 normalizedPrice = uint256(int256(_pythPrice)) * (10 ** uint256(int256(18 + _pythExpo)));

        // Return token amount in 18 decimals (IP token also uses 18)
        return (_licensePriceUSD * 1e18) / normalizedPrice;
    }
}
