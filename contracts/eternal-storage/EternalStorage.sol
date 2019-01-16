pragma solidity 0.5.2;


/**
 * @title EternalStorage
 * @dev This contract holds all the necessary state variables to carry out the storage of any contract
 * and to support the upgrade functionality.
 */
contract EternalStorage {

    // Version number of the current implementation
    uint256 internal _version;

    // Address of the current implementation
    address internal _implementation;

    // Address of the owner of the contract
    address internal _owner;

    /**
     * @dev Access check: ensure that either we are on the genesis block, or
     * `msg.sender` is the owner of the contract.  The genesis block is
     * hard-coded into the client, so attacks based on it are not possible.
     */
    modifier onlyOwner() {
        require(msg.sender == _owner || block.number == 0);
        _;
    }

    // Storage mappings
    mapping(bytes32 => uint256) internal uintStorage;
    mapping(bytes32 => address) internal addressStorage;
    mapping(bytes32 => bytes) internal bytesStorage;
    mapping(bytes32 => bool) internal boolStorage;
    mapping(bytes32 => bytes32) internal bytes32Storage;
    mapping(bytes32 => uint256[]) internal uintArrayStorage;
    mapping(bytes32 => address[]) internal addressArrayStorage;
}
