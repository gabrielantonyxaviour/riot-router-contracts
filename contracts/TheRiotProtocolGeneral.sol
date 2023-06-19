// SPDX-License-Identifier: MIT
// Tells the Solidity compiler to compile only from v0.8.13 to v0.9.0
pragma solidity ^0.8.13;
import "@routerprotocol/evm-gateway-contracts/contracts/IDapp.sol";
import "@routerprotocol/evm-gateway-contracts/contracts/IGateway.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract TheRiotProtocolGeneral is ERC721, ERC721URIStorage, IDapp {
    struct Device {
        uint256 tokenId;
        address deviceId;
        bytes32 firmwareHash;
        bytes32 deviceDataHash;
        bytes32 deviceGroupIdHash;
        address subscriber;
        bytes32 sessionSalt;
        bool exists;
    }

    struct TransferParams {
        uint256 organisationId;
        Device device;
        bytes metadataUrl;
    }

    // Riot Variables
    uint256 private _devicesCount;

    mapping(uint256 => mapping(uint256 => Device)) private organisationToDevices;
    mapping(uint256 => Device) private devices;
    mapping(address => bool) private deviceMinted;
    address private _owner;

    // Router Variables
    IGateway private gatewayContract;
    mapping(string => string) public ourContractOnChains;

    event DeviceMinted(uint256 organisationId, uint256 tokenId, Device device, uint256 timestamp);

    constructor(
        string memory _name,
        string memory _symbol,
        address gatewayAddress,
        string memory feePayerAddress
    ) ERC721(_name, _symbol) {
        _owner = msg.sender;
        gatewayContract = IGateway(gatewayAddress);
        gatewayContract.setDappMetadata(feePayerAddress);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Only owner can call this function.");
        _;
    }

    modifier checkIfDeviceTokenMinted(uint256 tokenId) {
        require(devices[tokenId].exists, "Device not minted.");
        _;
    }
    modifier checkIfDeviceAddresssMinted(address deviceId) {
        require(deviceMinted[deviceId], "Device not minted.");
        _;
    }

    function getDeviceByTokenId(uint256 _tokenId) public view returns (Device memory) {
        return devices[_tokenId];
    }

    function isDeviceIdMinted(address deviceId) public view returns (bool) {
        return deviceMinted[deviceId];
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
        TransferParams memory transferParams,
        bytes calldata requestMetadata
    ) public payable {
        require(
            keccak256(abi.encodePacked(ourContractOnChains[destChainId])) !=
                keccak256(abi.encodePacked("")),
            "contract on dest not set"
        );
        // DO NOTHING
    }

    function iReceive(
        string memory, // requestSender,
        bytes memory packet,
        string memory srcChainId
    ) external override returns (bytes memory) {
        require(msg.sender == address(gatewayContract), "only gateway");
        // decoding our payload

        TransferParams memory transferParams = abi.decode(packet, (TransferParams));
        organisationToDevices[transferParams.organisationId][
            transferParams.device.tokenId
        ] = transferParams.device;
        devices[transferParams.device.tokenId] = transferParams.device;
        _safeMint(transferParams.device.subscriber, _devicesCount);
        _setTokenURI(_devicesCount, bytesToString(transferParams.metadataUrl));
        deviceMinted[transferParams.device.deviceId] = true;
        _devicesCount += 1;
        return abi.encode(srcChainId);
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
        uint256 requestIdentifier,
        bool execFlag,
        bytes memory execData
    ) external override {}

    // Overrides
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function bytesToString(bytes memory _bytes) public pure returns (string memory) {
        if (_bytes.length == 0) {
            return "";
        }
        string memory result = new string(_bytes.length);
        for (uint256 i = 0; i < _bytes.length; i++) {
            bytes1 char = _bytes[i];
            require(uint8(char) >= 32 && uint8(char) <= 126, "Invalid character");
            bytes(result)[i] = char;
        }
        return result;
    }
}
