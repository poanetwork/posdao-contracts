pragma solidity 0.5.9;

import "./interfaces/IBlockRewardAuRa.sol";
import "./interfaces/IERC20Minting.sol";
import "./interfaces/IStakingAuRa.sol";
import "./interfaces/IValidatorSetAuRa.sol";
import "./upgradeability/UpgradeableOwned.sol";
import "./libs/SafeMath.sol";


/// @dev Implements staking and withdrawal logic.
contract StakingAuRa is UpgradeableOwned, IStakingAuRa {
    using SafeMath for uint256;

    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables and do not change their types!

    address[] internal _pools;
    address[] internal _poolsInactive;
    address[] internal _poolsToBeElected;
    address[] internal _poolsToBeRemoved;
    uint256[] internal _poolsLikelihood;
    uint256 internal _poolsLikelihoodSum;
    mapping(address => address[]) internal _poolDelegators;
    mapping(address => address[]) internal _poolDelegatorsInactive;
    mapping(address => mapping(address => mapping(uint256 => uint256))) internal _stakeAmountByEpoch;

    /// @dev The limit of the minimum candidate stake (CANDIDATE_MIN_STAKE).
    uint256 public candidateMinStake;

    /// @dev The limit of the minimum delegator stake (DELEGATOR_MIN_STAKE).
    uint256 public delegatorMinStake;

    /// @dev A boolean flag indicating whether this contract restricts
    /// using ERC20/677 contract. If it returns `true`, native staking coins
    /// are used instead of ERC staking tokens.
    bool public erc20Restricted;

    /// @dev The address of the ERC20/677 staking token contract.
    IERC20Minting public erc20TokenContract;

    /// @dev The current amount of staking tokens/coins ordered for withdrawal from the specified
    /// pool by the specified staker. Used by the `orderWithdraw` and `claimOrderedWithdraw` functions.
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
    /// Used by the `_removePoolDelegator` function. The first parameter is a pool staking address.
    /// The second parameter is delegator's address.
    /// If the value is zero, it may mean the array doesn't contain the delegator.
    /// Check if the delegator is in the array using the `poolDelegators` getter.
    mapping(address => mapping(address => uint256)) public poolDelegatorIndex;

    /// @dev The delegator's index in the `poolDelegatorsInactive` array.
    /// Used by the `_removePoolDelegatorInactive` function.
    /// A delegator is considered inactive if they have withdrawn all their tokens from
    /// the specified pool or their entire stake is ordered to be withdrawn.
    /// The first parameter is a pool staking address. The second parameter is delegator's address.
    mapping(address => mapping(address => uint256)) public poolDelegatorInactiveIndex;

    /// @dev The pool's index in the array returned by the `getPoolsInactive` getter.
    /// Used by the `_removePoolInactive` function. The pool staking address is accepted as a parameter.
    mapping(address => uint256) public poolInactiveIndex;

    /// @dev The pool's index in the array returned by the `getPools` getter.
    /// Used by the `_removePool` function. A pool staking address is accepted as a parameter.
    /// If the value is zero, it may mean the array doesn't contain the address.
    /// Check the address is in the array using the `isPoolActive` getter.
    mapping(address => uint256) public poolIndex;

    /// @dev The pool's index in the array returned by the `getPoolsToBeElected` getter.
    /// Used by the `_deletePoolToBeElected` and `_isPoolToBeElected` functions.
    /// The pool staking address is accepted as a parameter.
    /// If the value is zero, it may mean the array doesn't contain the address.
    /// Check the address is in the array using the `getPoolsToBeElected` getter.
    mapping(address => uint256) public poolToBeElectedIndex;

    /// @dev The pool's index in the array returned by the `getPoolsToBeRemoved` getter.
    /// Used by the `_deletePoolToBeRemoved` function.
    /// The pool staking address is accepted as a parameter.
    /// If the value is zero, it may mean the array doesn't contain the address.
    /// Check the address is in the array using the `getPoolsToBeRemoved` getter.
    mapping(address => uint256) public poolToBeRemovedIndex;

    /// @dev The amount of staking tokens/coins currently staked into the specified pool by the specified
    /// staker. Doesn't take into account the ordered amount to be withdrawn (use the
    /// `stakeAmountMinusOrderedWithdraw` instead). The first parameter is the pool staking address,
    /// the second one is the staker address.
    mapping(address => mapping(address => uint256)) public stakeAmount;

    /// @dev The duration period (in blocks) at the end of staking epoch during which
    /// participants are not allowed to stake and withdraw their staking tokens/coins.
    uint256 public stakeWithdrawDisallowPeriod;

    /// @dev The serial number of the current staking epoch.
    uint256 public stakingEpoch;

    /// @dev The duration of a staking epoch in blocks.
    uint256 public stakingEpochDuration;

    /// @dev The number of the first block of the current staking epoch.
    uint256 public stakingEpochStartBlock;

    /// @dev Returns the total amount of staking tokens/coins currently staked into the specified pool.
    /// Doesn't take into account the ordered amounts to be withdrawn (use the
    /// `stakeAmountTotalMinusOrderedWithdraw` instead). The pool staking address is accepted as a parameter.
    mapping(address => uint256) public stakeAmountTotal;

    /// @dev The address of the `ValidatorSet` contract.
    IValidatorSetAuRa public validatorSetContract;

    // ============================================== Constants =======================================================

    /// @dev The max number of candidates (including validators). This limit was determined through stress testing.
    uint256 public constant MAX_CANDIDATES = 3000;

    /// @dev The max number of delegators for one pool. In total there can be
    /// MAX_CANDIDATES * MAX_DELEGATORS_PER_POOL delegators. This value must be
    /// divisible by BlockReward.DELEGATORS_ALIQUOT. The limit was determined through stress testing.
    uint256 public constant MAX_DELEGATORS_PER_POOL = 3000;

    /// @dev Represents an integer value of a staking unit (1 unit = 10**18).
    /// Used by the `_setLikelihood` function to calculate the probability of
    /// a candidate being selected as a validator for each pool.
    uint256 public constant STAKE_UNIT = 1 ether;

    // ================================================ Events ========================================================

    /// @dev Emitted by the `claimOrderedWithdraw` function to signal the staker withdrew the specified
    /// amount of requested tokens/coins from the specified pool during the specified staking epoch.
    /// @param fromPoolStakingAddress The pool from which the `staker` withdrew the `amount`.
    /// @param staker The address of the staker that withdrew the `amount`.
    /// @param stakingEpoch The serial number of the staking epoch during which the claim was made.
    /// @param amount The withdrawal amount.
    event Claimed(
        address indexed fromPoolStakingAddress,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount
    );

    /// @dev Emitted by the `stake` function to signal the staker placed a stake of the specified
    /// amount for the specified pool during the specified staking epoch.
    /// @param toPoolStakingAddress The pool in which the `staker` placed the stake.
    /// @param staker The address of the staker that placed the stake.
    /// @param stakingEpoch The serial number of the staking epoch during which the stake was made.
    /// @param amount The stake amount.
    event Staked(
        address indexed toPoolStakingAddress,
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
    /// @param amount The stake amount.
    event StakeMoved(
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
    event WithdrawalOrdered(
        address indexed fromPoolStakingAddress,
        address indexed staker,
        uint256 indexed stakingEpoch,
        int256 amount
    );

    /// @dev Emitted by the `withdraw` function to signal the staker withdrew the specified
    /// amount of a stake from the specified pool during the specified staking epoch.
    /// @param fromPoolStakingAddress The pool from which the `staker` withdrew the `amount`.
    /// @param staker The address of staker that withdrew the `amount`.
    /// @param stakingEpoch The serial number of the staking epoch during which the withdrawal was made.
    /// @param amount The withdrawal amount.
    event Withdrawn(
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

    /// @dev Ensures the caller is the BlockReward contract address
    /// (EternalStorageProxy proxy contract for BlockReward).
    modifier onlyBlockRewardContract() {
        require(msg.sender == validatorSetContract.blockRewardContract());
        _;
    }

    /// @dev Ensures the `initialize` function was called before.
    modifier onlyInitialized {
        require(isInitialized());
        _;
    }

    /// @dev Ensures the caller is the ValidatorSet contract address
    /// (EternalStorageProxy proxy contract for ValidatorSet).
    modifier onlyValidatorSetContract() {
        require(msg.sender == address(validatorSetContract));
        _;
    }

    // =============================================== Setters ========================================================

    /// @dev Adds a new candidate's pool to the list of active pools (see the `getPools` getter) and
    /// moves the specified amount of staking tokens from the candidate's staking address to the candidate's pool.
    /// A participant calls this function using their staking address when they want to create a pool.
    /// This is a wrapper for the `stake` function.
    /// @param _amount The amount of tokens to be staked.
    /// @param _miningAddress The mining address of the candidate. The mining address is bound to the staking address
    /// (msg.sender). This address cannot be equal to `msg.sender`.
    function addPool(uint256 _amount, address _miningAddress) external gasPriceIsValid onlyInitialized {
        address stakingAddress = msg.sender;
        validatorSetContract.setStakingAddress(_miningAddress, stakingAddress);
        _stake(stakingAddress, _amount);
    }

    /// @dev Adds a new candidate's pool to the list of active pools (see the `getPools` getter) and
    /// moves the specified amount of staking coins from the candidate's staking address to the candidate's pool.
    /// A participant calls this function using their staking address when they want to create a pool.
    /// This is a wrapper for the `stake` function.
    /// @param _miningAddress The mining address of the candidate. The mining address is bound to the staking address
    /// (msg.sender). This address cannot be equal to `msg.sender`.
    function addPoolNative(address _miningAddress) external gasPriceIsValid onlyInitialized payable {
        address stakingAddress = msg.sender;
        validatorSetContract.setStakingAddress(_miningAddress, stakingAddress);
        _stake(stakingAddress, msg.value);
    }

    /// @dev Adds the `unremovable validator` to either the `poolsToBeElected` or the `poolsToBeRemoved` array
    /// depending on their own stake in their own pool when they become removable. This allows the
    /// `ValidatorSet._newValidatorSet` function to recognize the unremovable validator as a regular removable pool.
    /// Called by the `ValidatorSet.clearUnremovableValidator` function.
    /// @param _unremovableStakingAddress The staking address of the unremovable validator.
    function clearUnremovableValidator(address _unremovableStakingAddress) external onlyValidatorSetContract {
        require(_unremovableStakingAddress != address(0));
        if (stakeAmountMinusOrderedWithdraw(_unremovableStakingAddress, _unremovableStakingAddress) != 0) {
            _addPoolToBeElected(_unremovableStakingAddress);
            _setLikelihood(_unremovableStakingAddress);
        } else {
            _addPoolToBeRemoved(_unremovableStakingAddress);
        }
    }

    /// @dev Increments the serial number of the current staking epoch. Called by the `ValidatorSet._newValidatorSet` at
    /// the last block of the finished staking epoch.
    function incrementStakingEpoch() external onlyValidatorSetContract {
        stakingEpoch++;
    }

    /// @dev Initializes the network parameters.
    /// Can only be called by the constructor of the `InitializerAuRa` contract or owner.
    /// @param _validatorSetContract The address of the `ValidatorSetAuRa` contract.
    /// @param _initialStakingAddresses The array of initial validators' staking addresses.
    /// @param _delegatorMinStake The minimum allowed amount of delegator stake in STAKE_UNITs.
    /// @param _candidateMinStake The minimum allowed amount of candidate/validator stake in STAKE_UNITs.
    /// @param _stakingEpochDuration The duration of a staking epoch in blocks
    /// (e.g., 120954 = 1 week for 5-seconds blocks in AuRa).
    /// @param _stakingEpochStartBlock The number of the first block of initial staking epoch
    /// (must be zero if the network is starting from genesis block).
    /// @param _stakeWithdrawDisallowPeriod The duration period (in blocks) at the end of a staking epoch
    /// during which participants cannot stake or withdraw their staking tokens/coins
    /// (e.g., 4320 = 6 hours for 5-seconds blocks in AuRa).
    /// @param _erc20Restricted Defines whether this staking contract restricts using ERC20/677 contract.
    /// If it's set to `true`, native staking coins are used instead of ERC staking tokens.
    function initialize(
        address _validatorSetContract,
        address[] calldata _initialStakingAddresses,
        uint256 _delegatorMinStake,
        uint256 _candidateMinStake,
        uint256 _stakingEpochDuration,
        uint256 _stakingEpochStartBlock,
        uint256 _stakeWithdrawDisallowPeriod,
        bool _erc20Restricted
    ) external {
        require(_stakingEpochDuration != 0);
        require(_stakingEpochDuration > _stakeWithdrawDisallowPeriod);
        IValidatorSetAuRa validatorSet = IValidatorSetAuRa(_validatorSetContract);
        IBlockRewardAuRa blockReward = IBlockRewardAuRa(validatorSet.blockRewardContract());
        require(_stakingEpochDuration >= validatorSet.MAX_VALIDATORS() * blockReward.DELEGATORS_ALIQUOT() * 2 + 1);
        require(_stakeWithdrawDisallowPeriod != 0);
        _initialize(
            _validatorSetContract,
            _initialStakingAddresses,
            _delegatorMinStake,
            _candidateMinStake,
            _erc20Restricted
        );
        stakingEpochDuration = _stakingEpochDuration;
        stakeWithdrawDisallowPeriod = _stakeWithdrawDisallowPeriod;
        stakingEpochStartBlock = _stakingEpochStartBlock;
    }

    /// @dev Removes a specified pool from the `pools` array (a list of active pools which can be retrieved by the
    /// `getPools` getter). Called by the `ValidatorSet._removeMaliciousValidator` or
    /// the `ValidatorSet._newValidatorSet` function when a pool must be removed by the algorithm.
    /// @param _stakingAddress The staking address of the pool to be removed.
    function removePool(address _stakingAddress) external onlyValidatorSetContract {
        _removePool(_stakingAddress);
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
        emit StakeMoved(_fromPoolStakingAddress, _toPoolStakingAddress, staker, stakingEpoch, _amount);
    }

    /// @dev Moves the specified amount of staking tokens from the staker's address to the staking address of
    /// the specified pool. A staker calls this function when they want to make a stake into a pool.
    /// @param _toPoolStakingAddress The staking address of the pool where the tokens should be staked.
    /// @param _amount The amount of tokens to be staked.
    function stake(address _toPoolStakingAddress, uint256 _amount) external gasPriceIsValid onlyInitialized {
        _stake(_toPoolStakingAddress, _amount);
    }

    /// @dev Receives the staking coins from the staker's address to the staking address of
    /// the specified pool. A staker calls this function when they want to make a stake into a pool.
    /// @param _toPoolStakingAddress The staking address of the pool where the coins should be staked.
    function stakeNative(address _toPoolStakingAddress) external gasPriceIsValid onlyInitialized payable {
        _stake(_toPoolStakingAddress, msg.value);
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
        if (erc20TokenContract != IERC20Minting(0)) {
            erc20TokenContract.transfer(staker, _amount);
        } else {
            require(erc20Restricted);
            staker.transfer(_amount);
        }
        emit Withdrawn(_fromPoolStakingAddress, staker, stakingEpoch, _amount);
    }

    /// @dev Orders a token/coin withdrawal from the staking address of the specified pool to the
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
        require(_isWithdrawAllowed(validatorSetContract.miningByStakingAddress(_poolStakingAddress)));

        address staker = msg.sender;

        // How much can `staker` order for withdrawal from `_poolStakingAddress` at the moment?
        require(_amount < 0 || uint256(_amount) <= maxWithdrawOrderAllowed(_poolStakingAddress, staker));

        uint256 alreadyOrderedAmount = orderedWithdrawAmount[_poolStakingAddress][staker];

        require(_amount > 0 || uint256(-_amount) <= alreadyOrderedAmount);

        uint256 newOrderedAmount;
        if (_amount > 0) {
            newOrderedAmount = alreadyOrderedAmount.add(uint256(_amount));
        } else {
            newOrderedAmount = alreadyOrderedAmount.sub(uint256(-_amount));
        }
        orderedWithdrawAmount[_poolStakingAddress][staker] = newOrderedAmount;

        // The amount to be withdrawn must be the whole staked amount or
        // must not exceed the diff between the entire amount and MIN_STAKE
        uint256 newStakeAmount = stakeAmount[_poolStakingAddress][staker].sub(newOrderedAmount);
        if (staker == _poolStakingAddress) {
            require(newStakeAmount == 0 || newStakeAmount >= candidateMinStake);

            address unremovableStakingAddress = validatorSetContract.unremovableValidator();

            if (_amount > 0) {
                if (newStakeAmount == 0 && _poolStakingAddress != unremovableStakingAddress) {
                    _addPoolToBeRemoved(_poolStakingAddress);
                }
            } else {
                _addPoolActive(_poolStakingAddress, _poolStakingAddress != unremovableStakingAddress);
            }
        } else {
            require(newStakeAmount == 0 || newStakeAmount >= delegatorMinStake);

            if (_amount > 0) {
                if (newStakeAmount == 0) {
                    _removePoolDelegator(_poolStakingAddress, staker);
                }
            } else {
                _addPoolDelegator(_poolStakingAddress, staker);
            }
        }

        // Set total ordered amount for this pool
        alreadyOrderedAmount = orderedWithdrawAmountTotal[_poolStakingAddress];
        if (_amount > 0) {
            newOrderedAmount = alreadyOrderedAmount.add(uint256(_amount));
        } else {
            newOrderedAmount = alreadyOrderedAmount.sub(uint256(-_amount));
        }
        orderedWithdrawAmountTotal[_poolStakingAddress] = newOrderedAmount;

        uint256 epoch = stakingEpoch;

        if (_amount > 0) {
            orderWithdrawEpoch[_poolStakingAddress][staker] = epoch;
        }

        _setLikelihood(_poolStakingAddress);

        emit WithdrawalOrdered(_poolStakingAddress, staker, epoch, _amount);
    }

    /// @dev Withdraws the staking tokens/coins from the specified pool ordered during the previous staking epochs with
    /// the `orderWithdraw` function. The ordered amount can be retrieved by the `orderedWithdrawAmount` getter.
    /// @param _poolStakingAddress The staking address of the pool from which the ordered tokens/coins are withdrawn.
    function claimOrderedWithdraw(address _poolStakingAddress) external gasPriceIsValid onlyInitialized {
        uint256 epoch = stakingEpoch;
        address payable staker = msg.sender;

        require(_poolStakingAddress != address(0));
        require(epoch > orderWithdrawEpoch[_poolStakingAddress][staker]);
        require(_isWithdrawAllowed(validatorSetContract.miningByStakingAddress(_poolStakingAddress)));

        uint256 claimAmount = orderedWithdrawAmount[_poolStakingAddress][staker];
        require(claimAmount != 0);

        uint256 resultingStakeAmount = stakeAmount[_poolStakingAddress][staker].sub(claimAmount);

        orderedWithdrawAmount[_poolStakingAddress][staker] = 0;
        orderedWithdrawAmountTotal[_poolStakingAddress] =
            orderedWithdrawAmountTotal[_poolStakingAddress].sub(claimAmount);
        stakeAmount[_poolStakingAddress][staker] = resultingStakeAmount;
        stakeAmountTotal[_poolStakingAddress] = stakeAmountTotal[_poolStakingAddress].sub(claimAmount);

        if (resultingStakeAmount == 0) {
            _withdrawCheckPool(_poolStakingAddress, staker);
        }

        _setLikelihood(_poolStakingAddress);

        if (erc20TokenContract != IERC20Minting(0)) {
            erc20TokenContract.transfer(staker, claimAmount);
        } else {
            require(erc20Restricted);
            staker.transfer(claimAmount);
        }

        emit Claimed(_poolStakingAddress, staker, epoch, claimAmount);
    }

    /// @dev Sets (updates) the address of the ERC20/ERC677 staking token contract. Can only be called by the `owner`.
    /// Cannot be called if there was at least one stake in native coins before.
    /// @param _erc20TokenContract The address of the contract.
    function setErc20TokenContract(IERC20Minting _erc20TokenContract) external onlyOwner onlyInitialized {
        require(_erc20TokenContract != IERC20Minting(0));
        require(_erc20TokenContract.balanceOf(address(this)) == 0);
        require(!erc20Restricted);
        erc20TokenContract = _erc20TokenContract;
    }

    /// @dev Sets (updates) the limit of the minimum candidate stake (CANDIDATE_MIN_STAKE).
    /// Can only be called by the `owner`.
    /// @param _minStake The value of a new limit in STAKE_UNITs.
    function setCandidateMinStake(uint256 _minStake) external onlyOwner onlyInitialized {
        _setCandidateMinStake(_minStake);
    }

    /// @dev Sets (updates) the limit of minimum delegator stake (DELEGATOR_MIN_STAKE).
    /// Can only be called by the `owner`.
    /// @param _minStake The value of a new limit in STAKE_UNITs.
    function setDelegatorMinStake(uint256 _minStake) external onlyOwner onlyInitialized {
        _setDelegatorMinStake(_minStake);
    }

    // =============================================== Getters ========================================================

    /// @dev Returns an array of the current active pools (the staking addresses of candidates and validators).
    /// The size of the array cannot exceed MAX_CANDIDATES. A pool can be added to this array with the `_addPoolActive`
    /// function which is called by the `stake` or `orderWithdraw` function. A pool is considered active
    /// if its address has at least the minimum stake and this stake is not ordered to be withdrawn.
    function getPools() external view returns(address[] memory) {
        return _pools;
    }

    /// @dev Returns an array of the current inactive pools (the staking addresses of former candidates).
    /// A pool can be added to this array with the `_addPoolInactive` function which is called by `_removePool`.
    /// A pool is considered inactive if it is banned for some reason, if its address has zero stake, or 
    /// if its entire stake is ordered to be withdrawn.
    function getPoolsInactive() external view returns(address[] memory) {
        return _poolsInactive;
    }

    /// @dev Returns the list of probability coefficients of being selected as a validator for each corresponding
    /// address in the `poolsToBeElected` array (see the `getPoolsToBeElected` getter) and a sum of these coefficients.
    /// Used by the `ValidatorSet._newValidatorSet` function when randomly selecting new validators at the last
    /// block of a staking epoch. A pool's coefficient is updated every time any staked amount is changed in this pool
    /// (see the `_setLikelihood` function).
    /// @return `uint256[] likelihoods` - The array of the coefficients. The array length is always equal to the length
    /// of the `poolsToBeElected` array.
    /// `uint256 sum` - The sum of the coefficients.
    function getPoolsLikelihood() external view returns(uint256[] memory likelihoods, uint256 sum) {
        return (_poolsLikelihood, _poolsLikelihoodSum);
    }

    /// @dev Returns the list of pools (their staking addresses) which will participate in a new validator set
    /// selection process in the `ValidatorSet._newValidatorSet` function. This is an array of pools
    /// which will be considered as candidates when forming a new validator set (at the last block of a staking epoch).
    /// This array is kept updated by the `_addPoolToBeElected` and `_deletePoolToBeElected` functions.
    function getPoolsToBeElected() external view returns(address[] memory) {
        return _poolsToBeElected;
    }

    /// @dev Returns the list of pools (their staking addresses) which will be removed by the
    /// `ValidatorSet._newValidatorSet` function from the active `pools` array (at the last block
    /// of a staking epoch). This array is kept updated by the `_addPoolToBeRemoved`
    /// and `_deletePoolToBeRemoved` functions. A pool is added to this array when the pool's address
    /// withdraws all of its own staking tokens from the pool, inactivating the pool.
    function getPoolsToBeRemoved() external view returns(address[] memory) {
        return _poolsToBeRemoved;
    }

    /// @dev Determines whether staking/withdrawal operations are allowed at the moment.
    /// Used by all staking/withdrawal functions.
    function areStakeAndWithdrawAllowed() public view returns(bool) {
        bool isSnapshotting = IBlockRewardAuRa(validatorSetContract.blockRewardContract()).isSnapshotting();
        uint256 currentBlock = _getCurrentBlockNumber();
        uint256 allowedDuration = stakingEpochDuration - stakeWithdrawDisallowPeriod;
        return !isSnapshotting && currentBlock.sub(stakingEpochStartBlock) <= allowedDuration;
    }

    /// @dev Returns a boolean flag indicating if the `initialize` function has been called.
    function isInitialized() public view returns(bool) {
        return validatorSetContract != IValidatorSetAuRa(0);
    }

    /// @dev Returns a flag indicating whether a specified address is in the `pools` array.
    /// See the `getPools` getter.
    /// @param _stakingAddress The staking address of the pool.
    function isPoolActive(address _stakingAddress) public view returns(bool) {
        return _pools.length != 0 && _pools[poolIndex[_stakingAddress]] == _stakingAddress;
    }

    /// @dev Returns the maximum amount which can be withdrawn from the specified pool by the specified staker
    /// at the moment. Used by the `withdraw` function.
    /// @param _poolStakingAddress The pool staking address from which the withdrawal will be made.
    /// @param _staker The staker address that is going to withdraw.
    function maxWithdrawAllowed(address _poolStakingAddress, address _staker) public view returns(uint256) {
        address miningAddress = validatorSetContract.miningByStakingAddress(_poolStakingAddress);

        if (!_isWithdrawAllowed(miningAddress)) {
            return 0;
        }

        uint256 canWithdraw = stakeAmountMinusOrderedWithdraw(_poolStakingAddress, _staker);

        if (!validatorSetContract.isValidator(miningAddress)) {
            // The pool is not an active validator, so the staker can
            // only withdraw staked amount minus already ordered amount
            return canWithdraw;
        }

        // The pool is an active validator, so the staker can only
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

        if (!_isWithdrawAllowed(miningAddress)) {
            return 0;
        }

        if (!validatorSetContract.isValidator(miningAddress)) {
            // If the pool is a candidate (not a validator), no one can order
            // withdrawal from the `_poolStakingAddress`, but anyone can withdraw
            // immediately (see the `maxWithdrawAllowed` getter)
            return 0;
        }

        // If the pool is an active validator, the staker can order withdrawal
        // up to their total staking amount minus an already ordered amount
        // minus an amount staked during the current staking epoch
        return stakeAmountMinusOrderedWithdraw(
            _poolStakingAddress,
            _staker
        ).sub(stakeAmountByCurrentEpoch(
            _poolStakingAddress,
            _staker
        ));
    }

    /// @dev Prevents sending tokens directly to the `Staking` contract address
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

    /// @dev Returns the amount of staking tokens/coins currently staked into the specified pool by the specified
    /// staker taking into account the ordered amount to be withdrawn. See also the `stakeAmount` and
    /// `orderedWithdrawAmount`.
    /// @param _poolStakingAddress The pool staking address.
    /// @param _staker The staker's address.
    function stakeAmountMinusOrderedWithdraw(
        address _poolStakingAddress,
        address _staker
    ) public view returns(uint256) {
        uint256 amount = stakeAmount[_poolStakingAddress][_staker];
        uint256 orderedAmount = orderedWithdrawAmount[_poolStakingAddress][_staker];
        return amount >= orderedAmount ? amount - orderedAmount : 0;
    }

    /// @dev Returns the total amount of staking tokens/coins currently staked into the specified pool taking into
    /// account the ordered amounts to be withdrawn. See also the `stakeAmountTotal` and `orderedWithdrawAmountTotal`
    /// getters.
    /// @param _poolStakingAddress The pool staking address.
    function stakeAmountTotalMinusOrderedWithdraw(address _poolStakingAddress) public view returns(uint256) {
        uint256 amount = stakeAmountTotal[_poolStakingAddress];
        uint256 orderedAmount = orderedWithdrawAmountTotal[_poolStakingAddress];
        return amount >= orderedAmount ? amount - orderedAmount : 0;
    }

    /// @dev Returns the number of the last block of the current staking epoch.
    function stakingEpochEndBlock() public view returns(uint256) {
        uint256 startBlock = stakingEpochStartBlock;
        return startBlock + stakingEpochDuration - (startBlock == 0 ? 0 : 1);
    }

    // =============================================== Private ========================================================

    /// @dev Adds the specified staking address to the array of active pools returned by
    /// the `getPools` getter. Used by the `stake` and `orderWithdraw` functions.
    /// @param _stakingAddress The pool added to the array of active pools.
    /// @param _toBeElected The boolean flag which defines whether the specified address should be
    /// added simultaneously to the `poolsToBeElected` array. See the `getPoolsToBeElected` getter.
    function _addPoolActive(address _stakingAddress, bool _toBeElected) internal {
        if (!isPoolActive(_stakingAddress)) {
            poolIndex[_stakingAddress] = _pools.length;
            _pools.push(_stakingAddress);
            require(_pools.length <= _getMaxCandidates());
        }
        _removePoolInactive(_stakingAddress);
        if (_toBeElected) {
            _addPoolToBeElected(_stakingAddress);
        }
    }

    /// @dev Adds the specified staking address to the array of inactive pools returned by
    /// the `getPoolsInactive` getter. Used by the `_removePool` function.
    /// @param _stakingAddress The pool added to the array of inactive pools.
    function _addPoolInactive(address _stakingAddress) internal {
        uint256 index = poolInactiveIndex[_stakingAddress];
        if (index >= _poolsInactive.length || _poolsInactive[index] != _stakingAddress) {
            poolInactiveIndex[_stakingAddress] = _poolsInactive.length;
            _poolsInactive.push(_stakingAddress);
        }
    }

    /// @dev Adds the specified staking address to the array of pools returned by the `getPoolsToBeElected`
    /// getter. Used by the `_addPoolActive` function. See the `getPoolsToBeElected` getter.
    /// @param _stakingAddress The pool added to the `poolsToBeElected` array.
    function _addPoolToBeElected(address _stakingAddress) internal {
        uint256 index = poolToBeElectedIndex[_stakingAddress];
        if (index >= _poolsToBeElected.length || _poolsToBeElected[index] != _stakingAddress) {
            poolToBeElectedIndex[_stakingAddress] = _poolsToBeElected.length;
            _poolsToBeElected.push(_stakingAddress);
            _poolsLikelihood.push(0);
        }
        _deletePoolToBeRemoved(_stakingAddress);
    }

    /// @dev Adds the specified staking address to the array of pools returned by the `getPoolsToBeRemoved`
    /// getter. Used by withdrawal functions. See the `getPoolsToBeRemoved` getter.
    /// @param _stakingAddress The pool added to the `poolsToBeRemoved` array.
    function _addPoolToBeRemoved(address _stakingAddress) internal {
        uint256 index = poolToBeRemovedIndex[_stakingAddress];
        if (index >= _poolsToBeRemoved.length || _poolsToBeRemoved[index] != _stakingAddress) {
            poolToBeRemovedIndex[_stakingAddress] = _poolsToBeRemoved.length;
            _poolsToBeRemoved.push(_stakingAddress);
        }
        _deletePoolToBeElected(_stakingAddress);
    }

    /// @dev Deletes the specified staking address from the array of pools returned by the
    /// `getPoolsToBeElected` getter. Used by the `_addPoolToBeRemoved` and `_removePool` functions.
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
            _poolsToBeElected[indexToDelete] = _poolsToBeElected[_poolsToBeElected.length - 1];
            _poolsLikelihood[indexToDelete] = _poolsLikelihood[_poolsToBeElected.length - 1];
            poolToBeElectedIndex[_poolsToBeElected[indexToDelete]] = indexToDelete;
            poolToBeElectedIndex[_stakingAddress] = 0;
            _poolsToBeElected.length--;
            _poolsLikelihood.length--;
        }
    }

    /// @dev Deletes the specified staking address from the array of pools returned by the
    /// `getPoolsToBeRemoved` getter. Used by the `_addPoolToBeElected` and `_removePool` functions.
    /// See the `getPoolsToBeRemoved` getter.
    /// @param _stakingAddress The pool deleted from the `poolsToBeRemoved` array.
    function _deletePoolToBeRemoved(address _stakingAddress) internal {
        uint256 indexToDelete = poolToBeRemovedIndex[_stakingAddress];
        if (_poolsToBeRemoved.length > indexToDelete && _poolsToBeRemoved[indexToDelete] == _stakingAddress) {
            _poolsToBeRemoved[indexToDelete] = _poolsToBeRemoved[_poolsToBeRemoved.length - 1];
            poolToBeRemovedIndex[_poolsToBeRemoved[indexToDelete]] = indexToDelete;
            poolToBeRemovedIndex[_stakingAddress] = 0;
            _poolsToBeRemoved.length--;
        }
    }

    /// @dev Removes the specified staking address from the array of active pools returned by
    /// the `getPools` getter. Used by the `removePool` and withdrawal functions.
    /// @param _stakingAddress The pool removed from the array of active pools.
    function _removePool(address _stakingAddress) internal {
        uint256 indexToRemove = poolIndex[_stakingAddress];
        if (_pools.length > indexToRemove && _pools[indexToRemove] == _stakingAddress) {
            _pools[indexToRemove] = _pools[_pools.length - 1];
            poolIndex[_pools[indexToRemove]] = indexToRemove;
            poolIndex[_stakingAddress] = 0;
            _pools.length--;
        }
        if (stakeAmountTotal[_stakingAddress] != 0) {
            _addPoolInactive(_stakingAddress);
        } else {
            _removePoolInactive(_stakingAddress);
        }
        _deletePoolToBeElected(_stakingAddress);
        _deletePoolToBeRemoved(_stakingAddress);
    }

    /// @dev Removes the specified staking address from the array of inactive pools returned by
    /// the `getPoolsInactive` getter. Used by the `_addPoolActive` and `_removePool` functions.
    /// @param _stakingAddress The pool removed from the array of inactive pools.
    function _removePoolInactive(address _stakingAddress) internal {
        uint256 indexToRemove = poolInactiveIndex[_stakingAddress];
        if (_poolsInactive.length > indexToRemove && _poolsInactive[indexToRemove] == _stakingAddress) {
            _poolsInactive[indexToRemove] = _poolsInactive[_poolsInactive.length - 1];
            poolInactiveIndex[_poolsInactive[indexToRemove]] = indexToRemove;
            poolInactiveIndex[_stakingAddress] = 0;
            _poolsInactive.length--;
        }
    }

    /// @dev Initializes the network parameters. Used by the `initialize` function.
    /// @param _validatorSetContract The address of the `ValidatorSet` contract.
    /// @param _initialStakingAddresses The array of initial validators' staking addresses.
    /// @param _delegatorMinStake The minimum allowed amount of delegator stake in STAKE_UNITs.
    /// @param _candidateMinStake The minimum allowed amount of candidate/validator stake in STAKE_UNITs.
    /// @param _erc20Restricted Defines whether this staking contract restricts using ERC20/677 contract.
    /// If it's set to `true`, native staking coins are used instead of ERC staking tokens.
    function _initialize(
        address _validatorSetContract,
        address[] memory _initialStakingAddresses,
        uint256 _delegatorMinStake,
        uint256 _candidateMinStake,
        bool _erc20Restricted
    ) internal {
        require(_getCurrentBlockNumber() == 0 || msg.sender == _admin());
        require(!isInitialized()); // initialization can only be done once
        require(_validatorSetContract != address(0));
        require(_initialStakingAddresses.length > 0);
        require(_delegatorMinStake != 0);
        require(_candidateMinStake != 0);

        validatorSetContract = IValidatorSetAuRa(_validatorSetContract);

        IBlockRewardAuRa blockRewardContract = IBlockRewardAuRa(
            validatorSetContract.blockRewardContract()
        );
        require(MAX_DELEGATORS_PER_POOL % blockRewardContract.DELEGATORS_ALIQUOT() == 0);

        address unremovableStakingAddress = validatorSetContract.unremovableValidator();

        for (uint256 i = 0; i < _initialStakingAddresses.length; i++) {
            require(_initialStakingAddresses[i] != address(0));
            _addPoolActive(_initialStakingAddresses[i], false);
            if (_initialStakingAddresses[i] != unremovableStakingAddress) {
                _addPoolToBeRemoved(_initialStakingAddresses[i]);
            }
        }

        _setDelegatorMinStake(_delegatorMinStake);
        _setCandidateMinStake(_candidateMinStake);

        erc20Restricted = _erc20Restricted;
    }

    /// @dev Adds the specified address to the array of the current active delegators of the specified pool.
    /// Used by the `stake` and `orderWithdraw` functions. See the `poolDelegators` getter.
    /// @param _poolStakingAddress The pool staking address.
    /// @param _delegator The delegator's address.
    function _addPoolDelegator(address _poolStakingAddress, address _delegator) internal {
        address[] storage delegators = _poolDelegators[_poolStakingAddress];
        if (delegators.length == 0 || delegators[poolDelegatorIndex[_poolStakingAddress][_delegator]] != _delegator) {
            poolDelegatorIndex[_poolStakingAddress][_delegator] = delegators.length;
            delegators.push(_delegator);
            require(delegators.length <= MAX_DELEGATORS_PER_POOL);
        }
        _removePoolDelegatorInactive(_poolStakingAddress, _delegator);
    }

    /// @dev Adds the specified address to the array of the current inactive delegators of the specified pool.
    /// Used by the `_removePoolDelegator` function.
    /// @param _poolStakingAddress The pool staking address.
    /// @param _delegator The delegator's address.
    function _addPoolDelegatorInactive(address _poolStakingAddress, address _delegator) internal {
        address[] storage delegators = _poolDelegatorsInactive[_poolStakingAddress];
        if (
            delegators.length == 0 ||
            delegators[poolDelegatorInactiveIndex[_poolStakingAddress][_delegator]] != _delegator
        ) {
            poolDelegatorInactiveIndex[_poolStakingAddress][_delegator] = delegators.length;
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
        if (delegators.length != 0 && delegators[indexToRemove] == _delegator) {
            delegators[indexToRemove] = delegators[delegators.length - 1];
            poolDelegatorIndex[_poolStakingAddress][delegators[indexToRemove]] = indexToRemove;
            poolDelegatorIndex[_poolStakingAddress][_delegator] = 0;
            delegators.length--;
        }
        if (stakeAmount[_poolStakingAddress][_delegator] != 0) {
            _addPoolDelegatorInactive(_poolStakingAddress, _delegator);
        } else {
            _removePoolDelegatorInactive(_poolStakingAddress, _delegator);
        }
    }

    /// @dev Removes the specified address from the array of the inactive delegators of the specified pool.
    /// Used by the `_addPoolDelegator` and `_removePoolDelegator` functions.
    /// @param _poolStakingAddress The pool staking address.
    /// @param _delegator The delegator's address.
    function _removePoolDelegatorInactive(address _poolStakingAddress, address _delegator) internal {
        address[] storage delegators = _poolDelegatorsInactive[_poolStakingAddress];
        uint256 indexToRemove = poolDelegatorInactiveIndex[_poolStakingAddress][_delegator];
        if (delegators.length != 0 && delegators[indexToRemove] == _delegator) {
            delegators[indexToRemove] = delegators[delegators.length - 1];
            poolDelegatorInactiveIndex[_poolStakingAddress][delegators[indexToRemove]] = indexToRemove;
            poolDelegatorInactiveIndex[_poolStakingAddress][_delegator] = 0;
            delegators.length--;
        }
    }

    /// @dev Calculates (updates) the probability of being selected as a validator for the specified pool
    /// and updates the total sum of probability coefficients. See the `getPoolsLikelihood` getter.
    /// Used by the staking and withdrawal functions.
    /// @param _poolStakingAddress The address of the pool for which the probability coefficient must be updated.
    function _setLikelihood(address _poolStakingAddress) internal {
        (bool isToBeElected, uint256 index) = _isPoolToBeElected(_poolStakingAddress);

        if (!isToBeElected) return;

        uint256 oldValue = _poolsLikelihood[index];
        uint256 newValue = stakeAmountTotalMinusOrderedWithdraw(_poolStakingAddress) * 100 / STAKE_UNIT;

        _poolsLikelihood[index] = newValue;

        if (newValue >= oldValue) {
            _poolsLikelihoodSum += newValue - oldValue;
        } else {
            _poolsLikelihoodSum -= oldValue - newValue;
        }
    }

    /// @dev Sets (updates) the limit of the minimum candidate stake (CANDIDATE_MIN_STAKE).
    /// Used by the `_initialize` and `setCandidateMinStake` functions.
    /// @param _minStake The value of a new limit in STAKE_UNITs.
    function _setCandidateMinStake(uint256 _minStake) internal {
        candidateMinStake = _minStake.mul(STAKE_UNIT);
    }

    /// @dev Sets (updates) the limit of the minimum delegator stake (DELEGATOR_MIN_STAKE).
    /// Used by the `_initialize` and `setDelegatorMinStake` functions.
    /// @param _minStake The value of a new limit in STAKE_UNITs.
    function _setDelegatorMinStake(uint256 _minStake) internal {
        delegatorMinStake = _minStake.mul(STAKE_UNIT);
    }

    /// @dev The internal function used by the `stake` and `addPool` functions.
    /// See the `stake` public function for more details.
    /// @param _toPoolStakingAddress The staking address of the pool where the tokens/coins should be staked.
    /// @param _amount The amount of tokens/coins to be staked.
    function _stake(address _toPoolStakingAddress, uint256 _amount) internal {
        if (erc20TokenContract != IERC20Minting(0)) {
            require(msg.value == 0);
        }
        address staker = msg.sender;
        _stake(_toPoolStakingAddress, staker, _amount);
        if (erc20TokenContract != IERC20Minting(0)) {
            erc20TokenContract.stake(staker, _amount);
        } else {
            require(erc20Restricted);
        }
        emit Staked(_toPoolStakingAddress, staker, stakingEpoch, _amount);
    }

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
            require(newStakeAmount >= candidateMinStake); // the staked amount must be at least CANDIDATE_MIN_STAKE
        } else {
            require(newStakeAmount >= delegatorMinStake); // the staked amount must be at least DELEGATOR_MIN_STAKE

            // The delegator cannot stake into the pool of the candidate which hasn't self-staked.
            // Also, that candidate shouldn't want to withdraw all his funds.
            require(stakeAmountMinusOrderedWithdraw(_poolStakingAddress, _poolStakingAddress) != 0);
        }
        stakeAmount[_poolStakingAddress][_staker] = newStakeAmount;
        _stakeAmountByEpoch[_poolStakingAddress][_staker][stakingEpoch] = 
            stakeAmountByCurrentEpoch(_poolStakingAddress, _staker).add(_amount);
        stakeAmountTotal[_poolStakingAddress] = stakeAmountTotal[_poolStakingAddress].add(_amount);

        if (_staker == _poolStakingAddress) { // `staker` makes a stake for himself and becomes a candidate
            // Add `_poolStakingAddress` to the array of pools
            _addPoolActive(_poolStakingAddress, _poolStakingAddress != validatorSetContract.unremovableValidator());
        } else {
            // Add `_staker` to the array of pool's delegators
            _addPoolDelegator(_poolStakingAddress, _staker);
        }

        _setLikelihood(_poolStakingAddress);
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

        uint256 currentStakeAmount = stakeAmount[_poolStakingAddress][_staker];
        uint256 alreadyOrderedAmount = orderedWithdrawAmount[_poolStakingAddress][_staker];
        uint256 resultingStakeAmount = currentStakeAmount.sub(alreadyOrderedAmount).sub(_amount);

        // The amount to be withdrawn must be the whole staked amount or
        // must not exceed the diff between the entire amount and MIN_STAKE
        uint256 minAllowedStake = (_poolStakingAddress == _staker) ? candidateMinStake : delegatorMinStake;
        require(resultingStakeAmount == 0 || resultingStakeAmount >= minAllowedStake);

        stakeAmount[_poolStakingAddress][_staker] = currentStakeAmount.sub(_amount);
        uint256 amountByEpoch = stakeAmountByCurrentEpoch(_poolStakingAddress, _staker);
        _stakeAmountByEpoch[_poolStakingAddress][_staker][stakingEpoch] = 
            amountByEpoch >= _amount ? amountByEpoch - _amount : 0;
        stakeAmountTotal[_poolStakingAddress] = stakeAmountTotal[_poolStakingAddress].sub(_amount);

        if (resultingStakeAmount == 0) {
            _withdrawCheckPool(_poolStakingAddress, _staker);
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
        }
    }

    /// @dev Returns the current block number. Needed mostly for unit tests.
    function _getCurrentBlockNumber() internal view returns(uint256) {
        return block.number;
    }

    /// @dev Returns the max number of candidates (including validators). See the MAX_CANDIDATES constant.
    /// Needed mostly for unit tests.
    function _getMaxCandidates() internal pure returns(uint256) {
        return MAX_CANDIDATES;
    }

    /// @dev Determines if the specified pool is in the `poolsToBeElected` array. See the `getPoolsToBeElected` getter.
    /// Used by the `_setLikelihood` function.
    /// @param _stakingAddress The staking address of the pool.
    /// @return `bool toBeElected` - The boolean flag indicating whether the `_stakingAddress` is in the
    /// `poolsToBeElected` array.
    /// `uint256 index` - The position of the item in the `poolsToBeElected` array if `toBeElected` is `true`.
    function _isPoolToBeElected(address _stakingAddress) internal view returns(bool toBeElected, uint256 index) {
        if (_poolsToBeElected.length != 0) {
            index = poolToBeElectedIndex[_stakingAddress];
            if (_poolsToBeElected[index] == _stakingAddress) {
                return (true, index);
            }
        }
        return (false, 0);
    }

    /// @dev Returns `true` if withdrawal from the pool of the specified validator is allowed at the moment.
    /// Used by all withdrawal functions.
    /// @param _miningAddress The mining address of the validator's pool.
    function _isWithdrawAllowed(address _miningAddress) internal view returns(bool) {
        if (validatorSetContract.isValidatorBanned(_miningAddress)) {
            // No one can withdraw from `_poolStakingAddress` until the ban is expired
            return false;
        }

        if (!areStakeAndWithdrawAllowed()) {
            return false;
        }

        return true;
    }
}
