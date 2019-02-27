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
    /// @param toPoolStakingAddress The pool for which the `staker` made the stake.
    /// @param staker The address of staker who made the stake.
    /// @param stakingEpoch The serial number of staking epoch during which the stake was made.
    /// @param amount The amount of the stake.
    event Staked(
        address indexed toPoolStakingAddress,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount
    );

    /// @dev Emitted by `moveStake` function to signal that the staker moved the specified
    /// amount of a stake from one pool to another during the specified staking epoch.
    /// @param fromPoolStakingAddress The pool from which the `staker` moved the stake.
    /// @param toPoolStakingAddress The pool to which the `staker` moved the stake.
    /// @param staker The address of staker who moved the `amount`.
    /// @param stakingEpoch The serial number of staking epoch during which the `amount` was moved.
    /// @param amount The amount of the stake.
    event StakeMoved(
        address fromPoolStakingAddress,
        address indexed toPoolStakingAddress,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount
    );

    /// @dev Emitted by `orderWithdraw` function to signal that the staker ordered the withdrawal of the
    /// specified amount of their stake from the specified pool during the specified staking epoch.
    /// @param fromPoolStakingAddress The pool from which the `staker` ordered withdrawal of `amount`.
    /// @param staker The address of staker who ordered withdrawal of `amount`.
    /// @param stakingEpoch The serial number of staking epoch during which the order was made.
    /// @param amount The amount of the ordered withdrawal. Can be either positive or negative.
    event WithdrawalOrdered(
        address indexed fromPoolStakingAddress,
        address indexed staker,
        uint256 indexed stakingEpoch,
        int256 amount
    );

    /// @dev Emitted by `withdraw` function to signal that the staker withdrew the specified
    /// amount of a stake from the specified pool during the specified staking epoch.
    /// @param fromPoolStakingAddress The pool from which the `staker` withdrew `amount`.
    /// @param staker The address of staker who withdrew `amount`.
    /// @param stakingEpoch The serial number of staking epoch during which the withdrawal was made.
    /// @param amount The amount of the withdrawal.
    event Withdrawn(
        address indexed fromPoolStakingAddress,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount
    );

    // ============================================== Modifiers =======================================================

    modifier gasPriceIsValid() {
        require(tx.gasprice != 0);
        _;
    }

    modifier onlyBlockRewardContract() {
        require(msg.sender == address(blockRewardContract()));
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
            emit InitiateChange(blockhash(block.number - 1), newSet);
            _setInitiateChangeAllowed(false);
            _setQueueValidators(newSet, newStakingEpoch);
        }
    }

    function performOrderedWithdrawals() external onlyBlockRewardContract {
        if (validatorSetApplyBlock() != _getCurrentBlockNumber()) return;

        uint256 candidateMinStake = getCandidateMinStake();
        uint256 delegatorMinStake = getDelegatorMinStake();
        IERC20Minting tokenContract = IERC20Minting(erc20TokenContract());

        address[] storage validators = addressArrayStorage[PREVIOUS_VALIDATORS];

        for (uint256 i = 0; i < validators.length; i++) {
            address poolStakingAddress = stakingByMiningAddress(validators[i]);

            // Withdraw validator's stake
            _performOrderedWithdrawals(poolStakingAddress, poolStakingAddress, candidateMinStake, tokenContract);

            // Withdraw delegators' stakes
            address[] storage delegators = addressArrayStorage[keccak256(abi.encode(
                POOL_DELEGATORS, poolStakingAddress
            ))];

            for (uint256 d = 0; d < delegators.length; d++) {
                _performOrderedWithdrawals(poolStakingAddress, delegators[d], delegatorMinStake, tokenContract);
            }

            // Reset total ordered withdrawal amount for the pool
            _setOrderedWithdrawAmountTotal(poolStakingAddress, 0);
        }
    }

    function removePool() public gasPriceIsValid {
        address stakingAddress = msg.sender;
        // initial validator cannot remove their pool during the initial staking epoch
        require(stakingEpoch() > 0 || !isValidator(miningByStakingAddress(stakingAddress)));
        require(stakingAddress != unremovableValidator());
        _removeFromPools(stakingAddress);
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

    /// @dev Moves the tokens from one pool to another.
    /// @param _fromPoolStakingAddress The staking address of the source pool.
    /// @param _toPoolStakingAddress The staking address of the target pool.
    /// @param _amount The amount to be moved.
    function moveStake(
        address _fromPoolStakingAddress,
        address _toPoolStakingAddress,
        uint256 _amount
    ) public gasPriceIsValid {
        require(_fromPoolStakingAddress != _toPoolStakingAddress);
        address staker = msg.sender;
        _withdraw(_fromPoolStakingAddress, staker, _amount);
        _stake(_toPoolStakingAddress, staker, _amount);
        emit StakeMoved(_fromPoolStakingAddress, _toPoolStakingAddress, staker, stakingEpoch(), _amount);
    }

    /// @dev Moves the tokens from staker address to ValidatorSet address
    /// on the account of staking address of the pool.
    /// @param _toPoolStakingAddress The staking address of the pool.
    /// @param _amount The amount of the stake.
    function stake(address _toPoolStakingAddress, uint256 _amount) public gasPriceIsValid {
        IERC20Minting tokenContract = IERC20Minting(erc20TokenContract());
        require(address(tokenContract) != address(0));
        address staker = msg.sender;
        _stake(_toPoolStakingAddress, staker, _amount);
        tokenContract.stake(staker, _amount);
        emit Staked(_toPoolStakingAddress, staker, stakingEpoch(), _amount);
    }

    /// @dev Moves the tokens from ValidatorSet address (from the account of
    /// staking address of the pool) to staker address.
    /// @param _fromPoolStakingAddress The staking address of the pool.
    /// @param _amount The amount of the withdrawal.
    function withdraw(address _fromPoolStakingAddress, uint256 _amount) public gasPriceIsValid {
        IERC20Minting tokenContract = IERC20Minting(erc20TokenContract());
        require(address(tokenContract) != address(0));
        address staker = msg.sender;
        _withdraw(_fromPoolStakingAddress, staker, _amount);
        tokenContract.withdraw(staker, _amount);
        emit Withdrawn(_fromPoolStakingAddress, staker, stakingEpoch(), _amount);
    }

    /// @dev Makes an order of tokens withdrawal from ValidatorSet address
    /// (from the account of staking address of the pool) to staker address.
    /// The tokens will be automatically withdrawn at the beginning of the
    /// next staking epoch.
    /// @param _fromPoolStakingAddress The staking address of the pool.
    /// @param _amount The amount of the withdrawal. Positive value means
    /// that the staker wants to set or increase their withdrawal amount.
    /// Negative value means that the staker wants to decrease their
    /// withdrawal amount which was set before.
    function orderWithdraw(address _fromPoolStakingAddress, int256 _amount) public gasPriceIsValid {
        IERC20Minting tokenContract = IERC20Minting(erc20TokenContract());
        require(address(tokenContract) != address(0));

        require(_fromPoolStakingAddress != address(0));
        require(_amount != 0);
        require(areStakeAndWithdrawAllowed());

        address staker = msg.sender;

        // How much can `staker` order for withdrawal from `_fromPoolStakingAddress` at the moment?
        require(_amount < 0 || uint256(_amount) <= maxWithdrawOrderAllowed(_fromPoolStakingAddress, staker));

        uint256 alreadyOrderedAmount = orderedWithdrawAmount(_fromPoolStakingAddress, staker);

        require(_amount > 0 || uint256(-_amount) <= alreadyOrderedAmount);

        uint256 newOrderedAmount;
        if (_amount > 0) {
            newOrderedAmount = alreadyOrderedAmount.add(uint256(_amount));
        } else {
            newOrderedAmount = alreadyOrderedAmount.sub(uint256(-_amount));
        }

        uint256 newStakeAmount = stakeAmount(_fromPoolStakingAddress, staker).sub(newOrderedAmount);

        // The amount to be withdrawn must be the whole staked amount or
        // must not exceed the diff between the entire amount and MIN_STAKE
        if (staker == _fromPoolStakingAddress) {
            require(newStakeAmount == 0 || newStakeAmount >= getCandidateMinStake());
        } else {
            require(newStakeAmount == 0 || newStakeAmount >= getDelegatorMinStake());
        }

        _setOrderedWithdrawAmount(_fromPoolStakingAddress, staker, newOrderedAmount);

        // Set total ordered amount for this pool
        alreadyOrderedAmount = orderedWithdrawAmountTotal(_fromPoolStakingAddress);
        if (_amount > 0) {
            newOrderedAmount = alreadyOrderedAmount.add(uint256(_amount));
        } else {
            newOrderedAmount = alreadyOrderedAmount.sub(uint256(-_amount));
        }
        _setOrderedWithdrawAmountTotal(_fromPoolStakingAddress, newOrderedAmount);

        emit WithdrawalOrdered(_fromPoolStakingAddress, staker, stakingEpoch(), _amount);
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

    function doesPoolExist(address _stakingAddress) public view returns(bool) {
        return isPoolActive(_stakingAddress);
    }

    function emitInitiateChangeCallable() public view returns(bool) {
        return initiateChangeAllowed() && uintStorage[QUEUE_PV_LAST] >= uintStorage[QUEUE_PV_FIRST];
    }

    function erc20TokenContract() public view returns(address) {
        return addressStorage[ERC20_TOKEN_CONTRACT];
    }

    // Returns the list of current pools (candidates and validators)
    // (their staking addresses)
    function getPools() public view returns(address[] memory) {
        return addressArrayStorage[POOLS];
    }

    // Returns the list of pools which are inactive or banned
    // (their staking addresses)
    function getPoolsInactive() public view returns(address[] memory) {
        return addressArrayStorage[POOLS_INACTIVE];
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

    function getCandidateMinStake() public view returns(uint256) {
        return uintStorage[CANDIDATE_MIN_STAKE];
    }

    function getDelegatorMinStake() public view returns(uint256) {
        return uintStorage[DELEGATOR_MIN_STAKE];
    }

    // Returns the current set of validators (the same as in the engine)
    // (their mining addresses)
    function getValidators() public view returns(address[] memory) {
        return addressArrayStorage[CURRENT_VALIDATORS];
    }

    function initiateChangeAllowed() public view returns(bool) {
        return boolStorage[INITIATE_CHANGE_ALLOWED];
    }

    // Returns the flag whether the address is in the `pools` array
    function isPoolActive(address _stakingAddress) public view returns(bool) {
        return boolStorage[keccak256(abi.encode(IS_POOL_ACTIVE, _stakingAddress))];
    }

    function isReportValidatorValid(address _miningAddress) public view returns(bool) {
        bool isValid = isValidator(_miningAddress) && !isValidatorBanned(_miningAddress);
        if (stakingEpoch() == 0 || validatorSetApplyBlock() == 0) {
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

    function isValidatorBanned(address _miningAddress) public view returns(bool);

    function maxWithdrawAllowed(address _poolStakingAddress, address _staker) public view returns(uint256) {
        address miningAddress = miningByStakingAddress(_poolStakingAddress);

        if (!_isWithdrawAllowed(miningAddress)) {
            return 0;
        }

        if (!isValidator(miningAddress)) {
            // The whole amount can be withdrawn if the pool is not a validator
            return stakeAmount(_poolStakingAddress, _staker);
        }

        // The pool is an active validator, so the staker can
        // withdraw staked amount minus already ordered amount
        // but no more than amount staked during the current
        // staking epoch
        uint256 canWithdraw = stakeAmountMinusOrderedWithdraw(_poolStakingAddress, _staker);
        uint256 stakedDuringEpoch = stakeAmountByCurrentEpoch(_poolStakingAddress, _staker);

        if (canWithdraw > stakedDuringEpoch) {
            canWithdraw = stakedDuringEpoch;
        }

        return canWithdraw;
    }

    function maxWithdrawOrderAllowed(address _poolStakingAddress, address _staker) public view returns(uint256) {
        address miningAddress = miningByStakingAddress(_poolStakingAddress);

        if (!_isWithdrawAllowed(miningAddress)) {
            return 0;
        }

        if (!isValidator(miningAddress)) {
            // If the pool is a candidate (not a validator yet),
            // no one can order withdrawal from `_poolStakingAddress`,
            // but anyone can withdraw immediately (see `maxWithdrawAllowed()` getter)
            return 0;
        }

        // It the pool is an active validator, the staker can
        // order withdrawal up to their total staking amount
        // minus already ordered amount
        return stakeAmountMinusOrderedWithdraw(_poolStakingAddress, _staker);
    }

    function miningByStakingAddress(address _stakingAddress) public view returns(address) {
        return addressStorage[keccak256(abi.encode(MINING_BY_STAKING_ADDRESS, _stakingAddress))];
    }

    /// @dev Prevents sending tokens to `ValidatorSet` contract address
    /// directly by `ERC677BridgeTokenRewardable.transferAndCall` function.
    function onTokenTransfer(address, uint256, bytes memory) public pure returns(bool) {
        return false;
    }

    function orderedWithdrawAmount(address _poolStakingAddress, address _staker) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(ORDERED_WITHDRAW_AMOUNT, _poolStakingAddress, _staker))
        ];
    }

    function orderedWithdrawAmountTotal(address _poolStakingAddress) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(ORDERED_WITHDRAW_AMOUNT_TOTAL, _poolStakingAddress))
        ];
    }

    function stakeAmountTotal(address _poolStakingAddress) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(STAKE_AMOUNT_TOTAL, _poolStakingAddress))
        ];
    }

    // Returns an index of the pool in the `pools` array
    function poolIndex(address _stakingAddress) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(POOL_INDEX, _stakingAddress))
        ];
    }

    // Returns an index of the pool in the `poolsInactive` array
    function poolInactiveIndex(address _stakingAddress) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(POOL_INACTIVE_INDEX, _stakingAddress))
        ];
    }

    // Returns the list of the current delegators in the specified pool
    function poolDelegators(address _poolStakingAddress) public view returns(address[] memory) {
        return addressArrayStorage[
            keccak256(abi.encode(POOL_DELEGATORS, _poolStakingAddress))
        ];
    }

    // Returns delegator's index in `poolDelegators` array
    function poolDelegatorIndex(address _poolStakingAddress, address _delegator) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(POOL_DELEGATOR_INDEX, _poolStakingAddress, _delegator))
        ];
    }

    function randomContract() public view returns(address) {
        return addressStorage[RANDOM_CONTRACT];
    }

    function stakeAmount(address _poolStakingAddress, address _staker) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(STAKE_AMOUNT, _poolStakingAddress, _staker))
        ];
    }

    function stakeAmountByCurrentEpoch(address _poolStakingAddress, address _staker)
        public
        view
        returns(uint256)
    {
        if (!_wasValidatorSetApplied()) {
            return 0;
        }
        return uintStorage[
            keccak256(abi.encode(STAKE_AMOUNT_BY_CURRENT_EPOCH, _poolStakingAddress, _staker))
        ];
    }

    function stakeAmountMinusOrderedWithdraw(
        address _poolStakingAddress,
        address _staker
    ) public view returns(uint256) {
        return stakeAmount(_poolStakingAddress, _staker).sub(orderedWithdrawAmount(_poolStakingAddress, _staker));
    }

    function stakeAmountTotalMinusOrderedWithdraw(address _poolStakingAddress) public view returns(uint256) {
        return stakeAmountTotal(_poolStakingAddress).sub(orderedWithdrawAmountTotal(_poolStakingAddress));
    }

    function stakingByMiningAddress(address _miningAddress) public view returns(address) {
        return addressStorage[keccak256(abi.encode(STAKING_BY_MINING_ADDRESS, _miningAddress))];
    }

    // Returns the internal serial number of staking epoch
    function stakingEpoch() public view returns(uint256) {
        return uintStorage[STAKING_EPOCH];
    }

    function unremovableValidator() public view returns(address stakingAddress) {
        stakingAddress = addressStorage[UNREMOVABLE_STAKING_ADDRESS];
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
    bytes32 internal constant UNREMOVABLE_STAKING_ADDRESS = keccak256("unremovableStakingAddress");
    bytes32 internal constant VALIDATOR_SET_APPLY_BLOCK = keccak256("validatorSetApplyBlock");

    bytes32 internal constant BANNED_UNTIL = "bannedUntil";
    bytes32 internal constant IS_POOL_ACTIVE = "isPoolActive";
    bytes32 internal constant IS_VALIDATOR = "isValidator";
    bytes32 internal constant IS_VALIDATOR_ON_PREVIOUS_EPOCH = "isValidatorOnPreviousEpoch";
    bytes32 internal constant MINING_BY_STAKING_ADDRESS = "miningByStakingAddress";
    bytes32 internal constant POOL_DELEGATORS = "poolDelegators";
    bytes32 internal constant POOL_DELEGATOR_INDEX = "poolDelegatorIndex";
    bytes32 internal constant POOL_INDEX = "poolIndex";
    bytes32 internal constant POOL_INACTIVE_INDEX = "poolInactiveIndex";
    bytes32 internal constant QUEUE_PV_BLOCK = "queuePVBlock";
    bytes32 internal constant QUEUE_PV_LIST = "queuePVList";
    bytes32 internal constant QUEUE_PV_NEW_EPOCH = "queuePVNewEpoch";
    bytes32 internal constant STAKE_AMOUNT = "stakeAmount";
    bytes32 internal constant STAKE_AMOUNT_BY_CURRENT_EPOCH = "stakeAmountByCurrentEpoch";
    bytes32 internal constant STAKE_AMOUNT_TOTAL = "stakeAmountTotal";
    bytes32 internal constant STAKING_BY_MINING_ADDRESS = "stakingByMiningAddress";
    bytes32 internal constant VALIDATOR_INDEX = "validatorIndex";
    bytes32 internal constant ORDERED_WITHDRAW_AMOUNT = "orderedWithdrawAmount";
    bytes32 internal constant ORDERED_WITHDRAW_AMOUNT_TOTAL = "orderedWithdrawAmountTotal";

    // Adds `_stakingAddress` to the array of pools
    function _addToPools(address _stakingAddress) internal {
        if (!doesPoolExist(_stakingAddress)) {
            address[] storage pools = addressArrayStorage[POOLS];
            _setPoolIndex(_stakingAddress, pools.length);
            pools.push(_stakingAddress);
            require(pools.length <= _getMaxCandidates());
            _setIsPoolActive(_stakingAddress, true);
        }
        _removeFromPoolsInactive(_stakingAddress);
    }

    // Adds `_stakingAddress` to the array of inactive pools
    function _addToPoolsInactive(address _stakingAddress) internal {
        address[] storage poolsInactive = addressArrayStorage[POOLS_INACTIVE];
        if (poolsInactive.length == 0 || poolsInactive[poolInactiveIndex(_stakingAddress)] != _stakingAddress) {
            _setPoolInactiveIndex(_stakingAddress, poolsInactive.length);
            poolsInactive.push(_stakingAddress);
        }
    }

    // Removes `_stakingAddress` from the array of pools
    function _removeFromPools(address _stakingAddress) internal {
        uint256 indexToRemove = poolIndex(_stakingAddress);
        address[] storage pools = addressArrayStorage[POOLS];
        if (pools.length > 0 && pools[indexToRemove] == _stakingAddress) {
            pools[indexToRemove] = pools[pools.length - 1];
            _setPoolIndex(pools[indexToRemove], indexToRemove);
            pools.length--;
            _setPoolIndex(_stakingAddress, 0);
            _setIsPoolActive(_stakingAddress, false);
            if (stakeAmountTotal(_stakingAddress) != 0) {
                _addToPoolsInactive(_stakingAddress);
            }
        }
    }

    // Removes `_stakingAddress` from the array of inactive pools
    function _removeFromPoolsInactive(address _stakingAddress) internal {
        address[] storage poolsInactive = addressArrayStorage[POOLS_INACTIVE];
        uint256 indexToRemove = poolInactiveIndex(_stakingAddress);
        if (poolsInactive.length > 0 && poolsInactive[indexToRemove] == _stakingAddress) {
            poolsInactive[indexToRemove] = poolsInactive[poolsInactive.length - 1];
            _setPoolInactiveIndex(poolsInactive[indexToRemove], indexToRemove);
            poolsInactive.length--;
            _setPoolInactiveIndex(_stakingAddress, 0);
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

    function _banValidator(address _miningAddress) internal {
        uintStorage[
            keccak256(abi.encode(BANNED_UNTIL, _miningAddress))
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
        address[] memory _initialMiningAddresses,
        address[] memory _initialStakingAddresses,
        bool _firstValidatorIsUnremovable, // must be `false` for production network
        uint256 _delegatorMinStake,
        uint256 _candidateMinStake
    ) internal {
        require(_getCurrentBlockNumber() == 0); // initialization must be done on genesis block
        require(_blockRewardContract != address(0));
        require(_randomContract != address(0));
        require(_initialMiningAddresses.length > 0);
        require(_initialMiningAddresses.length == _initialStakingAddresses.length);
        require(_delegatorMinStake != 0);
        require(_candidateMinStake != 0);

        addressStorage[BLOCK_REWARD_CONTRACT] = _blockRewardContract;
        addressStorage[RANDOM_CONTRACT] = _randomContract;
        addressStorage[ERC20_TOKEN_CONTRACT] = _erc20TokenContract;

        address[] storage currentValidators = addressArrayStorage[CURRENT_VALIDATORS];
        address[] storage pendingValidators = addressArrayStorage[PENDING_VALIDATORS];
        require(currentValidators.length == 0);

        // Add initial validators to the `currentValidators` array
        for (uint256 i = 0; i < _initialMiningAddresses.length; i++) {
            currentValidators.push(_initialMiningAddresses[i]);
            pendingValidators.push(_initialMiningAddresses[i]);
            _setValidatorIndex(_initialMiningAddresses[i], i);
            _setIsValidator(_initialMiningAddresses[i], true);
            _addToPools(_initialStakingAddresses[i]);
            _setMiningAddress(_initialStakingAddresses[i], _initialMiningAddresses[i]);
        }

        if (_firstValidatorIsUnremovable) {
            _setUnremovableValidator(_initialStakingAddresses[0]);
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

        address unremovableStakingAddress = unremovableValidator();

        // Filter pools and leave only non-empty
        delete addressArrayStorage[POOLS_NON_EMPTY];
        delete addressArrayStorage[POOLS_EMPTY];
        for (i = 0; i < pools.length; i++) {
            if (pools[i] == unremovableStakingAddress) {
                continue;
            }
            if (stakeAmountMinusOrderedWithdraw(pools[i], pools[i]) > 0) {
                addressArrayStorage[POOLS_NON_EMPTY].push(pools[i]);
            } else {
                addressArrayStorage[POOLS_EMPTY].push(pools[i]);
            }
        }
        pools = addressArrayStorage[POOLS_NON_EMPTY];

        // Choose new validators
        if (pools.length < MAX_VALIDATORS) {
            if (pools.length > 0) {
                _setPendingValidators(pools, unremovableStakingAddress);
            }
        } else if (pools.length == MAX_VALIDATORS && unremovableStakingAddress == address(0)) {
            _setPendingValidators(pools, address(0));
        } else {
            uint256 randomNumber = uint256(keccak256(abi.encode(IRandom(randomContract()).getCurrentSeed())));

            address[] memory poolsLocal = pools;
            uint256 poolsLocalLength = poolsLocal.length;

            uint256[] memory likelihood = new uint256[](poolsLocalLength);
            uint256 likelihoodSum = 0;

            for (i = 0; i < poolsLocalLength; i++) {
                likelihood[i] = stakeAmountTotalMinusOrderedWithdraw(poolsLocal[i]) * 100 / STAKE_UNIT;
                likelihoodSum += likelihood[i];
            }

            address[] memory newValidators = new address[](
                unremovableStakingAddress == address(0) ? MAX_VALIDATORS : MAX_VALIDATORS - 1
            );

            for (i = 0; i < newValidators.length; i++) {
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

            _setPendingValidators(newValidators, unremovableStakingAddress);
        }

        // From this moment `getPendingValidators()` will return the new validator set

        // Increment counters
        _incrementStakingEpoch();
        _incrementChangeRequestCount();

        _enqueuePendingValidators(true);
        _setValidatorSetApplyBlock(0);
    }

    function _performOrderedWithdrawals(
        address _poolStakingAddress,
        address _staker,
        uint256 _minAllowedStake,
        IERC20Minting _tokenContract
    ) internal {
        uint256 orderedAmount = orderedWithdrawAmount(_poolStakingAddress, _staker);

        if (orderedAmount > 0) {
            uint256 currentStakeAmount = stakeAmount(_poolStakingAddress, _staker);

            if (
                currentStakeAmount >= orderedAmount &&
                address(_tokenContract) != address(0) &&
                orderedAmount <= _tokenContract.balanceOf(address(this)) &&
                _withdraw(
                    _poolStakingAddress,
                    _staker,
                    orderedAmount,
                    currentStakeAmount,
                    currentStakeAmount - orderedAmount,
                    _minAllowedStake
                )
            ) {
                _tokenContract.withdraw(_staker, orderedAmount);
            }

            _setOrderedWithdrawAmount(_poolStakingAddress, _staker, 0);
        }

        _setStakeAmountByCurrentEpoch(_poolStakingAddress, _staker, 0);
    }

    function _removeMaliciousValidator(address _miningAddress) internal returns(bool) {
        uint256 i;
        address stakingAddress = stakingByMiningAddress(_miningAddress);

        if (stakingAddress == unremovableValidator()) {
            return false;
        }

        // Remove malicious validator from `pools`
        _removeFromPools(stakingAddress);

        // Ban the malicious validator for the next 3 months
        _banValidator(_miningAddress);

        // Remove all ordered withdrawals from the pool of this validator
        address[] memory delegators = poolDelegators(stakingAddress);
        for (i = 0; i < delegators.length; i++) {
            _setOrderedWithdrawAmount(stakingAddress, delegators[i], 0);
            _setStakeAmountByCurrentEpoch(stakingAddress, delegators[i], 0);
        }
        _setOrderedWithdrawAmount(stakingAddress, stakingAddress, 0);
        _setOrderedWithdrawAmountTotal(stakingAddress, 0);
        _setStakeAmountByCurrentEpoch(stakingAddress, stakingAddress, 0);

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

    function _setIsPoolActive(address _stakingAddress, bool _isPoolActive) internal {
        boolStorage[keccak256(abi.encode(IS_POOL_ACTIVE, _stakingAddress))] = _isPoolActive;
    }

    function _setIsValidator(address _miningAddress, bool _isValidator) internal {
        boolStorage[keccak256(abi.encode(IS_VALIDATOR, _miningAddress))] = _isValidator;
    }

    function _setIsValidatorOnPreviousEpoch(address _miningAddress, bool _isValidator) internal {
        boolStorage[keccak256(abi.encode(IS_VALIDATOR_ON_PREVIOUS_EPOCH, _miningAddress))] = _isValidator;
    }

    function _setPendingValidators(address[] memory _stakingAddresses, address _unremovableStakingAddress) internal {
        uint256 i;

        delete addressArrayStorage[PENDING_VALIDATORS];

        if (_unremovableStakingAddress != address(0)) {
            addressArrayStorage[PENDING_VALIDATORS].push(miningByStakingAddress(_unremovableStakingAddress));
        }

        for (i = 0; i < _stakingAddresses.length; i++) {
            addressArrayStorage[PENDING_VALIDATORS].push(miningByStakingAddress(_stakingAddresses[i]));
        }

        for (i = 0; i < addressArrayStorage[POOLS_EMPTY].length; i++) {
            _removeFromPools(addressArrayStorage[POOLS_EMPTY][i]);
        }
    }

    function _setPoolIndex(address _stakingAddress, uint256 _index) internal {
        uintStorage[
            keccak256(abi.encode(POOL_INDEX, _stakingAddress))
        ] = _index;
    }

    function _setPoolInactiveIndex(address _stakingAddress, uint256 _index) internal {
        uintStorage[
            keccak256(abi.encode(POOL_INACTIVE_INDEX, _stakingAddress))
        ] = _index;
    }

    function _setPoolDelegatorIndex(address _poolStakingAddress, address _delegator, uint256 _index) internal {
        uintStorage[keccak256(abi.encode(POOL_DELEGATOR_INDEX, _poolStakingAddress, _delegator))] = _index;
    }

    function _setQueueValidators(address[] memory _miningAddresses, bool _newStakingEpoch) internal {
        addressArrayStorage[QUEUE_VALIDATORS] = _miningAddresses;
        boolStorage[QUEUE_VALIDATORS_NEW_STAKING_EPOCH] = _newStakingEpoch;
    }

    // Add `_delegator` to the array of pool's delegators
    function _addPoolDelegator(address _poolStakingAddress, address _delegator) internal {
        address[] storage delegators = addressArrayStorage[
            keccak256(abi.encode(POOL_DELEGATORS, _poolStakingAddress))
        ];
        _setPoolDelegatorIndex(_poolStakingAddress, _delegator, delegators.length);
        delegators.push(_delegator);
    }

    // Remove `_delegator` from the array of pool's delegators
    function _removePoolDelegator(address _poolStakingAddress, address _delegator) internal {
        address[] storage delegators = addressArrayStorage[
            keccak256(abi.encode(POOL_DELEGATORS, _poolStakingAddress))
        ];
        if (delegators.length == 0) return;
        uint256 indexToRemove = poolDelegatorIndex(_poolStakingAddress, _delegator);
        delegators[indexToRemove] = delegators[delegators.length - 1];
        _setPoolDelegatorIndex(_poolStakingAddress, delegators[indexToRemove], indexToRemove);
        delegators.length--;
        _setPoolDelegatorIndex(_poolStakingAddress, _delegator, 0);
    }

    function _setMiningAddress(address _stakingAddress, address _miningAddress) internal {
        require(_stakingAddress != address(0));
        require(_miningAddress != address(0));
        require(_stakingAddress != _miningAddress);
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

    function _setOrderedWithdrawAmount(address _poolStakingAddress, address _staker, uint256 _amount) internal {
        uintStorage[
            keccak256(abi.encode(ORDERED_WITHDRAW_AMOUNT, _poolStakingAddress, _staker))
        ] = _amount;
    }

    function _setOrderedWithdrawAmountTotal(address _poolStakingAddress, uint256 _amount) internal {
        uintStorage[
            keccak256(abi.encode(ORDERED_WITHDRAW_AMOUNT_TOTAL, _poolStakingAddress))
        ] = _amount;
    }

    function _setStakeAmount(address _poolStakingAddress, address _staker, uint256 _amount) internal {
        uintStorage[
            keccak256(abi.encode(STAKE_AMOUNT, _poolStakingAddress, _staker))
        ] = _amount;
    }

    function _setStakeAmountByCurrentEpoch(
        address _poolStakingAddress,
        address _staker,
        uint256 _amount
    ) internal {
        uintStorage[keccak256(abi.encode(
            STAKE_AMOUNT_BY_CURRENT_EPOCH, _poolStakingAddress, _staker
        ))] = _amount;
    }

    function _setStakeAmountTotal(address _poolStakingAddress, uint256 _amount) internal {
        uintStorage[
            keccak256(abi.encode(STAKE_AMOUNT_TOTAL, _poolStakingAddress))
        ] = _amount;
    }

    function _setDelegatorMinStake(uint256 _minStake) internal {
        uintStorage[DELEGATOR_MIN_STAKE] = _minStake * STAKE_UNIT;
    }

    function _setCandidateMinStake(uint256 _minStake) internal {
        uintStorage[CANDIDATE_MIN_STAKE] = _minStake * STAKE_UNIT;
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

    function _stake(address _poolStakingAddress, address _staker, uint256 _amount) internal {
        address poolMiningAddress = miningByStakingAddress(_poolStakingAddress);

        require(poolMiningAddress != address(0));
        require(_poolStakingAddress != address(0));
        require(_amount != 0);
        require(!isValidatorBanned(poolMiningAddress));
        require(areStakeAndWithdrawAllowed());

        uint256 newStakeAmount = stakeAmount(_poolStakingAddress, _staker).add(_amount);
        if (_staker == _poolStakingAddress) {
            require(newStakeAmount >= getCandidateMinStake()); // the staked amount must be at least CANDIDATE_MIN_STAKE
        } else {
            require(newStakeAmount >= getDelegatorMinStake()); // the staked amount must be at least DELEGATOR_MIN_STAKE

            // The delegator cannot stake into the pool of the candidate which hasn't self-staked.
            // Also, that candidate shouldn't want to withdraw all his funds.
            require(stakeAmountMinusOrderedWithdraw(_poolStakingAddress, _poolStakingAddress) > 0);
        }
        _setStakeAmount(_poolStakingAddress, _staker, newStakeAmount);
        _setStakeAmountByCurrentEpoch(
            _poolStakingAddress,
            _staker,
            stakeAmountByCurrentEpoch(_poolStakingAddress, _staker).add(_amount)
        );
        _setStakeAmountTotal(_poolStakingAddress, stakeAmountTotal(_poolStakingAddress).add(_amount));

        if (_staker == _poolStakingAddress) { // `staker` makes a stake for himself and becomes a candidate
            // Add `_poolStakingAddress` to the array of pools
            _addToPools(_poolStakingAddress);
        } else if (newStakeAmount == _amount) { // if the stake is first
            // Add `_staker` to the array of pool's delegators
            _addPoolDelegator(_poolStakingAddress, _staker);
        }
    }

    function _withdraw(address _poolStakingAddress, address _staker, uint256 _amount) internal {
        require(_poolStakingAddress != address(0));
        require(_amount != 0);

        // How much can `staker` withdraw from `_poolStakingAddress` at the moment?
        require(_amount <= maxWithdrawAllowed(_poolStakingAddress, _staker));

        uint256 currentStakeAmount = stakeAmount(_poolStakingAddress, _staker);
        uint256 alreadyOrderedAmount = orderedWithdrawAmount(_poolStakingAddress, _staker);
        uint256 resultingStakeAmount = currentStakeAmount.sub(alreadyOrderedAmount).sub(_amount);

        require(_withdraw(
            _poolStakingAddress,
            _staker,
            _amount,
            currentStakeAmount,
            resultingStakeAmount,
            _poolStakingAddress == _staker ? getCandidateMinStake() : getDelegatorMinStake()
        ));
    }

    function _withdraw(
        address _poolStakingAddress,
        address _staker,
        uint256 _withdrawalAmount,
        uint256 _currentStakeAmount,
        uint256 _resultingStakeAmount,
        uint256 _minAllowedStake
    ) internal returns(bool) {
        // The amount to be withdrawn must be the whole staked amount or
        // must not exceed the diff between the entire amount and MIN_STAKE
        if (_resultingStakeAmount > 0 && _resultingStakeAmount < _minAllowedStake) {
            return false;
        }

        uint256 newStakeAmount = _currentStakeAmount.sub(_withdrawalAmount);
        _setStakeAmount(_poolStakingAddress, _staker, newStakeAmount);

        uint256 amountByEpoch = stakeAmountByCurrentEpoch(_poolStakingAddress, _staker);
        _setStakeAmountByCurrentEpoch(
            _poolStakingAddress,
            _staker,
            amountByEpoch >= _withdrawalAmount ? amountByEpoch - _withdrawalAmount : 0
        );
        _setStakeAmountTotal(_poolStakingAddress, stakeAmountTotal(_poolStakingAddress).sub(_withdrawalAmount));

        if (newStakeAmount == 0) { // the whole amount has been withdrawn
            if (_staker == _poolStakingAddress) {
                if (_poolStakingAddress != unremovableValidator()) {
                    // Remove `_poolStakingAddress` from the array of pools
                    _removeFromPools(_poolStakingAddress);
                }
            } else {
                // Remove `_staker` from the array of pool's delegators
                _removePoolDelegator(_poolStakingAddress, _staker);
            }

            if (stakeAmountTotal(_poolStakingAddress) == 0) {
                _removeFromPoolsInactive(_poolStakingAddress);
            }
        }

        return true;
    }

    function _banUntil() internal view returns(uint256);

    function _getCurrentBlockNumber() internal view returns(uint256) {
        return block.number;
    }

    function _getMaxCandidates() internal pure returns(uint256) {
        return MAX_CANDIDATES;
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

    function _isWithdrawAllowed(address _miningAddress) internal view returns(bool) {
        if (isValidatorBanned(_miningAddress)) {
            // No one can withdraw from `_poolStakingAddress` until the ban is expired
            return false;
        }

        if (!areStakeAndWithdrawAllowed()) {
            return false;
        }

        return true;
    }

    function _wasValidatorSetApplied() internal view returns(bool) {
        uint256 applyBlock = validatorSetApplyBlock();
        return applyBlock != 0 && _getCurrentBlockNumber() > applyBlock;
    }
}
