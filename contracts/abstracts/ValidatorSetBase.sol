pragma solidity 0.5.9;

import "../interfaces/IBlockReward.sol";
import "../interfaces/IRandom.sol";
import "../interfaces/IStaking.sol";
import "../interfaces/IValidatorSet.sol";
import "../eternal-storage/OwnedEternalStorage.sol";
import "../libs/SafeMath.sol";


/// @dev The base contract for the ValidatorSetAuRa and ValidatorSetHBBFT contracts.
contract ValidatorSetBase is OwnedEternalStorage, IValidatorSet {
    using SafeMath for uint256;

    // ============================================== Constants =======================================================

    /// @dev The max number of validators.
    uint256 public constant MAX_VALIDATORS = 19;

    // ================================================ Events ========================================================

    /// @dev Emitted by the `emitInitiateChange` function when a new validator set
    /// needs to be applied in the Parity engine. See https://wiki.parity.io/Validator-Set.html
    /// @param parentHash Should be the parent block hash, otherwise the signal won't be recognized.
    /// @param newSet An array of new validators (their mining addresses).
    event InitiateChange(bytes32 indexed parentHash, address[] newSet);

    // ============================================== Modifiers =======================================================

    /// @dev Ensures the `initialize` function was called before.
    modifier onlyInitialized {
        require(isInitialized());
        _;
    }

    /// @dev Ensures the caller is the Staking contract address
    /// (EternalStorageProxy proxy contract for Staking).
    modifier onlyStakingContract() {
        require(msg.sender == stakingContract());
        _;
    }

    /// @dev Ensures the caller is the SYSTEM_ADDRESS. See https://wiki.parity.io/Validator-Set.html
    modifier onlySystem() {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    // =============================================== Setters ========================================================

    /// @dev Makes the non-removable validator removable. Can only be called by the staking address of the
    /// non-removable validator or by the `owner`.
    function clearUnremovableValidator() external onlyInitialized {
        address unremovableStakingAddress = unremovableValidator();
        require(msg.sender == unremovableStakingAddress || msg.sender == _owner);
        _setUnremovableValidator(address(0));
        IStaking(stakingContract()).clearUnremovableValidator(unremovableStakingAddress);
    }

    /// @dev Emits the `InitiateChange` event to pass a new validator set to the validator nodes.
    /// Called automatically by one of the current validator's nodes when the `emitInitiateChangeCallable` getter
    /// returns `true` (when some validator needs to be removed as malicious or the validator set needs to be
    /// updated at the beginning of a new staking epoch). The new validator set is passed to the validator nodes
    /// through the `InitiateChange` event and saved for later use by the `finalizeChange` function.
    /// See https://wiki.parity.io/Validator-Set.html for more info about the `InitiateChange` event.
    function emitInitiateChange() external onlyInitialized {
        require(emitInitiateChangeCallable());
        (address[] memory newSet, bool newStakingEpoch) = _dequeuePendingValidators();
        if (newSet.length > 0) {
            emit InitiateChange(blockhash(_getCurrentBlockNumber() - 1), newSet);
            _setInitiateChangeAllowed(false);
            _setQueueValidators(newSet, newStakingEpoch);
        }
    }

    /// @dev Called by the system when an initiated validator set change reaches finality and is activated.
    /// Only valid when msg.sender == SUPER_USER (EIP96, 2**160 - 2). Stores a new validator set saved
    /// before by the `emitInitiateChange` function and passed through the `InitiateChange` event.
    /// After this function is called, the `getValidators` getter returns the new validator set.
    /// If this function finalizes a new validator set formed by the `newValidatorSet` function,
    /// an old validator set is also stored and can be read by the `getPreviousValidators` getter.
    /// The `finalizeChange` is only called once for each `InitiateChange` event emitted. The next `InitiateChange`
    /// event is not emitted until the previous one is not yet finalized by the `finalizeChange`
    /// (this is achieved by the queue, `emitInitiateChange` function, and `initiateChangeAllowed` boolean flag -
    /// see the `_setInitiateChangeAllowed` function).
    function finalizeChange() external onlySystem {
        (address[] memory queueValidators, bool newStakingEpoch) = getQueueValidators();

        if (validatorSetApplyBlock() == 0 && newStakingEpoch) {
            // Apply a new validator set formed by the `newValidatorSet` function

            address[] memory previousValidators = getPreviousValidators();
            address[] memory currentValidators = getValidators();
            uint256 i;

            // Save the previous validator set
            for (i = 0; i < previousValidators.length; i++) {
                _setIsValidatorOnPreviousEpoch(previousValidators[i], false);
            }
            for (i = 0; i < currentValidators.length; i++) {
                _setIsValidatorOnPreviousEpoch(currentValidators[i], true);
            }
            addressArrayStorage[PREVIOUS_VALIDATORS] = currentValidators;

            _applyQueueValidators(queueValidators);

            _setValidatorSetApplyBlock(_getCurrentBlockNumber());
        } else if (queueValidators.length > 0) {
            // Apply new validator set after malicious validator is discovered
            _applyQueueValidators(queueValidators);
        } else {
            // This is the very first call of the `finalizeChange`
            _setValidatorSetApplyBlock(_getCurrentBlockNumber());
        }
        _setInitiateChangeAllowed(true);
    }

    /// @dev Initializes the network parameters. Used by the
    /// constructor of the `InitializerAuRa` or `InitializerHBBFT` contract.
    /// @param _blockRewardContract The address of the `BlockReward` contract.
    /// @param _randomContract The address of the `Random` contract.
    /// @param _stakingContract The address of the `Staking` contract.
    /// @param _initialMiningAddresses The array of initial validators' mining addresses.
    /// @param _initialStakingAddresses The array of initial validators' staking addresses.
    /// @param _firstValidatorIsUnremovable The boolean flag defining whether the first validator in the
    /// `_initialMiningAddresses/_initialStakingAddresses` array is non-removable.
    /// Must be `false` for a production network.
    function initialize(
        address _blockRewardContract,
        address _randomContract,
        address _stakingContract,
        address[] calldata _initialMiningAddresses,
        address[] calldata _initialStakingAddresses,
        bool _firstValidatorIsUnremovable
    ) external {
        require(!isInitialized()); // initialization can only be done once
        require(_blockRewardContract != address(0));
        require(_randomContract != address(0));
        require(_stakingContract != address(0));
        require(_initialMiningAddresses.length > 0);
        require(_initialMiningAddresses.length == _initialStakingAddresses.length);

        addressStorage[BLOCK_REWARD_CONTRACT] = _blockRewardContract;
        addressStorage[RANDOM_CONTRACT] = _randomContract;
        addressStorage[STAKING_CONTRACT] = _stakingContract;

        address[] storage currentValidators = addressArrayStorage[CURRENT_VALIDATORS];
        address[] storage pendingValidators = addressArrayStorage[PENDING_VALIDATORS];

        // Add initial validators to the `currentValidators` array
        for (uint256 i = 0; i < _initialMiningAddresses.length; i++) {
            currentValidators.push(_initialMiningAddresses[i]);
            pendingValidators.push(_initialMiningAddresses[i]);
            _setValidatorIndex(_initialMiningAddresses[i], i);
            _setIsValidator(_initialMiningAddresses[i], true);
            _setStakingAddress(_initialMiningAddresses[i], _initialStakingAddresses[i]);
        }

        if (_firstValidatorIsUnremovable) {
            _setUnremovableValidator(_initialStakingAddresses[0]);
        }

        intStorage[QUEUE_PV_FIRST] = 1;
        intStorage[QUEUE_PV_LAST] = 0;
    }

    /// @dev Binds a mining address to the specified staking address. Called by the `Staking.addPool` function
    /// when a user wants to become a candidate and create a pool.
    /// See also the `miningByStakingAddress` and `stakingByMiningAddress` getters.
    /// @param _miningAddress The mining address of the newly created pool. Cannot be equal to the `_stakingAddress`.
    /// @param _stakingAddress The staking address of the newly created pool. Cannot be equal to the `_miningAddress`.
    function setStakingAddress(address _miningAddress, address _stakingAddress) external onlyStakingContract {
        _setStakingAddress(_miningAddress, _stakingAddress);
    }

    // =============================================== Getters ========================================================

    /// @dev Returns how many times a given mining address was banned.
    /// @param _miningAddress The mining address of a candidate or validator.
    function banCounter(address _miningAddress) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(BAN_COUNTER, _miningAddress))];
    }

    /// @dev Returns the block number or unix timestamp (depending on the consensus algorithm)
    /// when the ban will be lifted for the specified mining address.
    /// @param _miningAddress The mining address of a participant.
    /// @return The block number (for AuRa) or unix timestamp (for HBBFT) from which the ban will be lifted for the
    /// specified address.
    function bannedUntil(address _miningAddress) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(BANNED_UNTIL, _miningAddress))];
    }

    /// @dev Returns the address of the `BlockReward` contract.
    function blockRewardContract() public view returns(address) {
        return addressStorage[BLOCK_REWARD_CONTRACT];
    }

    /// @dev Returns the serial number of a validator set change request. The counter is incremented
    /// by the `_incrementChangeRequestCount` function every time a validator set needs to be changed.
    function changeRequestCount() public view returns(uint256) {
        return uintStorage[CHANGE_REQUEST_COUNT];
    }

    /// @dev Returns a boolean flag indicating whether the `emitInitiateChange` function can be called
    /// at the moment. Used by a validator's node and `TxPermission` contract (to deny dummy calling).
    function emitInitiateChangeCallable() public view returns(bool) {
        return initiateChangeAllowed() && intStorage[QUEUE_PV_LAST] >= intStorage[QUEUE_PV_FIRST];
    }

    /// @dev Returns the validator set (validators' mining addresses array) which was active
    /// at the end of the previous staking epoch. The array is stored by the `finalizeChange` function
    /// when a new staking epoch's validator set is finalized.
    function getPreviousValidators() public view returns(address[] memory) {
        return addressArrayStorage[PREVIOUS_VALIDATORS];
    }

    /// @dev Returns the current array of validators which is not yet finalized by the
    /// `finalizeChange` function. The pending array is changed when a validator is removed as malicious
    /// or the validator set is updated at the beginning of a new staking epoch (see the `_newValidatorSet` function).
    /// Every time the pending array is updated, it is enqueued by the `_enqueuePendingValidators` and then
    /// dequeued by the `emitInitiateChange` function which emits the `InitiateChange` event to all
    /// validator nodes.
    function getPendingValidators() public view returns(address[] memory) {
        return addressArrayStorage[PENDING_VALIDATORS];
    }

    /// @dev Returns a validator set to be finalized by the `finalizeChange` function.
    /// Used by the `finalizeChange` function.
    /// @param miningAddresses An array set by the `emitInitiateChange` function.
    /// @param newStakingEpoch A boolean flag indicating whether the `miningAddresses` array was formed by the
    /// `_newValidatorSet` function. The `finalizeChange` function logic depends on this flag.
    function getQueueValidators() public view returns(address[] memory miningAddresses, bool newStakingEpoch) {
        return (addressArrayStorage[QUEUE_VALIDATORS], boolStorage[QUEUE_VALIDATORS_NEW_STAKING_EPOCH]);
    }

    /// @dev Returns the current validator set (an array of mining addresses)
    /// which always matches the validator set in the Parity engine.
    function getValidators() public view returns(address[] memory miningAddresses) {
        return addressArrayStorage[CURRENT_VALIDATORS];
    }

    /// @dev Returns a boolean flag indicating whether the `emitInitiateChange` can be called at the moment.
    /// Used by the `emitInitiateChangeCallable` getter. This flag is set to `false` by the `emitInitiateChange`
    /// and set to `true` by the `finalizeChange` function. When the `InitiateChange` event is emitted by
    /// `emitInitiateChange`, the next `emitInitiateChange` call is not possible until the previous call is
    /// finalized by the `finalizeChange` function.
    function initiateChangeAllowed() public view returns(bool) {
        return boolStorage[INITIATE_CHANGE_ALLOWED];
    }

    /// @dev Returns a boolean flag indicating if the `initialize` function has been called.
    function isInitialized() public view returns(bool) {
        return addressStorage[BLOCK_REWARD_CONTRACT] != address(0);
    }

    /// @dev Returns a boolean flag indicating whether the specified validator (mining address)
    /// can call the `reportMalicious` function or whether the specified validator (mining address)
    /// can be reported as malicious. This function also allows a validator to call the `reportMalicious`
    /// function several blocks after ceasing to be a validator. This is possible if a
    /// validator did not have the opportunity to call the `reportMalicious` function prior to the
    /// engine calling the `finalizeChange` function.
    /// @param _miningAddress The validator's mining address.
    function isReportValidatorValid(address _miningAddress) public view returns(bool) {
        bool isValid = isValidator(_miningAddress) && !isValidatorBanned(_miningAddress);
        if (IStaking(stakingContract()).stakingEpoch() == 0 || validatorSetApplyBlock() == 0) {
            return isValid;
        }
        if (_getCurrentBlockNumber() - validatorSetApplyBlock() <= 20) {
            // The current validator set was finalized by the engine,
            // but we should let the previous validators finish
            // reporting malicious validator within a few blocks
            bool previousEpochValidator =
                isValidatorOnPreviousEpoch(_miningAddress) && !isValidatorBanned(_miningAddress);
            return isValid || previousEpochValidator;
        }
        return isValid;
    }

    /// @dev Returns a boolean flag indicating whether the specified mining address is in the current validator set.
    /// See the `getValidators` getter.
    /// @param _miningAddress The mining address.
    function isValidator(address _miningAddress) public view returns(bool) {
        return boolStorage[keccak256(abi.encode(IS_VALIDATOR, _miningAddress))];
    }

    /// @dev Returns a boolean flag indicating whether the specified mining address was a validator at the end of
    /// the previous staking epoch. See the `getPreviousValidators` getter.
    /// @param _miningAddress The mining address.
    function isValidatorOnPreviousEpoch(address _miningAddress) public view returns(bool) {
        return boolStorage[keccak256(abi.encode(IS_VALIDATOR_ON_PREVIOUS_EPOCH, _miningAddress))];
    }

    /// @dev Returns a boolean flag indicating whether the specified mining address is currently banned.
    /// A validator can be banned when they misbehave (see the `_banValidator` function).
    /// @param _miningAddress The mining address.
    function isValidatorBanned(address _miningAddress) public view returns(bool) {
        return _banStart() < bannedUntil(_miningAddress);
    }

    /// @dev Returns a mining address bound to a specified staking address.
    /// See the `_setStakingAddress` function.
    /// @param _stakingAddress The staking address for which the function must return the corresponding mining address.
    function miningByStakingAddress(address _stakingAddress) public view returns(address) {
        return addressStorage[keccak256(abi.encode(MINING_BY_STAKING_ADDRESS, _stakingAddress))];
    }

    /// @dev Returns the `Random` contract address.
    function randomContract() public view returns(address) {
        return addressStorage[RANDOM_CONTRACT];
    }

    /// @dev Returns a staking address bound to a specified mining address.
    /// See the `_setStakingAddress` function.
    /// @param _miningAddress The mining address for which the function must return the corresponding staking address.
    function stakingByMiningAddress(address _miningAddress) public view returns(address) {
        return addressStorage[keccak256(abi.encode(STAKING_BY_MINING_ADDRESS, _miningAddress))];
    }

    /// @dev Returns the `Staking` contract address.
    function stakingContract() public view returns(address) {
        return addressStorage[STAKING_CONTRACT];
    }

    /// @dev Returns the staking address of the non-removable validator.
    /// Returns zero if a non-removable validator is not defined.
    function unremovableValidator() public view returns(address stakingAddress) {
        stakingAddress = addressStorage[UNREMOVABLE_STAKING_ADDRESS];
    }

    /// @dev Returns how many times the given address has become a validator.
    /// @param _miningAddress The mining address.
    function validatorCounter(address _miningAddress) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(VALIDATOR_COUNTER, _miningAddress))];
    }

    /// @dev Returns the index of the specified validator in the current validator set
    /// returned by the `getValidators` getter.
    /// @param _miningAddress The mining address the index is returned for.
    /// @return If the returned value is zero, it may mean the array doesn't contain the address.
    /// Check the address is in the current validator set using the `isValidator` getter.
    function validatorIndex(address _miningAddress) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(VALIDATOR_INDEX, _miningAddress))];
    }

    /// @dev Returns the block number when the `finalizeChange` function was called to apply
    /// the current validator set formed by the `_newValidatorSet` function. If it returns zero,
    /// it means the `_newValidatorSet` function has already been called (a new staking epoch has been started),
    /// but the new staking epoch's validator set hasn't yet been finalized by the `finalizeChange` function.
    /// See the `_setValidatorSetApplyBlock` function which is called by the `finalizeChange` and
    /// `_newValidatorSet` functions.
    function validatorSetApplyBlock() public view returns(uint256) {
        return uintStorage[VALIDATOR_SET_APPLY_BLOCK];
    }

    // =============================================== Private ========================================================

    bytes32 internal constant BLOCK_REWARD_CONTRACT = keccak256("blockRewardContract");
    bytes32 internal constant CHANGE_REQUEST_COUNT = keccak256("changeRequestCount");
    bytes32 internal constant CURRENT_VALIDATORS = keccak256("currentValidators");
    bytes32 internal constant INITIATE_CHANGE_ALLOWED = keccak256("initiateChangeAllowed");
    bytes32 internal constant PENDING_VALIDATORS = keccak256("pendingValidators");
    bytes32 internal constant PREVIOUS_VALIDATORS = keccak256("previousValidators");
    bytes32 internal constant QUEUE_PV_FIRST = keccak256("queuePVFirst");
    bytes32 internal constant QUEUE_PV_LAST = keccak256("queuePVLast");
    bytes32 internal constant QUEUE_VALIDATORS = keccak256("queueValidators");
    bytes32 internal constant QUEUE_VALIDATORS_NEW_STAKING_EPOCH = keccak256("queueValidatorsNewStakingEpoch");
    bytes32 internal constant RANDOM_CONTRACT = keccak256("randomContract");
    bytes32 internal constant STAKING_CONTRACT = keccak256("stakingContract");
    bytes32 internal constant UNREMOVABLE_STAKING_ADDRESS = keccak256("unremovableStakingAddress");
    bytes32 internal constant VALIDATOR_SET_APPLY_BLOCK = keccak256("validatorSetApplyBlock");

    bytes32 internal constant BAN_COUNTER = "banCounter";
    bytes32 internal constant BANNED_UNTIL = "bannedUntil";
    bytes32 internal constant IS_VALIDATOR = "isValidator";
    bytes32 internal constant IS_VALIDATOR_ON_PREVIOUS_EPOCH = "isValidatorOnPreviousEpoch";
    bytes32 internal constant MINING_BY_STAKING_ADDRESS = "miningByStakingAddress";
    bytes32 internal constant QUEUE_PV_BLOCK = "queuePVBlock";
    bytes32 internal constant QUEUE_PV_LIST = "queuePVList";
    bytes32 internal constant QUEUE_PV_NEW_EPOCH = "queuePVNewEpoch";
    bytes32 internal constant STAKING_BY_MINING_ADDRESS = "stakingByMiningAddress";
    bytes32 internal constant VALIDATOR_COUNTER = "validatorCounter";
    bytes32 internal constant VALIDATOR_INDEX = "validatorIndex";

    /// @dev Sets a new validator set returned by the `getValidators` getter.
    /// Called by the `finalizeChange` function.
    /// @param _queueValidators An array of new validators (their mining addresses).
    function _applyQueueValidators(address[] memory _queueValidators) internal {
        address[] memory prevValidators = getValidators();
        uint256 i;

        // Clear indexes for old validator set
        for (i = 0; i < prevValidators.length; i++) {
            _setValidatorIndex(prevValidators[i], 0);
            _setIsValidator(prevValidators[i], false);
        }

        addressArrayStorage[CURRENT_VALIDATORS] = _queueValidators;

        // Set indexes for new validator set
        for (i = 0; i < _queueValidators.length; i++) {
            _setValidatorIndex(_queueValidators[i], i);
            _setIsValidator(_queueValidators[i], true);
        }
    }

    /// @dev Sets the future block number or unix timestamp (depending on the consensus algorithm)
    /// until which the specified mining address is banned. Updates the banning statistics.
    /// Called by the `_removeMaliciousValidator` function.
    /// @param _miningAddress The banned mining address.
    function _banValidator(address _miningAddress) internal {
        if (_banStart() > bannedUntil(_miningAddress)) {
            uintStorage[keccak256(abi.encode(BAN_COUNTER, _miningAddress))]++;
        }

        uintStorage[keccak256(abi.encode(BANNED_UNTIL, _miningAddress))] = _banUntil();
    }

    /// @dev Enqueues the pending validator set which is returned by the `getPendingValidators` getter
    /// to be dequeued later by the `emitInitiateChange` function. Called when a validator is removed
    /// from the set as malicious or when a new validator set is formed by the `_newValidatorSet` function.
    /// @param _newStakingEpoch A boolean flag defining whether the pending validator set was formed by the
    /// `_newValidatorSet` function. The `finalizeChange` function logic depends on this flag.
    function _enqueuePendingValidators(bool _newStakingEpoch) internal {
        int256 queueFirst = intStorage[QUEUE_PV_FIRST];
        int256 queueLast = intStorage[QUEUE_PV_LAST];

        for (int256 i = queueLast; i >= queueFirst; i--) {
            if (uintStorage[keccak256(abi.encode(QUEUE_PV_BLOCK, i))] == _getCurrentBlockNumber()) {
                addressArrayStorage[keccak256(abi.encode(QUEUE_PV_LIST, i))] = getPendingValidators();
                if (_newStakingEpoch) {
                    boolStorage[keccak256(abi.encode(QUEUE_PV_NEW_EPOCH, i))] = true;
                }
                return;
            }
        }

        queueLast++;
        addressArrayStorage[keccak256(abi.encode(QUEUE_PV_LIST, queueLast))] = getPendingValidators();
        boolStorage[keccak256(abi.encode(QUEUE_PV_NEW_EPOCH, queueLast))] = _newStakingEpoch;
        uintStorage[keccak256(abi.encode(QUEUE_PV_BLOCK, queueLast))] = _getCurrentBlockNumber();
        intStorage[QUEUE_PV_LAST] = queueLast;
    }

    /// @dev Dequeues the pending validator set to pass it to the `InitiateChange` event
    /// (and then to the `finalizeChange` function). Called by the `emitInitiateChange` function.
    /// @param newSet An array of mining addresses.
    /// @param newStakingEpoch A boolean flag indicating whether the `newSet` array was formed by the
    /// `_newValidatorSet` function. The `finalizeChange` function logic depends on this flag.
    function _dequeuePendingValidators() internal returns(address[] memory newSet, bool newStakingEpoch) {
        int256 queueFirst = intStorage[QUEUE_PV_FIRST];
        int256 queueLast = intStorage[QUEUE_PV_LAST];

        if (queueLast < queueFirst) {
            newSet = new address[](0);
            newStakingEpoch = false;
        } else {
            newSet = addressArrayStorage[keccak256(abi.encode(QUEUE_PV_LIST, queueFirst))];
            newStakingEpoch = boolStorage[keccak256(abi.encode(QUEUE_PV_NEW_EPOCH, queueFirst))];
            delete addressArrayStorage[keccak256(abi.encode(QUEUE_PV_LIST, queueFirst))];
            delete boolStorage[keccak256(abi.encode(QUEUE_PV_NEW_EPOCH, queueFirst))];
            delete uintStorage[keccak256(abi.encode(QUEUE_PV_BLOCK, queueFirst))];
            intStorage[QUEUE_PV_FIRST]++;
        }
    }

    /// @dev Increments the serial number of a validator set changing request. The counter is incremented
    /// every time a validator set needs to be changed.
    function _incrementChangeRequestCount() internal {
        uintStorage[CHANGE_REQUEST_COUNT]++;
    }

    /// @dev An internal function implementing the logic which forms a new validator set. If the number of active pools
    /// is greater than MAX_VALIDATORS, the logic chooses the validators randomly using a random seed generated and
    /// stored by the `Random` contract.
    /// This function is called by the `newValidatorSet` function of a child contract.
    /// @return The number of pools ready to be elected (see the `Staking.getPoolsToBeElected` function).
    function _newValidatorSet() internal returns(uint256) {
        IStaking staking = IStaking(stakingContract());
        address[] memory poolsToBeElected = staking.getPoolsToBeElected();
        address unremovableStakingAddress = unremovableValidator();

        // Choose new validators
        if (
            poolsToBeElected.length >= MAX_VALIDATORS &&
            (poolsToBeElected.length != MAX_VALIDATORS || unremovableStakingAddress != address(0))
        ) {
            uint256 randomNumber = IRandom(randomContract()).getCurrentSeed();

            (uint256[] memory likelihood, uint256 likelihoodSum) = staking.getPoolsLikelihood();

            if (likelihood.length > 0 && likelihoodSum > 0) {
                address[] memory newValidators = new address[](
                    unremovableStakingAddress == address(0) ? MAX_VALIDATORS : MAX_VALIDATORS - 1
                );

                uint256 poolsToBeElectedLength = poolsToBeElected.length;
                for (uint256 i = 0; i < newValidators.length; i++) {
                    randomNumber = uint256(keccak256(abi.encode(randomNumber)));
                    uint256 randomPoolIndex = _getRandomIndex(likelihood, likelihoodSum, randomNumber);
                    newValidators[i] = poolsToBeElected[randomPoolIndex];
                    likelihoodSum -= likelihood[randomPoolIndex];
                    poolsToBeElectedLength--;
                    poolsToBeElected[randomPoolIndex] = poolsToBeElected[poolsToBeElectedLength];
                    likelihood[randomPoolIndex] = likelihood[poolsToBeElectedLength];
                }

                _setPendingValidators(staking, newValidators, unremovableStakingAddress);
            }
        } else {
            _setPendingValidators(staking, poolsToBeElected, unremovableStakingAddress);
        }

        // From this moment the `getPendingValidators()` will return a new validator set

        staking.incrementStakingEpoch();
        _setValidatorSetApplyBlock(0);

        _incrementChangeRequestCount();
        _enqueuePendingValidators(true);

        return poolsToBeElected.length;
    }

    /// @dev Removes the specified validator as malicious. Used by a child contract.
    /// @param _miningAddress The removed validator mining address.
    /// @return Returns `true` if the specified validator has been removed from the pending validator set.
    /// Otherwise returns `false` (if the specified validator was already removed).
    function _removeMaliciousValidator(address _miningAddress) internal returns(bool) {
        address stakingAddress = stakingByMiningAddress(_miningAddress);

        if (stakingAddress == unremovableValidator()) {
            return false;
        }

        // Ban the malicious validator for the next 3 months
        _banValidator(_miningAddress);

        // Remove malicious validator from the `pools`
        IStaking(stakingContract()).removePool(stakingAddress);

        address[] storage miningAddresses = addressArrayStorage[PENDING_VALIDATORS];

        for (uint256 i = 0; i < miningAddresses.length; i++) {
            if (miningAddresses[i] == _miningAddress) {
                // Remove the malicious validator from `pendingValidators`
                miningAddresses[i] = miningAddresses[miningAddresses.length - 1];
                miningAddresses.length--;
                return true;
            }
        }

        return false;
    }

    /// @dev Sets a boolean flag defining whether the `emitInitiateChange` can be called.
    /// Called by the `emitInitiateChange` and `finalizeChange` functions.
    /// See the `initiateChangeAllowed` getter.
    /// @param _allowed The boolean flag.
    function _setInitiateChangeAllowed(bool _allowed) internal {
        boolStorage[INITIATE_CHANGE_ALLOWED] = _allowed;
    }

    /// @dev Sets a boolean flag defining whether the specified mining address is a validator
    /// (whether it is existed in the array returned by the `getValidators` getter).
    /// See the `_applyQueueValidators` function and `isValidator`/`getValidators` getters.
    /// @param _miningAddress The mining address.
    /// @param _isValidator The boolean flag.
    function _setIsValidator(address _miningAddress, bool _isValidator) internal {
        boolStorage[keccak256(abi.encode(IS_VALIDATOR, _miningAddress))] = _isValidator;

        if (_isValidator) {
            uintStorage[keccak256(abi.encode(VALIDATOR_COUNTER, _miningAddress))]++;
        }
    }

    /// @dev Sets a boolean flag indicating whether the specified mining address was a validator at the end of
    /// the previous staking epoch. See the `getPreviousValidators` and `isValidatorOnPreviousEpoch` getters.
    /// @param _miningAddress The mining address.
    /// @param _isValidator The boolean flag.
    function _setIsValidatorOnPreviousEpoch(address _miningAddress, bool _isValidator) internal {
        boolStorage[keccak256(abi.encode(IS_VALIDATOR_ON_PREVIOUS_EPOCH, _miningAddress))] = _isValidator;
    }

    /// @dev Sets a new validator set as a pending (which is not yet finalized by the `finalizeChange` function).
    /// Removes the pools in the `poolsToBeRemoved` array (see the `Staking.getPoolsToBeRemoved` function).
    /// Called by the `_newValidatorSet` function.
    /// @param _stakingContract The `Staking` contract address.
    /// @param _stakingAddresses The array of the new validators' staking addresses.
    /// @param _unremovableStakingAddress The staking address of a non-removable validator.
    /// See the `unremovableValidator` getter.
    function _setPendingValidators(
        IStaking _stakingContract,
        address[] memory _stakingAddresses,
        address _unremovableStakingAddress
    ) internal {
        if (_stakingAddresses.length == 0) return;

        uint256 i;

        delete addressArrayStorage[PENDING_VALIDATORS];

        if (_unremovableStakingAddress != address(0)) {
            addressArrayStorage[PENDING_VALIDATORS].push(miningByStakingAddress(_unremovableStakingAddress));
        }

        for (i = 0; i < _stakingAddresses.length; i++) {
            addressArrayStorage[PENDING_VALIDATORS].push(miningByStakingAddress(_stakingAddresses[i]));
        }

        address[] memory poolsToBeRemoved = _stakingContract.getPoolsToBeRemoved();
        for (i = 0; i < poolsToBeRemoved.length; i++) {
            _stakingContract.removePool(poolsToBeRemoved[i]);
        }
    }

    /// @dev Sets a validator set for the `finalizeChange` function.
    /// Called by the `emitInitiateChange` function.
    /// @param _miningAddresses An array of the new validator set mining addresses.
    /// @param _newStakingEpoch A boolean flag indicating whether the `_miningAddresses` array was formed by the
    /// `_newValidatorSet` function. The `finalizeChange` function logic depends on this flag.
    function _setQueueValidators(address[] memory _miningAddresses, bool _newStakingEpoch) internal {
        addressArrayStorage[QUEUE_VALIDATORS] = _miningAddresses;
        boolStorage[QUEUE_VALIDATORS_NEW_STAKING_EPOCH] = _newStakingEpoch;
    }

    /// @dev Binds a mining address to the specified staking address. Used by the `setStakingAddress` function.
    /// See also the `miningByStakingAddress` and `stakingByMiningAddress` getters.
    /// @param _miningAddress The mining address of a newly created pool. Cannot be equal to the `_stakingAddress`.
    /// @param _stakingAddress The staking address of a newly created pool. Cannot be equal to the `_miningAddress`.
    function _setStakingAddress(address _miningAddress, address _stakingAddress) internal {
        require(_miningAddress != address(0));
        require(_stakingAddress != address(0));
        require(_miningAddress != _stakingAddress);
        require(miningByStakingAddress(_stakingAddress) == address(0));
        require(miningByStakingAddress(_miningAddress) == address(0));
        require(stakingByMiningAddress(_stakingAddress) == address(0));
        require(stakingByMiningAddress(_miningAddress) == address(0));
        addressStorage[keccak256(abi.encode(MINING_BY_STAKING_ADDRESS, _stakingAddress))] = _miningAddress;
        addressStorage[keccak256(abi.encode(STAKING_BY_MINING_ADDRESS, _miningAddress))] = _stakingAddress;
    }

    /// @dev Sets the staking address of a non-removable validator.
    /// Used by the `initialize` and `clearUnremovableValidator` functions.
    /// @param _stakingAddress The staking address of a non-removable validator.
    function _setUnremovableValidator(address _stakingAddress) internal {
        addressStorage[UNREMOVABLE_STAKING_ADDRESS] = _stakingAddress;
    }

    /// @dev Stores the index of the specified validator in the current validator set
    /// returned by the `getValidators` getter. Used by the `_applyQueueValidators` function.
    /// @param _miningAddress The mining address the index is saved for.
    /// @param _index The index value.
    function _setValidatorIndex(address _miningAddress, uint256 _index) internal {
        uintStorage[keccak256(abi.encode(VALIDATOR_INDEX, _miningAddress))] = _index;
    }

    /// @dev Sets the block number at which the `finalizeChange` function was called to apply
    /// the current validator set formed by the `_newValidatorSet` function.
    /// Called by the `finalizeChange` and `_newValidatorSet` functions.
    /// @param _blockNumber The current block number. Set to zero when calling with `_newValidatorSet`.
    function _setValidatorSetApplyBlock(uint256 _blockNumber) internal {
        uintStorage[VALIDATOR_SET_APPLY_BLOCK] = _blockNumber;
    }

    /// @dev Returns the current block number or unix timestamp (depending on the consensus algorithm).
    /// Used by the `isValidatorBanned`, `_banUntil`, and `_banValidator` functions.
    function _banStart() internal view returns(uint256);

    /// @dev Returns the future block number or unix timestamp (depending on the consensus algorithm)
    /// until which a validator is banned.
    function _banUntil() internal view returns(uint256);

    /// @dev Returns the current block number. Needed mostly for unit tests.
    function _getCurrentBlockNumber() internal view returns(uint256) {
        return block.number;
    }

    /// @dev Returns an index of a pool in the `poolsToBeElected` array (see the `Staking.getPoolsToBeElected` getter)
    /// by a random number and the corresponding probability coefficients.
    /// @param _likelihood An array of probability coefficients.
    /// @param _likelihoodSum A sum of probability coefficients.
    /// @param _randomNumber A random number.
    function _getRandomIndex(uint256[] memory _likelihood, uint256 _likelihoodSum, uint256 _randomNumber)
        internal
        pure
        returns(uint256)
    {
        uint256 random = _randomNumber % _likelihoodSum;
        uint256 sum = 0;
        uint256 index = 0;
        while (sum <= random) {
            sum += _likelihood[index];
            index++;
        }
        return index - 1;
    }
}
