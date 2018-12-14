pragma solidity 0.4.25;

import "./interfaces/IBlockReward.sol";
import "./interfaces/IRandom.sol";
import "./interfaces/IReportingValidatorSet.sol";
import "./eternal-storage/EternalStorage.sol";
import "./libs/SafeMath.sol";


contract ReportingValidatorSet is EternalStorage, IReportingValidatorSet {
    using SafeMath for uint256;

    // TODO: add a description for each function

    // ============================================== Constants =======================================================

    uint256 public constant MAX_OBSERVERS = 2000;
    uint256 public constant MAX_VALIDATORS = 20;
    uint256 public constant VALIDATOR_MIN_STAKE = 1 * STAKE_UNIT; // must be specified before network launching
    uint256 public constant STAKER_MIN_STAKE = 1 * STAKE_UNIT; // must be specified before network launching
    uint256 public constant STAKE_UNIT = 1 ether;
    uint256 public constant STAKING_EPOCH_DURATION = 1 weeks;
    uint256 public constant STAKE_WITHDRAW_DISALLOW_PERIOD = 6 hours; // the last hours of staking epoch

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

    modifier onlyOwner() {
        require(msg.sender == addressStorage[OWNER]);
        _;
    }

    modifier onlySystem() {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    modifier stakeWithdrawAllowed() {
        require(now - uintStorage[STAKING_EPOCH_TIMESTAMP] <= STAKING_EPOCH_DURATION - STAKE_WITHDRAW_DISALLOW_PERIOD);
        _;
    }

    // =============================================== Setters ========================================================

    /// Creates an initial set of validators at the start of the network.
    /// Must be called by the constructor of `Initializer` contract on genesis block.
    function initialize(address[] _initialValidators) external {
        address[] storage currentValidators = addressArrayStorage[CURRENT_VALIDATORS];

        require(block.number == 0);
        require(_initialValidators.length > 0);
        require(currentValidators.length == 0);
        
        // Add initial validators to the `currentValidators` array
        for (uint256 i = 0; i < _initialValidators.length; i++) {
            currentValidators.push(_initialValidators[i]);
            _setValidatorIndex(_initialValidators[i], i);
            _setIsValidator(_initialValidators[i], true);
        }

        _setStakingEpochTimestamp(now);
    }

    // TODO: the `_publicKey` param is only required for hbbft
    function addPool(bytes _publicKey) public payable {
        stake(msg.sender);
        savePublicKey(_publicKey);
    }

    function removePool() public {
        _removeFromPools(msg.sender);
    }

    function finalizeChange() public onlySystem {
        if (stakingEpoch() == 0) {
            // Ignore invocations if `newValidatorSet()` has never been called
            return;
        }

        // Apply new snapshot after `newValidatorSet()` is called,
        // not after `reportMaliciousValidator` function is called
        if (validatorSetApplyBlock() == 0) {
            _setValidatorSetApplyBlock(block.number);
            // Copy the new snapshot into the BlockReward contract
            blockRewardContract().setSnapshot(snapshotPoolBlockReward(), snapshotValidators());
        }
    }

    function newValidatorSet() public onlySystem {
        address[] memory pools = getPools();
        require(pools.length > 0);

        uint256 i;
        address[] memory previousValidators = getPreviousValidators();
        address[] memory currentValidators = getValidators();

        // Save the previous validator set
        for (i = 0; i < previousValidators.length; i++) {
            _setIsValidatorOnPreviousEpoch(previousValidators[i], false);
        }
        for (i = 0; i < currentValidators.length; i++) {
            _setIsValidatorOnPreviousEpoch(currentValidators[i], true);
        }
        _setPreviousValidators(currentValidators);

        // Clear indexes for current validator set
        for (i = 0; i < currentValidators.length; i++) {
            _setValidatorIndex(currentValidators[i], 0);
            _setIsValidator(currentValidators[i], false);
        }

        // Choose new validators
        if (pools.length <= MAX_VALIDATORS) {
            currentValidators = pools;
        } else {
            uint256[] memory randomNumbers = randomContract().currentRandom();

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
                uint256 observerIndex = _getRandomIndex(likelihood, likelihoodSum, randomNumbers[i]);
                newValidators[i] = poolsLocal[observerIndex];
                likelihoodSum -= likelihood[observerIndex];
                poolsLocalLength--;
                poolsLocal[observerIndex] = poolsLocal[poolsLocalLength];
                likelihood[observerIndex] = likelihood[poolsLocalLength];
            }

            currentValidators = newValidators;
        }

        _setCurrentValidators(currentValidators);

        // Set indexes for new validator set
        for (i = 0; i < currentValidators.length; i++) {
            _setValidatorIndex(currentValidators[i], i);
            _setIsValidator(currentValidators[i], true);
        }

        // Increment counters
        _incrementChangeRequestCount();
        _incrementStakingEpoch();

        // Save stakes' snapshot
        _setSnapshot(currentValidators);

        _setValidatorSetApplyBlock(0);
        _setStakingEpochTimestamp(now);

        // From this moment `getValidators()` will return the new validator set
    }

    // Note: this implementation is only for AuRA
    function reportMaliciousValidator(bytes _message, bytes _signature)
        public
        onlySystem
    {
        address maliciousValidator;
        uint256 blockNumber;
        assembly {
            maliciousValidator := and(mload(add(_message, 20)), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            blockNumber := mload(add(_message, 52))
        }
        address reportingValidator = _recoverAddressFromSignedMessage(_message, _signature);

        require(_isReportingValidatorValid(reportingValidator));

        bool validatorSetChanged = false;

        uint256 validatorsLength = _getValidatorsLength();

        address[] storage reportedValidators =
            addressArrayStorage[keccak256(abi.encode(MALICE_REPORTED_FOR_BLOCK, maliciousValidator, blockNumber))];

        // Don't allow reporting validator to report about malicious validator more than once
        for (uint256 m = 0; m < reportedValidators.length; m++) {
            if (reportedValidators[m] == reportingValidator) {
                return;
            }
        }

        reportedValidators.push(reportingValidator);

        if (isValidatorBanned(maliciousValidator)) {
            // The malicious validator is already banned
            return;
        }

        uint256 reportCount = reportedValidators.length;

        // If more than 1/2 of validators reported about malicious validator
        // for _blockNumber
        if (reportCount.mul(2) > validatorsLength) {
            validatorSetChanged = _removeMaliciousValidator(maliciousValidator);
        }

        if (validatorSetChanged) {
            _incrementChangeRequestCount();
            // From this moment `getValidators()` will return the new validator set
        }
    }

    // Note: this function is only for hbbft
    function reportMaliciousValidators(address[] _validators, address[] _reportingValidators)
        public
        onlySystem
    {
        require(_validators.length == _reportingValidators.length);

        bool validatorSetChanged = false;

        uint256 validatorsLength = _getValidatorsLength();

        // Handle each perpetrator-reporter pair
        for (uint256 i = 0; i < _validators.length; i++) {
            address maliciousValidator = _validators[i];
            address reportingValidator = _reportingValidators[i];

            if (!_isReportingValidatorValid(reportingValidator)) {
                continue;
            }

            bool alreadyReported = false;

            address[] storage reportedValidators =
                addressArrayStorage[keccak256(abi.encode(MALICE_REPORTED, maliciousValidator))];

            // Don't allow `reportingValidator` to report about `maliciousValidator` more than once
            for (uint256 m = 0; m < reportedValidators.length; m++) {
                if (reportedValidators[m] == reportingValidator) {
                    alreadyReported = true;
                    break;
                }
            }

            if (alreadyReported) {
                continue;
            } else {
                reportedValidators.push(reportingValidator);
            }

            if (isValidatorBanned(maliciousValidator)) {
                // The `maliciousValidator` is already banned
                continue;
            }

            uint256 reportCount = reportedValidators.length;

            // If at least 1/3 of validators reported about `maliciousValidator`
            if (reportCount.mul(3) >= validatorsLength) {
                if (_removeMaliciousValidator(maliciousValidator)) {
                    validatorSetChanged = true;
                }
            }
        }

        if (validatorSetChanged) {
            _incrementChangeRequestCount();
            // From this moment `getValidators()` will return the new validator set
        }
    }

    // Note: this function is only for hbbft
    function savePublicKey(bytes _key) public {
        require(_key.length == 48); // https://github.com/poanetwork/threshold_crypto/issues/63
        require(stakeAmount(msg.sender, msg.sender) != 0);
        bytesStorage[keccak256(abi.encode(PUBLIC_KEY, msg.sender))] = _key;

        if (!isValidatorBanned(msg.sender)) {
            _addToPools(msg.sender);
        }
    }

    function moveStake(address _fromObserver, address _toObserver, uint256 _amount) public {
        require(_fromObserver != _toObserver);
        address staker = msg.sender;
        _withdraw(_fromObserver, staker, _amount);
        _stake(_toObserver, staker, _amount);
        emit StakeMoved(_fromObserver, _toObserver, staker, stakingEpoch(), _amount);
    }

    function stake(address _toObserver) public payable {
        address staker = msg.sender;
        _stake(_toObserver, staker, msg.value);
        emit Staked(_toObserver, staker, stakingEpoch(), msg.value);
    }

    function withdraw(address _fromObserver, uint256 _amount) public {
        address staker = msg.sender;
        _withdraw(_fromObserver, staker, _amount);
        staker.transfer(_amount);
        emit Withdrawn(_fromObserver, staker, stakingEpoch(), _amount);
    }

    function clearStakeHistory(address _observer, address[] _staker, uint256 _stakingEpoch) public onlySystem {
        require(_stakingEpoch <= stakingEpoch().sub(2));
        for (uint256 i = 0; i < _staker.length; i++) {
            _setStakeAmountByEpoch(_observer, _staker[i], _stakingEpoch, 0);
        }
    }

    function setBlockRewardContract(IBlockReward _blockRewardContract) public onlyOwner {
        require(blockRewardContract() == address(0));
        require(_blockRewardContract != address(0));
        addressStorage[BLOCK_REWARD_CONTRACT] = _blockRewardContract;
    }

    function setRandomContract(IRandom _randomContract) public onlyOwner {
        require(randomContract() == address(0));
        require(_randomContract != address(0));
        addressStorage[RANDOM_CONTRACT] = _randomContract;
    }

    // =============================================== Getters ========================================================

    // Returns the unix timestamp from which the address will be unbanned
    function bannedUntil(address _who) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(BANNED_UNTIL, _who))
        ];
    }

    function blockRewardContract() public view returns(IBlockReward) {
        return IBlockReward(addressStorage[BLOCK_REWARD_CONTRACT]);
    }

    // Returns the serial number of validator set changing request
    function changeRequestCount() public view returns(uint256) {
        return uintStorage[CHANGE_REQUEST_COUNT];
    }

    function doesPoolExist(address _who) public view returns(bool) {
        return isPoolActive(_who);
    }

    // Returns the list of current observers (pools)
    function getPools() public view returns(address[]) {
        return addressArrayStorage[POOLS];
    }

    // Returns the list of pools which are inactive or banned
    function getPoolsInactive() public view returns(address[]) {
        return addressArrayStorage[POOLS_INACTIVE];
    }

    // Returns the set of validators which was actual at the end of previous staking epoch
    function getPreviousValidators() public view returns(address[]) {
        return addressArrayStorage[PREVIOUS_VALIDATORS];
    }

    // Returns the current set of validators
    function getValidators() public view returns(address[]) {
        return addressArrayStorage[CURRENT_VALIDATORS];
    }

    // Returns the flag whether the address in the `pools` array
    function isPoolActive(address _who) public view returns(bool) {
        return boolStorage[keccak256(abi.encode(IS_POOL_ACTIVE, _who))];
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

    // Note: this function is only for hbbft
    function maliceReported(address _validator) public view returns(address[]) {
        return addressArrayStorage[keccak256(abi.encode(MALICE_REPORTED, _validator))];
    }

    // Note: this function is only for AuRa
    function maliceReportedForBlock(address _validator, uint256 _blockNumber) public view returns(address[]) {
        return addressArrayStorage[keccak256(abi.encode(MALICE_REPORTED_FOR_BLOCK, _validator, _blockNumber))];
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

    // Returns the list of current stakers in the specified pool
    function poolStakers(address _pool) public view returns(address[]) {
        return addressArrayStorage[
            keccak256(abi.encode(POOL_STAKERS, _pool))
        ];
    }

    // Returns staker index in `poolStakers` array
    function poolStakerIndex(address _pool, address _staker) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(POOL_STAKER_INDEX, _pool, _staker))
        ];
    }

    // Returns the serialized public key of observer/ validator
    // Note: this function is only for hbbft
    function publicKey(address _who) public view returns(bytes) {
        return bytesStorage[
            keccak256(abi.encode(PUBLIC_KEY, _who))
        ];
    }

    function randomContract() public view returns(IRandom) {
        return IRandom(addressStorage[RANDOM_CONTRACT]);
    }

    // Returns the pool block reward for the current staking epoch
    function snapshotPoolBlockReward() public view returns(uint256) {
        return uintStorage[SNAPSHOT_POOL_BLOCK_REWARD];
    }

    function snapshotStakers(address _validator) public view returns(address[]) {
        return addressArrayStorage[
            keccak256(abi.encode(SNAPSHOT_STAKERS, _validator))
        ];
    }

    function snapshotStakeAmount(address _validator, address _staker) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(SNAPSHOT_STAKE_AMOUNT, _validator, _staker))
        ];
    }

    function snapshotValidators() public view returns(address[]) {
        return addressArrayStorage[SNAPSHOT_VALIDATORS];
    }

    function stakeAmount(address _observer, address _staker) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(STAKE_AMOUNT, _observer, _staker))
        ];
    }

    function stakeAmountByEpoch(address _observer, address _staker, uint256 _stakingEpoch) public view returns(uint256) {
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
    bytes32 internal constant OWNER = keccak256("owner");
    bytes32 internal constant POOLS = keccak256("pools");
    bytes32 internal constant POOLS_INACTIVE = keccak256("poolsInactive");
    bytes32 internal constant PREVIOUS_VALIDATORS = keccak256("previousValidators");
    bytes32 internal constant RANDOM_CONTRACT = keccak256("randomContract");
    bytes32 internal constant SNAPSHOT_POOL_BLOCK_REWARD = keccak256("snapshotPoolBlockReward");
    bytes32 internal constant SNAPSHOT_VALIDATORS = keccak256("snapshotValidators");
    bytes32 internal constant STAKING_EPOCH = keccak256("stakingEpoch");
    bytes32 internal constant STAKING_EPOCH_TIMESTAMP = keccak256("stakingEpochTimestamp");
    bytes32 internal constant VALIDATOR_SET_APPLY_BLOCK = keccak256("validatorSetApplyBlock");

    bytes32 internal constant BANNED_UNTIL = "bannedUntil";
    bytes32 internal constant IS_POOL_ACTIVE = "isPoolActive";
    bytes32 internal constant IS_VALIDATOR = "isValidator";
    bytes32 internal constant IS_VALIDATOR_ON_PREVIOUS_EPOCH = "isValidatorOnPreviousEpoch";
    bytes32 internal constant MALICE_REPORTED = "maliceReported";
    bytes32 internal constant MALICE_REPORTED_FOR_BLOCK = "maliceReportedForBlock";
    bytes32 internal constant POOL_INDEX = "poolIndex";
    bytes32 internal constant POOL_INACTIVE_INDEX = "poolInactiveIndex";
    bytes32 internal constant POOL_STAKERS = "poolStakers";
    bytes32 internal constant POOL_STAKER_INDEX = "poolStakerIndex";
    bytes32 internal constant PUBLIC_KEY = "publicKey";
    bytes32 internal constant SNAPSHOT_STAKERS = "snapshotStakers";
    bytes32 internal constant SNAPSHOT_STAKE_AMOUNT = "snapshotStakeAmount";
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
        delete addressArrayStorage[keccak256(abi.encode(MALICE_REPORTED, _who))];
    }

    // Adds `_who` to the array of inactive pools
    function _addToPoolsInactive(address _who) internal {
        address[] storage poolsInactive = addressArrayStorage[POOLS_INACTIVE];
        if (poolsInactive[poolInactiveIndex(_who)] != _who) {
            _setPoolInactiveIndex(_who, poolsInactive.length);
            poolsInactive.push(_who);
        }
    }

    // Removes `_who` from the array of pools
    function _removeFromPools(address _who) internal {
        uint256 indexToRemove = poolIndex(_who);
        address[] storage pools = addressArrayStorage[POOLS];
        if (pools[indexToRemove] == _who) {
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
        if (poolsInactive[indexToRemove] == _who) {
            poolsInactive[indexToRemove] = poolsInactive[poolsInactive.length - 1];
            _setPoolInactiveIndex(poolsInactive[indexToRemove], indexToRemove);
            poolsInactive.length--;
            _setPoolInactiveIndex(_who, 0);
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

    function _removeMaliciousValidator(address _validator) internal returns(bool) {
        // Remove malicious validator from `pools`
        _removeFromPools(_validator);

        // Ban the malicious validator for the next 3 months
        _banValidator(_validator, now + 90 days);

        if (isValidator(_validator)) {
            // Remove the malicious validator from `currentValidators`
            _removeValidator(_validator);
            return true;
        }

        return false;
    }

    function _removeValidator(address _validator) internal {
        uint256 indexToRemove = validatorIndex(_validator);
        address[] storage validators = addressArrayStorage[CURRENT_VALIDATORS];
        validators[indexToRemove] = validators[validators.length - 1];
        _setValidatorIndex(validators[indexToRemove], indexToRemove);
        validators.length--;
        _setValidatorIndex(_validator, 0);
        _setIsValidator(_validator, false);
    }

    function _setCurrentValidators(address[] _validators) internal {
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

    function _setPoolStakerIndex(address _pool, address _staker, uint256 _index) internal {
        uintStorage[keccak256(abi.encode(POOL_STAKER_INDEX, _pool, _staker))] = _index;
    }

    // Add `_staker` to the array of observer's stakers
    function _addPoolStaker(address _pool, address _staker) internal {
        address[] storage stakers = addressArrayStorage[
            keccak256(abi.encode(POOL_STAKERS, _pool))
        ];
        _setPoolStakerIndex(_pool, _staker, stakers.length);
        stakers.push(_staker);
    }

    // Remove `_staker` from the array of observer's stakers
    function _removePoolStaker(address _pool, address _staker) internal {
        address[] storage stakers = addressArrayStorage[
            keccak256(abi.encode(POOL_STAKERS, _pool))
        ];
        uint256 indexToRemove = poolStakerIndex(_pool, _staker);
        stakers[indexToRemove] = stakers[stakers.length - 1];
        _setPoolStakerIndex(_pool, stakers[indexToRemove], indexToRemove);
        stakers.length--;
        _setPoolStakerIndex(_pool, _staker, 0);
    }

    function _setPreviousValidators(address[] _validators) internal {
        addressArrayStorage[PREVIOUS_VALIDATORS] = _validators;
    }

    function _setSnapshot(address[] _newValidators) internal {
        address validator;
        uint256 i;
        uint256 s;

        address[] storage validators = addressArrayStorage[SNAPSHOT_VALIDATORS];

        // Clear the previous snapshot
        for (i = 0; i < validators.length; i++) {
            validator = validators[i];
            _setSnapshotStakeAmount(validator, validator, 0);

            address[] storage validatorStakers = addressArrayStorage[
                keccak256(abi.encode(SNAPSHOT_STAKERS, validator))
            ];

            for (s = 0; s < validatorStakers.length; s++) {
                _setSnapshotStakeAmount(validator, validatorStakers[s], 0);
            }

            validatorStakers.length = 0;
        }

        // Make a new snapshot
        uintStorage[SNAPSHOT_POOL_BLOCK_REWARD] = blockRewardContract().BLOCK_REWARD() / _newValidators.length;

        addressArrayStorage[SNAPSHOT_VALIDATORS] = _newValidators;
        for (i = 0; i < _newValidators.length; i++) {
            validator = _newValidators[i];
            _setSnapshotStakeAmount(validator, validator, stakeAmount(validator, validator));

            address[] memory stakers = poolStakers(validator);

            for (s = 0; s < stakers.length; s++) {
                _setSnapshotStakeAmount(validator, stakers[s], stakeAmount(validator, stakers[s]));
            }

            addressArrayStorage[
                keccak256(abi.encode(SNAPSHOT_STAKERS, validator))
            ] = stakers;
        }
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

    function _setSnapshotStakeAmount(address _validator, address _staker, uint256 _amount) internal {
        uintStorage[
            keccak256(abi.encode(SNAPSHOT_STAKE_AMOUNT, _validator, _staker))
        ] = _amount;
    }

    function _setStakingEpochTimestamp(uint256 _timestamp) internal {
        uintStorage[STAKING_EPOCH_TIMESTAMP] = _timestamp;
    }

    function _setValidatorIndex(address _validator, uint256 _index) internal {
        uintStorage[
            keccak256(abi.encode(VALIDATOR_INDEX, _validator))
        ] = _index;
    }

    function _setValidatorSetApplyBlock(uint256 _blockNumber) internal {
        uintStorage[VALIDATOR_SET_APPLY_BLOCK] = _blockNumber;
    }

    function _stake(address _observer, address _staker, uint256 _amount) internal stakeWithdrawAllowed {
        require(_observer != address(0));
        require(_amount != 0);
        require(!isValidatorBanned(_observer));

        uint256 epoch = stakingEpoch();

        uint256 newStakeAmount = stakeAmount(_observer, _staker).add(_amount);
        if (_staker == _observer) {
            require(newStakeAmount >= VALIDATOR_MIN_STAKE); // the staked amount must be at least MIN_STAKE_VALIDATOR
        } else {
            require(newStakeAmount >= STAKER_MIN_STAKE); // the staked amount must be at least STAKER_MIN_STAKE
        }
        _setStakeAmount(_observer, _staker, newStakeAmount);
        _setStakeAmountByEpoch(_observer, _staker, epoch, stakeAmountByEpoch(_observer, _staker, epoch).add(_amount));
        _setStakeAmountTotal(_observer, stakeAmountTotal(_observer).add(_amount));

        if (_staker == _observer) { // `staker` makes a stake for himself and becomes an observer
            if (publicKey(_observer).length != 0) {
                // Add `_observer` to the array of pools
                _addToPools(_observer);
            }
        } else if (newStakeAmount == _amount) { // if the stake is first
            // Add `_staker` to the array of observer's stakers
            _addPoolStaker(_observer, _staker);
        }
    }

    function _withdraw(address _observer, address _staker, uint256 _amount) internal stakeWithdrawAllowed {
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
                require(newStakeAmount >= VALIDATOR_MIN_STAKE);
            } else {
                require(newStakeAmount >= STAKER_MIN_STAKE);
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
                // Remove `_staker` from the array of observer's stakers
                _removePoolStaker(_observer, _staker);
            }

            if (stakeAmountTotal(_observer) == 0) {
                _removeFromPoolsInactive(_observer);
            }
        }
    }

    function _getValidatorsLength() internal view returns(uint256) {
        uint256 validatorsLength = getValidators().length;
        if (validatorSetApplyBlock() == 0 && stakingEpoch() > 0) {
            validatorsLength = getPreviousValidators().length;
        }
        return validatorsLength;
    }

    function _isReportingValidatorValid(address _reportingValidator) internal view returns(bool) {
        if (stakingEpoch() == 0) {
            return isValidator(_reportingValidator);
        }
        if (validatorSetApplyBlock() == 0) {
            // The current validator set is not applied on nodes yet,
            // so let the validators from previous staking epoch
            // report malicious validator
            if (!isValidatorOnPreviousEpoch(_reportingValidator)) {
                return false;
            }
            if (isValidatorBanned(_reportingValidator)) {
                return false;
            }
        } else if (block.number - validatorSetApplyBlock() <= 3) {
            // The current validator set is applied on hbbft,
            // but we should let the previous validators finish
            // reporting malicious validator within a few blocks
            bool previousEpochValidator =
                isValidatorOnPreviousEpoch(_reportingValidator) && !isValidatorBanned(_reportingValidator);
            return isValidator(_reportingValidator) || previousEpochValidator;
        } else {
            return isValidator(_reportingValidator);
        }
        return true;
    }

    function _getRandomIndex(uint256[] _likelihood, uint256 _likelihoodSum, uint256 _randomNumber)
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

    function _recoverAddressFromSignedMessage(bytes _message, bytes _signature)
        internal
        pure
        returns(address)
    {
        require(_signature.length == 65);
        bytes32 r;
        bytes32 s;
        bytes1 v;
        assembly {
            r := mload(add(_signature, 0x20))
            s := mload(add(_signature, 0x40))
            v := mload(add(_signature, 0x60))
        }
        bytes memory prefix = "\x19Ethereum Signed Message:\n";
        string memory msgLength = "52";
        require(_message.length == 52);
        bytes32 messageHash = keccak256(abi.encodePacked(prefix, msgLength, _message));
        return ecrecover(messageHash, uint8(v), r, s);
    }
}
