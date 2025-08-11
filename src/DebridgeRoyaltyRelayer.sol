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

interface IRoyaltyManager {
    function payRoyaltyOnBehalf(address receiverIpId, address payerIpId, address token, uint256 amount) external;
}

/**
 * @title DebridgeRoyaltyRelayer
 * @dev A contract that receives cross-chain royalty payments via deBridge and relays them to appropriate contracts on Story Blockchain
 */
contract DebridgeRoyaltyRelayer {
    address public constant DLN_DESTINATION = 0xE7351Fd770A37282b91D153Ee690B63579D6dd7f;
    address public constant MULTICALL = 0xcA11bde05977b3631167028862bE2a173976CA11;
    address public constant WIP = 0x1514000000000000000000000000000000000000;
    address public constant ROYALTY_MODULE = 0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086;

    event RoyaltySettled(address receiverIpId, address payerIpId, uint256 amount, bytes32 uniqueSalt);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // modifier onlyDeBridgeGate() {
    //     require(msg.sender == DLN_DESTINATION, "DebridgeRoyaltyRelayer: caller is not DLN_DESTINATION");
    //     _;
    // }

    /**
     * @notice Function to be called by the deBridge relayer
     * @param receiverIpId Address of the receiver's IP ID
     * @param payerIpId Address of the payer's IP ID
     */
    function settleRoyalties(bytes32 uniqueSalt, address receiverIpId, address payerIpId) external payable {
        uint256 amount = msg.value;
        require(amount > 0, "DebridgeRoyaltyRelayer: zero amount");

        // Create multicall data
        IMulticall.Call3Value[] memory calls = new IMulticall.Call3Value[](2);

        // First call: deposit to WrappedIP contract
        calls[0] = IMulticall.Call3Value({
            target: WIP,
            allowFailure: false,
            value: amount,
            callData: abi.encodeWithSelector(IWrappedIP.deposit.selector)
        });

        // Second call: pay royalty on behalf
        calls[1] = IMulticall.Call3Value({
            target: ROYALTY_MODULE,
            allowFailure: false,
            value: 0,
            callData: abi.encodeWithSelector(
                IRoyaltyManager.payRoyaltyOnBehalf.selector,
                receiverIpId,
                payerIpId,
                WIP, // Using wrappedIPAddress as the token address
                amount
            )
        });

        // Execute multicall with the total value received
        IMulticall(MULTICALL).aggregate3Value{ value: amount }(calls);

        emit RoyaltySettled(receiverIpId, payerIpId, amount, uniqueSalt);
    }
}
