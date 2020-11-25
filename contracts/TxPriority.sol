pragma solidity 0.5.10;
pragma experimental ABIEncoderV2;

import "./libs/BokkyPooBahsRedBlackTreeLibrary.sol";
import "./libs/SafeMath.sol";


/// @dev Keeps transaction destinations tree for TX Priority feature in Ethereum client,
/// keeps top priority senders whitelist, and rules for exclusive min gas prices.
contract TxPriority {

    using BokkyPooBahsRedBlackTreeLibrary for BokkyPooBahsRedBlackTreeLibrary.Tree;
    using SafeMath for uint256;

    struct Destination {
        address target;
        bytes4 fnSignature;
        uint256 value;
    }

    BokkyPooBahsRedBlackTreeLibrary.Tree internal _weightsTree; // sorted tree of destination weights
    
    address[] internal _sendersWhitelist; // an array of whitelisted senders
    Destination[] internal _minGasPrices; // an array of min gas price rules
    mapping(address => mapping(bytes4 => uint256)) internal _minGasPriceIndex;
    
    uint256 public weightsCount;
    mapping(uint256 => Destination) public destinationByWeight;
    mapping(address => mapping(bytes4 => uint256)) public weightByDestination;

    address public owner;
    
    event PrioritySet(address indexed target, bytes4 indexed fnSignature, uint256 weight);
    event SendersWhitelistSet(address[] whitelist);
    event MinGasPriceSet(address indexed target, bytes4 indexed fnSignature, uint256 minGasPrice);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @dev Throws if called by any account other than the owner.
    modifier onlyOwner() {
        require(owner == msg.sender, "caller is not the owner");
        _;
    }

    constructor (address _owner) public {
        if (_owner == address(0)) {
            _owner = msg.sender;
        }
        require(_owner != address(0));
        owner = _owner;
        emit OwnershipTransferred(address(0), _owner);
    }

    /// @dev Transfers ownership of the contract to a new account (`_newOwner`).
    /// Can only be called by the current owner.
    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "new owner is the zero address");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
    
    /// @dev Sets transaction destination priority (weight).
    /// The more the weight, the more priority transaction will have.
    /// @param _target The `to` address in transaction. Cannot be 0x0.
    /// @param _fnSignature The function signature if the `to` is a contract
    /// (the first 4 bytes of the `data` field in transaction).
    /// Can be 0x00000000 for EOA target address or when someone
    /// sends coins to a contract without calling any function.
    /// @param _weight The weight (priority) of the destination. Cannot be zero.
    function setPriority(address _target, bytes4 _fnSignature, uint256 _weight) external onlyOwner {
        require(_target != address(0), "target cannot be 0");
        require(_weight != 0, "weight cannot be 0");
        uint256 foundWeight = weightByDestination[_target][_fnSignature];
        if (foundWeight != 0) {
            // Destination already exists in the tree
            if (foundWeight == _weight) {
                emit PrioritySet(_target, _fnSignature, _weight);
                return; // nothing changes, return
            }
            // Remove existing destination from the tree
            _weightsTree.remove(foundWeight);
            delete destinationByWeight[foundWeight];
        } else {
            // This is a new destination, increment counter
            weightsCount = weightsCount.add(1);
        }
        _weightsTree.insert(_weight);
        destinationByWeight[_weight] = Destination(_target, _fnSignature, _weight);
        weightByDestination[_target][_fnSignature] = _weight;
        emit PrioritySet(_target, _fnSignature, _weight);
    }
    
    /// @dev Removes a destination from the priority list.
    /// @param _target The `to` address in transaction.
    /// @param _fnSignature The function signature if the `to` is a contract.
    /// See its description in the `setPriority` function.
    function removePriority(address _target, bytes4 _fnSignature) external onlyOwner {
        uint256 foundWeight = weightByDestination[_target][_fnSignature];
        require(foundWeight != 0, "destination does not exist"); // destination should exist
        
        _weightsTree.remove(foundWeight);
        
        delete weightByDestination[_target][_fnSignature];
        delete destinationByWeight[foundWeight];
        weightsCount = weightsCount.sub(1);

        emit PrioritySet(_target, _fnSignature, 0);
    }
    
    /// @dev Sets sender whitelist, an array of `from` addresses which have a top priority:
    /// if a whitelisted address sends a transaction, this transaction should be mined before
    /// transactions defined by the `setPriority` function.
    /// @param _whitelist The array of whitelisted senders.
    function setSendersWhitelist(address[] calldata _whitelist) external onlyOwner {
        _sendersWhitelist = _whitelist;
        emit SendersWhitelistSet(_whitelist);
    }
    
    /// @dev Sets an exclusive min gas price for the specified transaction destination.
    /// The defined _minGasPrice for the specified transaction should be used by Ethereum client
    /// instead of the MinGasPrice configured by default for all transactions in the client.
    /// If the specified _minGasPrice is less than default MinGasPrice, the default MinGasPrice should
    /// be used and the _minGasPrice should be ignored.
    /// These rules shouldn't overwrite (cancel) the Certifier and TxPermission filters.
    /// @param _target The `to` address in transaction.
    /// @param _fnSignature The function signature if the `to` is a contract.
    /// The first 4 bytes of the `data` field in transaction. Can be 0x00000000 for EOA target address
    /// or when someone just sends coins to a contract without calling any function (when `data` is empty).
    /// @param _minGasPrice The min gas price in Wei. Cannot be zero.
    function setMinGasPrice(address _target, bytes4 _fnSignature, uint256 _minGasPrice) external onlyOwner {
        require(_target != address(0), "target cannot be 0");
        require(_minGasPrice != 0, "minGasPrice cannot be 0");

        uint256 index = _minGasPriceIndex[_target][_fnSignature];

        if (
            _minGasPrices.length > index &&
            _minGasPrices[index].target == _target &&
            _minGasPrices[index].fnSignature == _fnSignature
        ) {
            _minGasPrices[index].value = _minGasPrice;
        } else {
            _minGasPriceIndex[_target][_fnSignature] = _minGasPrices.length;
            _minGasPrices.push(Destination(_target, _fnSignature, _minGasPrice));
        }

        emit MinGasPriceSet(_target, _fnSignature, _minGasPrice);
    }
    
    /// @dev Removes an exclusive min gas price for the specified transaction destination.
    /// @param _target See description of the `setMinGasPrice` function.
    /// @param _fnSignature See description of the `setMinGasPrice` function.
    function removeMinGasPrice(address _target, bytes4 _fnSignature) external onlyOwner {
        uint256 index = _minGasPriceIndex[_target][_fnSignature];

        if (
            _minGasPrices.length > index &&
            _minGasPrices[index].target == _target &&
            _minGasPrices[index].fnSignature == _fnSignature
        ) {
            Destination memory last = _minGasPrices[_minGasPrices.length - 1];
            _minGasPrices[index] = last;
            _minGasPriceIndex[last.target][last.fnSignature] = index;
            _minGasPriceIndex[_target][_fnSignature] = 0;
            _minGasPrices.length--;
            emit MinGasPriceSet(_target, _fnSignature, 0);
        } else {
            revert("not found");
        }
    }
    
    /// @dev Returns all destinations defined by the `setPriority`.
    /// The returned list is sorted by weight descending.
    function getPriorities() external view returns(Destination[] memory weights) {
        weights = new Destination[](weightsCount);
        uint256 weight = _weightsTree.last();
        uint256 i = 0;
        
        while (weight != 0) {
            require(i < weightsCount);
            weights[i++] = destinationByWeight[weight];
            weight = _weightsTree.prev(weight);
        }
    }
    
    /// @dev Returns the sender whitelist set by the `setSendersWhitelist` function.
    function getSendersWhitelist() external view returns(address[] memory whitelist) {
        whitelist = _sendersWhitelist;
    }

    /// @dev Returns all destinations defined by the `setMinGasPrice`.
    function getMinGasPrices() external view returns(Destination[] memory prices) {
        prices = _minGasPrices;
    }

}
