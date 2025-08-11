// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IMulticall {
    struct Call3Value {
        address target;
        bool allowFailure;
        uint256 value;
        bytes callData;
    }

    struct Result {
        bool success;
        bytes returnData;
    }

    function aggregate3Value(Call3Value[] calldata calls) external payable returns (Result[] memory returnData);
}

interface IWrappedIP {
    function deposit() external payable;
}

interface ILicensingModule {
    function mintLicenseTokens(
        address licensorIpId,
        address licenseTemplate,
        uint256 licenseTermsId,
        uint256 amount,
        address receiver,
        bytes calldata royaltyContext,
        uint256 maxMintingFee,
        uint32 maxRevenueShare
    ) external returns (uint256 startLicenseTokenId);
}

/**
 * @title DebridgeLicenseTokenMinter
 * @dev A contract that receives cross-chain payments via deBridge and mints license tokens
 */
contract DebridgeLicenseTokenMinter {
    address public constant MULTICALL = 0xcA11bde05977b3631167028862bE2a173976CA11;
    address public constant WIP = 0x1514000000000000000000000000000000000000;
    address public constant LICENSING_MODULE = 0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f;
    address public constant PIL_TEMPLATE = 0x2E896b0b2Fdb7457499B56AAaA4AE55BCB4Cd316;

    event LicenseTokensMinted(
        address indexed licensorIpId,
        address indexed receiver,
        uint256 startLicenseTokenId,
        uint256 amount
    );

    /**
     * @notice Function to be called by the deBridge relayer to mint license tokens
     */
    function mintLicenseTokensCrossChain(
        address licensorIpId,
        uint256 licenseTermsId,
        uint256 tokenAmount,
        address receiver
    ) external payable {
        uint256 amount = msg.value;
        require(amount > 0, "DebridgeLicenseTokenMinter: zero amount");

        // Create multicall data - using memory array directly to avoid stack issues
        IMulticall.Call3Value[] memory calls = new IMulticall.Call3Value[](2);

        // First call: deposit ETH to get WIP tokens
        calls[0] = IMulticall.Call3Value({
            target: WIP,
            allowFailure: false,
            value: amount,
            callData: abi.encodeWithSelector(IWrappedIP.deposit.selector)
        });

        // Second call: mint license tokens
        calls[1] = IMulticall.Call3Value({
            target: LICENSING_MODULE,
            allowFailure: false,
            value: 0,
            callData: abi.encodeWithSelector(
                ILicensingModule.mintLicenseTokens.selector,
                licensorIpId,
                PIL_TEMPLATE,
                licenseTermsId,
                tokenAmount,
                receiver,
                "",
                0,
                100_000_000
            )
        });

        // Execute multicall and emit event
        IMulticall.Result[] memory returnData = IMulticall(MULTICALL).aggregate3Value{ value: amount }(calls);
        bytes memory raw = returnData[1].returnData;
        uint256 startLicenseTokenId = abi.decode(raw, (uint256)); // if mintLicenseTokens returns uint256
        emit LicenseTokensMinted(licensorIpId, receiver, startLicenseTokenId, tokenAmount);
    }
}
