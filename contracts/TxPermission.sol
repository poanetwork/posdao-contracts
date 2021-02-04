pragma solidity 0.5.10;

import "./interfaces/ICertifier.sol";
import "./interfaces/IRandomAuRa.sol";
import "./interfaces/IStakingAuRa.sol";
import "./interfaces/ITxPermission.sol";
import "./interfaces/IValidatorSetAuRa.sol";
import "./upgradeability/UpgradeableOwned.sol";


/// @dev Controls the use of zero gas price by validators in service transactions,
/// protecting the network against "transaction spamming" by malicious validators.
/// The protection logic is declared in the `allowedTxTypes` function.
contract TxPermission is UpgradeableOwned, ITxPermission {

    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables, do not change their order,
    // and do not change their types!

    address[] internal _allowedSenders;

    /// @dev The address of the `Certifier` contract.
    ICertifier public certifierContract;

    /// @dev A boolean flag indicating whether the specified address is allowed
    /// to initiate transactions of any type. Used by the `allowedTxTypes` getter.
    /// See also the `addAllowedSender` and `removeAllowedSender` functions.
    mapping(address => bool) public isSenderAllowed;

    /// @dev The address of the `ValidatorSetAuRa` contract.
    IValidatorSetAuRa public validatorSetContract;

    mapping(address => uint256) internal _deployerInputLengthLimit;

    // ============================================== Constants =======================================================

    /// @dev A constant that defines a regular block gas limit.
    /// Used by the `blockGasLimit` public getter.
    uint256 public constant BLOCK_GAS_LIMIT = 12500000;

    /// @dev A constant that defines a reduced block gas limit.
    /// Used by the `blockGasLimit` public getter.
    uint256 public constant BLOCK_GAS_LIMIT_REDUCED = 4000000;

    // ================================================ Events ========================================================

    /// @dev Emitted by the `setDeployerInputLengthLimit` function.
    /// @param deployer The address of a contract deployer.
    /// @param limit The maximum number of bytes in `input` field of deployment transaction.
    event DeployerInputLengthLimitSet(address indexed deployer, uint256 limit);

    // ============================================== Modifiers =======================================================

    /// @dev Ensures the `initialize` function was called before.
    modifier onlyInitialized {
        require(isInitialized());
        _;
    }

    // =============================================== Setters ========================================================

    /// @dev Initializes the contract at network startup.
    /// Can only be called by the constructor of the `InitializerAuRa` contract or owner.
    /// @param _allowed The addresses for which transactions of any type must be allowed.
    /// See the `allowedTxTypes` getter.
    /// @param _certifier The address of the `Certifier` contract. It is used by `allowedTxTypes` function to know
    /// whether some address is explicitly allowed to use zero gas price.
    /// @param _validatorSet The address of the `ValidatorSetAuRa` contract.
    function initialize(
        address[] calldata _allowed,
        address _certifier,
        address _validatorSet
    ) external {
        require(block.number == 0 || msg.sender == _admin());
        require(!isInitialized());
        require(_certifier != address(0));
        require(_validatorSet != address(0));
        for (uint256 i = 0; i < _allowed.length; i++) {
            _addAllowedSender(_allowed[i]);
        }
        certifierContract = ICertifier(_certifier);
        validatorSetContract = IValidatorSetAuRa(_validatorSet);
    }

    /// @dev Adds the address for which transactions of any type must be allowed.
    /// Can only be called by the `owner`. See also the `allowedTxTypes` getter.
    /// @param _sender The address for which transactions of any type must be allowed.
    function addAllowedSender(address _sender) public onlyOwner onlyInitialized {
        _addAllowedSender(_sender);
    }

    /// @dev Removes the specified address from the array of addresses allowed
    /// to initiate transactions of any type. Can only be called by the `owner`.
    /// See also the `addAllowedSender` function and `allowedSenders` getter.
    /// @param _sender The removed address.
    function removeAllowedSender(address _sender) public onlyOwner onlyInitialized {
        require(isSenderAllowed[_sender]);

        uint256 allowedSendersLength = _allowedSenders.length;

        for (uint256 i = 0; i < allowedSendersLength; i++) {
            if (_sender == _allowedSenders[i]) {
                _allowedSenders[i] = _allowedSenders[allowedSendersLength - 1];
                _allowedSenders.length--;
                break;
            }
        }

        isSenderAllowed[_sender] = false;
    }

    /// @dev Sets the limit of `input` transaction field length in bytes
    /// for contract deployment transaction made by the specified deployer.
    /// @param _deployer The address of a contract deployer.
    /// @param _limit The maximum number of bytes in `input` field of deployment transaction.
    /// Set it to zero to reset to default 24Kb limit defined by EIP 170.
    function setDeployerInputLengthLimit(address _deployer, uint256 _limit) public onlyOwner onlyInitialized {
        _deployerInputLengthLimit[_deployer] = _limit;
        emit DeployerInputLengthLimitSet(_deployer, _limit);
    }

    // =============================================== Getters ========================================================

    /// @dev Returns the contract's name recognizable by node's engine.
    function contractName() public pure returns(string memory) {
        return "TX_PERMISSION_CONTRACT";
    }

    /// @dev Returns the contract name hash needed for node's engine.
    function contractNameHash() public pure returns(bytes32) {
        return keccak256(abi.encodePacked(contractName()));
    }

    /// @dev Returns the contract's version number needed for node's engine.
    function contractVersion() public pure returns(uint256) {
        return 3;
    }

    /// @dev Returns the list of addresses allowed to initiate transactions of any type.
    /// For these addresses the `allowedTxTypes` getter always returns the `ALL` bit mask
    /// (see https://openethereum.github.io/wiki/Permissioning.html#how-it-works-1).
    function allowedSenders() public view returns(address[] memory) {
        return _allowedSenders;
    }

    /// @dev Defines the allowed transaction types which may be initiated by the specified sender with
    /// the specified gas price and data. Used by node's engine each time a transaction is about to be
    /// included into a block. See https://openethereum.github.io/wiki/Permissioning.html#how-it-works-1
    /// @param _sender Transaction sender address.
    /// @param _to Transaction recipient address. If creating a contract, the `_to` address is zero.
    /// @param _value Transaction amount in wei.
    /// @param _gasPrice Gas price in wei for the transaction.
    /// @param _data Transaction data.
    /// @return `uint32 typesMask` - Set of allowed transactions for `_sender` depending on tx `_to` address,
    /// `_gasPrice`, and `_data`. The result is represented as a set of flags:
    /// 0x01 - basic transaction (e.g. ether transferring to user wallet);
    /// 0x02 - contract call;
    /// 0x04 - contract creation;
    /// 0x08 - private transaction.
    /// `bool cache` - If `true` is returned, the same permissions will be applied from the same
    /// `_sender` without calling this contract again.
    function allowedTxTypes(
        address _sender,
        address _to,
        uint256 _value,
        uint256 _gasPrice,
        bytes memory _data
    )
        public
        view
        returns(uint32 typesMask, bool cache)
    {
        if (isSenderAllowed[_sender]) {
            // Let the `_sender` initiate any transaction if the `_sender` is in the `allowedSenders` list
            return (ALL, false);
        }

        if (_to == address(0) && _data.length > deployerInputLengthLimit(_sender)) {
            // Don't let to deploy too big contracts
            return (NONE, false);
        }

        // Get the called function's signature
        bytes4 signature = bytes4(0);
        assembly {
            signature := shl(224, mload(add(_data, 4)))
        }

        if (_to == validatorSetContract.randomContract()) {
            if (signature == COMMIT_HASH_SIGNATURE && _data.length > 4+32) {
                bytes32 numberHash;
                assembly { numberHash := mload(add(_data, 36)) }
                return (IRandomAuRa(_to).commitHashCallable(_sender, numberHash) ? CALL : NONE, false);
            } else if (
                (signature == REVEAL_NUMBER_SIGNATURE || signature == REVEAL_SECRET_SIGNATURE) &&
                _data.length == 4+32
            ) {
                uint256 num;
                assembly { num := mload(add(_data, 36)) }
                return (IRandomAuRa(_to).revealNumberCallable(_sender, num) ? CALL : NONE, false);
            } else {
                return (NONE, false);
            }
        }

        if (_to == address(validatorSetContract)) {
            // The rules for the ValidatorSetAuRa contract
            if (signature == EMIT_INITIATE_CHANGE_SIGNATURE) {
                // The `emitInitiateChange()` can be called by anyone
                // if `emitInitiateChangeCallable()` returns `true`
                return (validatorSetContract.emitInitiateChangeCallable() ? CALL : NONE, false);
            } else if (signature == REPORT_MALICIOUS_SIGNATURE && _data.length >= 4+64) {
                address maliciousMiningAddress;
                uint256 blockNumber;
                assembly {
                    maliciousMiningAddress := mload(add(_data, 36))
                    blockNumber := mload(add(_data, 68))
                }
                // The `reportMalicious()` can only be called by the validator's mining address
                // when the calling is allowed
                (bool callable,) = validatorSetContract.reportMaliciousCallable(
                    _sender, maliciousMiningAddress, blockNumber
                );

                return (callable ? CALL : NONE, false);
            } else if (_gasPrice > 0) {
                // The other functions of ValidatorSetAuRa contract can be called
                // by anyone except validators' mining addresses if gasPrice is not zero
                return (validatorSetContract.isValidator(_sender) ? NONE : CALL, false);
            }
        }

        if (validatorSetContract.isValidator(_sender) && _gasPrice > 0) {
            // Let the validator's mining address send their accumulated tx fees to some wallet
            return (_sender.balance > 0 ? BASIC : NONE, false);
        }

        if (validatorSetContract.isValidator(_to)) {
            // Validator's mining address can't receive any coins
            return (NONE, false);
        }

        // Don't let the `_sender` use a zero gas price, if it is not explicitly allowed by the `Certifier` contract
        if (_gasPrice == 0) {
            return (certifierContract.certifiedExplicitly(_sender) ? ALL : NONE, false);
        }

        // In other cases let the `_sender` create any transaction with non-zero gas price
        return (ALL, false);
    }

    /// @dev Returns the current block gas limit which depends on the stage of the current
    /// staking epoch: the block gas limit is temporarily reduced for the latest block of the epoch.
    function blockGasLimit() public view returns(uint256) {
        address stakingContract = validatorSetContract.stakingContract();
        uint256 stakingEpochEndBlock = IStakingAuRa(stakingContract).stakingEpochEndBlock();
        if (block.number == stakingEpochEndBlock - 1 || block.number == stakingEpochEndBlock) {
            return BLOCK_GAS_LIMIT_REDUCED;
        }
        return BLOCK_GAS_LIMIT;
    }

    /// @dev Returns the limit of `input` transaction field length in bytes
    /// for contract deployment transaction made by the specified deployer.
    /// @param _deployer The address of a contract deployer.
    function deployerInputLengthLimit(address _deployer) public view returns(uint256) {
        uint256 limit = _deployerInputLengthLimit[_deployer];

        if (limit != 0) {
            return limit;
        } else {
            return 24576; // default EIP 170 limit (24 Kb)
        }
    }

    /// @dev Returns a boolean flag indicating if the `initialize` function has been called.
    function isInitialized() public view returns(bool) {
        return validatorSetContract != IValidatorSetAuRa(0);
    }

    // ============================================== Internal ========================================================

    // Allowed transaction types mask
    uint32 internal constant NONE = 0;
    uint32 internal constant ALL = 0xffffffff;
    uint32 internal constant BASIC = 0x01;
    uint32 internal constant CALL = 0x02;
    uint32 internal constant CREATE = 0x04;
    uint32 internal constant PRIVATE = 0x08;

    // Function signatures

    // bytes4(keccak256("commitHash(bytes32,bytes)"))
    bytes4 internal constant COMMIT_HASH_SIGNATURE = 0x0b61ba85; 

    // bytes4(keccak256("emitInitiateChange()"))
    bytes4 internal constant EMIT_INITIATE_CHANGE_SIGNATURE = 0x93b4e25e;

    // bytes4(keccak256("reportMalicious(address,uint256,bytes)"))
    bytes4 internal constant REPORT_MALICIOUS_SIGNATURE = 0xc476dd40;

    // bytes4(keccak256("revealSecret(uint256)"))
    bytes4 internal constant REVEAL_SECRET_SIGNATURE = 0x98df67c6;

    // bytes4(keccak256("revealNumber(uint256)"))
    bytes4 internal constant REVEAL_NUMBER_SIGNATURE = 0xfe7d567d;

    /// @dev An internal function used by the `addAllowedSender` and `initialize` functions.
    /// @param _sender The address for which transactions of any type must be allowed.
    function _addAllowedSender(address _sender) internal {
        require(!isSenderAllowed[_sender]);
        require(_sender != address(0));
        _allowedSenders.push(_sender);
        isSenderAllowed[_sender] = true;
    }
}
