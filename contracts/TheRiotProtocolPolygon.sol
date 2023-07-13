// SPDX-License-Identifier: MIT
// Tells the Solidity compiler to compile only from v0.8.13 to v0.9.0
pragma solidity ^0.8.13;
import "@routerprotocol/evm-gateway-contracts/contracts/IDapp.sol";
import "@routerprotocol/evm-gateway-contracts/contracts/IGateway.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract TheRiotProtocolPolygon is ERC721, ERC721URIStorage, IDapp {
    struct Organisation {
        uint256 id;
        string name;
        string symbol;
        address creator;
        string metadata;
        bool exists;
    }

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
    struct CreateDeviceParams {
        uint256 organisationId;
        address deviceId;
        bytes32 firmwareHash;
        bytes32 deviceDataHash;
        bytes32 deviceGroupIdHash;
        bytes32 sessionSalt;
        string uri;
    }

    struct TransferSendRiotKeyParams {
        uint256 tokenId;
        address caller;
    }
    struct TransferReceiveRiotKeyParams {
        uint256 tokenId;
        address caller;
        bytes32 riotKey;
    }
    // uint256 private _deviceCount;
    uint256 private _organisationsCount;
    uint256 private _devicesCount;

    mapping(address => Organisation[]) private ownerToOrganisations;
    mapping(uint256 => Organisation) private organisations;
    mapping(uint256 => Device[]) private organisationToDevices;
    mapping(uint256 => Device) private devices;
    mapping(address => bool) private deviceMinted;
    mapping(uint256 => string[]) private devicesMintedCrossChain;
    address private _owner;

    event OrganisationCreated(uint256 indexed organisationId, Organisation organisation);
    event DeviceCreated(uint256 indexed organisationId, Device device);
    event DeviceFirmwareUpdated(
        uint256 indexed organisationId,
        uint256 indexed tokenId,
        address indexed deviceId,
        bytes32 firmwareHash
    );
    event DeviceTransferred(
        uint256 indexed organisationId,
        uint256 indexed tokenId,
        address indexed deviceId,
        address newOwner
    );

    // Router Variables
    IGateway private gatewayContract;
    mapping(string => string) public ourContractOnChains;

    constructor(address gatewayAddress, string memory feePayerAddress)
        ERC721("The Riot Protocol", "TRP")
    {
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
        _;
    }
    modifier onlyOrganisationAdmin(uint256 organisationId) {
        require(msg.sender == organisations[organisationId].creator, "Unauthorized");
        _;
    }

    /**
     * @dev Registers a new group and adds a device.
     * @param _name The name of the Riot Organisation NFT Collection.
     * @param _symbol The symbol of the Riot Orgnaisation Devive NFT Collection.
     */
    function registerOrganisation(
        string memory _name,
        string memory _symbol,
        string memory _metadata
    ) public {
        _organisationsCount += 1;
        Organisation memory _organisation = Organisation(
            _organisationsCount - 1,
            _name,
            _symbol,
            msg.sender,
            _metadata,
            true
        );
        ownerToOrganisations[msg.sender].push(_organisation);
        organisations[_organisationsCount - 1] = _organisation;
        emit OrganisationCreated(_organisationsCount - 1, _organisation);
    }

    function createDevice(CreateDeviceParams calldata params)
        public
        onlyOrganisationAdmin(params.organisationId)
        checkIfDeviceAddresssMinted(params.deviceId)
    {
        uint256 _tokenId = _devicesCount;
        Device memory newDevice = Device(
            _tokenId,
            params.deviceId,
            params.firmwareHash,
            params.deviceDataHash,
            params.deviceGroupIdHash,
            msg.sender,
            params.sessionSalt, // drand randomness
            true
        );
        deviceMinted[params.deviceId] = true;
        _safeMint(msg.sender, _tokenId);
        _setTokenURI(_tokenId, params.uri);
        devices[_devicesCount] = newDevice;
        organisationToDevices[params.organisationId].push(newDevice);
        _devicesCount += 1;
        emit DeviceCreated(params.organisationId, newDevice);
    }

    function isRiotOrganisation(uint256 organisationId) public view returns (bool) {
        return organisations[organisationId].exists;
    }

    function getOrganisation(uint256 organisationId) public view returns (Organisation memory) {
        return organisations[organisationId];
    }

    function isDeviceMinted(address deviceId) public view returns (bool) {
        return deviceMinted[deviceId];
    }

    function setSubscriberAddress(
        uint256 _tokenId,
        uint256 organisationId,
        address _subscriber,
        bytes32 newSessionSalt
    ) public {
        // Update the mappings
        require(msg.sender == devices[_tokenId].subscriber, "Unauthorized");

        address from = devices[_tokenId].subscriber;
        devices[_tokenId].subscriber = _subscriber;

        organisationToDevices[organisationId][_tokenId].subscriber = _subscriber;
        organisationToDevices[organisationId][_tokenId].sessionSalt = newSessionSalt;
        devices[_tokenId].sessionSalt = newSessionSalt;
        _safeTransfer(from, _subscriber, _tokenId, "");

        emit DeviceTransferred(organisationId, _tokenId, devices[_tokenId].deviceId, _subscriber);
    }

    function updateFirmware(
        bytes32 _firmwareHash,
        uint256 _tokenId,
        uint256 organisationId,
        bytes32 sessionSalt
    ) public {
        require(msg.sender == devices[_tokenId].subscriber, "Unauthorized");

        devices[_tokenId].firmwareHash = _firmwareHash;
        devices[_tokenId].sessionSalt = sessionSalt;
        organisationToDevices[organisationId][_tokenId].firmwareHash = _firmwareHash;
        organisationToDevices[organisationId][_tokenId].sessionSalt = sessionSalt;

        emit DeviceFirmwareUpdated(
            organisationId,
            _tokenId,
            devices[_tokenId].deviceId,
            _firmwareHash
        );
    }

    /**
     * @dev Calculates the merkle root from an array of hashes.
     * @param hashes The array of hashes.
     * @return rootHash The merkle root hash.
     */
    function getMerkleRoot(bytes32[] memory hashes) public pure returns (bytes32) {
        require(hashes.length == 6, "Input array must have 6 elements");

        bytes32 rootHash = keccak256(
            abi.encodePacked(
                keccak256(abi.encodePacked(hashes[0], hashes[1])),
                keccak256(abi.encodePacked(hashes[2], hashes[3])),
                keccak256(abi.encodePacked(hashes[4], hashes[5]))
            )
        );

        return rootHash;
    }

    /**
     * @dev Generates a RIOT key for a device.
     * @param _firmwareHash The firmware hash of the device.
     * @param _deviceDataHash The device data hash.
     * @param _deviceGroupIdHash The device group ID hash.
     * @param _deviceId The device address.
     * @return The RIOT key for the device.
     */
    function generateRiotKeyForDevice(
        bytes32 _firmwareHash,
        bytes32 _deviceDataHash,
        bytes32 _deviceGroupIdHash,
        address _deviceId,
        uint256 tokenId
    ) public view checkIfDeviceAddresssMinted(_deviceId) returns (bytes32) {
        // Check if the received data is in the valid devices
        require(devices[tokenId].firmwareHash == _firmwareHash, "Invalid FirmwareHash");
        require(devices[tokenId].deviceDataHash == _deviceDataHash, "Invalid DeviceDataHash");
        require(
            devices[tokenId].deviceGroupIdHash == _deviceGroupIdHash,
            "Invalid DeviceGroupIdHash"
        );

        bytes32[] memory hashes = new bytes32[](6);
        hashes[0] = devices[tokenId].firmwareHash;
        hashes[1] = devices[tokenId].deviceDataHash;
        hashes[2] = devices[tokenId].deviceGroupIdHash;
        hashes[3] = bytes32(bytes20(_deviceId));
        hashes[4] = bytes32(bytes20(devices[tokenId].subscriber));
        hashes[5] = devices[tokenId].sessionSalt;

        return getMerkleRoot(hashes);
    }

    /**
     * @dev Generates a RIOT key for the subscriber of a device.
     * @return The RIOT key for the subscriber of the device.
     */
    function generateRiotKeyForSubscriber(uint256 tokenId) public view returns (bytes32) {
        // Check if the received data is in the valid devices
        if (!deviceMinted[devices[tokenId].deviceId]) {
            return bytes32(0);
        }
        if (devices[tokenId].subscriber != msg.sender) {
            return bytes32(uint256(1));
        }

        bytes32[] memory hashes = new bytes32[](6);
        hashes[0] = devices[tokenId].firmwareHash;
        hashes[1] = devices[tokenId].deviceDataHash;
        hashes[2] = devices[tokenId].deviceGroupIdHash;
        hashes[3] = bytes32(bytes20(devices[tokenId].deviceId));
        hashes[4] = bytes32(bytes20(msg.sender));
        hashes[5] = devices[tokenId].sessionSalt;
        return getMerkleRoot(hashes);
    }

    function _generateRiotKeyForSubscriberCrossChain(uint256 tokenId, address caller)
        internal
        view
        returns (bytes32)
    {
        // Check if the received data is in the valid devices
        if (!deviceMinted[devices[tokenId].deviceId]) {
            return bytes32(0);
        }
        if (devices[tokenId].subscriber != caller) {
            return bytes32(uint256(1));
        }

        bytes32[] memory hashes = new bytes32[](6);
        hashes[0] = devices[tokenId].firmwareHash;
        hashes[1] = devices[tokenId].deviceDataHash;
        hashes[2] = devices[tokenId].deviceGroupIdHash;
        hashes[3] = bytes32(bytes20(devices[tokenId].deviceId));
        hashes[4] = bytes32(bytes20(caller));
        hashes[5] = devices[tokenId].sessionSalt;
        return getMerkleRoot(hashes);
    }

    function getOrganisations(address user)
        public
        view
        returns (Organisation[] memory _organisations)
    {
        _organisations = ownerToOrganisations[user];
    }

    function getOrganisationDevices(uint256 organisationId)
        public
        view
        returns (Device[] memory _devices)
    {
        _devices = organisationToDevices[organisationId];
    }

    function getDevice(uint256 _tokenId) public view returns (Device memory) {
        return devices[_tokenId];
    }

    function getDevicesCount() public view returns (uint256) {
        return _devicesCount;
    }

    // Router functions
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
        TransferReceiveRiotKeyParams memory,
        bytes calldata
    ) public payable {
        require(
            keccak256(abi.encodePacked(ourContractOnChains[destChainId])) !=
                keccak256(abi.encodePacked("")),
            "contract on dest not set"
        );
        // DO NOTHING
    }

    function iReceive(
        string memory requestSender,
        bytes memory packet,
        string memory srcChainId
    ) external override returns (bytes memory) {
        require(
            keccak256(abi.encodePacked(ourContractOnChains[srcChainId])) !=
                keccak256(abi.encodePacked("")),
            "contract on dest not set"
        );

        require(
            keccak256(abi.encodePacked(ourContractOnChains[srcChainId])) ==
                keccak256(abi.encodePacked(requestSender)),
            "request sender not valid"
        );
        require(msg.sender == address(gatewayContract), "only gateway");
        TransferSendRiotKeyParams memory requestData = abi.decode(
            packet,
            (TransferSendRiotKeyParams)
        );
        bytes32 riotKey = _generateRiotKeyForSubscriberCrossChain(
            requestData.tokenId,
            requestData.caller
        );
        TransferReceiveRiotKeyParams memory receiveData = TransferReceiveRiotKeyParams(
            requestData.tokenId,
            requestData.caller,
            riotKey
        );
        return abi.encode(receiveData);
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

    function toAddress(bytes memory _bytes) internal pure returns (address addr) {
        bytes20 srcTokenAddress;
        assembly {
            srcTokenAddress := mload(add(_bytes, 0x20))
        }
        addr = address(srcTokenAddress);
    }

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
}
