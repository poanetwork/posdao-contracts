pragma solidity 0.5.2;

import "../interfaces/IBlockReward.sol";
import "../interfaces/IERC20Minting.sol";
import "../interfaces/IRandom.sol";
import "../interfaces/IValidatorSet.sol";
import "../eternal-storage/EternalStorage.sol";
import "../libs/SafeMath.sol";


contract ValidatorSetBase is EternalStorage, IValidatorSet {
    using SafeMath for uint256;

    // TODO: add a description for each function

    // ============================================== Constants =======================================================

    // These values must be set before deploy
    uint256 public constant MAX_OBSERVERS = 2000;
    uint256 public constant MAX_VALIDATORS = 20;
    uint256 public constant STAKE_UNIT = 1 ether;

    // ================================================ Events ========================================================

    /// Emitted by `stake` function to signal that the staker made a stake of the specified
    /// amount for the specified observer during the specified staking epoch.
    /// @param toObserver The observer for whom the `staker` made the stake.
    /// @param staker The address of staker who made the stake.
    /// @param stakingEpoch The serial number of staking epoch during which the stake was made.
    /// @param amount The amount of the stake.
    event Staked(
        address indexed toObserver,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount
    );

    /// Emitted by `moveStake` function to signal that the staker moved the specified
    /// amount of a stake from one observer to another during the specified staking epoch.
    /// @param fromObserver The observer from whom the `staker` moved the stake.
    /// @param toObserver The observer to whom the `staker` moved the stake.
    /// @param staker The address of staker who moved the `amount`.
    /// @param stakingEpoch The serial number of staking epoch during which the `amount` was moved.
    /// @param amount The amount of the stake.
    event StakeMoved(
        address fromObserver,
        address indexed toObserver,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount
    );

    /// Emitted by `withdraw` function to signal that the staker withdrew the specified
    /// amount of a stake from the specified observer during the specified staking epoch.
    /// @param fromObserver The observer from whom the `staker` withdrew `amount`.
    /// @param staker The address of staker who withdrew `amount`.
    /// @param stakingEpoch The serial number of staking epoch during which the withdrawal was made.
    /// @param amount The amount of the withdrawal.
    event Withdrawn(
        address indexed fromObserver,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount
    );

    // ============================================== Modifiers =======================================================

    modifier gasPriceIsValid() {
        require(tx.gasprice != 0);
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == addressStorage[OWNER]);
        _;
    }

    modifier onlySystem() {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    // =============================================== Setters ========================================================

    function removePool() public gasPriceIsValid {
        if (stakingEpoch() == 0 && isValidator(msg.sender)) {
            revert(); // initial validator cannot remove his pool during the initial staking epoch
        }
        _removeFromPools(msg.sender);
    }

    function finalizeChange() public onlySystem {
        if (stakingEpoch() == 0) {
            // Ignore invocations if `newValidatorSet()` has never been called
            return;
        }

        if (validatorSetApplyBlock() == 0) {
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

            _applyPendingValidators();
            _setValidatorSetApplyBlock(block.number);

            // Set a new snapshot inside BlockReward contract
            IBlockReward(blockRewardContract()).setSnapshot();
        } else {
            // Apply new validator set after `reportMalicious` is called
            _applyPendingValidators();
        }
    }

    function moveStake(address _fromObserver, address _toObserver, uint256 _amount) public gasPriceIsValid {
        require(_fromObserver != _toObserver);
        address staker = msg.sender;
        _withdraw(_fromObserver, staker, _amount);
        _stake(_toObserver, staker, _amount);
        emit StakeMoved(_fromObserver, _toObserver, staker, stakingEpoch(), _amount);
    }

    function stake(address _toObserver, uint256 _amount) public gasPriceIsValid {
        IERC20Minting tokenContract = IERC20Minting(erc20TokenContract());
        require(address(tokenContract) != address(0));
        address staker = msg.sender;
        _stake(_toObserver, staker, _amount);
        tokenContract.stake(staker, _amount);
        emit Staked(_toObserver, staker, stakingEpoch(), _amount);
    }

    function withdraw(address _fromObserver, uint256 _amount) public gasPriceIsValid {
        IERC20Minting tokenContract = IERC20Minting(erc20TokenContract());
        require(address(tokenContract) != address(0));
        address staker = msg.sender;
        _withdraw(_fromObserver, staker, _amount);
        tokenContract.withdraw(staker, _amount);
        emit Withdrawn(_fromObserver, staker, stakingEpoch(), _amount);
    }

    function clearStakeHistory(address _observer, address[] memory _staker, uint256 _stakingEpoch) public onlyOwner {
        require(_stakingEpoch <= stakingEpoch().sub(2));
        for (uint256 i = 0; i < _staker.length; i++) {
            _setStakeAmountByEpoch(_observer, _staker[i], _stakingEpoch, 0);
        }
    }

    function setErc20TokenContract(address _erc20TokenContract) public onlyOwner {
        require(_erc20TokenContract != address(0));
        addressStorage[ERC20_TOKEN_CONTRACT] = _erc20TokenContract;
    }

    function setDelegateMinStake(uint256 _minStake) public onlyOwner {
        _setDelegateMinStake(_minStake);
    }

    function setValidatorMinStake(uint256 _minStake) public onlyOwner {
        _setValidatorMinStake(_minStake);
    }

    // =============================================== Getters ========================================================

    // Returns the unix timestamp from which the address will be unbanned
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

    function erc20TokenContract() public view returns(address) {
        return addressStorage[ERC20_TOKEN_CONTRACT];
    }

    // Returns the list of current observers (pools)
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

    function getDelegateMinStake() public view returns(uint256) {
        return uintStorage[DELEGATE_MIN_STAKE];
    }

    function getValidatorMinStake() public view returns(uint256) {
        return uintStorage[VALIDATOR_MIN_STAKE];
    }

    // Returns the current set of validators (the same as in the engine)
    function getValidators() public view returns(address[] memory) {
        return addressArrayStorage[CURRENT_VALIDATORS];
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
        if (block.number - validatorSetApplyBlock() <= 3) {
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

    function isValidatorBanned(address _validator) public view returns(bool) {
        return now < bannedUntil(_validator);
    }

    function maxWithdrawAllowed(address _observer, address _staker) public view returns(uint256) {
        bool observerIsValidator = isValidator(_observer);

        if (_staker == _observer && observerIsValidator) {
            // An observer can't withdraw while he is a validator
            return 0;
        }

        if (isValidatorBanned(_observer)) {
            // No one can withdraw from `_observer` until the ban is expired
            return 0;
        }

        if (!_areStakeAndWithdrawAllowed()) {
            return 0;
        }

        if (!observerIsValidator) {
            // The whole amount can be withdrawn if observer is not a validator
            return stakeAmount(_observer, _staker);
        }

        if (isValidatorOnPreviousEpoch(_observer)) {
            // The observer was also a validator on the previous staking epoch, so
            // the staker can't withdraw amount staked on the previous staking epoch
            return stakeAmount(_observer, _staker).sub(
                stakeAmountByEpoch(_observer, _staker, stakingEpoch().sub(1)) // stakingEpoch is always > 0 here
            );
        } else {
            // The observer wasn't a validator on the previous staking epoch, so
            // the staker can only withdraw amount staked on the current staking epoch
            return stakeAmountByEpoch(_observer, _staker, stakingEpoch());
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

    // Returns the list of current delegates in the specified pool
    function poolDelegates(address _pool) public view returns(address[] memory) {
        return addressArrayStorage[
            keccak256(abi.encode(POOL_DELEGATES, _pool))
        ];
    }

    // Returns delegate's index in `poolDelegates` array
    function poolDelegateIndex(address _pool, address _delegate) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(POOL_DELEGATE_INDEX, _pool, _delegate))
        ];
    }

    function randomContract() public view returns(address) {
        return addressStorage[RANDOM_CONTRACT];
    }

    function stakeAmount(address _observer, address _staker) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(STAKE_AMOUNT, _observer, _staker))
        ];
    }

    function stakeAmountByEpoch(address _observer, address _staker, uint256 _stakingEpoch)
        public
        view
        returns(uint256)
    {
        return uintStorage[
            keccak256(abi.encode(STAKE_AMOUNT_BY_EPOCH, _observer, _staker, _stakingEpoch))
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
    bytes32 internal constant CHANGE_REQUEST_COUNT = keccak256("changeRequestCount");
    bytes32 internal constant CURRENT_VALIDATORS = keccak256("currentValidators");
    bytes32 internal constant DELEGATE_MIN_STAKE = keccak256("delegateMinStake");
    bytes32 internal constant ERC20_TOKEN_CONTRACT = keccak256("erc20TokenContract");
    bytes32 internal constant OWNER = keccak256("owner");
    bytes32 internal constant PENDING_VALIDATORS = keccak256("pendingValidators");
    bytes32 internal constant POOLS = keccak256("pools");
    bytes32 internal constant POOLS_INACTIVE = keccak256("poolsInactive");
    bytes32 internal constant POOLS_EMPTY = keccak256("poolsEmpty");
    bytes32 internal constant POOLS_NON_EMPTY = keccak256("poolsNonEmpty");
    bytes32 internal constant PREVIOUS_VALIDATORS = keccak256("previousValidators");
    bytes32 internal constant RANDOM_CONTRACT = keccak256("randomContract");
    bytes32 internal constant STAKING_EPOCH = keccak256("stakingEpoch");
    bytes32 internal constant VALIDATOR_MIN_STAKE = keccak256("validatorMinStake");
    bytes32 internal constant VALIDATOR_SET_APPLY_BLOCK = keccak256("validatorSetApplyBlock");

    bytes32 internal constant BANNED_UNTIL = "bannedUntil";
    bytes32 internal constant IS_POOL_ACTIVE = "isPoolActive";
    bytes32 internal constant IS_VALIDATOR = "isValidator";
    bytes32 internal constant IS_VALIDATOR_ON_PREVIOUS_EPOCH = "isValidatorOnPreviousEpoch";
    bytes32 internal constant POOL_DELEGATES = "poolDelegates";
    bytes32 internal constant POOL_DELEGATE_INDEX = "poolDelegateIndex";
    bytes32 internal constant POOL_INDEX = "poolIndex";
    bytes32 internal constant POOL_INACTIVE_INDEX = "poolInactiveIndex";
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
            require(pools.length <= MAX_OBSERVERS);
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

    function _applyPendingValidators() internal {
        address[] memory validators = getValidators();
        uint256 i;

        // Clear indexes for old validator set
        for (i = 0; i < validators.length; i++) {
            _setValidatorIndex(validators[i], 0);
            _setIsValidator(validators[i], false);
        }

        validators = getPendingValidators();
        _setCurrentValidators(validators);

        // Set indexes for new validator set
        for (i = 0; i < validators.length; i++) {
            _setValidatorIndex(validators[i], i);
            _setIsValidator(validators[i], true);
        }
    }

    function _banValidator(address _validator, uint256 _bannedUntil) internal {
        uintStorage[
            keccak256(abi.encode(BANNED_UNTIL, _validator))
        ] = _bannedUntil;
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
        uint256 _delegateMinStake,
        uint256 _validatorMinStake
    ) internal {
        require(_getCurrentBlockNumber() == 0); // initialization must be done on genesis block
        require(_blockRewardContract != address(0));
        require(_randomContract != address(0));
        require(_initialValidators.length > 0);
        require(_delegateMinStake != 0);
        require(_validatorMinStake != 0);

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

        _setDelegateMinStake(_delegateMinStake);
        _setValidatorMinStake(_validatorMinStake);

        _setValidatorSetApplyBlock(1);
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
            uint256[] memory randomNumbers = IRandom(randomContract()).currentRandom();

            require(randomNumbers.length == MAX_VALIDATORS);

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
                uint256 observerIndex = _getRandomIndex(
                    likelihood,
                    likelihoodSum,
                    uint256(keccak256(abi.encodePacked(randomNumbers[i])))
                );
                newValidators[i] = poolsLocal[observerIndex];
                likelihoodSum -= likelihood[observerIndex];
                poolsLocalLength--;
                poolsLocal[observerIndex] = poolsLocal[poolsLocalLength];
                likelihood[observerIndex] = likelihood[poolsLocalLength];
            }

            _setPendingValidators(newValidators);
        }

        // From this moment `getPendingValidators()` will return the new validator set

        // Increment counters
        _incrementChangeRequestCount();
        _incrementStakingEpoch();

        _setValidatorSetApplyBlock(0);
    }

    function _removeMaliciousValidator(address _validator) internal returns(bool) {
        // Remove malicious validator from `pools`
        _removeFromPools(_validator);

        // Ban the malicious validator for the next 3 months
        _banValidator(_validator, now + 90 days);

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
            validators[i] = validators[--validators.length];
            return true;
        }

        return false;
    }

    function _setCurrentValidators(address[] memory _validators) internal {
        addressArrayStorage[CURRENT_VALIDATORS] = _validators;
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

    function _setPoolDelegateIndex(address _pool, address _delegate, uint256 _index) internal {
        uintStorage[keccak256(abi.encode(POOL_DELEGATE_INDEX, _pool, _delegate))] = _index;
    }

    // Add `_delegate` to the array of observer's delegates
    function _addPoolDelegate(address _pool, address _delegate) internal {
        address[] storage delegates = addressArrayStorage[
            keccak256(abi.encode(POOL_DELEGATES, _pool))
        ];
        _setPoolDelegateIndex(_pool, _delegate, delegates.length);
        delegates.push(_delegate);
    }

    // Remove `_delegate` from the array of observer's delegates
    function _removePoolDelegate(address _pool, address _delegate) internal {
        address[] storage delegates = addressArrayStorage[
            keccak256(abi.encode(POOL_DELEGATES, _pool))
        ];
        if (delegates.length == 0) return;
        uint256 indexToRemove = poolDelegateIndex(_pool, _delegate);
        delegates[indexToRemove] = delegates[delegates.length - 1];
        _setPoolDelegateIndex(_pool, delegates[indexToRemove], indexToRemove);
        delegates.length--;
        _setPoolDelegateIndex(_pool, _delegate, 0);
    }

    function _setPreviousValidators(address[] memory _validators) internal {
        addressArrayStorage[PREVIOUS_VALIDATORS] = _validators;
    }

    function _setStakeAmount(address _observer, address _staker, uint256 _amount) internal {
        uintStorage[
            keccak256(abi.encode(STAKE_AMOUNT, _observer, _staker))
        ] = _amount;
    }

    function _setStakeAmountByEpoch(
        address _observer,
        address _staker,
        uint256 _stakingEpoch,
        uint256 _amount
    ) internal {
        uintStorage[
            keccak256(abi.encode(STAKE_AMOUNT_BY_EPOCH, _observer, _staker, _stakingEpoch))
        ] = _amount;
    }

    function _setStakeAmountTotal(address _pool, uint256 _amount) internal {
        uintStorage[
            keccak256(abi.encode(STAKE_AMOUNT_TOTAL, _pool))
        ] = _amount;
    }

    function _setDelegateMinStake(uint256 _minStake) internal {
        uintStorage[DELEGATE_MIN_STAKE] = _minStake * STAKE_UNIT;
    }

    function _setValidatorMinStake(uint256 _minStake) internal {
        uintStorage[VALIDATOR_MIN_STAKE] = _minStake * STAKE_UNIT;
    }

    function _setValidatorIndex(address _validator, uint256 _index) internal {
        uintStorage[
            keccak256(abi.encode(VALIDATOR_INDEX, _validator))
        ] = _index;
    }

    function _setValidatorSetApplyBlock(uint256 _blockNumber) internal {
        uintStorage[VALIDATOR_SET_APPLY_BLOCK] = _blockNumber;
    }

    function _stake(address _observer, address _staker, uint256 _amount) internal {
        require(_observer != address(0));
        require(_amount != 0);
        require(!isValidatorBanned(_observer));
        require(_areStakeAndWithdrawAllowed());

        uint256 epoch = stakingEpoch();

        uint256 newStakeAmount = stakeAmount(_observer, _staker).add(_amount);
        if (_staker == _observer) {
            require(newStakeAmount >= getValidatorMinStake()); // the staked amount must be at least VALIDATOR_MIN_STAKE
        } else {
            require(newStakeAmount >= getDelegateMinStake()); // the staked amount must be at least DELEGATE_MIN_STAKE
        }
        _setStakeAmount(_observer, _staker, newStakeAmount);
        _setStakeAmountByEpoch(_observer, _staker, epoch, stakeAmountByEpoch(_observer, _staker, epoch).add(_amount));
        _setStakeAmountTotal(_observer, stakeAmountTotal(_observer).add(_amount));

        if (_staker == _observer) { // `staker` makes a stake for himself and becomes an observer
            // Add `_observer` to the array of pools
            _addToPools(_observer);
        } else if (newStakeAmount == _amount) { // if the stake is first
            // Add `_staker` to the array of observer's delegates
            _addPoolDelegate(_observer, _staker);
        }
    }

    function _withdraw(address _observer, address _staker, uint256 _amount) internal {
        require(_observer != address(0));
        require(_amount != 0);

        // How much can `staker` withdraw from `_observer` pool at the moment?
        require(_amount <= maxWithdrawAllowed(_observer, _staker));

        uint256 epoch = stakingEpoch();

        // The amount to be withdrawn must be the whole staked amount or
        // must not exceed the diff between the entire amount and MIN_STAKE
        uint256 newStakeAmount = stakeAmount(_observer, _staker).sub(_amount);
        if (newStakeAmount > 0) {
            if (_staker == _observer) {
                require(newStakeAmount >= getValidatorMinStake());
            } else {
                require(newStakeAmount >= getDelegateMinStake());
            }
        }
        _setStakeAmount(_observer, _staker, newStakeAmount);
        uint256 amountByEpoch = stakeAmountByEpoch(_observer, _staker, epoch);
        if (_amount <= amountByEpoch) {
            _setStakeAmountByEpoch(_observer, _staker, epoch, amountByEpoch - _amount);
        } else {
            _setStakeAmountByEpoch(_observer, _staker, epoch, 0);
        }
        _setStakeAmountTotal(_observer, stakeAmountTotal(_observer).sub(_amount));

        if (newStakeAmount == 0) { // the whole amount has been withdrawn
            if (_staker == _observer) {
                // Remove `_observer` from the array of pools
                _removeFromPools(_observer);
            } else {
                // Remove `_staker` from the array of observer's delegates
                _removePoolDelegate(_observer, _staker);
            }

            if (stakeAmountTotal(_observer) == 0) {
                _removeFromPoolsInactive(_observer);
            }
        }
    }

    function _areStakeAndWithdrawAllowed() internal view returns(bool);

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
