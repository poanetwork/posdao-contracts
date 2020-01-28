pragma solidity 0.5.10;

import "../interfaces/IBlockRewardAuRa.sol";
import "../interfaces/IERC677Minting.sol";
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

    address[] internal _pools;
    address[] internal _poolsInactive;
    address[] internal _poolsToBeElected;
    address[] internal _poolsToBeRemoved;
    uint256[] internal _poolsLikelihood;
    uint256 internal _poolsLikelihoodSum;
    mapping(address => address[]) internal _poolDelegators;
    mapping(address => address[]) internal _poolDelegatorsInactive;
    mapping(address => address[]) internal _stakerPools;
    mapping(address => mapping(address => uint256)) internal _stakerPoolsIndexes;
    mapping(address => mapping(address => mapping(uint256 => uint256))) internal _stakeAmountByEpoch;

    // Reserved storage space to allow for layout changes in the future.
    uint256[25] private ______gapForInternal;

    /// @dev The limit of the minimum candidate stake (CANDIDATE_MIN_STAKE).
    uint256 public candidateMinStake;

    /// @dev The limit of the minimum delegator stake (DELEGATOR_MIN_STAKE).
    uint256 public delegatorMinStake;

    /// @dev The snapshot of tokens amount staked into the specified pool by the specified delegator
    /// before the specified staking epoch. Used by the `claimReward` function.
    /// The first parameter is the pool staking address, the second one is delegator's address,
    /// the third one is staking epoch number.
    mapping(address => mapping(address => mapping(uint256 => uint256))) public delegatorStakeSnapshot;

    /// @dev The current amount of staking tokens/coins ordered for withdrawal from the specified
    /// pool by the specified staker. Used by the `orderWithdraw`, `claimOrderedWithdraw` and other functions.
    /// The first parameter is the pool staking address, the second one is the staker address.
    mapping(address => mapping(address => uint256)) public orderedWithdrawAmount;

    /// @dev The current total amount of staking tokens/coins ordered for withdrawal from
    /// the specified pool by all of its stakers. Pool staking address is accepted as a parameter.
    mapping(address => uint256) public orderedWithdrawAmountTotal;

    /// @dev The number of the staking epoch during which the specified staker ordered
    /// the latest withdraw from the specified pool. Used by the `claimOrderedWithdraw` function
    /// to allow the ordered amount to be claimed only in future staking epochs. The first parameter
    /// is the pool staking address, the second one is the staker address.
    mapping(address => mapping(address => uint256)) public orderWithdrawEpoch;

    /// @dev The delegator's index in the array returned by the `poolDelegators` getter.
    /// Used by the `_removePoolDelegator` internal function. The first parameter is a pool staking address.
    /// The second parameter is delegator's address.
    /// If the value is zero, it may mean the array doesn't contain the delegator.
    /// Check if the delegator is in the array using the `poolDelegators` getter.
    mapping(address => mapping(address => uint256)) public poolDelegatorIndex;

    /// @dev The delegator's index in the `poolDelegatorsInactive` array.
    /// Used by the `_removePoolDelegatorInactive` internal function.
    /// A delegator is considered inactive if they have withdrawn their stake from
    /// the specified pool but haven't yet claimed an ordered amount.
    /// The first parameter is a pool staking address. The second parameter is delegator's address.
    mapping(address => mapping(address => uint256)) public poolDelegatorInactiveIndex;

    /// @dev The pool's index in the array returned by the `getPoolsInactive` getter.
    /// Used by the `_removePoolInactive` internal function. The pool staking address is accepted as a parameter.
    mapping(address => uint256) public poolInactiveIndex;

    /// @dev The pool's index in the array returned by the `getPools` getter.
    /// Used by the `_removePool` internal function. A pool staking address is accepted as a parameter.
    /// If the value is zero, it may mean the array doesn't contain the address.
    /// Check the address is in the array using the `isPoolActive` getter.
    mapping(address => uint256) public poolIndex;

    /// @dev The pool's index in the array returned by the `getPoolsToBeElected` getter.
    /// Used by the `_deletePoolToBeElected` and `_isPoolToBeElected` internal functions.
    /// The pool staking address is accepted as a parameter.
    /// If the value is zero, it may mean the array doesn't contain the address.
    /// Check the address is in the array using the `getPoolsToBeElected` getter.
    mapping(address => uint256) public poolToBeElectedIndex;

    /// @dev The pool's index in the array returned by the `getPoolsToBeRemoved` getter.
    /// Used by the `_deletePoolToBeRemoved` internal function.
    /// The pool staking address is accepted as a parameter.
    /// If the value is zero, it may mean the array doesn't contain the address.
    /// Check the address is in the array using the `getPoolsToBeRemoved` getter.
    mapping(address => uint256) public poolToBeRemovedIndex;

    /// @dev A boolean flag indicating whether the reward was already taken
    /// from the specified pool by the specified staker for the specified staking epoch.
    /// The first parameter is the pool staking address, the second one is staker's address,
    /// the third one is staking epoch number.
    mapping(address => mapping(address => mapping(uint256 => bool))) public rewardWasTaken;

    /// @dev The amount of tokens currently staked into the specified pool by the specified
    /// staker. Doesn't include the amount ordered for withdrawal.
    /// The first parameter is the pool staking address, the second one is the staker address.
    mapping(address => mapping(address => uint256)) public stakeAmount;

    /// @dev The number of staking epoch before which the specified delegator placed their first
    /// stake into the specified pool. If this is equal to zero, it means the delegator never
    /// staked into the specified pool. The first parameter is the pool staking address,
    /// the second one is delegator's address.
    mapping(address => mapping(address => uint256)) public stakeFirstEpoch;

    /// @dev The number of staking epoch before which the specified delegator withdrew their stake
    /// from the specified pool. If this is equal to zero and `stakeFirstEpoch` is not zero, that means
    /// the delegator still has some stake in the specified pool. The first parameter is the pool
    /// staking address, the second one is delegator's address.
    mapping(address => mapping(address => uint256)) public stakeLastEpoch;

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
    /// The pool staking address is accepted as a parameter.
    mapping(address => uint256) public stakeAmountTotal;

    /// @dev The address of the `ValidatorSetAuRa` contract.
    IValidatorSetAuRa public validatorSetContract;

    // Reserved storage space to allow for layout changes in the future.
    uint256[25] private ______gapForPublic;

    // ============================================== Constants =======================================================

    /// @dev The max number of candidates (including validators). This limit was determined through stress testing.
    uint256 public constant MAX_CANDIDATES = 3000;

    // ================================================ Events ========================================================

    /// @dev Emitted by `_addPoolActive` internal function to signal that
    /// the specified staking address created a new pool.
    /// @param poolStakingAddress The staking address of newly added pool.
    event AddedPool(address indexed poolStakingAddress);

    /// @dev Emitted by the `claimOrderedWithdraw` function to signal the staker withdrew the specified
    /// amount of requested tokens/coins from the specified pool during the specified staking epoch.
    /// @param fromPoolStakingAddress The pool from which the `staker` withdrew the `amount`.
    /// @param staker The address of the staker that withdrew the `amount`.
    /// @param stakingEpoch The serial number of the staking epoch during which the claim was made.
    /// @param amount The withdrawal amount.
    event ClaimedOrderedWithdrawal(
        address indexed fromPoolStakingAddress,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount
    );

    /// @dev Emitted by the `moveStake` function to signal the staker moved the specified
    /// amount of stake from one pool to another during the specified staking epoch.
    /// @param fromPoolStakingAddress The pool from which the `staker` moved the stake.
    /// @param toPoolStakingAddress The destination pool where the `staker` moved the stake.
    /// @param staker The address of the staker who moved the `amount`.
    /// @param stakingEpoch The serial number of the staking epoch during which the `amount` was moved.
    /// @param amount The stake amount which was moved.
    event MovedStake(
        address fromPoolStakingAddress,
        address indexed toPoolStakingAddress,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount
    );

    /// @dev Emitted by the `orderWithdraw` function to signal the staker ordered the withdrawal of the
    /// specified amount of their stake from the specified pool during the specified staking epoch.
    /// @param fromPoolStakingAddress The pool from which the `staker` ordered a withdrawal of the `amount`.
    /// @param staker The address of the staker that ordered the withdrawal of the `amount`.
    /// @param stakingEpoch The serial number of the staking epoch during which the order was made.
    /// @param amount The ordered withdrawal amount. Can be either positive or negative.
    /// See the `orderWithdraw` function.
    event OrderedWithdrawal(
        address indexed fromPoolStakingAddress,
        address indexed staker,
        uint256 indexed stakingEpoch,
        int256 amount
    );

    /// @dev Emitted by the `stake` function to signal the staker placed a stake of the specified
    /// amount for the specified pool during the specified staking epoch.
    /// @param toPoolStakingAddress The pool in which the `staker` placed the stake.
    /// @param staker The address of the staker that placed the stake.
    /// @param stakingEpoch The serial number of the staking epoch during which the stake was made.
    /// @param amount The stake amount.
    event PlacedStake(
        address indexed toPoolStakingAddress,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount
    );

    /// @dev Emitted by `_removePool` internal function to signal that
    /// a pool with the specified staking address was removed.
    /// @param poolStakingAddress The staking address of removed pool.
    event RemovedPool(address indexed poolStakingAddress);

    /// @dev Emitted by the `withdraw` function to signal the staker withdrew the specified
    /// amount of a stake from the specified pool during the specified staking epoch.
    /// @param fromPoolStakingAddress The pool from which the `staker` withdrew the `amount`.
    /// @param staker The address of staker that withdrew the `amount`.
    /// @param stakingEpoch The serial number of the staking epoch during which the withdrawal was made.
    /// @param amount The withdrawal amount.
    event WithdrewStake(
        address indexed fromPoolStakingAddress,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount
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

    /// @dev Adds a new candidate's pool to the list of active pools (see the `getPools` getter) and
    /// moves the specified amount of staking tokens/coins from the candidate's staking address
    /// to the candidate's pool. A participant calls this function using their staking address when
    /// they want to create a pool. This is a wrapper for the `stake` function.
    /// @param _amount The amount of tokens to be staked. Ignored when staking in native coins
    /// because `msg.value` is used in that case.
    /// @param _miningAddress The mining address of the candidate. The mining address is bound to the staking address
    /// (msg.sender). This address cannot be equal to `msg.sender`.
    function addPool(uint256 _amount, address _miningAddress) external payable {
        address stakingAddress = msg.sender;
        validatorSetContract.setStakingAddress(_miningAddress, stakingAddress);
        _stake(stakingAddress, _amount);
    }

    /// @dev Adds the `unremovable validator` to either the `poolsToBeElected` or the `poolsToBeRemoved` array
    /// depending on their own stake in their own pool when they become removable. This allows the
    /// `ValidatorSetAuRa.newValidatorSet` function to recognize the unremovable validator as a regular removable pool.
    /// Called by the `ValidatorSet.clearUnremovableValidator` function.
    /// @param _unremovableStakingAddress The staking address of the unremovable validator.
    function clearUnremovableValidator(address _unremovableStakingAddress) external onlyValidatorSetContract {
        require(_unremovableStakingAddress != address(0));
        if (stakeAmount[_unremovableStakingAddress][_unremovableStakingAddress] != 0) {
            _addPoolToBeElected(_unremovableStakingAddress);
            _setLikelihood(_unremovableStakingAddress);
        } else {
            _addPoolToBeRemoved(_unremovableStakingAddress);
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
    /// @param _initialStakingAddresses The array of initial validators' staking addresses.
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
        address[] calldata _initialStakingAddresses,
        uint256 _delegatorMinStake,
        uint256 _candidateMinStake,
        uint256 _stakingEpochDuration,
        uint256 _stakingEpochStartBlock,
        uint256 _stakeWithdrawDisallowPeriod
    ) external {
        require(_stakingEpochDuration != 0);
        require(_stakingEpochDuration > _stakeWithdrawDisallowPeriod);
        require(_stakeWithdrawDisallowPeriod != 0);
        _initialize(
            _validatorSetContract,
            _initialStakingAddresses,
            _delegatorMinStake,
            _candidateMinStake
        );
        stakingEpochDuration = _stakingEpochDuration;
        stakeWithdrawDisallowPeriod = _stakeWithdrawDisallowPeriod;
        stakingEpochStartBlock = _stakingEpochStartBlock;
    }

    /// @dev Removes a specified pool from the `pools` array (a list of active pools which can be retrieved by the
    /// `getPools` getter). Called by the `ValidatorSetAuRa._removeMaliciousValidator` internal function
    /// when a pool must be removed by the algorithm.
    /// @param _stakingAddress The staking address of the pool to be removed.
    function removePool(address _stakingAddress) external onlyValidatorSetContract {
        _removePool(_stakingAddress);
    }

    /// @dev Removes pools which are in the `_poolsToBeRemoved` internal array from the `pools` array.
    /// Called by the `ValidatorSetAuRa.newValidatorSet` function when a pool must be removed by the algorithm.
    function removePools() external onlyValidatorSetContract {
        address[] memory poolsToRemove = _poolsToBeRemoved;
        for (uint256 i = 0; i < poolsToRemove.length; i++) {
            _removePool(poolsToRemove[i]);
        }
    }

    /// @dev Removes the candidate's or validator's pool from the `pools` array (a list of active pools which
    /// can be retrieved by the `getPools` getter). When a candidate or validator wants to remove their pool,
    /// they should call this function from their staking address. A validator cannot remove their pool while
    /// they are an `unremovable validator`.
    function removeMyPool() external gasPriceIsValid onlyInitialized {
        address stakingAddress = msg.sender;
        address miningAddress = validatorSetContract.miningByStakingAddress(stakingAddress);
        // initial validator cannot remove their pool during the initial staking epoch
        require(stakingEpoch > 0 || !validatorSetContract.isValidator(miningAddress));
        require(stakingAddress != validatorSetContract.unremovableValidator());
        _removePool(stakingAddress);
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
    ) external gasPriceIsValid onlyInitialized {
        require(_fromPoolStakingAddress != _toPoolStakingAddress);
        address staker = msg.sender;
        _withdraw(_fromPoolStakingAddress, staker, _amount);
        _stake(_toPoolStakingAddress, staker, _amount);
        emit MovedStake(_fromPoolStakingAddress, _toPoolStakingAddress, staker, stakingEpoch, _amount);
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
    function withdraw(address _fromPoolStakingAddress, uint256 _amount) external gasPriceIsValid onlyInitialized {
        address payable staker = msg.sender;
        _withdraw(_fromPoolStakingAddress, staker, _amount);
        _sendWithdrawnStakeAmount(staker, _amount);
        emit WithdrewStake(_fromPoolStakingAddress, staker, stakingEpoch, _amount);
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
        require(_poolStakingAddress != address(0));
        require(_amount != 0);

        address staker = msg.sender;

        require(_isWithdrawAllowed(
            validatorSetContract.miningByStakingAddress(_poolStakingAddress), staker != _poolStakingAddress
        ));

        uint256 newOrderedAmount = orderedWithdrawAmount[_poolStakingAddress][staker];
        uint256 newOrderedAmountTotal = orderedWithdrawAmountTotal[_poolStakingAddress];
        uint256 newStakeAmount = stakeAmount[_poolStakingAddress][staker];
        uint256 newStakeAmountTotal = stakeAmountTotal[_poolStakingAddress];
        if (_amount > 0) {
            uint256 amount = uint256(_amount);

            // How much can `staker` order for withdrawal from `_poolStakingAddress` at the moment?
            require(amount <= maxWithdrawOrderAllowed(_poolStakingAddress, staker));

            newOrderedAmount = newOrderedAmount.add(amount);
            newOrderedAmountTotal = newOrderedAmountTotal.add(amount);
            newStakeAmount = newStakeAmount.sub(amount);
            newStakeAmountTotal = newStakeAmountTotal.sub(amount);
            orderWithdrawEpoch[_poolStakingAddress][staker] = stakingEpoch;
        } else {
            uint256 amount = uint256(-_amount);
            newOrderedAmount = newOrderedAmount.sub(amount);
            newOrderedAmountTotal = newOrderedAmountTotal.sub(amount);
            newStakeAmount = newStakeAmount.add(amount);
            newStakeAmountTotal = newStakeAmountTotal.add(amount);
        }
        orderedWithdrawAmount[_poolStakingAddress][staker] = newOrderedAmount;
        orderedWithdrawAmountTotal[_poolStakingAddress] = newOrderedAmountTotal;
        stakeAmount[_poolStakingAddress][staker] = newStakeAmount;
        stakeAmountTotal[_poolStakingAddress] = newStakeAmountTotal;

        if (staker == _poolStakingAddress) {
            // The amount to be withdrawn must be the whole staked amount or
            // must not exceed the diff between the entire amount and `candidateMinStake`
            require(newStakeAmount == 0 || newStakeAmount >= candidateMinStake);

            address unremovableStakingAddress = validatorSetContract.unremovableValidator();

            if (_amount > 0) { // if the validator orders the `_amount` for withdrawal
                if (newStakeAmount == 0 && _poolStakingAddress != unremovableStakingAddress) {
                    // If the removable validator orders their entire stake,
                    // mark their pool as `to be removed`
                    _addPoolToBeRemoved(_poolStakingAddress);
                }
            } else {
                // If the validator wants to reduce withdrawal value,
                // add their pool as `active` if it hasn't already done
                _addPoolActive(_poolStakingAddress, _poolStakingAddress != unremovableStakingAddress);
            }
        } else {
            // The amount to be withdrawn must be the whole staked amount or
            // must not exceed the diff between the entire amount and `delegatorMinStake`
            require(newStakeAmount == 0 || newStakeAmount >= delegatorMinStake);

            if (_amount > 0) { // if the delegator orders the `_amount` for withdrawal
                if (newStakeAmount == 0) {
                    // If the delegator orders their entire stake,
                    // remove the delegator from delegator list of the pool
                    _removePoolDelegator(_poolStakingAddress, staker);
                }
            } else {
                // If the delegator wants to reduce withdrawal value,
                // add them to delegator list of the pool if it hasn't already done
                _addPoolDelegator(_poolStakingAddress, staker);
            }

            // Remember stake movement to use it later in the `claimReward` function
            _snapshotDelegatorStake(_poolStakingAddress, staker);
        }

        _setLikelihood(_poolStakingAddress);

        emit OrderedWithdrawal(_poolStakingAddress, staker, stakingEpoch, _amount);
    }

    /// @dev Withdraws the staking tokens/coins from the specified pool ordered during the previous staking epochs with
    /// the `orderWithdraw` function. The ordered amount can be retrieved by the `orderedWithdrawAmount` getter.
    /// @param _poolStakingAddress The staking address of the pool from which the ordered tokens/coins are withdrawn.
    function claimOrderedWithdraw(address _poolStakingAddress) external gasPriceIsValid onlyInitialized {
        address payable staker = msg.sender;

        require(stakingEpoch > orderWithdrawEpoch[_poolStakingAddress][staker]);
        require(_isWithdrawAllowed(
            validatorSetContract.miningByStakingAddress(_poolStakingAddress), staker != _poolStakingAddress
        ));

        uint256 claimAmount = orderedWithdrawAmount[_poolStakingAddress][staker];
        require(claimAmount != 0);

        orderedWithdrawAmount[_poolStakingAddress][staker] = 0;
        orderedWithdrawAmountTotal[_poolStakingAddress] =
            orderedWithdrawAmountTotal[_poolStakingAddress].sub(claimAmount);

        if (stakeAmount[_poolStakingAddress][staker] == 0) {
            _withdrawCheckPool(_poolStakingAddress, staker);
        }

        _sendWithdrawnStakeAmount(staker, claimAmount);

        emit ClaimedOrderedWithdrawal(_poolStakingAddress, staker, stakingEpoch, claimAmount);
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

    /// @dev Returns an array of the current active pools (the staking addresses of candidates and validators).
    /// The size of the array cannot exceed MAX_CANDIDATES. A pool can be added to this array with the `_addPoolActive`
    /// internal function which is called by the `stake` or `orderWithdraw` function. A pool is considered active
    /// if its address has at least the minimum stake and this stake is not ordered to be withdrawn.
    function getPools() external view returns(address[] memory) {
        return _pools;
    }

    /// @dev Returns an array of the current inactive pools (the staking addresses of former candidates).
    /// A pool can be added to this array with the `_addPoolInactive` internal function which is called
    /// by `_removePool`. A pool is considered inactive if it is banned for some reason, if its address
    /// has zero stake, or if its entire stake is ordered to be withdrawn.
    function getPoolsInactive() external view returns(address[] memory) {
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

    /// @dev Returns the list of pools (their staking addresses) which will participate in a new validator set
    /// selection process in the `ValidatorSetAuRa.newValidatorSet` function. This is an array of pools
    /// which will be considered as candidates when forming a new validator set (at the last block of a staking epoch).
    /// This array is kept updated by the `_addPoolToBeElected` and `_deletePoolToBeElected` internal functions.
    function getPoolsToBeElected() external view returns(address[] memory) {
        return _poolsToBeElected;
    }

    /// @dev Returns the list of pools (their staking addresses) which will be removed by the
    /// `ValidatorSetAuRa.newValidatorSet` function from the active `pools` array (at the last block
    /// of a staking epoch). This array is kept updated by the `_addPoolToBeRemoved`
    /// and `_deletePoolToBeRemoved` internal functions. A pool is added to this array when the pool's
    /// address withdraws (or orders) all of its own staking tokens from the pool, inactivating the pool.
    function getPoolsToBeRemoved() external view returns(address[] memory) {
        return _poolsToBeRemoved;
    }

    /// @dev Returns the list of pools (staking addresses) into which the specified staker have ever staked.
    /// @param _staker The staker address (it can be a delegator or a pool staking address itself).
    /// @param _offset The index in the array at which the reading should start. Ignored if the `_length` is 0.
    /// @param _length The max number of items to return.
    function getStakerPools(
        address _staker,
        uint256 _offset,
        uint256 _length
    ) external view returns(address[] memory result) {
        address[] storage stakerPools = _stakerPools[_staker];
        if (_length == 0) {
            return stakerPools;
        }
        uint256 maxLength = stakerPools.length.sub(_offset);
        result = new address[](_length > maxLength ? maxLength : _length);
        for (uint256 i = 0; i < result.length; i++) {
            result[i] = stakerPools[_offset + i];
        }
    }

    /// @dev Returns the length of the list of pools into which the specified staker have ever staked.
    /// @param _staker The staker address (it can be a delegator or a pool staking address itself).
    function getStakerPoolsLength(address _staker) external view returns(uint256) {
        return _stakerPools[_staker].length;
    }

    /// @dev Determines whether staking/withdrawal operations are allowed at the moment.
    /// Used by all staking/withdrawal functions.
    function areStakeAndWithdrawAllowed() public view returns(bool) {
        uint256 currentBlock = _getCurrentBlockNumber();
        uint256 allowedDuration = stakingEpochDuration - stakeWithdrawDisallowPeriod;
        if (currentBlock < stakingEpochStartBlock) return false;
        return currentBlock - stakingEpochStartBlock <= allowedDuration;
    }

    /// @dev Returns a boolean flag indicating if the `initialize` function has been called.
    function isInitialized() public view returns(bool) {
        return validatorSetContract != IValidatorSetAuRa(0);
    }

    /// @dev Returns a flag indicating whether a specified address is in the `pools` array.
    /// See the `getPools` getter.
    /// @param _stakingAddress The staking address of the pool.
    function isPoolActive(address _stakingAddress) public view returns(bool) {
        uint256 index = poolIndex[_stakingAddress];
        return index < _pools.length && _pools[index] == _stakingAddress;
    }

    /// @dev Returns the maximum amount which can be withdrawn from the specified pool by the specified staker
    /// at the moment. Used by the `withdraw` and `moveStake` functions.
    /// @param _poolStakingAddress The pool staking address from which the withdrawal will be made.
    /// @param _staker The staker address that is going to withdraw.
    function maxWithdrawAllowed(address _poolStakingAddress, address _staker) public view returns(uint256) {
        address miningAddress = validatorSetContract.miningByStakingAddress(_poolStakingAddress);

        if (!_isWithdrawAllowed(miningAddress, _poolStakingAddress != _staker)) {
            return 0;
        }

        uint256 canWithdraw = stakeAmount[_poolStakingAddress][_staker];

        if (!validatorSetContract.isValidatorOrPending(miningAddress)) {
            // The pool is not a validator and is not going to become one,
            // so the staker can only withdraw staked amount minus already
            // ordered amount
            return canWithdraw;
        }

        // The pool is a validator (active or pending), so the staker can only
        // withdraw staked amount minus already ordered amount but
        // no more than the amount staked during the current staking epoch
        uint256 stakedDuringEpoch = stakeAmountByCurrentEpoch(_poolStakingAddress, _staker);

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
        address miningAddress = validatorSetContract.miningByStakingAddress(_poolStakingAddress);

        if (!_isWithdrawAllowed(miningAddress, _poolStakingAddress != _staker)) {
            return 0;
        }

        if (!validatorSetContract.isValidatorOrPending(miningAddress)) {
            // If the pool is a candidate (not an active validator and not pending one),
            // no one can order withdrawal from the `_poolStakingAddress`, but
            // anyone can withdraw immediately (see the `maxWithdrawAllowed` getter)
            return 0;
        }

        // If the pool is an active or pending validator, the staker can order withdrawal
        // up to their total staking amount minus an already ordered amount
        // minus an amount staked during the current staking epoch
        return stakeAmount[_poolStakingAddress][_staker].sub(stakeAmountByCurrentEpoch(_poolStakingAddress, _staker));
    }

    /// @dev Prevents sending tokens directly to the `StakingAuRa` contract address
    /// by the `ERC677BridgeTokenRewardable.transferAndCall` function.
    function onTokenTransfer(address, uint256, bytes memory) public pure returns(bool) {
        revert();
    }

    /// @dev Returns an array of the current active delegators of the specified pool.
    /// A delegator is considered active if they have staked into the specified
    /// pool and their stake is not ordered to be withdrawn.
    /// @param _poolStakingAddress The pool staking address.
    function poolDelegators(address _poolStakingAddress) public view returns(address[] memory) {
        return _poolDelegators[_poolStakingAddress];
    }

    /// @dev Returns an array of the current inactive delegators of the specified pool.
    /// A delegator is considered inactive if their entire stake is ordered to be withdrawn
    /// but not yet claimed.
    /// @param _poolStakingAddress The pool staking address.
    function poolDelegatorsInactive(address _poolStakingAddress) public view returns(address[] memory) {
        return _poolDelegatorsInactive[_poolStakingAddress];
    }

    /// @dev Returns the amount of staking tokens/coins staked into the specified pool by the specified staker
    /// during the current staking epoch (see the `stakingEpoch` getter).
    /// Used by the `stake`, `withdraw`, and `orderWithdraw` functions.
    /// @param _poolStakingAddress The pool staking address.
    /// @param _staker The staker's address.
    function stakeAmountByCurrentEpoch(address _poolStakingAddress, address _staker)
        public
        view
        returns(uint256)
    {
        return _stakeAmountByEpoch[_poolStakingAddress][_staker][stakingEpoch];
    }

    /// @dev Returns the number of the last block of the current staking epoch.
    function stakingEpochEndBlock() public view returns(uint256) {
        uint256 startBlock = stakingEpochStartBlock;
        return startBlock + stakingEpochDuration - (startBlock == 0 ? 0 : 1);
    }

    // ============================================== Internal ========================================================

    /// @dev Adds the specified staking address to the array of active pools returned by
    /// the `getPools` getter. Used by the `stake`, `addPool`, and `orderWithdraw` functions.
    /// @param _stakingAddress The pool added to the array of active pools.
    /// @param _toBeElected The boolean flag which defines whether the specified address should be
    /// added simultaneously to the `poolsToBeElected` array. See the `getPoolsToBeElected` getter.
    function _addPoolActive(address _stakingAddress, bool _toBeElected) internal {
        if (!isPoolActive(_stakingAddress)) {
            poolIndex[_stakingAddress] = _pools.length;
            _pools.push(_stakingAddress);
            require(_pools.length <= _getMaxCandidates());
            emit AddedPool(_stakingAddress);
        }
        _removePoolInactive(_stakingAddress);
        if (_toBeElected) {
            _addPoolToBeElected(_stakingAddress);
        }
    }

    /// @dev Adds the specified staking address to the array of inactive pools returned by
    /// the `getPoolsInactive` getter. Used by the `_removePool` internal function.
    /// @param _stakingAddress The pool added to the array of inactive pools.
    function _addPoolInactive(address _stakingAddress) internal {
        uint256 index = poolInactiveIndex[_stakingAddress];
        uint256 length = _poolsInactive.length;
        if (index >= length || _poolsInactive[index] != _stakingAddress) {
            poolInactiveIndex[_stakingAddress] = length;
            _poolsInactive.push(_stakingAddress);
        }
    }

    /// @dev Adds the specified staking address to the array of pools returned by the `getPoolsToBeElected`
    /// getter. Used by the `_addPoolActive` internal function. See the `getPoolsToBeElected` getter.
    /// @param _stakingAddress The pool added to the `poolsToBeElected` array.
    function _addPoolToBeElected(address _stakingAddress) internal {
        uint256 index = poolToBeElectedIndex[_stakingAddress];
        uint256 length = _poolsToBeElected.length;
        if (index >= length || _poolsToBeElected[index] != _stakingAddress) {
            poolToBeElectedIndex[_stakingAddress] = length;
            _poolsToBeElected.push(_stakingAddress);
            _poolsLikelihood.push(0); // assumes the likelihood is set with `_setLikelihood` function hereinafter
        }
        _deletePoolToBeRemoved(_stakingAddress);
    }

    /// @dev Adds the specified staking address to the array of pools returned by the `getPoolsToBeRemoved`
    /// getter. Used by withdrawal functions. See the `getPoolsToBeRemoved` getter.
    /// @param _stakingAddress The pool added to the `poolsToBeRemoved` array.
    function _addPoolToBeRemoved(address _stakingAddress) internal {
        uint256 index = poolToBeRemovedIndex[_stakingAddress];
        uint256 length = _poolsToBeRemoved.length;
        if (index >= length || _poolsToBeRemoved[index] != _stakingAddress) {
            poolToBeRemovedIndex[_stakingAddress] = length;
            _poolsToBeRemoved.push(_stakingAddress);
        }
        _deletePoolToBeElected(_stakingAddress);
    }

    /// @dev Deletes the specified staking address from the array of pools returned by the
    /// `getPoolsToBeElected` getter. Used by the `_addPoolToBeRemoved` and `_removePool` internal functions.
    /// See the `getPoolsToBeElected` getter.
    /// @param _stakingAddress The pool deleted from the `poolsToBeElected` array.
    function _deletePoolToBeElected(address _stakingAddress) internal {
        if (_poolsToBeElected.length != _poolsLikelihood.length) return;
        uint256 indexToDelete = poolToBeElectedIndex[_stakingAddress];
        if (_poolsToBeElected.length > indexToDelete && _poolsToBeElected[indexToDelete] == _stakingAddress) {
            if (_poolsLikelihoodSum >= _poolsLikelihood[indexToDelete]) {
                _poolsLikelihoodSum -= _poolsLikelihood[indexToDelete];
            } else {
                _poolsLikelihoodSum = 0;
            }
            uint256 lastPoolIndex = _poolsToBeElected.length - 1;
            address lastPool = _poolsToBeElected[lastPoolIndex];
            _poolsToBeElected[indexToDelete] = lastPool;
            _poolsLikelihood[indexToDelete] = _poolsLikelihood[lastPoolIndex];
            poolToBeElectedIndex[lastPool] = indexToDelete;
            poolToBeElectedIndex[_stakingAddress] = 0;
            _poolsToBeElected.length--;
            _poolsLikelihood.length--;
        }
    }

    /// @dev Deletes the specified staking address from the array of pools returned by the
    /// `getPoolsToBeRemoved` getter. Used by the `_addPoolToBeElected` and `_removePool` internal functions.
    /// See the `getPoolsToBeRemoved` getter.
    /// @param _stakingAddress The pool deleted from the `poolsToBeRemoved` array.
    function _deletePoolToBeRemoved(address _stakingAddress) internal {
        uint256 indexToDelete = poolToBeRemovedIndex[_stakingAddress];
        if (_poolsToBeRemoved.length > indexToDelete && _poolsToBeRemoved[indexToDelete] == _stakingAddress) {
            address lastPool = _poolsToBeRemoved[_poolsToBeRemoved.length - 1];
            _poolsToBeRemoved[indexToDelete] = lastPool;
            poolToBeRemovedIndex[lastPool] = indexToDelete;
            poolToBeRemovedIndex[_stakingAddress] = 0;
            _poolsToBeRemoved.length--;
        }
    }

    /// @dev Removes the specified staking address from the array of active pools returned by
    /// the `getPools` getter. Used by the `removePool`, `removeMyPool`, and withdrawal functions.
    /// @param _stakingAddress The pool removed from the array of active pools.
    function _removePool(address _stakingAddress) internal {
        uint256 indexToRemove = poolIndex[_stakingAddress];
        if (_pools.length > indexToRemove && _pools[indexToRemove] == _stakingAddress) {
            address lastPool = _pools[_pools.length - 1];
            _pools[indexToRemove] = lastPool;
            poolIndex[lastPool] = indexToRemove;
            poolIndex[_stakingAddress] = 0;
            _pools.length--;
            emit RemovedPool(_stakingAddress);
        }
        if (_isPoolEmpty(_stakingAddress)) {
            _removePoolInactive(_stakingAddress);
        } else {
            _addPoolInactive(_stakingAddress);
        }
        _deletePoolToBeElected(_stakingAddress);
        _deletePoolToBeRemoved(_stakingAddress);
    }

    /// @dev Removes the specified staking address from the array of inactive pools returned by
    /// the `getPoolsInactive` getter. Used by withdrawal functions, by the `_addPoolActive` and
    /// `_removePool` internal functions.
    /// @param _stakingAddress The pool removed from the array of inactive pools.
    function _removePoolInactive(address _stakingAddress) internal {
        uint256 indexToRemove = poolInactiveIndex[_stakingAddress];
        if (_poolsInactive.length > indexToRemove && _poolsInactive[indexToRemove] == _stakingAddress) {
            address lastPool = _poolsInactive[_poolsInactive.length - 1];
            _poolsInactive[indexToRemove] = lastPool;
            poolInactiveIndex[lastPool] = indexToRemove;
            poolInactiveIndex[_stakingAddress] = 0;
            _poolsInactive.length--;
        }
    }

    /// @dev Initializes the network parameters. Used by the `initialize` function.
    /// @param _validatorSetContract The address of the `ValidatorSetAuRa` contract.
    /// @param _initialStakingAddresses The array of initial validators' staking addresses.
    /// @param _delegatorMinStake The minimum allowed amount of delegator stake in Wei.
    /// @param _candidateMinStake The minimum allowed amount of candidate/validator stake in Wei.
    function _initialize(
        address _validatorSetContract,
        address[] memory _initialStakingAddresses,
        uint256 _delegatorMinStake,
        uint256 _candidateMinStake
    ) internal {
        require(_getCurrentBlockNumber() == 0 || msg.sender == _admin());
        require(!isInitialized()); // initialization can only be done once
        require(_validatorSetContract != address(0));
        require(_initialStakingAddresses.length > 0);
        require(_delegatorMinStake != 0);
        require(_candidateMinStake != 0);

        validatorSetContract = IValidatorSetAuRa(_validatorSetContract);

        address unremovableStakingAddress = validatorSetContract.unremovableValidator();

        for (uint256 i = 0; i < _initialStakingAddresses.length; i++) {
            require(_initialStakingAddresses[i] != address(0));
            _addPoolActive(_initialStakingAddresses[i], false);
            if (_initialStakingAddresses[i] != unremovableStakingAddress) {
                _addPoolToBeRemoved(_initialStakingAddresses[i]);
            }
        }

        delegatorMinStake = _delegatorMinStake;
        candidateMinStake = _candidateMinStake;
    }

    /// @dev Adds the specified address to the array of the current active delegators of the specified pool.
    /// Used by the `stake` and `orderWithdraw` functions. See the `poolDelegators` getter.
    /// @param _poolStakingAddress The pool staking address.
    /// @param _delegator The delegator's address.
    function _addPoolDelegator(address _poolStakingAddress, address _delegator) internal {
        address[] storage delegators = _poolDelegators[_poolStakingAddress];
        uint256 index = poolDelegatorIndex[_poolStakingAddress][_delegator];
        uint256 length = delegators.length;
        if (index >= length || delegators[index] != _delegator) {
            poolDelegatorIndex[_poolStakingAddress][_delegator] = length;
            delegators.push(_delegator);
        }
        _removePoolDelegatorInactive(_poolStakingAddress, _delegator);
    }

    /// @dev Adds the specified address to the array of the current inactive delegators of the specified pool.
    /// Used by the `_removePoolDelegator` internal function.
    /// @param _poolStakingAddress The pool staking address.
    /// @param _delegator The delegator's address.
    function _addPoolDelegatorInactive(address _poolStakingAddress, address _delegator) internal {
        address[] storage delegators = _poolDelegatorsInactive[_poolStakingAddress];
        uint256 index = poolDelegatorInactiveIndex[_poolStakingAddress][_delegator];
        uint256 length = delegators.length;
        if (index >= length || delegators[index] != _delegator) {
            poolDelegatorInactiveIndex[_poolStakingAddress][_delegator] = length;
            delegators.push(_delegator);
        }
    }

    /// @dev Removes the specified address from the array of the current active delegators of the specified pool.
    /// Used by the withdrawal functions. See the `poolDelegators` getter.
    /// @param _poolStakingAddress The pool staking address.
    /// @param _delegator The delegator's address.
    function _removePoolDelegator(address _poolStakingAddress, address _delegator) internal {
        address[] storage delegators = _poolDelegators[_poolStakingAddress];
        uint256 indexToRemove = poolDelegatorIndex[_poolStakingAddress][_delegator];
        if (delegators.length > indexToRemove && delegators[indexToRemove] == _delegator) {
            address lastDelegator = delegators[delegators.length - 1];
            delegators[indexToRemove] = lastDelegator;
            poolDelegatorIndex[_poolStakingAddress][lastDelegator] = indexToRemove;
            poolDelegatorIndex[_poolStakingAddress][_delegator] = 0;
            delegators.length--;
        }
        if (orderedWithdrawAmount[_poolStakingAddress][_delegator] != 0) {
            _addPoolDelegatorInactive(_poolStakingAddress, _delegator);
        } else {
            _removePoolDelegatorInactive(_poolStakingAddress, _delegator);
        }
    }

    /// @dev Removes the specified address from the array of the inactive delegators of the specified pool.
    /// Used by the `_addPoolDelegator` and `_removePoolDelegator` internal functions.
    /// @param _poolStakingAddress The pool staking address.
    /// @param _delegator The delegator's address.
    function _removePoolDelegatorInactive(address _poolStakingAddress, address _delegator) internal {
        address[] storage delegators = _poolDelegatorsInactive[_poolStakingAddress];
        uint256 indexToRemove = poolDelegatorInactiveIndex[_poolStakingAddress][_delegator];
        if (delegators.length > indexToRemove && delegators[indexToRemove] == _delegator) {
            address lastDelegator = delegators[delegators.length - 1];
            delegators[indexToRemove] = lastDelegator;
            poolDelegatorInactiveIndex[_poolStakingAddress][lastDelegator] = indexToRemove;
            poolDelegatorInactiveIndex[_poolStakingAddress][_delegator] = 0;
            delegators.length--;
        }
    }

    function _sendWithdrawnStakeAmount(address payable _to, uint256 _amount) internal;

    /// @dev Calculates (updates) the probability of being selected as a validator for the specified pool
    /// and updates the total sum of probability coefficients. Actually, the probability is equal to the
    /// amount totally staked into the pool. See the `getPoolsLikelihood` getter.
    /// Used by the staking and withdrawal functions.
    /// @param _poolStakingAddress The address of the pool for which the probability coefficient must be updated.
    function _setLikelihood(address _poolStakingAddress) internal {
        (bool isToBeElected, uint256 index) = _isPoolToBeElected(_poolStakingAddress);

        if (!isToBeElected) return;

        uint256 oldValue = _poolsLikelihood[index];
        uint256 newValue = stakeAmountTotal[_poolStakingAddress];

        _poolsLikelihood[index] = newValue;

        if (newValue >= oldValue) {
            _poolsLikelihoodSum = _poolsLikelihoodSum.add(newValue - oldValue);
        } else {
            _poolsLikelihoodSum = _poolsLikelihoodSum.sub(oldValue - newValue);
        }
    }

    /// @dev Makes a snapshot of the amount currently staked by the specified delegator
    /// into the specified pool (staking address). Used by the `orderWithdraw`, `_stake`, and `_withdraw` functions.
    /// @param _poolStakingAddress The staking address of the pool.
    /// @param _delegator The address of the delegator.
    function _snapshotDelegatorStake(address _poolStakingAddress, address _delegator) internal {
        uint256 nextStakingEpoch = stakingEpoch + 1;
        uint256 newAmount = stakeAmount[_poolStakingAddress][_delegator];

        delegatorStakeSnapshot[_poolStakingAddress][_delegator][nextStakingEpoch] =
            (newAmount != 0) ? newAmount : uint256(-1);

        if (stakeFirstEpoch[_poolStakingAddress][_delegator] == 0) {
            stakeFirstEpoch[_poolStakingAddress][_delegator] = nextStakingEpoch;
        }
        stakeLastEpoch[_poolStakingAddress][_delegator] = (newAmount == 0) ? nextStakingEpoch : 0;
    }

    function _stake(address _toPoolStakingAddress, uint256 _amount) internal;

    /// @dev The internal function used by the `_stake` and `moveStake` functions.
    /// See the `stake` public function for more details.
    /// @param _poolStakingAddress The staking address of the pool where the tokens/coins should be staked.
    /// @param _staker The staker's address.
    /// @param _amount The amount of tokens/coins to be staked.
    function _stake(address _poolStakingAddress, address _staker, uint256 _amount) internal {
        address poolMiningAddress = validatorSetContract.miningByStakingAddress(_poolStakingAddress);

        require(poolMiningAddress != address(0));
        require(_poolStakingAddress != address(0));
        require(_amount != 0);
        require(!validatorSetContract.isValidatorBanned(poolMiningAddress));
        require(areStakeAndWithdrawAllowed());

        uint256 newStakeAmount = stakeAmount[_poolStakingAddress][_staker].add(_amount);

        if (_staker == _poolStakingAddress) {
            // The staked amount must be at least CANDIDATE_MIN_STAKE
            require(newStakeAmount >= candidateMinStake);
        } else {
            // The staked amount must be at least DELEGATOR_MIN_STAKE
            require(newStakeAmount >= delegatorMinStake);

            // The delegator cannot stake into the pool of the candidate which hasn't self-staked.
            // Also, that candidate shouldn't want to withdraw all their funds.
            require(stakeAmount[_poolStakingAddress][_poolStakingAddress] != 0);
        }

        stakeAmount[_poolStakingAddress][_staker] = newStakeAmount;
        _stakeAmountByEpoch[_poolStakingAddress][_staker][stakingEpoch] = 
            stakeAmountByCurrentEpoch(_poolStakingAddress, _staker).add(_amount);
        stakeAmountTotal[_poolStakingAddress] = stakeAmountTotal[_poolStakingAddress].add(_amount);

        if (_staker == _poolStakingAddress) { // `staker` places a stake for himself and becomes a candidate
            // Add `_poolStakingAddress` to the array of pools
            _addPoolActive(_poolStakingAddress, _poolStakingAddress != validatorSetContract.unremovableValidator());
        } else {
            // Add `_staker` to the array of pool's delegators
            _addPoolDelegator(_poolStakingAddress, _staker);

            // Save amount value staked by the delegator
            _snapshotDelegatorStake(_poolStakingAddress, _staker);
        }

        _setLikelihood(_poolStakingAddress);

        // Remember that the `_staker` staked into `_poolStakingAddress`
        address[] storage stakerPools = _stakerPools[_staker];
        uint256 index = _stakerPoolsIndexes[_staker][_poolStakingAddress];
        if (index >= stakerPools.length || stakerPools[index] != _poolStakingAddress) {
            _stakerPoolsIndexes[_staker][_poolStakingAddress] = stakerPools.length;
            stakerPools.push(_poolStakingAddress);
        }
    }

    /// @dev The internal function used by the `withdraw` and `moveStake` functions.
    /// See the `withdraw` public function for more details.
    /// @param _poolStakingAddress The staking address of the pool from which the tokens/coins should be withdrawn.
    /// @param _staker The staker's address.
    /// @param _amount The amount of the tokens/coins to be withdrawn.
    function _withdraw(address _poolStakingAddress, address _staker, uint256 _amount) internal {
        require(_poolStakingAddress != address(0));
        require(_amount != 0);

        // How much can `staker` withdraw from `_poolStakingAddress` at the moment?
        require(_amount <= maxWithdrawAllowed(_poolStakingAddress, _staker));

        uint256 newStakeAmount = stakeAmount[_poolStakingAddress][_staker].sub(_amount);

        // The amount to be withdrawn must be the whole staked amount or
        // must not exceed the diff between the entire amount and MIN_STAKE
        uint256 minAllowedStake = (_poolStakingAddress == _staker) ? candidateMinStake : delegatorMinStake;
        require(newStakeAmount == 0 || newStakeAmount >= minAllowedStake);

        stakeAmount[_poolStakingAddress][_staker] = newStakeAmount;
        uint256 amountByEpoch = stakeAmountByCurrentEpoch(_poolStakingAddress, _staker);
        _stakeAmountByEpoch[_poolStakingAddress][_staker][stakingEpoch] = 
            amountByEpoch >= _amount ? amountByEpoch - _amount : 0;
        stakeAmountTotal[_poolStakingAddress] = stakeAmountTotal[_poolStakingAddress].sub(_amount);

        if (newStakeAmount == 0) {
            _withdrawCheckPool(_poolStakingAddress, _staker);
        }

        if (_staker != _poolStakingAddress) {
            _snapshotDelegatorStake(_poolStakingAddress, _staker);
        }

        _setLikelihood(_poolStakingAddress);
    }

    /// @dev The internal function used by the `_withdraw` and `claimOrderedWithdraw` functions.
    /// Contains a common logic for these functions.
    /// @param _poolStakingAddress The staking address of the pool from which the tokens/coins are withdrawn.
    /// @param _staker The staker's address.
    function _withdrawCheckPool(address _poolStakingAddress, address _staker) internal {
        if (_staker == _poolStakingAddress) {
            address unremovableStakingAddress = validatorSetContract.unremovableValidator();

            if (_poolStakingAddress != unremovableStakingAddress) {
                address miningAddress = validatorSetContract.miningByStakingAddress(_poolStakingAddress);
                if (validatorSetContract.isValidator(miningAddress)) {
                    _addPoolToBeRemoved(_poolStakingAddress);
                } else {
                    _removePool(_poolStakingAddress);
                }
            }
        } else {
            _removePoolDelegator(_poolStakingAddress, _staker);

            if (_isPoolEmpty(_poolStakingAddress)) {
                _removePoolInactive(_poolStakingAddress);
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
        address _poolStakingAddress,
        address _delegator
    ) internal view returns(uint256 delegatorStake) {
        while (true) {
            delegatorStake = delegatorStakeSnapshot[_poolStakingAddress][_delegator][_epoch];
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
    /// @param _poolStakingAddress The staking address of the pool
    function _isPoolEmpty(address _poolStakingAddress) internal view returns(bool) {
        return stakeAmountTotal[_poolStakingAddress] == 0 && orderedWithdrawAmountTotal[_poolStakingAddress] == 0;
    }

    /// @dev Determines if the specified pool is in the `poolsToBeElected` array. See the `getPoolsToBeElected` getter.
    /// Used by the `_setLikelihood` internal function.
    /// @param _stakingAddress The staking address of the pool.
    /// @return `bool toBeElected` - The boolean flag indicating whether the `_stakingAddress` is in the
    /// `poolsToBeElected` array.
    /// `uint256 index` - The position of the item in the `poolsToBeElected` array if `toBeElected` is `true`.
    function _isPoolToBeElected(address _stakingAddress) internal view returns(bool toBeElected, uint256 index) {
        index = poolToBeElectedIndex[_stakingAddress];
        if (_poolsToBeElected.length > index && _poolsToBeElected[index] == _stakingAddress) {
            return (true, index);
        }
        return (false, 0);
    }

    /// @dev Returns `true` if withdrawal from the pool of the specified candidate/validator is allowed at the moment.
    /// Used by all withdrawal functions.
    /// @param _miningAddress The mining address of the validator's pool.
    /// @param _isDelegator Whether the withdrawal is requested by a delegator, not by a candidate/validator.
    function _isWithdrawAllowed(address _miningAddress, bool _isDelegator) internal view returns(bool) {
        if (_isDelegator) {
            if (validatorSetContract.areDelegatorsBanned(_miningAddress)) {
                // The delegator cannot withdraw from the banned validator pool until the ban is expired
                return false;
            }
        } else {
            if (validatorSetContract.isValidatorBanned(_miningAddress)) {
                // The banned validator cannot withdraw from their pool until the ban is expired
                return false;
            }
        }

        if (!areStakeAndWithdrawAllowed()) {
            return false;
        }

        return true;
    }
}
