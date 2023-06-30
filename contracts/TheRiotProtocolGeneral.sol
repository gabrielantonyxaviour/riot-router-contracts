// SPDX-License-Identifier: MIT
// Tells the Solidity compiler to compile only from v0.8.13 to v0.9.0
pragma solidity ^0.8.13;
import "@routerprotocol/evm-gateway-contracts/contracts/IDapp.sol";
import "@routerprotocol/evm-gateway-contracts/contracts/IGateway.sol";

contract TheRiotProtocolGeneral is IDapp {
    struct TransferSendRiotKeyParams {
        uint256 tokenId;
        address caller;
    }

    struct TransferReceiveRiotKeyParams {
        uint256 tokenId;
        address caller;
        bytes32 riotKey;
    }

    address private _owner;

    // Router Variables
    IGateway private gatewayContract;
    mapping(string => string) public ourContractOnChains;

    mapping(address => mapping(uint256 => bytes32)) private latestRiotKey;

    constructor(address gatewayAddress, string memory feePayerAddress) {
        _owner = msg.sender;
        gatewayContract = IGateway(gatewayAddress);
        gatewayContract.setDappMetadata(feePayerAddress);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Only owner can call this function.");
        _;
    }

    // Router Functions
    function setDappMetadata(string memory feePayerAddress) external onlyOwner {
        gatewayContract.setDappMetadata(feePayerAddress);
    }

    function setGateway(address gateway) external onlyOwner {
        gatewayContract = IGateway(gateway);
    }

    function setContractOnChain(string calldata chainId, string calldata contractAddress)
        external
        onlyOwner
    {
        ourContractOnChains[chainId] = contractAddress;
    }

    function transferCrossChain(
        string calldata destChainId,
        TransferSendRiotKeyParams memory transferParams,
        bytes calldata requestMetadata
    ) public payable {
        require(
            keccak256(abi.encodePacked(ourContractOnChains[destChainId])) !=
                keccak256(abi.encodePacked("")),
            "contract on dest not set"
        );
        transferParams.caller = msg.sender;
        bytes memory packet = abi.encode(transferParams);
        bytes memory requestPacket = abi.encode(ourContractOnChains[destChainId], packet);

        gatewayContract.iSend{value: msg.value}(
            1,
            0,
            string(""),
            destChainId,
            requestMetadata,
            requestPacket
        );
    }

    function getLatestRiotKey(uint256 tokenId) public view returns (bytes32) {
        return latestRiotKey[msg.sender][tokenId];
    }

    function iReceive(
        string memory, // requestSender,
        bytes memory,
        string memory
    ) external override returns (bytes memory) {
        require(msg.sender == address(gatewayContract), "only gateway");
        // DO NOTHING
    }

    function getRequestMetadata(
        uint64 destGasLimit,
        uint64 destGasPrice,
        uint64 ackGasLimit,
        uint64 ackGasPrice,
        uint128 relayerFees,
        uint8 ackType,
        bool isReadCall,
        bytes memory asmAddress
    ) public pure returns (bytes memory) {
        bytes memory requestMetadata = abi.encodePacked(
            destGasLimit,
            destGasPrice,
            ackGasLimit,
            ackGasPrice,
            relayerFees,
            ackType,
            isReadCall,
            asmAddress
        );
        return requestMetadata;
    }

    function iAck(
        uint256,
        bool execFlag,
        bytes memory execData
    ) external override {
        require(msg.sender == address(gatewayContract), "only gateway");
        TransferReceiveRiotKeyParams memory receivedData = abi.decode(
            execData,
            (TransferReceiveRiotKeyParams)
        );
        if (execFlag) {
            latestRiotKey[receivedData.caller][receivedData.tokenId] = receivedData.riotKey;
        } else {
            latestRiotKey[receivedData.caller][receivedData.tokenId] = bytes32(0);
        }
    }
}
