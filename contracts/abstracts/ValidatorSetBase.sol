pragma solidity 0.5.2;

import "../interfaces/IBlockReward.sol";
import "../interfaces/IRandom.sol";
import "../interfaces/IStaking.sol";
import "../interfaces/IValidatorSet.sol";
import "../eternal-storage/OwnedEternalStorage.sol";
import "../libs/SafeMath.sol";


contract ValidatorSetBase is OwnedEternalStorage, IValidatorSet {
    using SafeMath for uint256;

    // TODO: add a description for each function

    // ============================================== Constants =======================================================

    uint256 public constant MAX_VALIDATORS = 19;

    // ================================================ Events ========================================================

    /// Issue this log event to signal a desired change in validator set.
    /// This will not lead to a change in active validator set until
    /// finalizeChange is called.
    ///
    /// Only the last log event of any block can take effect.
    /// If a signal is issued while another is being finalized it may never
    /// take effect.
    ///
    /// parentHash here should be the parent block hash, or the
    /// signal will not be recognized.
    event InitiateChange(bytes32 indexed parentHash, address[] newSet);

    // ============================================== Modifiers =======================================================

    modifier onlyStakingContract() {
        require(msg.sender == address(stakingContract()));
        _;
    }

    modifier onlySystem() {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    // =============================================== Setters ========================================================

    function clearUnremovableValidator() external {
        require(msg.sender == unremovableValidator() || msg.sender == _owner);
        _setUnremovableValidator(address(0));
    }

    function emitInitiateChange() external {
        require(emitInitiateChangeCallable());
        (address[] memory newSet, bool newStakingEpoch) = _dequeuePendingValidators();
        if (newSet.length > 0) {
            emit InitiateChange(blockhash(_getCurrentBlockNumber() - 1), newSet);
            _setInitiateChangeAllowed(false);
            _setQueueValidators(newSet, newStakingEpoch);
        }
    }

    function finalizeChange() external onlySystem {
        (address[] memory queueValidators, bool newStakingEpoch) = getQueueValidators();

        if (validatorSetApplyBlock() == 0 && newStakingEpoch) {
            // Apply new validator set after `newValidatorSet()` is called

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
            _setPreviousValidators(currentValidators);

            _applyQueueValidators(queueValidators);

            _setValidatorSetApplyBlock(_getCurrentBlockNumber());

            IBlockReward(blockRewardContract()).setPendingValidatorsEnqueued(false);
        } else if (queueValidators.length > 0) {
            // Apply new validator set after malicious validator is discovered
            _applyQueueValidators(queueValidators);
        }
        _setInitiateChangeAllowed(true);
    }

    /// Creates an initial set of validators at the start of the network.
    /// Must be called by the constructor of `InitializerAuRa` contract on genesis block.
    /// This is used instead of `constructor()` because this contract is upgradable.
    function initialize(
        address _blockRewardContract,
        address _randomContract,
        address _stakingContract,
        address[] calldata _initialMiningAddresses,
        address[] calldata _initialStakingAddresses,
        bool _firstValidatorIsUnremovable // must be `false` for production network
    ) external {
        require(_getCurrentBlockNumber() == 0); // initialization must be done on genesis block
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
        require(currentValidators.length == 0); // initialization can only be done once

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

        _setValidatorSetApplyBlock(1);

        uintStorage[QUEUE_PV_FIRST] = 1;
        uintStorage[QUEUE_PV_LAST] = 0;
    }

    function setStakingAddress(address _miningAddress, address _stakingAddress) external onlyStakingContract {
        _setStakingAddress(_miningAddress, _stakingAddress);
    }

    // =============================================== Getters ========================================================

    // Returns how many times the given address was banned
    function banCounter(address _miningAddress) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(BAN_COUNTER, _miningAddress))];
    }

    /// @dev Returns the block number or unix timestamp (depending on
    /// consensus algorithm) from which the address will be unbanned.
    /// @param _miningAddress The address of participant.
    /// @return The block number (for AuRa) or unix timestamp (for HBBFT)
    /// from which the address will be unbanned.
    function bannedUntil(address _miningAddress) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(BANNED_UNTIL, _miningAddress))
        ];
    }

    function blockRewardContract() public view returns(address) {
        return addressStorage[BLOCK_REWARD_CONTRACT];
    }

    // Returns the serial number of validator set changing request
    function changeRequestCount() public view returns(uint256) {
        return uintStorage[CHANGE_REQUEST_COUNT];
    }

    function emitInitiateChangeCallable() public view returns(bool) {
        return initiateChangeAllowed() && uintStorage[QUEUE_PV_LAST] >= uintStorage[QUEUE_PV_FIRST];
    }

    // Returns the set of validators which was actual at the end of previous staking epoch
    // (their mining addresses)
    function getPreviousValidators() public view returns(address[] memory) {
        return addressArrayStorage[PREVIOUS_VALIDATORS];
    }

    // Returns the set of pending validators
    // (their mining addresses)
    function getPendingValidators() public view returns(address[] memory) {
        return addressArrayStorage[PENDING_VALIDATORS];
    }

    // Returns the set of validators to be finalized in engine
    // (their mining addresses)
    function getQueueValidators() public view returns(address[] memory, bool) {
        return (addressArrayStorage[QUEUE_VALIDATORS], boolStorage[QUEUE_VALIDATORS_NEW_STAKING_EPOCH]);
    }

    // Returns the current set of validators (the same as in the engine)
    // (their mining addresses)
    function getValidators() public view returns(address[] memory) {
        return addressArrayStorage[CURRENT_VALIDATORS];
    }

    function initiateChangeAllowed() public view returns(bool) {
        return boolStorage[INITIATE_CHANGE_ALLOWED];
    }

    function isReportValidatorValid(address _miningAddress) public view returns(bool) {
        bool isValid = isValidator(_miningAddress) && !isValidatorBanned(_miningAddress);
        if (IStaking(stakingContract()).stakingEpoch() == 0 || validatorSetApplyBlock() == 0) {
            return isValid;
        }
        if (_getCurrentBlockNumber() - validatorSetApplyBlock() <= 20) {
            // The current validator set was applied in engine,
            // but we should let the previous validators finish
            // reporting malicious validator within a few blocks
            bool previousEpochValidator =
                isValidatorOnPreviousEpoch(_miningAddress) && !isValidatorBanned(_miningAddress);
            return isValid || previousEpochValidator;
        }
        return isValid;
    }

    // Returns the flag whether the mining address is in the `currentValidators` array
    function isValidator(address _miningAddress) public view returns(bool) {
        return boolStorage[keccak256(abi.encode(IS_VALIDATOR, _miningAddress))];
    }

    // Returns the flag whether the mining address was a validator at the end of previous staking epoch
    function isValidatorOnPreviousEpoch(address _miningAddress) public view returns(bool) {
        return boolStorage[keccak256(abi.encode(IS_VALIDATOR_ON_PREVIOUS_EPOCH, _miningAddress))];
    }

    function isValidatorBanned(address _miningAddress) public view returns(bool) {
        return _banStart() < bannedUntil(_miningAddress);
    }

    function miningByStakingAddress(address _stakingAddress) public view returns(address) {
        return addressStorage[keccak256(abi.encode(MINING_BY_STAKING_ADDRESS, _stakingAddress))];
    }

    function randomContract() public view returns(address) {
        return addressStorage[RANDOM_CONTRACT];
    }

    function stakingByMiningAddress(address _miningAddress) public view returns(address) {
        return addressStorage[keccak256(abi.encode(STAKING_BY_MINING_ADDRESS, _miningAddress))];
    }

    function stakingContract() public view returns(address) {
        return addressStorage[STAKING_CONTRACT];
    }

    function unremovableValidator() public view returns(address stakingAddress) {
        stakingAddress = addressStorage[UNREMOVABLE_STAKING_ADDRESS];
    }

    // Returns how many staking epochs the given address became a validator
    function validatorCounter(address _miningAddress) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(VALIDATOR_COUNTER, _miningAddress))];
    }

    // Returns the index of validator in the `currentValidators`
    function validatorIndex(address _miningAddress) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(VALIDATOR_INDEX, _miningAddress))
        ];
    }

    // Returns the block number when `finalizeChange` was called to apply the current validator set
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

    function _applyQueueValidators(address[] memory _queueValidators) internal {
        address[] memory prevValidators = getValidators();
        uint256 i;

        // Clear indexes for old validator set
        for (i = 0; i < prevValidators.length; i++) {
            _setValidatorIndex(prevValidators[i], 0);
            _setIsValidator(prevValidators[i], false);
        }

        _setCurrentValidators(_queueValidators);

        // Set indexes for new validator set
        for (i = 0; i < _queueValidators.length; i++) {
            _setValidatorIndex(_queueValidators[i], i);
            _setIsValidator(_queueValidators[i], true);
        }
    }

    function _banValidator(address _miningAddress) internal {
        if (_banStart() > bannedUntil(_miningAddress)) {
            uintStorage[keccak256(abi.encode(BAN_COUNTER, _miningAddress))]++;
        }

        uintStorage[keccak256(abi.encode(BANNED_UNTIL, _miningAddress))] = _banUntil();
    }

    function _enqueuePendingValidators(bool _newStakingEpoch) internal {
        uint256 queueFirst = uintStorage[QUEUE_PV_FIRST];
        uint256 queueLast = uintStorage[QUEUE_PV_LAST];

        for (uint256 i = queueLast; i >= queueFirst; i--) {
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
        uintStorage[QUEUE_PV_LAST] = queueLast;
    }

    function _dequeuePendingValidators() internal returns(address[] memory newSet, bool newStakingEpoch) {
        uint256 queueFirst = uintStorage[QUEUE_PV_FIRST];
        uint256 queueLast = uintStorage[QUEUE_PV_LAST];

        if (queueLast < queueFirst) {
            newSet = new address[](0);
            newStakingEpoch = false;
        } else {
            newSet = addressArrayStorage[keccak256(abi.encode(QUEUE_PV_LIST, queueFirst))];
            newStakingEpoch = boolStorage[keccak256(abi.encode(QUEUE_PV_NEW_EPOCH, queueFirst))];
            delete addressArrayStorage[keccak256(abi.encode(QUEUE_PV_LIST, queueFirst))];
            delete boolStorage[keccak256(abi.encode(QUEUE_PV_NEW_EPOCH, queueFirst))];
            delete uintStorage[keccak256(abi.encode(QUEUE_PV_BLOCK, queueFirst))];
            uintStorage[QUEUE_PV_FIRST]++;
        }
    }

    function _incrementChangeRequestCount() internal {
        uintStorage[CHANGE_REQUEST_COUNT]++;
    }

    function _newValidatorSet() internal returns(uint256) {
        IStaking staking = IStaking(stakingContract());
        address[] memory poolsToBeElected = staking.getPoolsToBeElected();
        address[] memory poolsToBeRemoved = staking.getPoolsToBeRemoved();
        address unremovableStakingAddress = unremovableValidator();

        // Choose new validators
        if (
            poolsToBeElected.length >= MAX_VALIDATORS &&
            (poolsToBeElected.length != MAX_VALIDATORS || unremovableStakingAddress != address(0))
        ) {
            uint256 randomNumber = IRandom(randomContract()).getCurrentSeed();

            (int256[] memory likelihood, int256 likelihoodSum) = staking.getPoolsLikelihood();
            address[] memory newValidators = new address[](
                unremovableStakingAddress == address(0) ? MAX_VALIDATORS : MAX_VALIDATORS - 1
            );

            uint256 poolsToBeElectedLength = poolsToBeElected.length;
            for (uint256 i = 0; i < newValidators.length; i++) {
                randomNumber = uint256(keccak256(abi.encode(randomNumber)));
                uint256 randomPoolIndex = _getRandomIndex(
                    likelihood,
                    likelihoodSum,
                    randomNumber
                );
                newValidators[i] = poolsToBeElected[randomPoolIndex];
                likelihoodSum -= likelihood[randomPoolIndex];
                poolsToBeElectedLength--;
                poolsToBeElected[randomPoolIndex] = poolsToBeElected[poolsToBeElectedLength];
                likelihood[randomPoolIndex] = likelihood[poolsToBeElectedLength];
            }

            poolsToBeElected = newValidators;
        }

        _setPendingValidators(staking, poolsToBeElected, poolsToBeRemoved, unremovableStakingAddress);

        // From this moment `getPendingValidators()` will return the new validator set

        staking.incrementStakingEpoch();
        _setValidatorSetApplyBlock(0);

        return poolsToBeElected.length;
    }

    function _removeMaliciousValidator(address _miningAddress) internal returns(bool) {
        uint256 i;
        address stakingAddress = stakingByMiningAddress(_miningAddress);

        if (stakingAddress == unremovableValidator()) {
            return false;
        }

        // Ban the malicious validator for the next 3 months
        _banValidator(_miningAddress);

        // Remove malicious validator from `pools` and remove
        // all ordered withdrawals from the pool of this validator
        IStaking(stakingContract()).removeMaliciousValidator(stakingAddress);

        address[] storage miningAddresses = addressArrayStorage[PENDING_VALIDATORS];
        bool isPendingValidator = false;

        for (i = 0; i < miningAddresses.length; i++) {
            if (miningAddresses[i] == _miningAddress) {
                isPendingValidator = true;
                break;
            }
        }

        if (isPendingValidator) {
            // Remove the malicious validator from `pendingValidators`
            miningAddresses[i] = miningAddresses[miningAddresses.length - 1];
            miningAddresses.length--;
            return true;
        }

        return false;
    }

    function _setCurrentValidators(address[] memory _miningAddresses) internal {
        addressArrayStorage[CURRENT_VALIDATORS] = _miningAddresses;
    }

    function _setInitiateChangeAllowed(bool _allowed) internal {
        boolStorage[INITIATE_CHANGE_ALLOWED] = _allowed;
    }

    function _setIsValidator(address _miningAddress, bool _isValidator) internal {
        boolStorage[keccak256(abi.encode(IS_VALIDATOR, _miningAddress))] = _isValidator;

        if (_isValidator) {
            uintStorage[keccak256(abi.encode(VALIDATOR_COUNTER, _miningAddress))]++;
        }
    }

    function _setIsValidatorOnPreviousEpoch(address _miningAddress, bool _isValidator) internal {
        boolStorage[keccak256(abi.encode(IS_VALIDATOR_ON_PREVIOUS_EPOCH, _miningAddress))] = _isValidator;
    }

    function _setPendingValidators(
        IStaking _stakingContract,
        address[] memory _stakingAddresses,
        address[] memory _poolsToBeRemoved,
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

        for (i = 0; i < _poolsToBeRemoved.length; i++) {
            _stakingContract.removePool(_poolsToBeRemoved[i]);
        }
    }

    function _setQueueValidators(address[] memory _miningAddresses, bool _newStakingEpoch) internal {
        addressArrayStorage[QUEUE_VALIDATORS] = _miningAddresses;
        boolStorage[QUEUE_VALIDATORS_NEW_STAKING_EPOCH] = _newStakingEpoch;
    }

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

    function _setPreviousValidators(address[] memory _miningAddresses) internal {
        addressArrayStorage[PREVIOUS_VALIDATORS] = _miningAddresses;
    }

    function _setUnremovableValidator(address _stakingAddress) internal {
        addressStorage[UNREMOVABLE_STAKING_ADDRESS] = _stakingAddress;
    }

    function _setValidatorIndex(address _miningAddress, uint256 _index) internal {
        uintStorage[
            keccak256(abi.encode(VALIDATOR_INDEX, _miningAddress))
        ] = _index;
    }

    function _setValidatorSetApplyBlock(uint256 _blockNumber) internal {
        uintStorage[VALIDATOR_SET_APPLY_BLOCK] = _blockNumber;
    }

    function _banStart() internal view returns(uint256);

    function _banUntil() internal view returns(uint256);

    function _getCurrentBlockNumber() internal view returns(uint256) {
        return block.number;
    }

    function _getRandomIndex(int256[] memory _likelihood, int256 _likelihoodSum, uint256 _randomNumber)
        internal
        pure
        returns(uint256)
    {
        int256 r = int256(_randomNumber % uint256(_likelihoodSum)) + 1;
        uint256 index = 0;
        while (true) {
            r -= _likelihood[index];
            if (r <= 0) break;
            index++;
        }
        return index;
    }
}
