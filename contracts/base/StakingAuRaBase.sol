pragma solidity 0.5.10;

import "../interfaces/IBlockRewardAuRa.sol";
import "../interfaces/IERC677.sol";
import "../interfaces/IStakingAuRa.sol";
import "../interfaces/IValidatorSetAuRa.sol";
import "../upgradeability/UpgradeableOwned.sol";
import "../libs/SafeMath.sol";


/// @dev Implements staking and withdrawal logic.
contract StakingAuRaBase is UpgradeableOwned, IStakingAuRa {
    using SafeMath for uint256;

    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables, do not change their order,
    // and do not change their types!

    uint256[] internal _pools;
    uint256[] internal _poolsInactive;
    uint256[] internal _poolsToBeElected;
    uint256[] internal _poolsToBeRemoved;
    uint256[] internal _poolsLikelihood;
    uint256 internal _poolsLikelihoodSum;
    mapping(uint256 => address[]) internal _poolDelegators;
    mapping(uint256 => address[]) internal _poolDelegatorsInactive;
    mapping(address => uint256[]) internal _delegatorPools;
    mapping(address => mapping(uint256 => uint256)) internal _delegatorPoolsIndexes;
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) internal _stakeAmountByEpoch;
    mapping(uint256 => uint256) internal _stakeInitial;

    // Reserved storage slots to allow for layout changes in the future.
    uint256[24] private ______gapForInternal;

    /// @dev The limit of the minimum candidate stake (CANDIDATE_MIN_STAKE).
    uint256 public candidateMinStake;

    /// @dev The limit of the minimum delegator stake (DELEGATOR_MIN_STAKE).
    uint256 public delegatorMinStake;

    /// @dev The snapshot of tokens amount staked into the specified pool by the specified delegator
    /// before the specified staking epoch. Used by the `claimReward` function.
    /// The first parameter is the pool id, the second one is delegator's address,
    /// the third one is staking epoch number.
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public delegatorStakeSnapshot;

    /// @dev The current amount of staking tokens/coins ordered for withdrawal from the specified
    /// pool by the specified staker. Used by the `orderWithdraw`, `claimOrderedWithdraw` and other functions.
    /// The first parameter is the pool id, the second one is the staker address.
    /// The second parameter should be a zero address if the staker is the pool itself.
    mapping(uint256 => mapping(address => uint256)) public orderedWithdrawAmount;

    /// @dev The current total amount of staking tokens/coins ordered for withdrawal from
    /// the specified pool by all of its stakers. Pool id is accepted as a parameter.
    mapping(uint256 => uint256) public orderedWithdrawAmountTotal;

    /// @dev The number of the staking epoch during which the specified staker ordered
    /// the latest withdraw from the specified pool. Used by the `claimOrderedWithdraw` function
    /// to allow the ordered amount to be claimed only in future staking epochs. The first parameter
    /// is the pool id, the second one is the staker address.
    /// The second parameter should be a zero address if the staker is the pool itself.
    mapping(uint256 => mapping(address => uint256)) public orderWithdrawEpoch;

    /// @dev The delegator's index in the array returned by the `poolDelegators` getter.
    /// Used by the `_removePoolDelegator` internal function. The first parameter is a pool id.
    /// The second parameter is delegator's address.
    /// If the value is zero, it may mean the array doesn't contain the delegator.
    /// Check if the delegator is in the array using the `poolDelegators` getter.
    mapping(uint256 => mapping(address => uint256)) public poolDelegatorIndex;

    /// @dev The delegator's index in the `poolDelegatorsInactive` array.
    /// Used by the `_removePoolDelegatorInactive` internal function.
    /// A delegator is considered inactive if they have withdrawn their stake from
    /// the specified pool but haven't yet claimed an ordered amount.
    /// The first parameter is a pool id. The second parameter is delegator's address.
    mapping(uint256 => mapping(address => uint256)) public poolDelegatorInactiveIndex;

    /// @dev The pool's index in the array returned by the `getPoolsInactive` getter.
    /// Used by the `_removePoolInactive` internal function. The pool id is accepted as a parameter.
    mapping(uint256 => uint256) public poolInactiveIndex;

    /// @dev The pool's index in the array returned by the `getPools` getter.
    /// Used by the `_removePool` internal function. A pool id is accepted as a parameter.
    /// If the value is zero, it may mean the array doesn't contain the address.
    /// Check the address is in the array using the `isPoolActive` getter.
    mapping(uint256 => uint256) public poolIndex;

    /// @dev The pool's index in the array returned by the `getPoolsToBeElected` getter.
    /// Used by the `_deletePoolToBeElected` and `_isPoolToBeElected` internal functions.
    /// The pool id is accepted as a parameter.
    /// If the value is zero, it may mean the array doesn't contain the address.
    /// Check the address is in the array using the `getPoolsToBeElected` getter.
    mapping(uint256 => uint256) public poolToBeElectedIndex;

    /// @dev The pool's index in the array returned by the `getPoolsToBeRemoved` getter.
    /// Used by the `_deletePoolToBeRemoved` internal function.
    /// The pool id is accepted as a parameter.
    /// If the value is zero, it may mean the array doesn't contain the address.
    /// Check the address is in the array using the `getPoolsToBeRemoved` getter.
    mapping(uint256 => uint256) public poolToBeRemovedIndex;

    /// @dev A boolean flag indicating whether the reward was already taken
    /// from the specified pool by the specified staker for the specified staking epoch.
    /// The first parameter is the pool id, the second one is staker's address,
    /// the third one is staking epoch number.
    /// The second parameter should be a zero address if the staker is the pool itself.
    mapping(uint256 => mapping(address => mapping(uint256 => bool))) public rewardWasTaken;

    /// @dev The amount of tokens currently staked into the specified pool by the specified
    /// staker. Doesn't include the amount ordered for withdrawal.
    /// The first parameter is the pool id, the second one is the staker address.
    /// The second parameter should be a zero address if the staker is the pool itself.
    mapping(uint256 => mapping(address => uint256)) public stakeAmount;

    /// @dev The number of staking epoch before which the specified delegator placed their first
    /// stake into the specified pool. If this is equal to zero, it means the delegator never
    /// staked into the specified pool. The first parameter is the pool id,
    /// the second one is delegator's address.
    mapping(uint256 => mapping(address => uint256)) public stakeFirstEpoch;

    /// @dev The number of staking epoch before which the specified delegator withdrew their stake
    /// from the specified pool. If this is equal to zero and `stakeFirstEpoch` is not zero, that means
    /// the delegator still has some stake in the specified pool. The first parameter is the pool id,
    /// the second one is delegator's address.
    mapping(uint256 => mapping(address => uint256)) public stakeLastEpoch;

    /// @dev The duration period (in blocks) at the end of staking epoch during which
    /// participants are not allowed to stake/withdraw/order/claim their staking tokens/coins.
    uint256 public stakeWithdrawDisallowPeriod;

    /// @dev The serial number of the current staking epoch.
    uint256 public stakingEpoch;

    /// @dev The duration of a staking epoch in blocks.
    uint256 public stakingEpochDuration;

    /// @dev The number of the first block of the current staking epoch.
    uint256 public stakingEpochStartBlock;

    /// @dev Returns the total amount of staking tokens/coins currently staked into the specified pool.
    /// Doesn't include the amount ordered for withdrawal.
    /// The pool id is accepted as a parameter.
    mapping(uint256 => uint256) public stakeAmountTotal;

    /// @dev The address of the `ValidatorSetAuRa` contract.
    IValidatorSetAuRa public validatorSetContract;

    /// @dev The block number of the last change in this contract.
    /// Can be used by Staking DApp.
    uint256 public lastChangeBlock;

    // Reserved storage slots to allow for layout changes in the future.
    uint256[24] private ______gapForPublic;

    // ============================================== Constants =======================================================

    /// @dev The max number of candidates (including validators). This limit was determined through stress testing.
    uint256 public constant MAX_CANDIDATES = 3000;

    // ================================================ Events ========================================================

    /// @dev Emitted by the `_addPool` internal function to signal that
    /// a new pool is created.
    /// @param poolStakingAddress The staking address of newly added pool.
    /// @param poolMiningAddress The mining address of newly added pool.
    /// @param poolId The id of newly added pool.
    event AddedPool(address indexed poolStakingAddress, address indexed poolMiningAddress, uint256 poolId);

    /// @dev Emitted by the `claimOrderedWithdraw` function to signal the staker withdrew the specified
    /// amount of requested tokens/coins from the specified pool during the specified staking epoch.
    /// @param fromPoolStakingAddress A staking address of the pool from which the `staker` withdrew the `amount`.
    /// @param staker The address of the staker that withdrew the `amount`.
    /// @param stakingEpoch The serial number of the staking epoch during which the claim was made.
    /// @param amount The withdrawal amount.
    /// @param fromPoolId An id of the pool from which the `staker` withdrew the `amount`.
    event ClaimedOrderedWithdrawal(
        address indexed fromPoolStakingAddress,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount,
        uint256 fromPoolId
    );

    /// @dev Emitted by the `moveStake` function to signal the staker moved the specified
    /// amount of stake from one pool to another during the specified staking epoch.
    /// @param fromPoolStakingAddress A staking address of the pool from which the `staker` moved the stake.
    /// @param toPoolStakingAddress A staking address of the destination pool where the `staker` moved the stake.
    /// @param staker The address of the staker who moved the `amount`.
    /// @param stakingEpoch The serial number of the staking epoch during which the `amount` was moved.
    /// @param amount The stake amount which was moved.
    /// @param fromPoolId An id of the pool from which the `staker` moved the stake.
    /// @param toPoolId An id of the destination pool where the `staker` moved the stake.
    event MovedStake(
        address fromPoolStakingAddress,
        address indexed toPoolStakingAddress,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount,
        uint256 fromPoolId,
        uint256 toPoolId
    );

    /// @dev Emitted by the `orderWithdraw` function to signal the staker ordered the withdrawal of the
    /// specified amount of their stake from the specified pool during the specified staking epoch.
    /// @param fromPoolStakingAddress A staking address of the pool from which the `staker`
    /// ordered a withdrawal of the `amount`.
    /// @param staker The address of the staker that ordered the withdrawal of the `amount`.
    /// @param stakingEpoch The serial number of the staking epoch during which the order was made.
    /// @param amount The ordered withdrawal amount. Can be either positive or negative.
    /// See the `orderWithdraw` function.
    /// @param fromPoolId An id of the pool from which the `staker` ordered a withdrawal of the `amount`.
    event OrderedWithdrawal(
        address indexed fromPoolStakingAddress,
        address indexed staker,
        uint256 indexed stakingEpoch,
        int256 amount,
        uint256 fromPoolId
    );

    /// @dev Emitted by the `stake` function to signal the staker placed a stake of the specified
    /// amount for the specified pool during the specified staking epoch.
    /// @param toPoolStakingAddress A staking address of the pool into which the `staker` placed the stake.
    /// @param staker The address of the staker that placed the stake.
    /// @param stakingEpoch The serial number of the staking epoch during which the stake was made.
    /// @param amount The stake amount.
    /// @param toPoolId An id of the pool into which the `staker` placed the stake.
    event PlacedStake(
        address indexed toPoolStakingAddress,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount,
        uint256 toPoolId
    );

    /// @dev Emitted by the `withdraw` function to signal the staker withdrew the specified
    /// amount of a stake from the specified pool during the specified staking epoch.
    /// @param fromPoolStakingAddress A staking address of the pool from which the `staker` withdrew the `amount`.
    /// @param staker The address of staker that withdrew the `amount`.
    /// @param stakingEpoch The serial number of the staking epoch during which the withdrawal was made.
    /// @param amount The withdrawal amount.
    /// @param fromPoolId An id of the pool from which the `staker` withdrew the `amount`.
    event WithdrewStake(
        address indexed fromPoolStakingAddress,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount,
        uint256 fromPoolId
    );

    // ============================================== Modifiers =======================================================

    /// @dev Ensures the transaction gas price is not zero.
    modifier gasPriceIsValid() {
        require(tx.gasprice != 0);
        _;
    }

    /// @dev Ensures the caller is the BlockRewardAuRa contract address.
    modifier onlyBlockRewardContract() {
        require(msg.sender == validatorSetContract.blockRewardContract());
        _;
    }

    /// @dev Ensures the `initialize` function was called before.
    modifier onlyInitialized {
        require(isInitialized());
        _;
    }

    /// @dev Ensures the caller is the ValidatorSetAuRa contract address.
    modifier onlyValidatorSetContract() {
        require(msg.sender == address(validatorSetContract));
        _;
    }

    // =============================================== Setters ========================================================

    /// @dev Fallback function. Prevents direct sending native coins to this contract.
    function () payable external {
        revert();
    }

    /// @dev Adds a new candidate's pool to the list of active pools (see the `getPools` getter),
    /// moves the specified amount of staking tokens/coins from the candidate's staking address
    /// to the candidate's pool, and returns a unique id of the newly added pool.
    /// A participant calls this function using their staking address when
    /// they want to create a pool. This is a wrapper for the `stake` function.
    /// @param _amount The amount of tokens to be staked. Ignored when staking in native coins
    /// because `msg.value` is used in that case.
    /// @param _miningAddress The mining address of the candidate. The mining address is bound to the staking address
    /// (msg.sender). This address cannot be equal to `msg.sender`.
    function addPool(uint256 _amount, address _miningAddress) external payable returns(uint256) {
        return _addPool(_amount, msg.sender, _miningAddress, false);
    }

    /// @dev Adds the `unremovable validator` to either the `poolsToBeElected` or the `poolsToBeRemoved` array
    /// depending on their own stake in their own pool when they become removable. This allows the
    /// `ValidatorSetAuRa.newValidatorSet` function to recognize the unremovable validator as a regular removable pool.
    /// Called by the `ValidatorSet.clearUnremovableValidator` function.
    /// @param _unremovablePoolId The pool id of the unremovable validator.
    function clearUnremovableValidator(uint256 _unremovablePoolId) external onlyValidatorSetContract {
        require(_unremovablePoolId != 0);
        if (stakeAmount[_unremovablePoolId][address(0)] != 0) {
            _addPoolToBeElected(_unremovablePoolId);
            _setLikelihood(_unremovablePoolId);
        } else {
            _addPoolToBeRemoved(_unremovablePoolId);
        }
    }

    /// @dev Increments the serial number of the current staking epoch.
    /// Called by the `ValidatorSetAuRa.newValidatorSet` at the last block of the finished staking epoch.
    function incrementStakingEpoch() external onlyValidatorSetContract {
        stakingEpoch++;
    }

    /// @dev Initializes the network parameters.
    /// Can only be called by the constructor of the `InitializerAuRa` contract or owner.
    /// @param _validatorSetContract The address of the `ValidatorSetAuRa` contract.
    /// @param _initialIds The array of initial validators' pool ids.
    /// @param _delegatorMinStake The minimum allowed amount of delegator stake in Wei.
    /// @param _candidateMinStake The minimum allowed amount of candidate/validator stake in Wei.
    /// @param _stakingEpochDuration The duration of a staking epoch in blocks
    /// (e.g., 120954 = 1 week for 5-seconds blocks in AuRa).
    /// @param _stakingEpochStartBlock The number of the first block of initial staking epoch
    /// (must be zero if the network is starting from genesis block).
    /// @param _stakeWithdrawDisallowPeriod The duration period (in blocks) at the end of a staking epoch
    /// during which participants cannot stake/withdraw/order/claim their staking tokens/coins
    /// (e.g., 4320 = 6 hours for 5-seconds blocks in AuRa).
    function initialize(
        address _validatorSetContract,
        uint256[] calldata _initialIds,
        uint256 _delegatorMinStake,
        uint256 _candidateMinStake,
        uint256 _stakingEpochDuration,
        uint256 _stakingEpochStartBlock,
        uint256 _stakeWithdrawDisallowPeriod
    ) external {
        require(_validatorSetContract != address(0));
        require(_initialIds.length > 0);
        require(_delegatorMinStake != 0);
        require(_candidateMinStake != 0);
        require(_stakingEpochDuration != 0);
        require(_stakingEpochDuration > _stakeWithdrawDisallowPeriod);
        require(_stakeWithdrawDisallowPeriod != 0);
        require(_getCurrentBlockNumber() == 0 || msg.sender == _admin());
        require(!isInitialized()); // initialization can only be done once

        validatorSetContract = IValidatorSetAuRa(_validatorSetContract);

        uint256 unremovablePoolId = validatorSetContract.unremovableValidator();

        for (uint256 i = 0; i < _initialIds.length; i++) {
            require(_initialIds[i] != 0);
            _addPoolActive(_initialIds[i], false);
            if (_initialIds[i] != unremovablePoolId) {
                _addPoolToBeRemoved(_initialIds[i]);
            }
        }

        delegatorMinStake = _delegatorMinStake;
        candidateMinStake = _candidateMinStake;
        stakingEpochDuration = _stakingEpochDuration;
        stakingEpochStartBlock = _stakingEpochStartBlock;
        stakeWithdrawDisallowPeriod = _stakeWithdrawDisallowPeriod;
        lastChangeBlock = _getCurrentBlockNumber();
    }

    /// @dev Makes initial validator stakes. Can only be called by the owner
    /// before the network starts (after `initialize` is called but before `stakingEpochStartBlock`).
    /// Cannot be called more than once and cannot be called when starting from genesis.
    /// Requires `StakingAuRa` contract balance to be equal to the `_totalAmount`.
    /// @param _totalAmount The initial validator total stake amount (for all initial validators).
    function initialValidatorStake(uint256 _totalAmount) external onlyOwner {
        uint256 currentBlock = _getCurrentBlockNumber();

        require(stakingEpoch == 0);
        require(currentBlock < stakingEpochStartBlock);
        require(_thisBalance() == _totalAmount);
        require(_totalAmount % _pools.length == 0);

        uint256 stakingAmount = _totalAmount.div(_pools.length);
        uint256 stakingEpochStartBlock_ = stakingEpochStartBlock;

        // Temporarily set `stakingEpochStartBlock` to the current block number
        // to avoid revert in the `_stake` function
        stakingEpochStartBlock = currentBlock;

        for (uint256 i = 0; i < _pools.length; i++) {
            uint256 poolId = _pools[i];
            address stakingAddress = validatorSetContract.stakingAddressById(poolId);
            require(stakeAmount[poolId][address(0)] == 0);
            _stake(stakingAddress, stakingAddress, stakingAmount);
            _stakeInitial[poolId] = stakingAmount;
        }

        // Restore `stakingEpochStartBlock` value
        stakingEpochStartBlock = stakingEpochStartBlock_;
    }

    /// @dev Removes a specified pool from the `pools` array (a list of active pools which can be retrieved by the
    /// `getPools` getter). Called by the `ValidatorSetAuRa._removeMaliciousValidator` internal function
    /// when a pool must be removed by the algorithm.
    /// @param _poolId The id of the pool to be removed.
    function removePool(uint256 _poolId) external onlyValidatorSetContract {
        _removePool(_poolId);
    }

    /// @dev Removes pools which are in the `_poolsToBeRemoved` internal array from the `pools` array.
    /// Called by the `ValidatorSetAuRa.newValidatorSet` function when pools must be removed by the algorithm.
    function removePools() external onlyValidatorSetContract {
        uint256[] memory poolsToRemove = _poolsToBeRemoved;
        for (uint256 i = 0; i < poolsToRemove.length; i++) {
            _removePool(poolsToRemove[i]);
        }
    }

    /// @dev Removes the candidate's or validator's pool from the `pools` array (a list of active pools which
    /// can be retrieved by the `getPools` getter). When a candidate or validator wants to remove their pool,
    /// they should call this function from their staking address. A validator cannot remove their pool while
    /// they are an `unremovable validator`.
    function removeMyPool() external gasPriceIsValid onlyInitialized {
        uint256 poolId = validatorSetContract.idByStakingAddress(msg.sender);
        require(poolId != 0);
        // initial validator cannot remove their pool during the initial staking epoch
        require(stakingEpoch > 0 || !validatorSetContract.isValidatorById(poolId));
        require(poolId != validatorSetContract.unremovableValidator());
        _removePool(poolId);
    }

    /// @dev Sets the number of the first block in the upcoming staking epoch.
    /// Called by the `ValidatorSetAuRa.newValidatorSet` function at the last block of a staking epoch.
    /// @param _blockNumber The number of the very first block in the upcoming staking epoch.
    function setStakingEpochStartBlock(uint256 _blockNumber) external onlyValidatorSetContract {
        stakingEpochStartBlock = _blockNumber;
    }

    /// @dev Moves staking tokens/coins from one pool to another. A staker calls this function when they want
    /// to move their tokens/coins from one pool to another without withdrawing their tokens/coins.
    /// @param _fromPoolStakingAddress The staking address of the source pool.
    /// @param _toPoolStakingAddress The staking address of the target pool.
    /// @param _amount The amount of staking tokens/coins to be moved. The amount cannot exceed the value returned
    /// by the `maxWithdrawAllowed` getter.
    function moveStake(
        address _fromPoolStakingAddress,
        address _toPoolStakingAddress,
        uint256 _amount
    ) external {
        require(_fromPoolStakingAddress != _toPoolStakingAddress);
        uint256 fromPoolId = validatorSetContract.idByStakingAddress(_fromPoolStakingAddress);
        uint256 toPoolId = validatorSetContract.idByStakingAddress(_toPoolStakingAddress);
        address staker = msg.sender;
        _withdraw(_fromPoolStakingAddress, staker, _amount);
        _stake(_toPoolStakingAddress, staker, _amount);
        emit MovedStake(
            _fromPoolStakingAddress,
            _toPoolStakingAddress,
            staker,
            stakingEpoch,
            _amount,
            fromPoolId,
            toPoolId
        );
    }

    /// @dev Moves the specified amount of staking tokens/coins from the staker's address to the staking address of
    /// the specified pool. Actually, the amount is stored in a balance of this StakingAuRa contract.
    /// A staker calls this function when they want to make a stake into a pool.
    /// @param _toPoolStakingAddress The staking address of the pool where the tokens should be staked.
    /// @param _amount The amount of tokens to be staked. Ignored when staking in native coins
    /// because `msg.value` is used instead.
    function stake(address _toPoolStakingAddress, uint256 _amount) external payable {
        _stake(_toPoolStakingAddress, _amount);
    }

    /// @dev Moves the specified amount of staking tokens/coins from the staking address of
    /// the specified pool to the staker's address. A staker calls this function when they want to withdraw
    /// their tokens/coins.
    /// @param _fromPoolStakingAddress The staking address of the pool from which the tokens/coins should be withdrawn.
    /// @param _amount The amount of tokens/coins to be withdrawn. The amount cannot exceed the value returned
    /// by the `maxWithdrawAllowed` getter.
    function withdraw(address _fromPoolStakingAddress, uint256 _amount) external {
        address payable staker = msg.sender;
        uint256 fromPoolId = validatorSetContract.idByStakingAddress(_fromPoolStakingAddress);
        _withdraw(_fromPoolStakingAddress, staker, _amount);
        _sendWithdrawnStakeAmount(staker, _amount);
        emit WithdrewStake(_fromPoolStakingAddress, staker, stakingEpoch, _amount, fromPoolId);
    }

    /// @dev Orders tokens/coins withdrawal from the staking address of the specified pool to the
    /// staker's address. The requested tokens/coins can be claimed after the current staking epoch is complete using
    /// the `claimOrderedWithdraw` function.
    /// @param _poolStakingAddress The staking address of the pool from which the amount will be withdrawn.
    /// @param _amount The amount to be withdrawn. A positive value means the staker wants to either set or
    /// increase their withdrawal amount. A negative value means the staker wants to decrease a
    /// withdrawal amount that was previously set. The amount cannot exceed the value returned by the
    /// `maxWithdrawOrderAllowed` getter.
    function orderWithdraw(address _poolStakingAddress, int256 _amount) external gasPriceIsValid onlyInitialized {
        uint256 poolId = validatorSetContract.idByStakingAddress(_poolStakingAddress);

        require(_poolStakingAddress != address(0));
        require(_amount != 0);
        require(poolId != 0);

        address staker = msg.sender;
        address delegatorOrZero = (staker != _poolStakingAddress) ? staker : address(0);

        require(_isWithdrawAllowed(poolId, delegatorOrZero != address(0)));

        uint256 newOrderedAmount = orderedWithdrawAmount[poolId][delegatorOrZero];
        uint256 newOrderedAmountTotal = orderedWithdrawAmountTotal[poolId];
        uint256 newStakeAmount = stakeAmount[poolId][delegatorOrZero];
        uint256 newStakeAmountTotal = stakeAmountTotal[poolId];
        if (_amount > 0) {
            uint256 amount = uint256(_amount);

            // How much can `staker` order for withdrawal from `_poolStakingAddress` at the moment?
            require(amount <= maxWithdrawOrderAllowed(_poolStakingAddress, staker));

            newOrderedAmount = newOrderedAmount.add(amount);
            newOrderedAmountTotal = newOrderedAmountTotal.add(amount);
            newStakeAmount = newStakeAmount.sub(amount);
            newStakeAmountTotal = newStakeAmountTotal.sub(amount);
            orderWithdrawEpoch[poolId][delegatorOrZero] = stakingEpoch;
        } else {
            uint256 amount = uint256(-_amount);
            newOrderedAmount = newOrderedAmount.sub(amount);
            newOrderedAmountTotal = newOrderedAmountTotal.sub(amount);
            newStakeAmount = newStakeAmount.add(amount);
            newStakeAmountTotal = newStakeAmountTotal.add(amount);
        }
        orderedWithdrawAmount[poolId][delegatorOrZero] = newOrderedAmount;
        orderedWithdrawAmountTotal[poolId] = newOrderedAmountTotal;
        stakeAmount[poolId][delegatorOrZero] = newStakeAmount;
        stakeAmountTotal[poolId] = newStakeAmountTotal;

        if (staker == _poolStakingAddress) {
            // Initial validator cannot withdraw their initial stake
            require(newStakeAmount >= _stakeInitial[poolId]);

            // The amount to be withdrawn must be the whole staked amount or
            // must not exceed the diff between the entire amount and `candidateMinStake`
            require(newStakeAmount == 0 || newStakeAmount >= candidateMinStake);

            uint256 unremovablePoolId = validatorSetContract.unremovableValidator();

            if (_amount > 0) { // if the validator orders the `_amount` for withdrawal
                if (newStakeAmount == 0 && poolId != unremovablePoolId) {
                    // If the removable validator orders their entire stake,
                    // mark their pool as `to be removed`
                    _addPoolToBeRemoved(poolId);
                }
            } else {
                // If the validator wants to reduce withdrawal value,
                // add their pool as `active` if it hasn't already done
                _addPoolActive(poolId, poolId != unremovablePoolId);
            }
        } else {
            // The amount to be withdrawn must be the whole staked amount or
            // must not exceed the diff between the entire amount and `delegatorMinStake`
            require(newStakeAmount == 0 || newStakeAmount >= delegatorMinStake);

            if (_amount > 0) { // if the delegator orders the `_amount` for withdrawal
                if (newStakeAmount == 0) {
                    // If the delegator orders their entire stake,
                    // remove the delegator from delegator list of the pool
                    _removePoolDelegator(poolId, staker);
                }
            } else {
                // If the delegator wants to reduce withdrawal value,
                // add them to delegator list of the pool if it hasn't already done
                _addPoolDelegator(poolId, staker);
            }

            // Remember stake movement to use it later in the `claimReward` function
            _snapshotDelegatorStake(poolId, staker);
        }

        _setLikelihood(poolId);

        emit OrderedWithdrawal(_poolStakingAddress, staker, stakingEpoch, _amount, poolId);
    }

    /// @dev Withdraws the staking tokens/coins from the specified pool ordered during the previous staking epochs with
    /// the `orderWithdraw` function. The ordered amount can be retrieved by the `orderedWithdrawAmount` getter.
    /// @param _poolStakingAddress The staking address of the pool from which the ordered tokens/coins are withdrawn.
    function claimOrderedWithdraw(address _poolStakingAddress) external {
        uint256 poolId = validatorSetContract.idByStakingAddress(_poolStakingAddress);
        require(poolId != 0);

        address payable staker = msg.sender;
        address delegatorOrZero = (staker != _poolStakingAddress) ? staker : address(0);

        require(stakingEpoch > orderWithdrawEpoch[poolId][delegatorOrZero]);
        require(_isWithdrawAllowed(poolId, delegatorOrZero != address(0)));

        uint256 claimAmount = orderedWithdrawAmount[poolId][delegatorOrZero];
        require(claimAmount != 0);

        orderedWithdrawAmount[poolId][delegatorOrZero] = 0;
        orderedWithdrawAmountTotal[poolId] = orderedWithdrawAmountTotal[poolId].sub(claimAmount);

        if (stakeAmount[poolId][delegatorOrZero] == 0) {
            _withdrawCheckPool(poolId, _poolStakingAddress, staker);
        }

        _sendWithdrawnStakeAmount(staker, claimAmount);

        emit ClaimedOrderedWithdrawal(_poolStakingAddress, staker, stakingEpoch, claimAmount, poolId);
    }

    /// @dev Sets (updates) the limit of the minimum candidate stake (CANDIDATE_MIN_STAKE).
    /// Can only be called by the `owner`.
    /// @param _minStake The value of a new limit in Wei.
    function setCandidateMinStake(uint256 _minStake) external onlyOwner onlyInitialized {
        candidateMinStake = _minStake;
    }

    /// @dev Sets (updates) the limit of the minimum delegator stake (DELEGATOR_MIN_STAKE).
    /// Can only be called by the `owner`.
    /// @param _minStake The value of a new limit in Wei.
    function setDelegatorMinStake(uint256 _minStake) external onlyOwner onlyInitialized {
        delegatorMinStake = _minStake;
    }

    // =============================================== Getters ========================================================

    /// @dev Returns an array of the current active pools (the pool ids of candidates and validators).
    /// The size of the array cannot exceed MAX_CANDIDATES. A pool can be added to this array with the `_addPoolActive`
    /// internal function which is called by the `stake` or `orderWithdraw` function. A pool is considered active
    /// if its address has at least the minimum stake and this stake is not ordered to be withdrawn.
    function getPools() external view returns(uint256[] memory) {
        return _pools;
    }

    /// @dev Returns an array of the current inactive pools (the pool ids of former candidates).
    /// A pool can be added to this array with the `_addPoolInactive` internal function which is called
    /// by `_removePool`. A pool is considered inactive if it is banned for some reason, if its address
    /// has zero stake, or if its entire stake is ordered to be withdrawn.
    function getPoolsInactive() external view returns(uint256[] memory) {
        return _poolsInactive;
    }

    /// @dev Returns the array of stake amounts for each corresponding
    /// address in the `poolsToBeElected` array (see the `getPoolsToBeElected` getter) and a sum of these amounts.
    /// Used by the `ValidatorSetAuRa.newValidatorSet` function when randomly selecting new validators at the last
    /// block of a staking epoch. An array value is updated every time any staked amount is changed in this pool
    /// (see the `_setLikelihood` internal function).
    /// @return `uint256[] likelihoods` - The array of the coefficients. The array length is always equal to the length
    /// of the `poolsToBeElected` array.
    /// `uint256 sum` - The total sum of the amounts.
    function getPoolsLikelihood() external view returns(uint256[] memory likelihoods, uint256 sum) {
        return (_poolsLikelihood, _poolsLikelihoodSum);
    }

    /// @dev Returns the list of pools (their ids) which will participate in a new validator set
    /// selection process in the `ValidatorSetAuRa.newValidatorSet` function. This is an array of pools
    /// which will be considered as candidates when forming a new validator set (at the last block of a staking epoch).
    /// This array is kept updated by the `_addPoolToBeElected` and `_deletePoolToBeElected` internal functions.
    function getPoolsToBeElected() external view returns(uint256[] memory) {
        return _poolsToBeElected;
    }

    /// @dev Returns the list of pools (their ids) which will be removed by the
    /// `ValidatorSetAuRa.newValidatorSet` function from the active `pools` array (at the last block
    /// of a staking epoch). This array is kept updated by the `_addPoolToBeRemoved`
    /// and `_deletePoolToBeRemoved` internal functions. A pool is added to this array when the pool's
    /// address withdraws (or orders) all of its own staking tokens from the pool, inactivating the pool.
    function getPoolsToBeRemoved() external view returns(uint256[] memory) {
        return _poolsToBeRemoved;
    }

    /// @dev Returns the list of pool ids into which the specified delegator have ever staked.
    /// @param _delegator The delegator address.
    /// @param _offset The index in the array at which the reading should start. Ignored if the `_length` is 0.
    /// @param _length The max number of items to return.
    function getDelegatorPools(
        address _delegator,
        uint256 _offset,
        uint256 _length
    ) external view returns(uint256[] memory result) {
        uint256[] storage delegatorPools = _delegatorPools[_delegator];
        if (_length == 0) {
            return delegatorPools;
        }
        uint256 maxLength = delegatorPools.length.sub(_offset);
        result = new uint256[](_length > maxLength ? maxLength : _length);
        for (uint256 i = 0; i < result.length; i++) {
            result[i] = delegatorPools[_offset + i];
        }
    }

    /// @dev Returns the length of the list of pools into which the specified delegator have ever staked.
    /// @param _delegator The delegator address.
    function getDelegatorPoolsLength(address _delegator) external view returns(uint256) {
        return _delegatorPools[_delegator].length;
    }

    /// @dev Determines whether staking/withdrawal operations are allowed at the moment.
    /// Used by all staking/withdrawal functions.
    function areStakeAndWithdrawAllowed() public view returns(bool) {
        uint256 currentBlock = _getCurrentBlockNumber();
        if (currentBlock < stakingEpochStartBlock) return false;
        uint256 allowedDuration = stakingEpochDuration - stakeWithdrawDisallowPeriod;
        if (stakingEpochStartBlock == 0) allowedDuration++;
        return currentBlock - stakingEpochStartBlock < allowedDuration;
    }


    /// @dev Returns a boolean flag indicating if the `initialize` function has been called.
    function isInitialized() public view returns(bool) {
        return validatorSetContract != IValidatorSetAuRa(0);
    }

    /// @dev Returns a flag indicating whether a specified id is in the `pools` array.
    /// See the `getPools` getter.
    /// @param _poolId An id of the pool.
    function isPoolActive(uint256 _poolId) public view returns(bool) {
        uint256 index = poolIndex[_poolId];
        return index < _pools.length && _pools[index] == _poolId;
    }

    /// @dev Returns the maximum amount which can be withdrawn from the specified pool by the specified staker
    /// at the moment. Used by the `withdraw` and `moveStake` functions.
    /// @param _poolStakingAddress The pool staking address from which the withdrawal will be made.
    /// @param _staker The staker address that is going to withdraw.
    function maxWithdrawAllowed(address _poolStakingAddress, address _staker) public view returns(uint256) {
        uint256 poolId = validatorSetContract.idByStakingAddress(_poolStakingAddress);
        address delegatorOrZero = (_staker != _poolStakingAddress) ? _staker : address(0);
        bool isDelegator = _poolStakingAddress != _staker;

        if (!_isWithdrawAllowed(poolId, isDelegator)) {
            return 0;
        }
        
        uint256 canWithdraw = stakeAmount[poolId][delegatorOrZero];

        if (!isDelegator) {
            // Initial validator cannot withdraw their initial stake
            canWithdraw = canWithdraw.sub(_stakeInitial[poolId]);
        }

        if (!validatorSetContract.isValidatorOrPending(poolId)) {
            // The pool is not a validator and is not going to become one,
            // so the staker can only withdraw staked amount minus already
            // ordered amount
            return canWithdraw;
        }

        // The pool is a validator (active or pending), so the staker can only
        // withdraw staked amount minus already ordered amount but
        // no more than the amount staked during the current staking epoch
        uint256 stakedDuringEpoch = stakeAmountByCurrentEpoch(poolId, delegatorOrZero);

        if (canWithdraw > stakedDuringEpoch) {
            canWithdraw = stakedDuringEpoch;
        }

        return canWithdraw;
    }

    /// @dev Returns the maximum amount which can be ordered to be withdrawn from the specified pool by the
    /// specified staker at the moment. Used by the `orderWithdraw` function.
    /// @param _poolStakingAddress The pool staking address from which the withdrawal will be ordered.
    /// @param _staker The staker address that is going to order the withdrawal.
    function maxWithdrawOrderAllowed(address _poolStakingAddress, address _staker) public view returns(uint256) {
        uint256 poolId = validatorSetContract.idByStakingAddress(_poolStakingAddress);
        address delegatorOrZero = (_staker != _poolStakingAddress) ? _staker : address(0);
        bool isDelegator = _poolStakingAddress != _staker;

        if (!_isWithdrawAllowed(poolId, isDelegator)) {
            return 0;
        }

        if (!validatorSetContract.isValidatorOrPending(poolId)) {
            // If the pool is a candidate (not an active validator and not pending one),
            // no one can order withdrawal from the `_poolStakingAddress`, but
            // anyone can withdraw immediately (see the `maxWithdrawAllowed` getter)
            return 0;
        }

        // If the pool is an active or pending validator, the staker can order withdrawal
        // up to their total staking amount minus an already ordered amount
        // minus an amount staked during the current staking epoch

        uint256 canOrder = stakeAmount[poolId][delegatorOrZero];

        if (!isDelegator) {
            // Initial validator cannot withdraw their initial stake
            canOrder = canOrder.sub(_stakeInitial[poolId]);
        }

        return canOrder.sub(stakeAmountByCurrentEpoch(poolId, delegatorOrZero));
    }

    /// @dev Returns an array of the current active delegators of the specified pool.
    /// A delegator is considered active if they have staked into the specified
    /// pool and their stake is not ordered to be withdrawn.
    /// @param _poolId The pool id.
    function poolDelegators(uint256 _poolId) public view returns(address[] memory) {
        return _poolDelegators[_poolId];
    }

    /// @dev Returns an array of the current inactive delegators of the specified pool.
    /// A delegator is considered inactive if their entire stake is ordered to be withdrawn
    /// but not yet claimed.
    /// @param _poolId The pool id.
    function poolDelegatorsInactive(uint256 _poolId) public view returns(address[] memory) {
        return _poolDelegatorsInactive[_poolId];
    }

    /// @dev Returns the amount of staking tokens/coins staked into the specified pool by the specified staker
    /// during the current staking epoch (see the `stakingEpoch` getter).
    /// Used by the `stake`, `withdraw`, and `orderWithdraw` functions.
    /// @param _poolId The pool id.
    /// @param _delegatorOrZero The delegator's address (or zero address if the staker is the pool itself).
    function stakeAmountByCurrentEpoch(uint256 _poolId, address _delegatorOrZero)
        public
        view
        returns(uint256)
    {
        return _stakeAmountByEpoch[_poolId][_delegatorOrZero][stakingEpoch];
    }

    /// @dev Returns the number of the last block of the current staking epoch.
    function stakingEpochEndBlock() public view returns(uint256) {
        uint256 startBlock = stakingEpochStartBlock;
        return startBlock + stakingEpochDuration - (startBlock == 0 ? 0 : 1);
    }

    // ============================================== Internal ========================================================

    /// @dev Adds the specified pool id to the array of active pools returned by
    /// the `getPools` getter. Used by the `stake`, `addPool`, and `orderWithdraw` functions.
    /// @param _poolId The pool id added to the array of active pools.
    /// @param _toBeElected The boolean flag which defines whether the specified id should be
    /// added simultaneously to the `poolsToBeElected` array. See the `getPoolsToBeElected` getter.
    function _addPoolActive(uint256 _poolId, bool _toBeElected) internal {
        if (!isPoolActive(_poolId)) {
            poolIndex[_poolId] = _pools.length;
            _pools.push(_poolId);
            require(_pools.length <= _getMaxCandidates());
        }
        _removePoolInactive(_poolId);
        if (_toBeElected) {
            _addPoolToBeElected(_poolId);
        }
    }

    /// @dev Adds the specified pool id to the array of inactive pools returned by
    /// the `getPoolsInactive` getter. Used by the `_removePool` internal function.
    /// @param _poolId The pool id added to the array of inactive pools.
    function _addPoolInactive(uint256 _poolId) internal {
        uint256 index = poolInactiveIndex[_poolId];
        uint256 length = _poolsInactive.length;
        if (index >= length || _poolsInactive[index] != _poolId) {
            poolInactiveIndex[_poolId] = length;
            _poolsInactive.push(_poolId);
        }
    }

    /// @dev Adds the specified pool id to the array of pools returned by the `getPoolsToBeElected`
    /// getter. Used by the `_addPoolActive` internal function. See the `getPoolsToBeElected` getter.
    /// @param _poolId The pool id added to the `poolsToBeElected` array.
    function _addPoolToBeElected(uint256 _poolId) internal {
        uint256 index = poolToBeElectedIndex[_poolId];
        uint256 length = _poolsToBeElected.length;
        if (index >= length || _poolsToBeElected[index] != _poolId) {
            poolToBeElectedIndex[_poolId] = length;
            _poolsToBeElected.push(_poolId);
            _poolsLikelihood.push(0); // assumes the likelihood is set with `_setLikelihood` function hereinafter
        }
        _deletePoolToBeRemoved(_poolId);
    }

    /// @dev Adds the specified pool id to the array of pools returned by the `getPoolsToBeRemoved`
    /// getter. Used by withdrawal functions. See the `getPoolsToBeRemoved` getter.
    /// @param _poolId The pool id added to the `poolsToBeRemoved` array.
    function _addPoolToBeRemoved(uint256 _poolId) internal {
        uint256 index = poolToBeRemovedIndex[_poolId];
        uint256 length = _poolsToBeRemoved.length;
        if (index >= length || _poolsToBeRemoved[index] != _poolId) {
            poolToBeRemovedIndex[_poolId] = length;
            _poolsToBeRemoved.push(_poolId);
        }
        _deletePoolToBeElected(_poolId);
    }

    /// @dev Deletes the specified pool id from the array of pools returned by the
    /// `getPoolsToBeElected` getter. Used by the `_addPoolToBeRemoved` and `_removePool` internal functions.
    /// See the `getPoolsToBeElected` getter.
    /// @param _poolId The pool id deleted from the `poolsToBeElected` array.
    function _deletePoolToBeElected(uint256 _poolId) internal {
        if (_poolsToBeElected.length != _poolsLikelihood.length) return;
        uint256 indexToDelete = poolToBeElectedIndex[_poolId];
        if (_poolsToBeElected.length > indexToDelete && _poolsToBeElected[indexToDelete] == _poolId) {
            if (_poolsLikelihoodSum >= _poolsLikelihood[indexToDelete]) {
                _poolsLikelihoodSum -= _poolsLikelihood[indexToDelete];
            } else {
                _poolsLikelihoodSum = 0;
            }
            uint256 lastPoolIndex = _poolsToBeElected.length - 1;
            uint256 lastPool = _poolsToBeElected[lastPoolIndex];
            _poolsToBeElected[indexToDelete] = lastPool;
            _poolsLikelihood[indexToDelete] = _poolsLikelihood[lastPoolIndex];
            poolToBeElectedIndex[lastPool] = indexToDelete;
            poolToBeElectedIndex[_poolId] = 0;
            _poolsToBeElected.length--;
            _poolsLikelihood.length--;
        }
    }

    /// @dev Deletes the specified pool id from the array of pools returned by the
    /// `getPoolsToBeRemoved` getter. Used by the `_addPoolToBeElected` and `_removePool` internal functions.
    /// See the `getPoolsToBeRemoved` getter.
    /// @param _poolId The pool id deleted from the `poolsToBeRemoved` array.
    function _deletePoolToBeRemoved(uint256 _poolId) internal {
        uint256 indexToDelete = poolToBeRemovedIndex[_poolId];
        if (_poolsToBeRemoved.length > indexToDelete && _poolsToBeRemoved[indexToDelete] == _poolId) {
            uint256 lastPool = _poolsToBeRemoved[_poolsToBeRemoved.length - 1];
            _poolsToBeRemoved[indexToDelete] = lastPool;
            poolToBeRemovedIndex[lastPool] = indexToDelete;
            poolToBeRemovedIndex[_poolId] = 0;
            _poolsToBeRemoved.length--;
        }
    }

    /// @dev Removes the specified pool id from the array of active pools returned by
    /// the `getPools` getter. Used by the `removePool`, `removeMyPool`, and withdrawal functions.
    /// @param _poolId The pool id removed from the array of active pools.
    function _removePool(uint256 _poolId) internal {
        uint256 indexToRemove = poolIndex[_poolId];
        if (_pools.length > indexToRemove && _pools[indexToRemove] == _poolId) {
            uint256 lastPool = _pools[_pools.length - 1];
            _pools[indexToRemove] = lastPool;
            poolIndex[lastPool] = indexToRemove;
            poolIndex[_poolId] = 0;
            _pools.length--;
        }
        if (_isPoolEmpty(_poolId)) {
            _removePoolInactive(_poolId);
        } else {
            _addPoolInactive(_poolId);
        }
        _deletePoolToBeElected(_poolId);
        _deletePoolToBeRemoved(_poolId);
        lastChangeBlock = _getCurrentBlockNumber();
    }

    /// @dev Removes the specified pool id from the array of inactive pools returned by
    /// the `getPoolsInactive` getter. Used by withdrawal functions, by the `_addPoolActive` and
    /// `_removePool` internal functions.
    /// @param _poolId The pool id removed from the array of inactive pools.
    function _removePoolInactive(uint256 _poolId) internal {
        uint256 indexToRemove = poolInactiveIndex[_poolId];
        if (_poolsInactive.length > indexToRemove && _poolsInactive[indexToRemove] == _poolId) {
            uint256 lastPool = _poolsInactive[_poolsInactive.length - 1];
            _poolsInactive[indexToRemove] = lastPool;
            poolInactiveIndex[lastPool] = indexToRemove;
            poolInactiveIndex[_poolId] = 0;
            _poolsInactive.length--;
        }
    }

    /// @dev Used by `addPool` and `onTokenTransfer` functions. See their descriptions and code.
    /// @param _amount The amount of tokens to be staked. Ignored when staking in native coins
    /// because `msg.value` is used in that case.
    /// @param _stakingAddress The staking address of the new candidate.
    /// @param _miningAddress The mining address of the candidate. The mining address is bound to the staking address
    /// (msg.sender). This address cannot be equal to `_stakingAddress`.
    /// @param _byOnTokenTransfer A boolean flag defining whether this internal function is called
    /// by the `onTokenTransfer` function.
    function _addPool(
        uint256 _amount,
        address _stakingAddress,
        address _miningAddress,
        bool _byOnTokenTransfer
    ) internal returns(uint256) {
        uint256 poolId = validatorSetContract.addPool(_miningAddress, _stakingAddress);
        if (_byOnTokenTransfer) {
            _stake(_stakingAddress, _stakingAddress, _amount);
        } else {
            _stake(_stakingAddress, _amount);
        }
        emit AddedPool(_stakingAddress, _miningAddress, poolId);
        return poolId;
    }

    /// @dev Adds the specified address to the array of the current active delegators of the specified pool.
    /// Used by the `stake` and `orderWithdraw` functions. See the `poolDelegators` getter.
    /// @param _poolId The pool id.
    /// @param _delegator The delegator's address.
    function _addPoolDelegator(uint256 _poolId, address _delegator) internal {
        address[] storage delegators = _poolDelegators[_poolId];
        uint256 index = poolDelegatorIndex[_poolId][_delegator];
        uint256 length = delegators.length;
        if (index >= length || delegators[index] != _delegator) {
            poolDelegatorIndex[_poolId][_delegator] = length;
            delegators.push(_delegator);
        }
        _removePoolDelegatorInactive(_poolId, _delegator);
    }

    /// @dev Adds the specified address to the array of the current inactive delegators of the specified pool.
    /// Used by the `_removePoolDelegator` internal function.
    /// @param _poolId The pool id.
    /// @param _delegator The delegator's address.
    function _addPoolDelegatorInactive(uint256 _poolId, address _delegator) internal {
        address[] storage delegators = _poolDelegatorsInactive[_poolId];
        uint256 index = poolDelegatorInactiveIndex[_poolId][_delegator];
        uint256 length = delegators.length;
        if (index >= length || delegators[index] != _delegator) {
            poolDelegatorInactiveIndex[_poolId][_delegator] = length;
            delegators.push(_delegator);
        }
    }

    /// @dev Removes the specified address from the array of the current active delegators of the specified pool.
    /// Used by the withdrawal functions. See the `poolDelegators` getter.
    /// @param _poolId The pool id.
    /// @param _delegator The delegator's address.
    function _removePoolDelegator(uint256 _poolId, address _delegator) internal {
        address[] storage delegators = _poolDelegators[_poolId];
        uint256 indexToRemove = poolDelegatorIndex[_poolId][_delegator];
        if (delegators.length > indexToRemove && delegators[indexToRemove] == _delegator) {
            address lastDelegator = delegators[delegators.length - 1];
            delegators[indexToRemove] = lastDelegator;
            poolDelegatorIndex[_poolId][lastDelegator] = indexToRemove;
            poolDelegatorIndex[_poolId][_delegator] = 0;
            delegators.length--;
        }
        if (orderedWithdrawAmount[_poolId][_delegator] != 0) {
            _addPoolDelegatorInactive(_poolId, _delegator);
        } else {
            _removePoolDelegatorInactive(_poolId, _delegator);
        }
    }

    /// @dev Removes the specified address from the array of the inactive delegators of the specified pool.
    /// Used by the `_addPoolDelegator` and `_removePoolDelegator` internal functions.
    /// @param _poolId The pool id.
    /// @param _delegator The delegator's address.
    function _removePoolDelegatorInactive(uint256 _poolId, address _delegator) internal {
        address[] storage delegators = _poolDelegatorsInactive[_poolId];
        uint256 indexToRemove = poolDelegatorInactiveIndex[_poolId][_delegator];
        if (delegators.length > indexToRemove && delegators[indexToRemove] == _delegator) {
            address lastDelegator = delegators[delegators.length - 1];
            delegators[indexToRemove] = lastDelegator;
            poolDelegatorInactiveIndex[_poolId][lastDelegator] = indexToRemove;
            poolDelegatorInactiveIndex[_poolId][_delegator] = 0;
            delegators.length--;
        }
    }

    function _sendWithdrawnStakeAmount(address payable _to, uint256 _amount) internal;

    /// @dev Calculates (updates) the probability of being selected as a validator for the specified pool
    /// and updates the total sum of probability coefficients. Actually, the probability is equal to the
    /// amount totally staked into the pool. See the `getPoolsLikelihood` getter.
    /// Used by the staking and withdrawal functions.
    /// @param _poolId An id of the pool for which the probability coefficient must be updated.
    function _setLikelihood(uint256 _poolId) internal {
        lastChangeBlock = _getCurrentBlockNumber();

        (bool isToBeElected, uint256 index) = _isPoolToBeElected(_poolId);

        if (!isToBeElected) return;

        uint256 oldValue = _poolsLikelihood[index];
        uint256 newValue = stakeAmountTotal[_poolId];

        _poolsLikelihood[index] = newValue;

        if (newValue >= oldValue) {
            _poolsLikelihoodSum = _poolsLikelihoodSum.add(newValue - oldValue);
        } else {
            _poolsLikelihoodSum = _poolsLikelihoodSum.sub(oldValue - newValue);
        }
    }

    /// @dev Makes a snapshot of the amount currently staked by the specified delegator
    /// into the specified pool. Used by the `orderWithdraw`, `_stake`, and `_withdraw` functions.
    /// @param _poolId An id of the pool.
    /// @param _delegator The address of the delegator.
    function _snapshotDelegatorStake(uint256 _poolId, address _delegator) internal {
        uint256 nextStakingEpoch = stakingEpoch + 1;
        uint256 newAmount = stakeAmount[_poolId][_delegator];

        delegatorStakeSnapshot[_poolId][_delegator][nextStakingEpoch] =
            (newAmount != 0) ? newAmount : uint256(-1);

        if (stakeFirstEpoch[_poolId][_delegator] == 0) {
            stakeFirstEpoch[_poolId][_delegator] = nextStakingEpoch;
        }
        stakeLastEpoch[_poolId][_delegator] = (newAmount == 0) ? nextStakingEpoch : 0;
    }

    function _stake(address _toPoolStakingAddress, uint256 _amount) internal;

    /// @dev The internal function used by the `_stake` and `moveStake` functions.
    /// See the `stake` public function for more details.
    /// @param _poolStakingAddress The staking address of the pool where the tokens/coins should be staked.
    /// @param _staker The staker's address.
    /// @param _amount The amount of tokens/coins to be staked.
    function _stake(
        address _poolStakingAddress,
        address _staker,
        uint256 _amount
    ) internal gasPriceIsValid onlyInitialized {
        uint256 poolId = validatorSetContract.idByStakingAddress(_poolStakingAddress);

        require(_poolStakingAddress != address(0));
        require(poolId != 0);
        require(_amount != 0);
        require(!validatorSetContract.isValidatorIdBanned(poolId));
        require(areStakeAndWithdrawAllowed());

        address delegatorOrZero = (_staker != _poolStakingAddress) ? _staker : address(0);
        uint256 newStakeAmount = stakeAmount[poolId][delegatorOrZero].add(_amount);

        if (_staker == _poolStakingAddress) {
            // The staked amount must be at least CANDIDATE_MIN_STAKE
            require(newStakeAmount >= candidateMinStake);
        } else {
            // The staked amount must be at least DELEGATOR_MIN_STAKE
            require(newStakeAmount >= delegatorMinStake);

            // The delegator cannot stake into the pool of the candidate which hasn't self-staked.
            // Also, that candidate shouldn't want to withdraw all their funds.
            require(stakeAmount[poolId][address(0)] != 0);
        }

        stakeAmount[poolId][delegatorOrZero] = newStakeAmount;
        _stakeAmountByEpoch[poolId][delegatorOrZero][stakingEpoch] = 
            stakeAmountByCurrentEpoch(poolId, delegatorOrZero).add(_amount);
        stakeAmountTotal[poolId] = stakeAmountTotal[poolId].add(_amount);

        if (_staker == _poolStakingAddress) { // `staker` places a stake for himself and becomes a candidate
            // Add `_poolStakingAddress` to the array of pools
            _addPoolActive(poolId, poolId != validatorSetContract.unremovableValidator());
        } else {
            // Add `_staker` to the array of pool's delegators
            _addPoolDelegator(poolId, _staker);

            // Save/update amount value staked by the delegator
            _snapshotDelegatorStake(poolId, _staker);

            // Remember that the delegator (`_staker`) has ever staked into `_poolStakingAddress`
            uint256[] storage delegatorPools = _delegatorPools[_staker];
            uint256 delegatorPoolsLength = delegatorPools.length;
            uint256 index = _delegatorPoolsIndexes[_staker][poolId];
            bool neverStakedBefore = index >= delegatorPoolsLength || delegatorPools[index] != poolId;
            if (neverStakedBefore) {
                _delegatorPoolsIndexes[_staker][poolId] = delegatorPoolsLength;
                delegatorPools.push(poolId);
            }

            if (delegatorPoolsLength == 0) {
                // If this is the first time the delegator stakes,
                // make sure the delegator has never been a mining address
                require(!validatorSetContract.hasEverBeenMiningAddress(_staker));
            }
        }

        _setLikelihood(poolId);

        emit PlacedStake(_poolStakingAddress, _staker, stakingEpoch, _amount, poolId);
    }

    /// @dev The internal function used by the `withdraw` and `moveStake` functions.
    /// See the `withdraw` public function for more details.
    /// @param _poolStakingAddress The staking address of the pool from which the tokens/coins should be withdrawn.
    /// @param _staker The staker's address.
    /// @param _amount The amount of the tokens/coins to be withdrawn.
    function _withdraw(
        address _poolStakingAddress,
        address _staker,
        uint256 _amount
    ) internal gasPriceIsValid onlyInitialized {
        uint256 poolId = validatorSetContract.idByStakingAddress(_poolStakingAddress);

        require(_poolStakingAddress != address(0));
        require(_amount != 0);
        require(poolId != 0);

        // How much can `_staker` withdraw from `_poolStakingAddress` at the moment?
        require(_amount <= maxWithdrawAllowed(_poolStakingAddress, _staker));

        address delegatorOrZero = (_staker != _poolStakingAddress) ? _staker : address(0);
        uint256 newStakeAmount = stakeAmount[poolId][delegatorOrZero].sub(_amount);

        // The amount to be withdrawn must be the whole staked amount or
        // must not exceed the diff between the entire amount and min allowed stake
        uint256 minAllowedStake;
        if (_poolStakingAddress == _staker) {
            // initial validator cannot withdraw their initial stake
            require(newStakeAmount >= _stakeInitial[poolId]);
            minAllowedStake = candidateMinStake;
        } else {
            minAllowedStake = delegatorMinStake;
        }
        require(newStakeAmount == 0 || newStakeAmount >= minAllowedStake);

        stakeAmount[poolId][delegatorOrZero] = newStakeAmount;
        uint256 amountByEpoch = stakeAmountByCurrentEpoch(poolId, delegatorOrZero);
        _stakeAmountByEpoch[poolId][delegatorOrZero][stakingEpoch] = 
            amountByEpoch >= _amount ? amountByEpoch - _amount : 0;
        stakeAmountTotal[poolId] = stakeAmountTotal[poolId].sub(_amount);

        if (newStakeAmount == 0) {
            _withdrawCheckPool(poolId, _poolStakingAddress, _staker);
        }

        if (_staker != _poolStakingAddress) {
            _snapshotDelegatorStake(poolId, _staker);
        }

        _setLikelihood(poolId);
    }

    /// @dev The internal function used by the `_withdraw` and `claimOrderedWithdraw` functions.
    /// Contains a common logic for these functions.
    /// @param _poolId The id of the pool from which the tokens/coins are withdrawn.
    /// @param _poolStakingAddress The staking address of the pool from which the tokens/coins are withdrawn.
    /// @param _staker The staker's address.
    function _withdrawCheckPool(uint256 _poolId, address _poolStakingAddress, address _staker) internal {
        if (_staker == _poolStakingAddress) {
            uint256 unremovablePoolId = validatorSetContract.unremovableValidator();

            if (_poolId != unremovablePoolId) {
                if (validatorSetContract.isValidatorById(_poolId)) {
                    _addPoolToBeRemoved(_poolId);
                } else {
                    _removePool(_poolId);
                }
            }
        } else {
            _removePoolDelegator(_poolId, _staker);

            if (_isPoolEmpty(_poolId)) {
                _removePoolInactive(_poolId);
            }
        }
    }

    /// @dev Returns the current block number. Needed mostly for unit tests.
    function _getCurrentBlockNumber() internal view returns(uint256) {
        return block.number;
    }

    /// @dev The internal function used by the `claimReward` function and `getRewardAmount` getter.
    /// Finds the stake amount made by a specified delegator into a specified pool before a specified
    /// staking epoch.
    function _getDelegatorStake(
        uint256 _epoch,
        uint256 _firstEpoch,
        uint256 _prevDelegatorStake,
        uint256 _poolId,
        address _delegator
    ) internal view returns(uint256 delegatorStake) {
        while (true) {
            delegatorStake = delegatorStakeSnapshot[_poolId][_delegator][_epoch];
            if (delegatorStake != 0) {
                delegatorStake = (delegatorStake == uint256(-1)) ? 0 : delegatorStake;
                break;
            } else if (_epoch == _firstEpoch) {
                delegatorStake = _prevDelegatorStake;
                break;
            }
            _epoch--;
        }
    }

    /// @dev Returns the max number of candidates (including validators). See the MAX_CANDIDATES constant.
    /// Needed mostly for unit tests.
    function _getMaxCandidates() internal pure returns(uint256) {
        return MAX_CANDIDATES;
    }

    /// @dev Returns a boolean flag indicating whether the specified pool is fully empty
    /// (all stakes are withdrawn including ordered withdrawals).
    /// @param _poolId An id of the pool.
    function _isPoolEmpty(uint256 _poolId) internal view returns(bool) {
        return stakeAmountTotal[_poolId] == 0 && orderedWithdrawAmountTotal[_poolId] == 0;
    }

    /// @dev Determines if the specified pool is in the `poolsToBeElected` array. See the `getPoolsToBeElected` getter.
    /// Used by the `_setLikelihood` internal function.
    /// @param _poolId An id of the pool.
    /// @return `bool toBeElected` - The boolean flag indicating whether the `_poolId` is in the
    /// `poolsToBeElected` array.
    /// `uint256 index` - The position of the item in the `poolsToBeElected` array if `toBeElected` is `true`.
    function _isPoolToBeElected(uint256 _poolId) internal view returns(bool toBeElected, uint256 index) {
        index = poolToBeElectedIndex[_poolId];
        if (_poolsToBeElected.length > index && _poolsToBeElected[index] == _poolId) {
            return (true, index);
        }
        return (false, 0);
    }

    /// @dev Returns `true` if withdrawal from the pool of the specified candidate/validator is allowed at the moment.
    /// Used by all withdrawal functions.
    /// @param _poolId An id of the validator's pool.
    /// @param _isDelegator Whether the withdrawal is requested by a delegator, not by a candidate/validator.
    function _isWithdrawAllowed(uint256 _poolId, bool _isDelegator) internal view returns(bool) {
        if (_isDelegator) {
            if (validatorSetContract.areIdDelegatorsBanned(_poolId)) {
                // The delegator cannot withdraw from the banned validator pool until the ban is expired
                return false;
            }
        } else {
            if (validatorSetContract.isValidatorIdBanned(_poolId)) {
                // The banned validator cannot withdraw from their pool until the ban is expired
                return false;
            }
        }

        if (!areStakeAndWithdrawAllowed()) {
            return false;
        }

        return true;
    }

    /// @dev Returns the balance of this contract in staking tokens or coins
    /// depending on implementation.
    function _thisBalance() internal view returns(uint256);
}
