pragma solidity 0.5.7;

import "./abstracts/ContractsAddresses.sol";
import "./interfaces/IBlockReward.sol";
import "./interfaces/IRandomAuRa.sol";
import "./interfaces/IStakingAuRa.sol";
import "./interfaces/ITxPermission.sol";
import "./interfaces/IValidatorSet.sol";
import "./interfaces/IValidatorSetAuRa.sol";
import "./eternal-storage/OwnedEternalStorage.sol";


/// @dev Controls the use of zero gas price by validators in service transactions,
/// protecting the network against "transaction spamming" by malicious validators.
/// The protection logic is declared in the `allowedTxTypes` function.
contract TxPermission is ContractsAddresses, OwnedEternalStorage, ITxPermission {

    // =============================================== Setters ========================================================

    /// @dev Initializes the contract at network startup.
    /// Must be called by the constructor of the `Initializer` contract on the genesis block.
    /// @param _allowedSender The address for which transactions of any type must be allowed.
    /// See the `allowedTxTypes` getter.
    function initialize(
        address _allowedSender
    ) external {
        require(block.number == 0);
        _addAllowedSender(_allowedSender);
    }

    /// @dev Adds the address for which transactions of any type must be allowed.
    /// Can only be called by the `owner`. See also the `allowedTxTypes` getter.
    /// @param _sender The address for which transactions of any type must be allowed.
    function addAllowedSender(address _sender) public onlyOwner {
        _addAllowedSender(_sender);
    }

    /// @dev Removes the specified address from the array of addresses allowed
    /// to initiate transactions of any type. Can only be called by the `owner`.
    /// See also the `addAllowedSender` function and `allowedSenders` getter.
    /// @param _sender The removed address.
    function removeAllowedSender(address _sender) public onlyOwner {
        uint256 allowedSendersLength = addressArrayStorage[ALLOWED_SENDERS].length;

        for (uint256 i = 0; i < allowedSendersLength; i++) {
            if (_sender == addressArrayStorage[ALLOWED_SENDERS][i]) {
                addressArrayStorage[ALLOWED_SENDERS][i] = addressArrayStorage[ALLOWED_SENDERS][allowedSendersLength-1];
                addressArrayStorage[ALLOWED_SENDERS].length--;
                break;
            }
        }
    }

    // =============================================== Getters ========================================================

    /// @dev Returns the contract's name recognizable by the Parity engine.
    function contractName() public pure returns(string memory) {
        return "TX_PERMISSION_CONTRACT";
    }

    /// @dev Returns the contract name hash needed for the Parity engine.
    function contractNameHash() public pure returns(bytes32) {
        return keccak256(abi.encodePacked(contractName()));
    }

    /// @dev Returns the contract's version number needed for the Parity engine.
    function contractVersion() public pure returns(uint256) {
        return 0xfffffffffffffffe;
    }

    /// @dev Returns the list of addresses allowed to initiate transactions of any type.
    /// For these addresses the `allowedTxTypes` getter always returns the `ALL` bit mask
    /// (see https://wiki.parity.io/Permissioning.html#how-it-works-1).
    function allowedSenders() public view returns(address[] memory) {
        return addressArrayStorage[ALLOWED_SENDERS];
    }

    /// @dev Defines the allowed transaction types which may be initiated by the specified sender with
    /// the specified gas price and data. Used by the Parity engine each time a transaction is about to be
    /// included into a block. See https://wiki.parity.io/Permissioning.html#how-it-works-1
    /// @param _sender Transaction sender address.
    /// @param _to Transaction recipient address. If creating a contract, the `_to` address is zero.
    /// @param _gasPrice Gas price in wei for the transaction.
    /// @param _data Transaction data.
    /// @return typesMask Set of allowed transactions for `_sender` depending on tx `_to` address,
    /// `_gasPrice`, and `_data`. The result is represented as a set of flags:
    /// - 0x01 - basic transaction (e.g. ether transferring to user wallet)
    /// - 0x02 - contract call
    /// - 0x04 - contract creation
    /// - 0x08 - private transaction
    /// @return cache If `true` is returned, the same permissions will be applied from the same
    /// `_sender` without calling this contract again.
    function allowedTxTypes(
        address _sender,
        address _to,
        uint256 /*_value*/, // solhint-disable-line space-after-comma
        uint256 _gasPrice,
        bytes memory _data
    )
        public
        view
        returns(uint32 typesMask, bool cache)
    {
        if (isSenderAllowed(_sender)) {
            // Let the `_sender` initiate any transaction if the `_sender` is in the `allowedSenders` list
            return (ALL, false);
        }

        IValidatorSet validatorSet = IValidatorSet(VALIDATOR_SET_CONTRACT);

        // Get the called function's signature
        bytes4 signature = bytes4(0);
        bytes memory abiParams;
        uint256 i;
        for (i = 0; _data.length >= 4 && i < 4; i++) {
            signature |= bytes4(_data[i]) >> i*8;
        }

        if (_to == RANDOM_CONTRACT) {
            abiParams = new bytes(_data.length - 4 > 32 ? 32 : _data.length - 4);

            for (i = 0; i < abiParams.length; i++) {
                abiParams[i] = _data[i + 4];
            }

            if (signature == bytes4(keccak256("commitHash(bytes32,bytes)"))) {
                (bytes32 secretHash) = abi.decode(abiParams, (bytes32));
                return (IRandomAuRa(RANDOM_CONTRACT).commitHashCallable(_sender, secretHash) ? CALL : NONE, false);
            } else if (signature == bytes4(keccak256("revealSecret(uint256)"))) {
                (uint256 secret) = abi.decode(abiParams, (uint256));
                return (IRandomAuRa(RANDOM_CONTRACT).revealSecretCallable(_sender, secret) ? CALL : NONE, false);
            } else {
                return (NONE, false);
            }
        }

        if (_to == VALIDATOR_SET_CONTRACT) {
            // The rules for the ValidatorSet contract
            if (signature == bytes4(keccak256("emitInitiateChange()"))) {
                // The `emitInitiateChange()` can be called by anyone
                // if `emitInitiateChangeCallable()` returns `true`
                return (validatorSet.emitInitiateChangeCallable() ? CALL : NONE, false);
            } else if (signature == bytes4(keccak256("reportMalicious(address,uint256,bytes)"))) {
                abiParams = new bytes(_data.length - 4 > 64 ? 64 : _data.length - 4);

                for (i = 0; i < abiParams.length; i++) {
                    abiParams[i] = _data[i + 4];
                }

                (
                    address maliciousMiningAddress,
                    uint256 blockNumber
                ) = abi.decode(
                    abiParams,
                    (address, uint256)
                );

                // The `reportMalicious()` can only be called by the validator's mining address
                // when the calling is allowed
                (bool callable,) = IValidatorSetAuRa(VALIDATOR_SET_CONTRACT).reportMaliciousCallable(
                    _sender, maliciousMiningAddress, blockNumber
                );

                return (callable ? CALL : NONE, false);
            } else if (_gasPrice > 0) {
                // The other functions of ValidatorSet contract can be called
                // by anyone except validators' mining addresses if gasPrice is not zero
                return (validatorSet.isValidator(_sender) ? NONE : CALL, false);
            }
        }

        if (validatorSet.isValidator(_sender) && _gasPrice > 0) {
            // Let the validator's mining address send their accumulated tx fees to some wallet
            return (_sender.balance > 0 ? BASIC : NONE, false);
        }

        if (validatorSet.isValidator(_to)) {
            // Validator's mining address can't receive any coins
            return (NONE, false);
        }

        // In other cases let the `_sender` create any transaction with non-zero gas price,
        // don't let them use a zero gas price
        return (_gasPrice > 0 ? ALL : NONE, false);
    }

    /// @dev Returns a boolean flag indicating whether the current block gas limit must be limited.
    /// See https://github.com/poanetwork/parity-ethereum/issues/119
    function limitBlockGas() public view returns(bool) {
        if (IBlockReward(BLOCK_REWARD_CONTRACT).isRewarding()) {
            return true;
        }
        uint256 stakingEpochEndBlock = IStakingAuRa(STAKING_CONTRACT).stakingEpochEndBlock();
        if (block.number == stakingEpochEndBlock - 1 || block.number == stakingEpochEndBlock) {
            return true;
        }
        if (IBlockReward(BLOCK_REWARD_CONTRACT).isSnapshotting()) {
            return true;
        }
        return false;
    }

    /// @dev Returns a boolean flag indicating whether the specified address is allowed
    /// to initiate transactions of any type. Used by the `allowedTxTypes` getter.
    /// See also the `addAllowedSender` and `removeAllowedSender` functions.
    /// @param _sender The specified address to check.
    function isSenderAllowed(address _sender) public view returns(bool) {
        uint256 allowedSendersLength = addressArrayStorage[ALLOWED_SENDERS].length;

        for (uint256 i = 0; i < allowedSendersLength; i++) {
            if (_sender == addressArrayStorage[ALLOWED_SENDERS][i]) {
                return true;
            }
        }

        return false;
    }

    // =============================================== Private ========================================================

    bytes32 internal constant ALLOWED_SENDERS = keccak256("allowedSenders");

    // Allowed transaction types mask
    uint32 internal constant NONE = 0;
    uint32 internal constant ALL = 0xffffffff;
    uint32 internal constant BASIC = 0x01;
    uint32 internal constant CALL = 0x02;
    uint32 internal constant CREATE = 0x04;
    uint32 internal constant PRIVATE = 0x08;

    /// @dev An internal function used by the `addAllowedSender` and `initialize` functions.
    /// @param _sender The address for which transactions of any type must be allowed.
    function _addAllowedSender(address _sender) internal {
        require(!isSenderAllowed(_sender));
        require(_sender != address(0));
        addressArrayStorage[ALLOWED_SENDERS].push(_sender);
    }
}
