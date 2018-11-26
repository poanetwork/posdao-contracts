pragma solidity 0.4.25;

import "./interfaces/IBlockReward.sol";
import "./interfaces/IReportingValidatorSet.sol";
import "./libs/SafeMath.sol";


contract ReportingValidatorSet is IReportingValidatorSet {
    using SafeMath for uint256;

    // TODO: add a description for each function

    struct ObserverState {
        uint256 validatorIndex; // index in the `currentValidators`
        uint256 bannedUntil; // unix timestamp from which the address will be unbanned
        bytes publicKey; // serialized public key of observer/ validator
        bool isValidator; // is this address in the `currentValidators` array?
        bool isActive; // is this address in the `pools` array?
    }

    // ================================================ Store =========================================================

    IBlockReward public blockReward;

    uint256 public stakingEpoch; // the internal serial number of staking epoch
    uint256 public changeRequestCount; // the serial number of validator set changing request
    uint256 public validatorSetApplyBlock; // the block number when `finalizeChange` was called to apply set on hbbft
    
    address[] public currentValidators; // the current set of validators
    address[] public previousValidators; // the set of validators at the end of previous staking epoch

    uint64[] public currentRandom;

    address[] public pools; // the list of current observers (pools)
    mapping(address => uint256) public poolIndex; // pool index in `pools` array

    address[] public poolsInactive; // the list of pools which are inactive or banned
    mapping(address => uint256) public poolInactiveIndex; // pool index in `poolsInactive` array

    mapping(address => address[]) public poolStakers; // the list of current stakers in the specified pool
    mapping(address => mapping(address => uint256)) public poolStakerIndex; // staker index in `poolStakers` array

    mapping(address => mapping(address => uint256)) public stakeAmount;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public stakeAmountByEpoch;
    mapping(address => uint256) public stakeAmountTotal;

    mapping(address => ObserverState) public observersState;
    mapping(address => bool) public isValidatorOnPreviousEpoch;

    mapping(address => mapping(uint256 => mapping(bytes32 => uint256))) public maliceProofCount;
    mapping(address => mapping(uint256 => mapping(bytes32 => mapping(address => bool)))) public maliceReported;

    // Distribution of block reward for the current staking epoch
    mapping(address => mapping(address => uint256)) public rewardDistribution;
    mapping(address => address[]) public rewardDistributionStakers;
    address[] public rewardDistributionValidators;

    // ============================================== Constants =======================================================

    uint256 public constant MAX_OBSERVERS = 2000;
    uint256 public constant MAX_VALIDATORS = 20;
    uint256 public constant MIN_STAKE = 1 * STAKE_UNIT; // must be specified before network launching
    uint256 public constant STAKE_UNIT = 1 ether;

    // ================================================ Events ========================================================
    
    /// Emitted by `reportMalicious` function to signal a desired change in validator set.
    /// @param parentHash Should be the parent block hash.
    /// @param newSet New set of validators (without malicious validator).
    event InitiateChange(
        bytes32 indexed parentHash,
        address[] newSet
    );

    /// Emitted by `reportBenign` function to signal that the validator doesn't take part
    /// in the consensus process.
    /// @param reporter Reporting validator.
    /// @param validator Reported validator.
    /// @param blockNumber The block on which the reported validator didn't take part in consensus.
    event BenignReported(
        address indexed reporter,
        address indexed validator,
        uint256 indexed blockNumber
    );

    /// Emitted by `reportMalicious` function to signal that the validator misbehaves.
    /// @param reporter Reporting validator.
    /// @param validator Reported validator.
    /// @param blockNumber The block on which the reported validator misbehaved.
    /// @param proofHash keccak256 hash of the proof bytes sequence.
    event MaliciousReported(
        address indexed reporter,
        address indexed validator,
        uint256 indexed blockNumber,
        bytes32 proofHash
    );

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

    modifier onlySystem() {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    // =============================================== Setters ========================================================

    constructor(IBlockReward _blockReward) public {
        require(_blockReward != address(0));
        blockReward = _blockReward;
    }

    function exit() public {
        require(isValidator(msg.sender));
        _removeFromPools(msg.sender);
    }

    function finalizeChange() public onlySystem {
        if (stakingEpoch == 0) {
            // Ignore invocations if `newValidatorSet()` has never been called
            return;
        }

        // Apply new reward distribution after `newValidatorSet()` is called,
        // not after `InitiateChange` event is emitted
        if (validatorSetApplyBlock == 0) {
            validatorSetApplyBlock = block.number;
            blockReward.newDistribution(); // trigger setting of new reward distribution
        }
    }

    function newValidatorSet() public onlySystem returns(address[]) {
        require(pools.length != 0);

        uint256 i;

        // Save the previous validator set
        for (i = 0; i < previousValidators.length; i++) {
            isValidatorOnPreviousEpoch[previousValidators[i]] = false;
        }
        for (i = 0; i < currentValidators.length; i++) {
            isValidatorOnPreviousEpoch[currentValidators[i]] = true;
        }
        previousValidators = currentValidators;

        // Clear `ObserverState` for current validator set
        for (i = 0; i < currentValidators.length; i++) {
            observersState[currentValidators[i]].validatorIndex = 0;
            observersState[currentValidators[i]].isValidator = false;
        }

        // Choose new validators
        if (pools.length <= MAX_VALIDATORS) {
            currentValidators = pools;
        } else {
            require(currentRandom.length == MAX_VALIDATORS);

            uint256[] memory likelihood = new uint256[](pools.length);
            address[] memory poolsLocal = pools;
            address[] memory newValidators = new address[](MAX_VALIDATORS);

            uint256 likelihoodSum = 0;
            uint256 poolsLocalLength = poolsLocal.length;

            for (i = 0; i < pools.length; i++) {
               likelihood[i] = stakeAmountTotal[pools[i]].mul(100).div(STAKE_UNIT);
               likelihoodSum = likelihoodSum.add(likelihood[i]);
            }

            for (i = 0; i < MAX_VALIDATORS; i++) {
                uint256 observerIndex = _getRandomIndex(likelihood, likelihoodSum, currentRandom[i]);
                newValidators[i] = poolsLocal[observerIndex];
                likelihoodSum -= likelihood[observerIndex];
                poolsLocalLength--;
                poolsLocal[observerIndex] = poolsLocal[poolsLocalLength];
                likelihood[observerIndex] = likelihood[poolsLocalLength];
            }

            currentValidators = newValidators;
        }

        // Set `ObserverState` for new validator set
        for (i = 0; i < currentValidators.length; i++) {
            observersState[currentValidators[i]].validatorIndex = i;
            observersState[currentValidators[i]].isValidator = true;
        }

        // Increment counters
        changeRequestCount++;
        stakingEpoch++;

        // Calculate and save the new reward distribution
        _setRewardDistribution();

        validatorSetApplyBlock = 0;

        return currentValidators;
    }

    function reportBenign(address _validator, uint256 _blockNumber) public {
        require(_isReportingValidatorValid());
        emit BenignReported(msg.sender, _validator, _blockNumber);
    }

    // Note: the calling validator must have enough balance for gas spending
    function reportMalicious(address _validator, uint256 _blockNumber, bytes _proof) public {
        require(_isReportingValidatorValid());

        bytes32 proofHash = keccak256(_proof);

        // Don't allow the validator to report the same more than once
        require(!maliceReported[_validator][_blockNumber][proofHash][msg.sender]);
        maliceReported[_validator][_blockNumber][proofHash][msg.sender] = true;

        // If the `_proof` is the same for most validators
        uint256 proofCount = ++maliceProofCount[_validator][_blockNumber][proofHash];
        
        bool majorityAchieved;
        if (validatorSetApplyBlock == 0) {
            majorityAchieved = proofCount > previousValidators.length / 2;
        } else {
            majorityAchieved = proofCount > currentValidators.length / 2;
        }

        if (majorityAchieved && !isValidatorBanned(_validator)) {
            // Remove `_validator` from `pools`
            _removeFromPools(_validator);

            // Ban the `_validator` for the next 3 months
            observersState[_validator].bannedUntil = now + 90 days;

            if (isValidator(_validator)) {
                // Remove `_validator` from `currentValidators`
                uint256 indexToRemove = observersState[_validator].validatorIndex;
                currentValidators[indexToRemove] = currentValidators[currentValidators.length - 1];
                observersState[currentValidators[indexToRemove]].validatorIndex = indexToRemove;
                currentValidators.length--;
                observersState[_validator].validatorIndex = 0;
                observersState[_validator].isValidator = false;

                changeRequestCount++;
                emit InitiateChange(blockhash(block.number - 1), currentValidators);
            }
        }
        
        emit MaliciousReported(msg.sender, _validator, _blockNumber, proofHash);
    }

    function savePublicKey(bytes _key) public {
        require(_key.length == 48); // https://github.com/poanetwork/threshold_crypto/issues/63
        observersState[msg.sender].publicKey = _key;
        // TODO: allow calling this function only after observer makes a stake for himself
    }

    function storeRandom(uint64[] _random) public onlySystem {
        require(_random.length == MAX_VALIDATORS);
        currentRandom.length = 0;
        for (uint256 i = 0; i < _random.length; i++) {
            currentRandom.push(_random[i]);
        }
    }

    function moveStake(address _fromObserver, address _toObserver, uint256 _amount) public {
        require(_fromObserver != _toObserver);
        address staker = msg.sender;
        _withdraw(_fromObserver, staker, _amount);
        _stake(_toObserver, staker, _amount);
        emit StakeMoved(_fromObserver, _toObserver, staker, stakingEpoch, _amount);
    }

    function stake(address _toObserver) public payable {
        address staker = msg.sender;
        _stake(_toObserver, staker, msg.value);
        emit Staked(_toObserver, staker, stakingEpoch, msg.value);
    }

    function withdraw(address _fromObserver, uint256 _amount) public {
        address staker = msg.sender;
        _withdraw(_fromObserver, staker, _amount);
        staker.transfer(_amount);
        emit Withdrawn(_fromObserver, staker, stakingEpoch, _amount);
    }

    function clearStakeHistory(address _observer, address[] _staker, uint256 _stakingEpoch) public onlySystem {
        require(_stakingEpoch <= stakingEpoch.sub(2));
        for (uint256 i = 0; i < _staker.length; i++) {
            delete stakeAmountByEpoch[_observer][_staker[i]][_stakingEpoch];
        }
    }

    // =============================================== Getters ========================================================

    function doesPoolExist(address _who) public view returns(bool) {
        return observersState[_who].isActive;
    }

    function getPools() public view returns(address[]) {
        return pools;
    }

    function getValidators() public view returns(address[]) {
        return currentValidators;
    }

    function isValidator(address _who) public view returns(bool) {
        return observersState[_who].isValidator;
    }

    function isValidatorBanned(address _validator) public view returns(bool) {
        return now < observersState[_validator].bannedUntil;
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
            return stakeAmount[_observer][_staker];
        }

        if (isValidatorOnPreviousEpoch[_observer]) {
            // The observer was also a validator on the previous staking epoch, so
            // the staker can't withdraw amount staked on the previous staking epoch
            return stakeAmount[_observer][_staker].sub(
                stakeAmountByEpoch[_observer][_staker][stakingEpoch.sub(1)] // stakingEpoch is always > 0 here
            );
        } else {
            // The observer wasn't a validator on the previous staking epoch, so
            // the staker can only withdraw amount staked on the current staking epoch
            return stakeAmountByEpoch[_observer][_staker][stakingEpoch];
        }
    }

    // =============================================== Private ========================================================

    // Adds `_who` to the array of pools
    function _addToPools(address _who) internal {
        if (!doesPoolExist(_who)) {
            poolIndex[_who] = pools.length;
            pools.push(_who);
            require(pools.length <= MAX_OBSERVERS);
            observersState[_who].isActive = true;
        }
        _removeFromPoolsInactive(_who);
    }

    // Adds `_who` to the array of inactive pools
    function _addToPoolsInactive(address _who) internal {
        if (poolsInactive[poolInactiveIndex[_who]] != _who) {
            poolInactiveIndex[_who] = poolsInactive.length;
            poolsInactive.push(_who);
        }
    }

    // Removes `_who` from the array of pools
    function _removeFromPools(address _who) internal {
        uint256 indexToRemove = poolIndex[_who];
        if (pools[indexToRemove] == _who) {
            pools[indexToRemove] = pools[pools.length - 1];
            poolIndex[pools[indexToRemove]] = indexToRemove;
            pools.length--;
            delete poolIndex[_who];
            observersState[_who].isActive = false;
            if (stakeAmountTotal[_who] != 0) {
                _addToPoolsInactive(_who);
            }
        }
    }

    // Removes `_who` from the array of inactive pools
    function _removeFromPoolsInactive(address _who) internal {
        uint256 indexToRemove = poolsInactiveIndex[_who];
        if (poolsInactive[indexToRemove] == _who) {
            poolsInactive[indexToRemove] = poolsInactive[poolsInactive.length - 1];
            poolsInactiveIndex[poolsInactive[indexToRemove]] = indexToRemove;
            poolsInactive.length--;
            delete poolsInactiveIndex[_who];
        }
    }

    function _setRewardDistribution() internal {
        uint256 i;
        uint256 s;
        address validator;
        address staker;

        // Clear the previous distribution
        for (i = 0; i < rewardDistributionValidators.length; i++) {
            validator = rewardDistributionValidators[i];
            rewardDistribution[validator][validator] = 0;
            for (s = 0; s < rewardDistributionStakers[validator].length; s++) {
                staker = rewardDistributionStakers[validator][s];
                rewardDistribution[validator][staker] = 0;
            }
            delete rewardDistributionStakers[validator];
        }

        // Set a new distribution
        uint256 poolReward = blockReward.BLOCK_REWARD() / currentValidators.length;
        
        rewardDistributionValidators = currentValidators;
        for (i = 0; i < currentValidators.length; i++) {
            validator = currentValidators[i];

            uint256 validatorStake = stakeAmount[validator][validator];
            uint256 totalAmount = stakeAmountTotal[validator];
            uint256 stakersAmount = totalAmount - validatorStake;
            bool validatorDominates = validatorStake > stakersAmount;

            uint256 reward;
            if (validatorDominates) {
                reward = poolReward.mul(validatorStake).div(totalAmount);
            } else {
                reward = poolReward.mul(3).div(10);
            }
            rewardDistribution[validator][validator] = reward;

            for (s = 0; s < poolStakers[validator].length; s++) {
                staker = poolStakers[validator][s];
                uint256 stakerStake = stakeAmount[validator][staker];
                if (validatorDominates) {
                    reward = poolReward.mul(stakerStake).div(totalAmount);
                } else {
                    reward = poolReward.mul(stakerStake).mul(7).div(stakersAmount.mul(10));
                }
                rewardDistribution[validator][staker] = reward;
                rewardDistributionStakers[validator].push(staker);
            }
        }
    }

    function _stake(address _observer, address _staker, uint256 _amount) internal {
        require(_observer != address(0));
        require(_amount != 0);
        require(!isValidatorBanned(_observer));

        bool stakerIsObserver = _staker == _observer; // `staker` makes a stake for himself and becomes an observer

        if (stakerIsObserver) {
            require(observersState[_observer].publicKey.length != 0);
        }

        uint256 newStakeAmount = stakeAmount[_observer][_staker].add(_amount);
        require(newStakeAmount >= MIN_STAKE); // the staked amount must be at least MIN_STAKE
        stakeAmount[_observer][_staker] = newStakeAmount;
        stakeAmountByEpoch[_observer][_staker][stakingEpoch] =
            stakeAmountByEpoch[_observer][_staker][stakingEpoch].add(_amount);
        stakeAmountTotal[_observer] = stakeAmountTotal[_observer].add(_amount);

        if (stakerIsObserver) { // if the observer makes a stake for himself
            // Add `_observer` to the array of pools
            _addToPools(_observer);
        } else if (newStakeAmount == _amount) { // if the stake is first
            // Add `_staker` to the array of observer's stakers
            poolStakerIndex[_observer][_staker] = poolStakers[_observer].length;
            poolStakers[_observer].push(_staker);
        }
    }

    function _withdraw(address _observer, address _staker, uint256 _amount) internal {
        require(_observer != address(0));
        require(_amount != 0);

        // How much can `staker` withdraw from `_observer` pool at the moment?
        require(_amount <= maxWithdrawAllowed(_observer, _staker));

        // The amount to be withdrawn must be the whole staked amount or
        // must not exceed the diff between the entire amount and MIN_STAKE
        uint256 newStakeAmount = stakeAmount[_observer][_staker].sub(_amount);
        require(newStakeAmount == 0 || newStakeAmount >= MIN_STAKE);
        stakeAmount[_observer][_staker] = newStakeAmount;
        if (_amount <= stakeAmountByEpoch[_observer][_staker][stakingEpoch]) {
            stakeAmountByEpoch[_observer][_staker][stakingEpoch] -= _amount;
        } else {
            stakeAmountByEpoch[_observer][_staker][stakingEpoch] = 0;
        }
        stakeAmountTotal[_observer] = stakeAmountTotal[_observer].sub(_amount);

        if (newStakeAmount == 0) { // the whole amount has been withdrawn
            if (_staker == _observer) {
                // Remove `_observer` from the array of pools
                _removeFromPools(_observer);
            } else {
                // Remove `_staker` from the array of observer's stakers
                uint256 indexToRemove = poolStakerIndex[_observer][_staker];
                poolStakers[_observer][indexToRemove] =
                    poolStakers[_observer][poolStakers[_observer].length];
                poolStakerIndex[_observer][poolStakers[_observer][indexToRemove]] =
                    indexToRemove;
                poolStakers[_observer].length--;
                delete poolStakerIndex[_observer][_staker];
            }

            if (stakeAmountTotal[_observer] == 0) {
                _removeFromPoolsInactive(_observer);
            }
        }
    }

    function _isReportingValidatorValid() internal view returns(bool) {
        if (validatorSetApplyBlock == 0) {
            // The current validator set is not applied on hbbft yet,
            // so let the validators from previous staking epoch
            // report malicious validator
            if (!isValidatorOnPreviousEpoch[msg.sender]) {
                return false;
            }
            if (isValidatorBanned(msg.sender)) {
                return false;
            }
        } else if (block.number - validatorSetApplyBlock <= 3) {
            // The current validator set is applied on hbbft,
            // but we should let the previous validators finish
            // reporting malicious validator within a few blocks
            bool previousEpochValidator = isValidatorOnPreviousEpoch[msg.sender] && !isValidatorBanned(msg.sender);
            return isValidator(msg.sender) || previousEpochValidator;
        } else {
            return isValidator(msg.sender);
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
}
