pragma solidity 0.5.2;

import "../interfaces/IBlockReward.sol";
import "../interfaces/IERC20Minting.sol";
import "../interfaces/IRandom.sol";
import "../interfaces/IValidatorSet.sol";
import "../eternal-storage/OwnedEternalStorage.sol";
import "../libs/SafeMath.sol";


contract ValidatorSetBase is OwnedEternalStorage, IValidatorSet {
    using SafeMath for uint256;

    // TODO: add a description for each function

    // ============================================== Constants =======================================================

    // These values must be set before deploy
    uint256 public constant MAX_CANDIDATES = 2000;
    uint256 public constant MAX_VALIDATORS = 20;
    uint256 public constant STAKE_UNIT = 1 ether;

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

    /// @dev Emitted by `stake` function to signal that the staker made a stake of the specified
    /// amount for the specified pool during the specified staking epoch.
    /// @param toPool The pool for which the `staker` made the stake.
    /// @param staker The address of staker who made the stake.
    /// @param stakingEpoch The serial number of staking epoch during which the stake was made.
    /// @param amount The amount of the stake.
    event Staked(
        address indexed toPool,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount
    );

    /// @dev Emitted by `moveStake` function to signal that the staker moved the specified
    /// amount of a stake from one pool to another during the specified staking epoch.
    /// @param fromPool The pool from which the `staker` moved the stake.
    /// @param toPool The pool to which the `staker` moved the stake.
    /// @param staker The address of staker who moved the `amount`.
    /// @param stakingEpoch The serial number of staking epoch during which the `amount` was moved.
    /// @param amount The amount of the stake.
    event StakeMoved(
        address fromPool,
        address indexed toPool,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount
    );

    /// @dev Emitted by `withdraw` function to signal that the staker withdrew the specified
    /// amount of a stake from the specified pool during the specified staking epoch.
    /// @param fromPool The pool from which the `staker` withdrew `amount`.
    /// @param staker The address of staker who withdrew `amount`.
    /// @param stakingEpoch The serial number of staking epoch during which the withdrawal was made.
    /// @param amount The amount of the withdrawal.
    event Withdrawn(
        address indexed fromPool,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount
    );

    // ============================================== Modifiers =======================================================

    modifier gasPriceIsValid() {
        require(tx.gasprice != 0);
        _;
    }

    modifier onlySystem() {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    // =============================================== Setters ========================================================

    function emitInitiateChange() external {
        require(emitInitiateChangeCallable());
        (address[] memory newSet, bool newStakingEpoch) = _dequeuePendingValidators();
        if (newSet.length > 0) {
            emit InitiateChange(blockhash(block.number - 1), newSet);
            _setInitiateChangeAllowed(false);
            _setQueueValidators(newSet, newStakingEpoch);
        }
    }

    function removePool() public gasPriceIsValid {
        if (stakingEpoch() == 0 && isValidator(msg.sender)) {
            revert(); // initial validator cannot remove his pool during the initial staking epoch
        }
        _removeFromPools(msg.sender);
    }

    function finalizeChange() public onlySystem {
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

            // Set a new snapshot inside BlockReward contract
            IBlockReward(blockRewardContract()).setSnapshot();
        } else if (queueValidators.length > 0) {
            // Apply new validator set after `reportMalicious` is called
            _applyQueueValidators(queueValidators);
        }
        _setInitiateChangeAllowed(true);
    }

    function moveStake(address _fromPool, address _toPool, uint256 _amount) public gasPriceIsValid {
        require(_fromPool != _toPool);
        address staker = msg.sender;
        _withdraw(_fromPool, staker, _amount);
        _stake(_toPool, staker, _amount);
        emit StakeMoved(_fromPool, _toPool, staker, stakingEpoch(), _amount);
    }

    function stake(address _toPool, uint256 _amount) public gasPriceIsValid {
        IERC20Minting tokenContract = IERC20Minting(erc20TokenContract());
        require(address(tokenContract) != address(0));
        address staker = msg.sender;
        _stake(_toPool, staker, _amount);
        tokenContract.stake(staker, _amount);
        emit Staked(_toPool, staker, stakingEpoch(), _amount);
    }

    function withdraw(address _fromPool, uint256 _amount) public gasPriceIsValid {
        IERC20Minting tokenContract = IERC20Minting(erc20TokenContract());
        require(address(tokenContract) != address(0));
        address staker = msg.sender;
        _withdraw(_fromPool, staker, _amount);
        tokenContract.withdraw(staker, _amount);
        emit Withdrawn(_fromPool, staker, stakingEpoch(), _amount);
    }

    function clearStakeHistory(address _pool, address[] memory _staker, uint256 _stakingEpoch) public onlyOwner {
        require(_stakingEpoch <= stakingEpoch().sub(2));
        for (uint256 i = 0; i < _staker.length; i++) {
            _setStakeAmountByEpoch(_pool, _staker[i], _stakingEpoch, 0);
        }
    }

    function setErc20TokenContract(address _erc20TokenContract) public onlyOwner {
        require(_erc20TokenContract != address(0));
        addressStorage[ERC20_TOKEN_CONTRACT] = _erc20TokenContract;
    }

    function setCandidateMinStake(uint256 _minStake) public onlyOwner {
        _setCandidateMinStake(_minStake);
    }

    function setDelegatorMinStake(uint256 _minStake) public onlyOwner {
        _setDelegatorMinStake(_minStake);
    }

    // =============================================== Getters ========================================================

    function areStakeAndWithdrawAllowed() public view returns(bool);

    /// @dev Returns the block number or unix timestamp (depending on
    /// consensus algorithm) from which the address will be unbanned.
    /// @param _who The address of participant.
    /// @return The block number (for AuRa) or unix timestamp (for HBBFT)
    /// from which the address will be unbanned.
    function bannedUntil(address _who) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(BANNED_UNTIL, _who))
        ];
    }

    function blockRewardContract() public view returns(address) {
        return addressStorage[BLOCK_REWARD_CONTRACT];
    }

    // Returns the serial number of validator set changing request
    function changeRequestCount() public view returns(uint256) {
        return uintStorage[CHANGE_REQUEST_COUNT];
    }

    function doesPoolExist(address _who) public view returns(bool) {
        return isPoolActive(_who);
    }

    function emitInitiateChangeCallable() public view returns(bool) {
        return initiateChangeAllowed() && uintStorage[QUEUE_PV_LAST] >= uintStorage[QUEUE_PV_FIRST];
    }

    function erc20TokenContract() public view returns(address) {
        return addressStorage[ERC20_TOKEN_CONTRACT];
    }

    // Returns the list of current pools (candidates and validators)
    function getPools() public view returns(address[] memory) {
        return addressArrayStorage[POOLS];
    }

    // Returns the list of pools which are inactive or banned
    function getPoolsInactive() public view returns(address[] memory) {
        return addressArrayStorage[POOLS_INACTIVE];
    }

    // Returns the set of validators which was actual at the end of previous staking epoch
    function getPreviousValidators() public view returns(address[] memory) {
        return addressArrayStorage[PREVIOUS_VALIDATORS];
    }

    // Returns the set of validators to be finalized in engine
    function getPendingValidators() public view returns(address[] memory) {
        return addressArrayStorage[PENDING_VALIDATORS];
    }

    function getQueueValidators() public view returns(address[] memory, bool) {
        return (addressArrayStorage[QUEUE_VALIDATORS], boolStorage[QUEUE_VALIDATORS_NEW_STAKING_EPOCH]);
    }

    function getCandidateMinStake() public view returns(uint256) {
        return uintStorage[CANDIDATE_MIN_STAKE];
    }

    function getDelegatorMinStake() public view returns(uint256) {
        return uintStorage[DELEGATOR_MIN_STAKE];
    }

    // Returns the current set of validators (the same as in the engine)
    function getValidators() public view returns(address[] memory) {
        return addressArrayStorage[CURRENT_VALIDATORS];
    }

    function initiateChangeAllowed() public view returns(bool) {
        return boolStorage[INITIATE_CHANGE_ALLOWED];
    }

    // Returns the flag whether the address in the `pools` array
    function isPoolActive(address _who) public view returns(bool) {
        return boolStorage[keccak256(abi.encode(IS_POOL_ACTIVE, _who))];
    }

    function isReportValidatorValid(address _validator) public view returns(bool) {
        bool isValid = isValidator(_validator) && !isValidatorBanned(_validator);
        if (stakingEpoch() == 0 || validatorSetApplyBlock() == 0) {
            return isValid;
        }
        if (_getCurrentBlockNumber() - validatorSetApplyBlock() <= 3) {
            // The current validator set was applied in engine,
            // but we should let the previous validators finish
            // reporting malicious validator within a few blocks
            bool previousEpochValidator =
                isValidatorOnPreviousEpoch(_validator) && !isValidatorBanned(_validator);
            return isValid || previousEpochValidator;
        }
        return isValid;
    }

    // Returns the flag whether the address in the `currentValidators` array
    function isValidator(address _who) public view returns(bool) {
        return boolStorage[keccak256(abi.encode(IS_VALIDATOR, _who))];
    }

    // Returns the flag whether the address was a validator at the end of previous staking epoch
    function isValidatorOnPreviousEpoch(address _who) public view returns(bool) {
        return boolStorage[keccak256(abi.encode(IS_VALIDATOR_ON_PREVIOUS_EPOCH, _who))];
    }

    function isValidatorBanned(address _validator) public view returns(bool);

    function maxWithdrawAllowed(address _pool, address _staker) public view returns(uint256) {
        bool poolIsValidator = isValidator(_pool);

        if (_staker == _pool && poolIsValidator) {
            // A pool can't withdraw while it is a validator
            return 0;
        }

        if (isValidatorBanned(_pool)) {
            // No one can withdraw from `_pool` until the ban is expired
            return 0;
        }

        if (!areStakeAndWithdrawAllowed()) {
            return 0;
        }

        if (!poolIsValidator) {
            // The whole amount can be withdrawn if the pool is not a validator
            return stakeAmount(_pool, _staker);
        }

        if (isValidatorOnPreviousEpoch(_pool)) {
            // The pool was also a validator on the previous staking epoch, so
            // the staker can't withdraw amount staked on the previous staking epoch
            return stakeAmount(_pool, _staker).sub(
                stakeAmountByEpoch(_pool, _staker, stakingEpoch().sub(1)) // stakingEpoch is always > 0 here
            );
        } else {
            // The pool wasn't a validator on the previous staking epoch, so
            // the staker can only withdraw amount staked on the current staking epoch
            return stakeAmountByEpoch(_pool, _staker, stakingEpoch());
        }
    }

    // Returns an index of the pool in the `pools` array
    function poolIndex(address _who) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(POOL_INDEX, _who))
        ];
    }

    // Returns an index of the pool in the `poolsInactive` array
    function poolInactiveIndex(address _who) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(POOL_INACTIVE_INDEX, _who))
        ];
    }

    // Returns the list of current delegators in the specified pool
    function poolDelegators(address _pool) public view returns(address[] memory) {
        return addressArrayStorage[
            keccak256(abi.encode(POOL_DELEGATORS, _pool))
        ];
    }

    // Returns delegator's index in `poolDelegators` array
    function poolDelegatorIndex(address _pool, address _delegator) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(POOL_DELEGATOR_INDEX, _pool, _delegator))
        ];
    }

    function randomContract() public view returns(address) {
        return addressStorage[RANDOM_CONTRACT];
    }

    function stakeAmount(address _pool, address _staker) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(STAKE_AMOUNT, _pool, _staker))
        ];
    }

    function stakeAmountByEpoch(address _pool, address _staker, uint256 _stakingEpoch)
        public
        view
        returns(uint256)
    {
        return uintStorage[
            keccak256(abi.encode(STAKE_AMOUNT_BY_EPOCH, _pool, _staker, _stakingEpoch))
        ];
    }

    function stakeAmountTotal(address _pool) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(STAKE_AMOUNT_TOTAL, _pool))
        ];
    }

    // Returns the internal serial number of staking epoch
    function stakingEpoch() public view returns(uint256) {
        return uintStorage[STAKING_EPOCH];
    }

    // Returns the index of validator in the `currentValidators`
    function validatorIndex(address _validator) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(VALIDATOR_INDEX, _validator))
        ];
    }

    // Returns the block number when `finalizeChange` was called to apply the validator set
    function validatorSetApplyBlock() public view returns(uint256) {
        return uintStorage[VALIDATOR_SET_APPLY_BLOCK];
    }

    // =============================================== Private ========================================================

    bytes32 internal constant BLOCK_REWARD_CONTRACT = keccak256("blockRewardContract");
    bytes32 internal constant CANDIDATE_MIN_STAKE = keccak256("candidateMinStake");
    bytes32 internal constant CHANGE_REQUEST_COUNT = keccak256("changeRequestCount");
    bytes32 internal constant CURRENT_VALIDATORS = keccak256("currentValidators");
    bytes32 internal constant DELEGATOR_MIN_STAKE = keccak256("delegatorMinStake");
    bytes32 internal constant ERC20_TOKEN_CONTRACT = keccak256("erc20TokenContract");
    bytes32 internal constant INITIATE_CHANGE_ALLOWED = keccak256("initiateChangeAllowed");
    bytes32 internal constant PENDING_VALIDATORS = keccak256("pendingValidators");
    bytes32 internal constant POOLS = keccak256("pools");
    bytes32 internal constant POOLS_INACTIVE = keccak256("poolsInactive");
    bytes32 internal constant POOLS_EMPTY = keccak256("poolsEmpty");
    bytes32 internal constant POOLS_NON_EMPTY = keccak256("poolsNonEmpty");
    bytes32 internal constant PREVIOUS_VALIDATORS = keccak256("previousValidators");
    bytes32 internal constant QUEUE_PV_FIRST = keccak256("queuePVFirst");
    bytes32 internal constant QUEUE_PV_LAST = keccak256("queuePVLast");
    bytes32 internal constant QUEUE_VALIDATORS = keccak256("queueValidators");
    bytes32 internal constant QUEUE_VALIDATORS_NEW_STAKING_EPOCH = keccak256("queueValidatorsNewStakingEpoch");
    bytes32 internal constant RANDOM_CONTRACT = keccak256("randomContract");
    bytes32 internal constant STAKING_EPOCH = keccak256("stakingEpoch");
    bytes32 internal constant VALIDATOR_SET_APPLY_BLOCK = keccak256("validatorSetApplyBlock");

    bytes32 internal constant BANNED_UNTIL = "bannedUntil";
    bytes32 internal constant IS_POOL_ACTIVE = "isPoolActive";
    bytes32 internal constant IS_VALIDATOR = "isValidator";
    bytes32 internal constant IS_VALIDATOR_ON_PREVIOUS_EPOCH = "isValidatorOnPreviousEpoch";
    bytes32 internal constant POOL_DELEGATORS = "poolDelegators";
    bytes32 internal constant POOL_DELEGATOR_INDEX = "poolDelegatorIndex";
    bytes32 internal constant POOL_INDEX = "poolIndex";
    bytes32 internal constant POOL_INACTIVE_INDEX = "poolInactiveIndex";
    bytes32 internal constant QUEUE_PV_BLOCK = "queuePVBlock";
    bytes32 internal constant QUEUE_PV_LIST = "queuePVList";
    bytes32 internal constant QUEUE_PV_NEW_EPOCH = "queuePVNewEpoch";
    bytes32 internal constant STAKE_AMOUNT = "stakeAmount";
    bytes32 internal constant STAKE_AMOUNT_BY_EPOCH = "stakeAmountByEpoch";
    bytes32 internal constant STAKE_AMOUNT_TOTAL = "stakeAmountTotal";
    bytes32 internal constant VALIDATOR_INDEX = "validatorIndex";

    // Adds `_who` to the array of pools
    function _addToPools(address _who) internal {
        if (!doesPoolExist(_who)) {
            address[] storage pools = addressArrayStorage[POOLS];
            _setPoolIndex(_who, pools.length);
            pools.push(_who);
            require(pools.length <= MAX_CANDIDATES);
            _setIsPoolActive(_who, true);
        }
        _removeFromPoolsInactive(_who);
    }

    // Adds `_who` to the array of inactive pools
    function _addToPoolsInactive(address _who) internal {
        address[] storage poolsInactive = addressArrayStorage[POOLS_INACTIVE];
        if (poolsInactive.length == 0 || poolsInactive[poolInactiveIndex(_who)] != _who) {
            _setPoolInactiveIndex(_who, poolsInactive.length);
            poolsInactive.push(_who);
        }
    }

    // Removes `_who` from the array of pools
    function _removeFromPools(address _who) internal {
        uint256 indexToRemove = poolIndex(_who);
        address[] storage pools = addressArrayStorage[POOLS];
        if (pools.length > 0 && pools[indexToRemove] == _who) {
            pools[indexToRemove] = pools[pools.length - 1];
            _setPoolIndex(pools[indexToRemove], indexToRemove);
            pools.length--;
            _setPoolIndex(_who, 0);
            _setIsPoolActive(_who, false);
            if (stakeAmountTotal(_who) != 0) {
                _addToPoolsInactive(_who);
            }
        }
    }

    // Removes `_who` from the array of inactive pools
    function _removeFromPoolsInactive(address _who) internal {
        address[] storage poolsInactive = addressArrayStorage[POOLS_INACTIVE];
        uint256 indexToRemove = poolInactiveIndex(_who);
        if (poolsInactive.length > 0 && poolsInactive[indexToRemove] == _who) {
            poolsInactive[indexToRemove] = poolsInactive[poolsInactive.length - 1];
            _setPoolInactiveIndex(poolsInactive[indexToRemove], indexToRemove);
            poolsInactive.length--;
            _setPoolInactiveIndex(_who, 0);
        }
    }

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

    function _banUntil() internal view returns(uint256);

    function _banValidator(address _validator) internal {
        uintStorage[
            keccak256(abi.encode(BANNED_UNTIL, _validator))
        ] = _banUntil();
    }

    function _enqueuePendingValidators(bool _newStakingEpoch) internal {
        uint256 queueFirst = uintStorage[QUEUE_PV_FIRST];
        uint256 queueLast = uintStorage[QUEUE_PV_LAST];

        for (uint256 i = queueLast; i >= queueFirst; i--) {
            if (uintStorage[keccak256(abi.encode(QUEUE_PV_BLOCK, i))] == block.number) {
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
        uintStorage[keccak256(abi.encode(QUEUE_PV_BLOCK, queueLast))] = block.number;
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

    function _incrementStakingEpoch() internal {
        uintStorage[STAKING_EPOCH]++;
    }

    function _initialize(
        address _blockRewardContract,
        address _randomContract,
        address _erc20TokenContract,
        address[] memory _initialValidators,
        uint256 _delegatorMinStake,
        uint256 _candidateMinStake
    ) internal {
        require(_getCurrentBlockNumber() == 0); // initialization must be done on genesis block
        require(_blockRewardContract != address(0));
        require(_randomContract != address(0));
        require(_initialValidators.length > 0);
        require(_delegatorMinStake != 0);
        require(_candidateMinStake != 0);

        addressStorage[BLOCK_REWARD_CONTRACT] = _blockRewardContract;
        addressStorage[RANDOM_CONTRACT] = _randomContract;
        addressStorage[ERC20_TOKEN_CONTRACT] = _erc20TokenContract;

        address[] storage currentValidators = addressArrayStorage[CURRENT_VALIDATORS];
        address[] storage pendingValidators = addressArrayStorage[PENDING_VALIDATORS];
        require(currentValidators.length == 0);

        // Add initial validators to the `currentValidators` array
        for (uint256 i = 0; i < _initialValidators.length; i++) {
            currentValidators.push(_initialValidators[i]);
            pendingValidators.push(_initialValidators[i]);
            _setValidatorIndex(_initialValidators[i], i);
            _setIsValidator(_initialValidators[i], true);
            _addToPools(_initialValidators[i]);
        }

        _setDelegatorMinStake(_delegatorMinStake);
        _setCandidateMinStake(_candidateMinStake);

        _setValidatorSetApplyBlock(1);

        uintStorage[QUEUE_PV_FIRST] = 1;
        uintStorage[QUEUE_PV_LAST] = 0;
    }

    function _newValidatorSet() internal {
        address[] memory pools = getPools();
        uint256 i;

        // Filter pools and leave only non-empty
        delete addressArrayStorage[POOLS_NON_EMPTY];
        delete addressArrayStorage[POOLS_EMPTY];
        for (i = 0; i < pools.length; i++) {
            if (stakeAmount(pools[i], pools[i]) > 0) {
                addressArrayStorage[POOLS_NON_EMPTY].push(pools[i]);
            } else {
                addressArrayStorage[POOLS_EMPTY].push(pools[i]);
            }
        }
        pools = addressArrayStorage[POOLS_NON_EMPTY];

        // Choose new validators
        if (pools.length <= MAX_VALIDATORS) {
            if (pools.length > 0) {
                _setPendingValidators(pools);
            }
        } else {
            uint256 randomNumber = uint256(keccak256(abi.encode(IRandom(randomContract()).getCurrentSecret())));

            address[] memory poolsLocal = pools;
            uint256 poolsLocalLength = poolsLocal.length;

            uint256[] memory likelihood = new uint256[](poolsLocalLength);
            address[] memory newValidators = new address[](MAX_VALIDATORS);

            uint256 likelihoodSum = 0;

            for (i = 0; i < poolsLocalLength; i++) {
                likelihood[i] = stakeAmountTotal(poolsLocal[i]).mul(100).div(STAKE_UNIT);
                likelihoodSum = likelihoodSum.add(likelihood[i]);
            }

            for (i = 0; i < MAX_VALIDATORS; i++) {
                uint256 randomPoolIndex = _getRandomIndex(
                    likelihood,
                    likelihoodSum,
                    randomNumber
                );
                newValidators[i] = poolsLocal[randomPoolIndex];
                likelihoodSum -= likelihood[randomPoolIndex];
                poolsLocalLength--;
                poolsLocal[randomPoolIndex] = poolsLocal[poolsLocalLength];
                likelihood[randomPoolIndex] = likelihood[poolsLocalLength];
                randomNumber = uint256(keccak256(abi.encode(randomNumber)));
            }

            _setPendingValidators(newValidators);
        }

        // From this moment `getPendingValidators()` will return the new validator set

        // Increment counters
        _incrementStakingEpoch();
        _incrementChangeRequestCount();

        _enqueuePendingValidators(true);
        _setValidatorSetApplyBlock(0);
    }

    function _removeMaliciousValidator(address _validator) internal returns(bool) {
        // Remove malicious validator from `pools`
        _removeFromPools(_validator);

        // Ban the malicious validator for the next 3 months
        _banValidator(_validator);

        address[] storage validators = addressArrayStorage[PENDING_VALIDATORS];
        bool isPendingValidator = false;
        uint256 i;

        for (i = 0; i < validators.length; i++) {
            if (validators[i] == _validator) {
                isPendingValidator = true;
                break;
            }
        }

        if (isPendingValidator) {
            // Remove the malicious validator from `pendingValidators`
            validators[i] = validators[validators.length - 1];
            validators.length--;
            return true;
        }

        return false;
    }

    function _setCurrentValidators(address[] memory _validators) internal {
        addressArrayStorage[CURRENT_VALIDATORS] = _validators;
    }

    function _setInitiateChangeAllowed(bool _allowed) internal {
        boolStorage[INITIATE_CHANGE_ALLOWED] = _allowed;
    }

    function _setIsPoolActive(address _who, bool _isPoolActive) internal {
        boolStorage[keccak256(abi.encode(IS_POOL_ACTIVE, _who))] = _isPoolActive;
    }

    function _setIsValidator(address _who, bool _isValidator) internal {
        boolStorage[keccak256(abi.encode(IS_VALIDATOR, _who))] = _isValidator;
    }

    function _setIsValidatorOnPreviousEpoch(address _who, bool _isValidator) internal {
        boolStorage[keccak256(abi.encode(IS_VALIDATOR_ON_PREVIOUS_EPOCH, _who))] = _isValidator;
    }

    function _setPendingValidators(address[] memory _validators) internal {
        addressArrayStorage[PENDING_VALIDATORS] = _validators;

        for (uint256 i = 0; i < addressArrayStorage[POOLS_EMPTY].length; i++) {
            _removeFromPools(addressArrayStorage[POOLS_EMPTY][i]);
        }
    }

    function _setPoolIndex(address _who, uint256 _index) internal {
        uintStorage[
            keccak256(abi.encode(POOL_INDEX, _who))
        ] = _index;
    }

    function _setPoolInactiveIndex(address _who, uint256 _index) internal {
        uintStorage[
            keccak256(abi.encode(POOL_INACTIVE_INDEX, _who))
        ] = _index;
    }

    function _setPoolDelegatorIndex(address _pool, address _delegator, uint256 _index) internal {
        uintStorage[keccak256(abi.encode(POOL_DELEGATOR_INDEX, _pool, _delegator))] = _index;
    }

    function _setQueueValidators(address[] memory _validators, bool _newStakingEpoch) internal {
        addressArrayStorage[QUEUE_VALIDATORS] = _validators;
        boolStorage[QUEUE_VALIDATORS_NEW_STAKING_EPOCH] = _newStakingEpoch;
    }

    // Add `_delegator` to the array of pool's delegators
    function _addPoolDelegator(address _pool, address _delegator) internal {
        address[] storage delegators = addressArrayStorage[
            keccak256(abi.encode(POOL_DELEGATORS, _pool))
        ];
        _setPoolDelegatorIndex(_pool, _delegator, delegators.length);
        delegators.push(_delegator);
    }

    // Remove `_delegator` from the array of pool's delegators
    function _removePoolDelegator(address _pool, address _delegator) internal {
        address[] storage delegators = addressArrayStorage[
            keccak256(abi.encode(POOL_DELEGATORS, _pool))
        ];
        if (delegators.length == 0) return;
        uint256 indexToRemove = poolDelegatorIndex(_pool, _delegator);
        delegators[indexToRemove] = delegators[delegators.length - 1];
        _setPoolDelegatorIndex(_pool, delegators[indexToRemove], indexToRemove);
        delegators.length--;
        _setPoolDelegatorIndex(_pool, _delegator, 0);
    }

    function _setPreviousValidators(address[] memory _validators) internal {
        addressArrayStorage[PREVIOUS_VALIDATORS] = _validators;
    }

    function _setStakeAmount(address _pool, address _staker, uint256 _amount) internal {
        uintStorage[
            keccak256(abi.encode(STAKE_AMOUNT, _pool, _staker))
        ] = _amount;
    }

    function _setStakeAmountByEpoch(
        address _pool,
        address _staker,
        uint256 _stakingEpoch,
        uint256 _amount
    ) internal {
        uintStorage[
            keccak256(abi.encode(STAKE_AMOUNT_BY_EPOCH, _pool, _staker, _stakingEpoch))
        ] = _amount;
    }

    function _setStakeAmountTotal(address _pool, uint256 _amount) internal {
        uintStorage[
            keccak256(abi.encode(STAKE_AMOUNT_TOTAL, _pool))
        ] = _amount;
    }

    function _setDelegatorMinStake(uint256 _minStake) internal {
        uintStorage[DELEGATOR_MIN_STAKE] = _minStake * STAKE_UNIT;
    }

    function _setCandidateMinStake(uint256 _minStake) internal {
        uintStorage[CANDIDATE_MIN_STAKE] = _minStake * STAKE_UNIT;
    }

    function _setValidatorIndex(address _validator, uint256 _index) internal {
        uintStorage[
            keccak256(abi.encode(VALIDATOR_INDEX, _validator))
        ] = _index;
    }

    function _setValidatorSetApplyBlock(uint256 _blockNumber) internal {
        uintStorage[VALIDATOR_SET_APPLY_BLOCK] = _blockNumber;
    }

    function _stake(address _pool, address _staker, uint256 _amount) internal {
        require(_pool != address(0));
        require(_amount != 0);
        require(!isValidatorBanned(_pool));
        require(areStakeAndWithdrawAllowed());

        uint256 epoch = stakingEpoch();

        uint256 newStakeAmount = stakeAmount(_pool, _staker).add(_amount);
        if (_staker == _pool) {
            require(newStakeAmount >= getCandidateMinStake()); // the staked amount must be at least CANDIDATE_MIN_STAKE
        } else {
            require(newStakeAmount >= getDelegatorMinStake()); // the staked amount must be at least DELEGATOR_MIN_STAKE
        }
        _setStakeAmount(_pool, _staker, newStakeAmount);
        _setStakeAmountByEpoch(_pool, _staker, epoch, stakeAmountByEpoch(_pool, _staker, epoch).add(_amount));
        _setStakeAmountTotal(_pool, stakeAmountTotal(_pool).add(_amount));

        if (_staker == _pool) { // `staker` makes a stake for himself and becomes a candidate
            // Add `_pool` to the array of pools
            _addToPools(_pool);
        } else if (newStakeAmount == _amount) { // if the stake is first
            // Add `_staker` to the array of pool's delegators
            _addPoolDelegator(_pool, _staker);
        }
    }

    function _withdraw(address _pool, address _staker, uint256 _amount) internal {
        require(_pool != address(0));
        require(_amount != 0);

        // How much can `staker` withdraw from `_pool` at the moment?
        require(_amount <= maxWithdrawAllowed(_pool, _staker));

        uint256 epoch = stakingEpoch();

        // The amount to be withdrawn must be the whole staked amount or
        // must not exceed the diff between the entire amount and MIN_STAKE
        uint256 newStakeAmount = stakeAmount(_pool, _staker).sub(_amount);
        if (newStakeAmount > 0) {
            if (_staker == _pool) {
                require(newStakeAmount >= getCandidateMinStake());
            } else {
                require(newStakeAmount >= getDelegatorMinStake());
            }
        }
        _setStakeAmount(_pool, _staker, newStakeAmount);
        uint256 amountByEpoch = stakeAmountByEpoch(_pool, _staker, epoch);
        if (_amount <= amountByEpoch) {
            _setStakeAmountByEpoch(_pool, _staker, epoch, amountByEpoch - _amount);
        } else {
            _setStakeAmountByEpoch(_pool, _staker, epoch, 0);
        }
        _setStakeAmountTotal(_pool, stakeAmountTotal(_pool).sub(_amount));

        if (newStakeAmount == 0) { // the whole amount has been withdrawn
            if (_staker == _pool) {
                // Remove `_pool` from the array of pools
                _removeFromPools(_pool);
            } else {
                // Remove `_staker` from the array of pool's delegators
                _removePoolDelegator(_pool, _staker);
            }

            if (stakeAmountTotal(_pool) == 0) {
                _removeFromPoolsInactive(_pool);
            }
        }
    }

    function _getCurrentBlockNumber() internal view returns(uint256) {
        return block.number;
    }

    function _getRandomIndex(uint256[] memory _likelihood, uint256 _likelihoodSum, uint256 _randomNumber)
        internal
        pure
        returns(uint256)
    {
        int256 r = int256(_randomNumber % _likelihoodSum) + 1;
        int256 index = -1;
        do {
            r -= int256(_likelihood[uint256(++index)]);
        } while (r > 0);
        return uint256(index);
    }
}
