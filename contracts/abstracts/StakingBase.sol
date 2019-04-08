pragma solidity 0.5.2;

import "../interfaces/IBlockReward.sol";
import "../interfaces/IERC20Minting.sol";
import "../interfaces/IStaking.sol";
import "../interfaces/IValidatorSet.sol";
import "../eternal-storage/OwnedEternalStorage.sol";
import "../libs/SafeMath.sol";


contract StakingBase is OwnedEternalStorage, IStaking {
    using SafeMath for uint256;

    // TODO: add a description for each function

    // ============================================== Constants =======================================================

    // These values must be set before deploy
    uint256 public constant MAX_CANDIDATES = 1500;
    uint256 public constant MAX_DELEGATORS_PER_POOL = 200; // must be divisible by BlockReward.DELEGATORS_ALIQUOT
    uint256 public constant STAKE_UNIT = 1 ether;

    // ================================================ Events ========================================================

    /// @dev Emitted by the `claimOrderedWithdraw` function to signal that the staker withdrew the specified
    /// amount of ordered tokens from the specified pool during the specified staking epoch.
    /// @param fromPoolStakingAddress The pool from which the `staker` withdrew `amount`.
    /// @param staker The address of staker who withdrew `amount`.
    /// @param stakingEpoch The serial number of staking epoch during which the claiming was made.
    /// @param amount The amount of the withdrawal.
    event Claimed(
        address indexed fromPoolStakingAddress,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount
    );

    /// @dev Emitted by the `stake` function to signal that the staker made a stake of the specified
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

    /// @dev Emitted by the `moveStake` function to signal that the staker moved the specified
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

    /// @dev Emitted by the `orderWithdraw` function to signal that the staker ordered the withdrawal of the
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

    /// @dev Emitted by the `withdraw` function to signal that the staker withdrew the specified
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
        require(msg.sender == validatorSetContract().blockRewardContract());
        _;
    }

    modifier onlyValidatorSetContract() {
        require(msg.sender == address(validatorSetContract()));
        _;
    }

    // =============================================== Setters ========================================================

    function clearUnremovableValidator(address _unremovableStakingAddress) external onlyValidatorSetContract {
        require(_unremovableStakingAddress != address(0));
        if (stakeAmountMinusOrderedWithdraw(_unremovableStakingAddress, _unremovableStakingAddress) != 0) {
            _addPoolToBeElected(_unremovableStakingAddress);
            _setLikelihood(_unremovableStakingAddress);
        } else {
            _addPoolToBeRemoved(_unremovableStakingAddress);
        }
    }

    function incrementStakingEpoch() external onlyValidatorSetContract {
        uintStorage[STAKING_EPOCH]++;
    }

    function removePool(address _stakingAddress) external onlyValidatorSetContract {
        _removePool(_stakingAddress);
    }

    function removePool() external gasPriceIsValid {
        IValidatorSet validatorSetContract = validatorSetContract();
        address stakingAddress = msg.sender;
        address miningAddress = validatorSetContract.miningByStakingAddress(stakingAddress);
        // initial validator cannot remove their pool during the initial staking epoch
        require(stakingEpoch() > 0 || !validatorSetContract.isValidator(miningAddress));
        require(stakingAddress != validatorSetContract.unremovableValidator());
        _removePool(stakingAddress);
    }

    /// @dev Moves the tokens from one pool to another.
    /// @param _fromPoolStakingAddress The staking address of the source pool.
    /// @param _toPoolStakingAddress The staking address of the target pool.
    /// @param _amount The amount to be moved.
    function moveStake(
        address _fromPoolStakingAddress,
        address _toPoolStakingAddress,
        uint256 _amount
    ) external gasPriceIsValid {
        require(_fromPoolStakingAddress != _toPoolStakingAddress);
        address staker = msg.sender;
        _withdraw(_fromPoolStakingAddress, staker, _amount);
        _stake(_toPoolStakingAddress, staker, _amount);
        emit StakeMoved(_fromPoolStakingAddress, _toPoolStakingAddress, staker, stakingEpoch(), _amount);
    }

    /// @dev Moves the tokens from staker address to Staking contract address
    /// on the account of staking address of the pool.
    /// @param _toPoolStakingAddress The staking address of the pool.
    /// @param _amount The amount of the stake.
    function stake(address _toPoolStakingAddress, uint256 _amount) external gasPriceIsValid {
        _stake(_toPoolStakingAddress, _amount);
    }

    /// @dev Moves the tokens from Staking contract address (from the account of
    /// staking address of the pool) to staker address.
    /// @param _fromPoolStakingAddress The staking address of the pool.
    /// @param _amount The amount of the withdrawal.
    function withdraw(address _fromPoolStakingAddress, uint256 _amount) external gasPriceIsValid {
        IERC20Minting tokenContract = IERC20Minting(erc20TokenContract());
        require(address(tokenContract) != address(0));
        address staker = msg.sender;
        _withdraw(_fromPoolStakingAddress, staker, _amount);
        tokenContract.withdraw(staker, _amount);
        emit Withdrawn(_fromPoolStakingAddress, staker, stakingEpoch(), _amount);
    }

    /// @dev Makes an order of tokens withdrawal from Staking contract address
    /// (from the account of staking address of the pool) to staker address.
    /// The ordered tokens can be claimed after the current staking epoch.
    /// @param _poolStakingAddress The staking address of the pool.
    /// @param _amount The amount of the withdrawal. Positive value means
    /// that the staker wants to set or increase their withdrawal amount.
    /// Negative value means that the staker wants to decrease their
    /// withdrawal amount which was set before.
    function orderWithdraw(address _poolStakingAddress, int256 _amount) external gasPriceIsValid {
        IValidatorSet validatorSetContract = validatorSetContract();

        require(_poolStakingAddress != address(0));
        require(_amount != 0);
        require(_isWithdrawAllowed(validatorSetContract.miningByStakingAddress(_poolStakingAddress)));

        address staker = msg.sender;

        // How much can `staker` order for withdrawal from `_poolStakingAddress` at the moment?
        require(_amount < 0 || uint256(_amount) <= maxWithdrawOrderAllowed(_poolStakingAddress, staker));

        uint256 alreadyOrderedAmount = orderedWithdrawAmount(_poolStakingAddress, staker);

        require(_amount > 0 || uint256(-_amount) <= alreadyOrderedAmount);

        uint256 newOrderedAmount;
        if (_amount > 0) {
            newOrderedAmount = alreadyOrderedAmount.add(uint256(_amount));
        } else {
            newOrderedAmount = alreadyOrderedAmount.sub(uint256(-_amount));
        }
        _setOrderedWithdrawAmount(_poolStakingAddress, staker, newOrderedAmount);

        // The amount to be withdrawn must be the whole staked amount or
        // must not exceed the diff between the entire amount and MIN_STAKE
        uint256 newStakeAmount = stakeAmount(_poolStakingAddress, staker).sub(newOrderedAmount);
        if (staker == _poolStakingAddress) {
            require(newStakeAmount == 0 || newStakeAmount >= getCandidateMinStake());

            address unremovableStakingAddress = validatorSetContract.unremovableValidator();

            if (_amount > 0) {
                if (newStakeAmount == 0 && _poolStakingAddress != unremovableStakingAddress) {
                    _addPoolToBeRemoved(_poolStakingAddress);
                }
            } else {
                _addPoolActive(_poolStakingAddress, _poolStakingAddress != unremovableStakingAddress);
            }
        } else {
            require(newStakeAmount == 0 || newStakeAmount >= getDelegatorMinStake());

            if (_amount > 0) {
                if (newStakeAmount == 0) {
                    _removePoolDelegator(_poolStakingAddress, staker);
                }
            } else {
                _addPoolDelegator(_poolStakingAddress, staker);
            }
        }

        // Set total ordered amount for this pool
        alreadyOrderedAmount = orderedWithdrawAmountTotal(_poolStakingAddress);
        if (_amount > 0) {
            newOrderedAmount = alreadyOrderedAmount.add(uint256(_amount));
        } else {
            newOrderedAmount = alreadyOrderedAmount.sub(uint256(-_amount));
        }
        _setOrderedWithdrawAmountTotal(_poolStakingAddress, newOrderedAmount);

        uint256 epoch = stakingEpoch();

        if (_amount > 0) {
            _setOrderWithdrawEpoch(_poolStakingAddress, staker, epoch);
        }

        _setLikelihood(_poolStakingAddress);

        emit WithdrawalOrdered(_poolStakingAddress, staker, epoch, _amount);
    }

    /// @dev Withdraws the tokens ordered during the previous staking epochs.
    /// @param _poolStakingAddress The staking address of the pool from which
    /// the ordered tokens are being withdrawn.
    function claimOrderedWithdraw(address _poolStakingAddress) external gasPriceIsValid {
        IERC20Minting tokenContract = IERC20Minting(erc20TokenContract());
        IValidatorSet validatorSetContract = validatorSetContract();
        uint256 epoch = stakingEpoch();
        address staker = msg.sender;

        require(address(tokenContract) != address(0));
        require(_poolStakingAddress != address(0));
        require(epoch > orderWithdrawEpoch(_poolStakingAddress, staker));
        require(_isWithdrawAllowed(validatorSetContract.miningByStakingAddress(_poolStakingAddress)));

        uint256 claimAmount = orderedWithdrawAmount(_poolStakingAddress, staker);
        require(claimAmount != 0);

        uint256 resultingStakeAmount = stakeAmount(_poolStakingAddress, staker).sub(claimAmount);

        _setOrderedWithdrawAmount(_poolStakingAddress, staker, 0);
        _setOrderedWithdrawAmountTotal(
            _poolStakingAddress,
            orderedWithdrawAmountTotal(_poolStakingAddress).sub(claimAmount)
        );
        _setStakeAmount(_poolStakingAddress, staker, resultingStakeAmount);
        _setStakeAmountTotal(_poolStakingAddress, stakeAmountTotal(_poolStakingAddress).sub(claimAmount));

        if (resultingStakeAmount == 0) {
            _withdrawCheckPool(_poolStakingAddress, staker);
        }

        _setLikelihood(_poolStakingAddress);

        tokenContract.withdraw(staker, claimAmount);

        emit Claimed(_poolStakingAddress, staker, epoch, claimAmount);
    }

    function setErc20TokenContract(address _erc20TokenContract) external onlyOwner {
        require(_erc20TokenContract != address(0));
        addressStorage[ERC20_TOKEN_CONTRACT] = _erc20TokenContract;
    }

    function setCandidateMinStake(uint256 _minStake) external onlyOwner {
        _setCandidateMinStake(_minStake);
    }

    function setDelegatorMinStake(uint256 _minStake) external onlyOwner {
        _setDelegatorMinStake(_minStake);
    }

    // =============================================== Getters ========================================================

    // Returns the list of current pools (candidates and validators)
    // (their staking addresses)
    function getPools() external view returns(address[] memory) {
        return addressArrayStorage[POOLS];
    }

    // Returns the list of pools which are inactive or banned
    // (their staking addresses)
    function getPoolsInactive() external view returns(address[] memory) {
        return addressArrayStorage[POOLS_INACTIVE];
    }

    // Returns the list of pool likelihoods
    function getPoolsLikelihood() external view returns(int256[] memory, int256) {
        return (intArrayStorage[POOLS_LIKELIHOOD], intStorage[POOLS_LIKELIHOOD_SUM]);
    }

    // Returns the list of pools to be elected (candidates and validators)
    // (their staking addresses)
    function getPoolsToBeElected() external view returns(address[] memory) {
        return addressArrayStorage[POOLS_TO_BE_ELECTED];
    }

    // Returns the list of pools to be removed (candidates and validators)
    // (their staking addresses)
    function getPoolsToBeRemoved() external view returns(address[] memory) {
        return addressArrayStorage[POOLS_TO_BE_REMOVED];
    }

    function areStakeAndWithdrawAllowed() public view returns(bool);

    function erc20TokenContract() public view returns(address) {
        return addressStorage[ERC20_TOKEN_CONTRACT];
    }

    function getCandidateMinStake() public view returns(uint256) {
        return uintStorage[CANDIDATE_MIN_STAKE];
    }

    function getDelegatorMinStake() public view returns(uint256) {
        return uintStorage[DELEGATOR_MIN_STAKE];
    }

    // Returns the flag whether the address is in the `pools` array
    function isPoolActive(address _stakingAddress) public view returns(bool) {
        address[] storage pools = addressArrayStorage[POOLS];
        return pools.length != 0 && pools[poolIndex(_stakingAddress)] == _stakingAddress;
    }

    function maxWithdrawAllowed(address _poolStakingAddress, address _staker) public view returns(uint256) {
        IValidatorSet validatorSetContract = validatorSetContract();
        address miningAddress = validatorSetContract.miningByStakingAddress(_poolStakingAddress);

        if (!_isWithdrawAllowed(miningAddress)) {
            return 0;
        }

        uint256 canWithdraw = stakeAmountMinusOrderedWithdraw(_poolStakingAddress, _staker);

        if (!validatorSetContract.isValidator(miningAddress)) {
            // The pool is not an active validator, so the staker can
            // withdraw staked amount minus already ordered amount
            return canWithdraw;
        }

        // The pool is an active validator, so the staker can
        // withdraw staked amount minus already ordered amount
        // but no more than amount staked during the current
        // staking epoch
        uint256 stakedDuringEpoch = stakeAmountByCurrentEpoch(_poolStakingAddress, _staker);

        if (canWithdraw > stakedDuringEpoch) {
            canWithdraw = stakedDuringEpoch;
        }

        return canWithdraw;
    }

    function maxWithdrawOrderAllowed(address _poolStakingAddress, address _staker) public view returns(uint256) {
        IValidatorSet validatorSetContract = validatorSetContract();
        address miningAddress = validatorSetContract.miningByStakingAddress(_poolStakingAddress);

        if (!_isWithdrawAllowed(miningAddress)) {
            return 0;
        }

        if (!validatorSetContract.isValidator(miningAddress)) {
            // If the pool is a candidate (not a validator yet),
            // no one can order withdrawal from `_poolStakingAddress`,
            // but anyone can withdraw immediately
            // (see the `maxWithdrawAllowed()` getter)
            return 0;
        }

        // If the pool is an active validator, the staker can
        // order withdrawal up to their total staking amount
        // minus already ordered amount minus amount staked
        // during the current staking epoch
        return stakeAmountMinusOrderedWithdraw(
            _poolStakingAddress,
            _staker
        ).sub(stakeAmountByCurrentEpoch(
            _poolStakingAddress,
            _staker
        ));
    }

    /// @dev Prevents sending tokens to `Staking` contract address
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

    function orderWithdrawEpoch(address _poolStakingAddress, address _staker) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(ORDER_WITHDRAW_EPOCH, _poolStakingAddress, _staker))];
    }

    function stakeAmountTotal(address _poolStakingAddress) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(STAKE_AMOUNT_TOTAL, _poolStakingAddress))
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

    // Returns delegator's index in `poolDelegatorsInactive` array
    function poolDelegatorInactiveIndex(address _poolStakingAddress, address _delegator) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(POOL_DELEGATOR_INACTIVE_INDEX, _poolStakingAddress, _delegator))
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

    // Returns an index of the pool in the `poolsToBeElected` array
    function poolToBeElectedIndex(address _stakingAddress) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(POOL_TO_BE_ELECTED_INDEX, _stakingAddress))
        ];
    }

    // Returns an index of the pool in the `poolsToBeRemoved` array
    function poolToBeRemovedIndex(address _stakingAddress) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(POOL_TO_BE_REMOVED_INDEX, _stakingAddress))
        ];
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
        return uintStorage[
            keccak256(abi.encode(STAKE_AMOUNT_BY_EPOCH, _poolStakingAddress, _staker, stakingEpoch()))
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

    // Returns the internal serial number of staking epoch
    function stakingEpoch() public view returns(uint256) {
        return uintStorage[STAKING_EPOCH];
    }

    function validatorSetContract() public view returns(IValidatorSet) {
        return IValidatorSet(addressStorage[VALIDATOR_SET_CONTRACT]);
    }

    // =============================================== Private ========================================================

    bytes32 internal constant CANDIDATE_MIN_STAKE = keccak256("candidateMinStake");
    bytes32 internal constant DELEGATOR_MIN_STAKE = keccak256("delegatorMinStake");
    bytes32 internal constant ERC20_TOKEN_CONTRACT = keccak256("erc20TokenContract");
    bytes32 internal constant POOLS = keccak256("pools");
    bytes32 internal constant POOLS_INACTIVE = keccak256("poolsInactive");
    bytes32 internal constant POOLS_LIKELIHOOD = keccak256("poolsLikelihood");
    bytes32 internal constant POOLS_LIKELIHOOD_SUM = keccak256("poolsLikelihoodSum");
    bytes32 internal constant POOLS_TO_BE_ELECTED = keccak256("poolsToBeElected");
    bytes32 internal constant POOLS_TO_BE_REMOVED = keccak256("poolsToBeRemoved");
    bytes32 internal constant STAKING_EPOCH = keccak256("stakingEpoch");
    bytes32 internal constant VALIDATOR_SET_CONTRACT = keccak256("validatorSetContract");

    bytes32 internal constant POOL_DELEGATORS = "poolDelegators";
    bytes32 internal constant POOL_DELEGATORS_INACTIVE = "poolDelegatorsInactive";
    bytes32 internal constant POOL_DELEGATOR_INDEX = "poolDelegatorIndex";
    bytes32 internal constant POOL_DELEGATOR_INACTIVE_INDEX = "poolDelegatorInactiveIndex";
    bytes32 internal constant POOL_INDEX = "poolIndex";
    bytes32 internal constant POOL_INACTIVE_INDEX = "poolInactiveIndex";
    bytes32 internal constant POOL_TO_BE_ELECTED_INDEX = "poolToBeElectedIndex";
    bytes32 internal constant POOL_TO_BE_REMOVED_INDEX = "poolToBeRemovedIndex";
    bytes32 internal constant STAKE_AMOUNT = "stakeAmount";
    bytes32 internal constant STAKE_AMOUNT_BY_EPOCH = "stakeAmountByEpoch";
    bytes32 internal constant STAKE_AMOUNT_TOTAL = "stakeAmountTotal";
    bytes32 internal constant ORDER_WITHDRAW_EPOCH = "orderWithdrawEpoch";
    bytes32 internal constant ORDERED_WITHDRAW_AMOUNT = "orderedWithdrawAmount";
    bytes32 internal constant ORDERED_WITHDRAW_AMOUNT_TOTAL = "orderedWithdrawAmountTotal";

    // Adds `_stakingAddress` to the array of pools
    function _addPoolActive(address _stakingAddress, bool _toBeElected) internal {
        address[] storage pools = addressArrayStorage[POOLS];
        if (!isPoolActive(_stakingAddress)) {
            _setPoolIndex(_stakingAddress, pools.length);
            pools.push(_stakingAddress);
            require(pools.length <= _getMaxCandidates());
        }
        _removePoolInactive(_stakingAddress);
        if (_toBeElected) {
            _addPoolToBeElected(_stakingAddress);
        }
    }

    // Adds `_stakingAddress` to the array of inactive pools
    function _addPoolInactive(address _stakingAddress) internal {
        address[] storage pools = addressArrayStorage[POOLS_INACTIVE];
        if (pools.length == 0 || pools[poolInactiveIndex(_stakingAddress)] != _stakingAddress) {
            _setPoolInactiveIndex(_stakingAddress, pools.length);
            pools.push(_stakingAddress);
        }
    }

    // Adds `_stakingAddress` to the array of pools to be elected by the `newValidatorSet` function
    function _addPoolToBeElected(address _stakingAddress) internal {
        address[] storage pools = addressArrayStorage[POOLS_TO_BE_ELECTED];
        if (pools.length == 0 || pools[poolToBeElectedIndex(_stakingAddress)] != _stakingAddress) {
            _setPoolToBeElectedIndex(_stakingAddress, pools.length);
            pools.push(_stakingAddress);
            intArrayStorage[POOLS_LIKELIHOOD].push(0);
        }
        _deletePoolToBeRemoved(_stakingAddress);
    }

    // Adds `_stakingAddress` to the array of pools to be removed by the `newValidatorSet` function
    function _addPoolToBeRemoved(address _stakingAddress) internal {
        address[] storage pools = addressArrayStorage[POOLS_TO_BE_REMOVED];
        if (pools.length == 0 || pools[poolToBeRemovedIndex(_stakingAddress)] != _stakingAddress) {
            _setPoolToBeRemovedIndex(_stakingAddress, pools.length);
            pools.push(_stakingAddress);
        }
        _deletePoolToBeElected(_stakingAddress);
    }

    // Removes `_stakingAddress` from the array of pools to be elected
    function _deletePoolToBeElected(address _stakingAddress) internal {
        address[] storage pools = addressArrayStorage[POOLS_TO_BE_ELECTED];
        uint256 indexToDelete = poolToBeElectedIndex(_stakingAddress);
        if (pools.length > 0 && pools[indexToDelete] == _stakingAddress) {
            int256[] storage likelihood = intArrayStorage[POOLS_LIKELIHOOD];
            intStorage[POOLS_LIKELIHOOD_SUM] -= likelihood[indexToDelete];
            pools[indexToDelete] = pools[pools.length - 1];
            likelihood[indexToDelete] = likelihood[pools.length - 1];
            _setPoolToBeElectedIndex(pools[indexToDelete], indexToDelete);
            _setPoolToBeElectedIndex(_stakingAddress, 0);
            pools.length--;
            likelihood.length--;
        }
    }

    // Removes `_stakingAddress` from the array of pools to be removed
    function _deletePoolToBeRemoved(address _stakingAddress) internal {
        address[] storage pools = addressArrayStorage[POOLS_TO_BE_REMOVED];
        uint256 indexToDelete = poolToBeRemovedIndex(_stakingAddress);
        if (pools.length > 0 && pools[indexToDelete] == _stakingAddress) {
            pools[indexToDelete] = pools[pools.length - 1];
            _setPoolToBeRemovedIndex(pools[indexToDelete], indexToDelete);
            _setPoolToBeRemovedIndex(_stakingAddress, 0);
            pools.length--;
        }
    }

    // Removes `_stakingAddress` from the array of pools
    function _removePool(address _stakingAddress) internal {
        uint256 indexToRemove = poolIndex(_stakingAddress);
        address[] storage pools = addressArrayStorage[POOLS];
        if (pools.length > 0 && pools[indexToRemove] == _stakingAddress) {
            pools[indexToRemove] = pools[pools.length - 1];
            _setPoolIndex(pools[indexToRemove], indexToRemove);
            _setPoolIndex(_stakingAddress, 0);
            pools.length--;
        }
        if (stakeAmountTotal(_stakingAddress) != 0) {
            _addPoolInactive(_stakingAddress);
        } else {
            _removePoolInactive(_stakingAddress);
        }
        _deletePoolToBeElected(_stakingAddress);
        _deletePoolToBeRemoved(_stakingAddress);
    }

    // Removes `_stakingAddress` from the array of inactive pools
    function _removePoolInactive(address _stakingAddress) internal {
        address[] storage pools = addressArrayStorage[POOLS_INACTIVE];
        uint256 indexToRemove = poolInactiveIndex(_stakingAddress);
        if (pools.length > 0 && pools[indexToRemove] == _stakingAddress) {
            pools[indexToRemove] = pools[pools.length - 1];
            _setPoolInactiveIndex(pools[indexToRemove], indexToRemove);
            _setPoolInactiveIndex(_stakingAddress, 0);
            pools.length--;
        }
    }

    function _initialize(
        address _validatorSetContract,
        address _erc20TokenContract,
        address[] memory _initialStakingAddresses,
        uint256 _delegatorMinStake,
        uint256 _candidateMinStake
    ) internal {
        require(_getCurrentBlockNumber() == 0); // initialization must be done on genesis block
        require(address(validatorSetContract()) == address(0)); // initialization can only be done once
        require(_validatorSetContract != address(0));
        require(_initialStakingAddresses.length > 0);
        require(_delegatorMinStake != 0);
        require(_candidateMinStake != 0);

        IBlockReward blockRewardContract = IBlockReward(IValidatorSet(_validatorSetContract).blockRewardContract());
        require(MAX_DELEGATORS_PER_POOL % blockRewardContract.DELEGATORS_ALIQUOT() == 0);

        addressStorage[VALIDATOR_SET_CONTRACT] = _validatorSetContract;
        addressStorage[ERC20_TOKEN_CONTRACT] = _erc20TokenContract;

        address unremovableStakingAddress = IValidatorSet(_validatorSetContract).unremovableValidator();

        for (uint256 i = 0; i < _initialStakingAddresses.length; i++) {
            require(_initialStakingAddresses[i] != address(0));
            _addPoolActive(_initialStakingAddresses[i], false);
            if (_initialStakingAddresses[i] != unremovableStakingAddress) {
                _addPoolToBeRemoved(_initialStakingAddresses[i]);
            }
        }

        _setDelegatorMinStake(_delegatorMinStake);
        _setCandidateMinStake(_candidateMinStake);
    }

    function _setOrderWithdrawEpoch(address _poolStakingAddress, address _staker, uint256 _stakingEpoch) internal {
        uintStorage[keccak256(abi.encode(ORDER_WITHDRAW_EPOCH, _poolStakingAddress, _staker))] = _stakingEpoch;
    }

    function _setPoolDelegatorIndex(address _poolStakingAddress, address _delegator, uint256 _index) internal {
        uintStorage[keccak256(abi.encode(POOL_DELEGATOR_INDEX, _poolStakingAddress, _delegator))] = _index;
    }

    function _setPoolDelegatorInactiveIndex(address _poolStakingAddress, address _delegator, uint256 _index) internal {
        uintStorage[keccak256(abi.encode(POOL_DELEGATOR_INACTIVE_INDEX, _poolStakingAddress, _delegator))] = _index;
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

    function _setPoolToBeElectedIndex(address _stakingAddress, uint256 _index) internal {
        uintStorage[
            keccak256(abi.encode(POOL_TO_BE_ELECTED_INDEX, _stakingAddress))
        ] = _index;
    }

    function _setPoolToBeRemovedIndex(address _stakingAddress, uint256 _index) internal {
        uintStorage[
            keccak256(abi.encode(POOL_TO_BE_REMOVED_INDEX, _stakingAddress))
        ] = _index;
    }

    // Add `_delegator` to the array of pool's delegators
    function _addPoolDelegator(address _poolStakingAddress, address _delegator) internal {
        address[] storage delegators = addressArrayStorage[
            keccak256(abi.encode(POOL_DELEGATORS, _poolStakingAddress))
        ];
        if (delegators.length == 0 || delegators[poolDelegatorIndex(_poolStakingAddress, _delegator)] != _delegator) {
            _setPoolDelegatorIndex(_poolStakingAddress, _delegator, delegators.length);
            delegators.push(_delegator);
            require(delegators.length <= MAX_DELEGATORS_PER_POOL);
        }
        _removePoolDelegatorInactive(_poolStakingAddress, _delegator);
    }

    // Add `_delegator` to the array of pool's inactive delegators
    function _addPoolDelegatorInactive(address _poolStakingAddress, address _delegator) internal {
        address[] storage delegators = addressArrayStorage[
            keccak256(abi.encode(POOL_DELEGATORS_INACTIVE, _poolStakingAddress))
        ];
        if (
            delegators.length == 0 ||
            delegators[poolDelegatorInactiveIndex(_poolStakingAddress, _delegator)] != _delegator
        ) {
            _setPoolDelegatorInactiveIndex(_poolStakingAddress, _delegator, delegators.length);
            delegators.push(_delegator);
        }
    }

    // Remove `_delegator` from the array of pool's delegators
    function _removePoolDelegator(address _poolStakingAddress, address _delegator) internal {
        address[] storage delegators = addressArrayStorage[
            keccak256(abi.encode(POOL_DELEGATORS, _poolStakingAddress))
        ];
        uint256 indexToRemove = poolDelegatorIndex(_poolStakingAddress, _delegator);
        if (delegators.length != 0 && delegators[indexToRemove] == _delegator) {
            delegators[indexToRemove] = delegators[delegators.length - 1];
            _setPoolDelegatorIndex(_poolStakingAddress, delegators[indexToRemove], indexToRemove);
            _setPoolDelegatorIndex(_poolStakingAddress, _delegator, 0);
            delegators.length--;
        }
        if (stakeAmount(_poolStakingAddress, _delegator) != 0) {
            _addPoolDelegatorInactive(_poolStakingAddress, _delegator);
        } else {
            _removePoolDelegatorInactive(_poolStakingAddress, _delegator);
        }
    }

    // Remove `_delegator` from the array of pool's inactive delegators
    function _removePoolDelegatorInactive(address _poolStakingAddress, address _delegator) internal {
        address[] storage delegators = addressArrayStorage[
            keccak256(abi.encode(POOL_DELEGATORS_INACTIVE, _poolStakingAddress))
        ];
        uint256 indexToRemove = poolDelegatorInactiveIndex(_poolStakingAddress, _delegator);
        if (delegators.length != 0 && delegators[indexToRemove] == _delegator) {
            delegators[indexToRemove] = delegators[delegators.length - 1];
            _setPoolDelegatorInactiveIndex(_poolStakingAddress, delegators[indexToRemove], indexToRemove);
            _setPoolDelegatorInactiveIndex(_poolStakingAddress, _delegator, 0);
            delegators.length--;
        }
    }

    function _setLikelihood(address _poolStakingAddress) internal {
        (bool isToBeElected, uint256 index) = _isPoolToBeElected(_poolStakingAddress);

        if (!isToBeElected) return;

        int256 oldValue = intArrayStorage[POOLS_LIKELIHOOD][index];
        int256 newValue = int256(stakeAmountTotalMinusOrderedWithdraw(_poolStakingAddress) * 100 / STAKE_UNIT);

        intArrayStorage[POOLS_LIKELIHOOD][index] = newValue;
        intStorage[POOLS_LIKELIHOOD_SUM] += newValue - oldValue;
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
            STAKE_AMOUNT_BY_EPOCH, _poolStakingAddress, _staker, stakingEpoch()
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

    function _stake(address _toPoolStakingAddress, uint256 _amount) internal {
        IERC20Minting tokenContract = IERC20Minting(erc20TokenContract());
        require(address(tokenContract) != address(0));
        address staker = msg.sender;
        _stake(_toPoolStakingAddress, staker, _amount);
        tokenContract.stake(staker, _amount);
        emit Staked(_toPoolStakingAddress, staker, stakingEpoch(), _amount);
    }

    function _stake(address _poolStakingAddress, address _staker, uint256 _amount) internal {
        IValidatorSet validatorSet = validatorSetContract();
        address poolMiningAddress = validatorSet.miningByStakingAddress(_poolStakingAddress);

        require(poolMiningAddress != address(0));
        require(_poolStakingAddress != address(0));
        require(_amount != 0);
        require(!validatorSet.isValidatorBanned(poolMiningAddress));
        require(areStakeAndWithdrawAllowed());

        uint256 newStakeAmount = stakeAmount(_poolStakingAddress, _staker).add(_amount);
        if (_staker == _poolStakingAddress) {
            require(newStakeAmount >= getCandidateMinStake()); // the staked amount must be at least CANDIDATE_MIN_STAKE
        } else {
            require(newStakeAmount >= getDelegatorMinStake()); // the staked amount must be at least DELEGATOR_MIN_STAKE

            // The delegator cannot stake into the pool of the candidate which hasn't self-staked.
            // Also, that candidate shouldn't want to withdraw all his funds.
            require(stakeAmountMinusOrderedWithdraw(_poolStakingAddress, _poolStakingAddress) != 0);
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
            _addPoolActive(_poolStakingAddress, _poolStakingAddress != validatorSet.unremovableValidator());
        } else {
            // Add `_staker` to the array of pool's delegators
            _addPoolDelegator(_poolStakingAddress, _staker);
        }

        _setLikelihood(_poolStakingAddress);
    }

    function _withdraw(address _poolStakingAddress, address _staker, uint256 _amount) internal {
        require(_poolStakingAddress != address(0));
        require(_amount != 0);

        // How much can `staker` withdraw from `_poolStakingAddress` at the moment?
        require(_amount <= maxWithdrawAllowed(_poolStakingAddress, _staker));

        uint256 currentStakeAmount = stakeAmount(_poolStakingAddress, _staker);
        uint256 alreadyOrderedAmount = orderedWithdrawAmount(_poolStakingAddress, _staker);
        uint256 resultingStakeAmount = currentStakeAmount.sub(alreadyOrderedAmount).sub(_amount);

        // The amount to be withdrawn must be the whole staked amount or
        // must not exceed the diff between the entire amount and MIN_STAKE
        uint256 minAllowedStake = (_poolStakingAddress == _staker) ? getCandidateMinStake() : getDelegatorMinStake();
        require(resultingStakeAmount == 0 || resultingStakeAmount >= minAllowedStake);

        _setStakeAmount(_poolStakingAddress, _staker, currentStakeAmount.sub(_amount));
        uint256 amountByEpoch = stakeAmountByCurrentEpoch(_poolStakingAddress, _staker);
        _setStakeAmountByCurrentEpoch(
            _poolStakingAddress,
            _staker,
            amountByEpoch >= _amount ? amountByEpoch - _amount : 0
        );
        _setStakeAmountTotal(_poolStakingAddress, stakeAmountTotal(_poolStakingAddress).sub(_amount));

        if (resultingStakeAmount == 0) {
            _withdrawCheckPool(_poolStakingAddress, _staker);
        }

        _setLikelihood(_poolStakingAddress);
    }

    function _withdrawCheckPool(address _poolStakingAddress, address _staker) internal {
        if (_staker == _poolStakingAddress) {
            IValidatorSet validatorSet = validatorSetContract();
            address unremovableStakingAddress = validatorSet.unremovableValidator();

            if (_poolStakingAddress != unremovableStakingAddress) {
                if (validatorSet.isValidator(validatorSet.miningByStakingAddress(_poolStakingAddress))) {
                    _addPoolToBeRemoved(_poolStakingAddress);
                } else {
                    _removePool(_poolStakingAddress);
                }
            }
        } else {
            _removePoolDelegator(_poolStakingAddress, _staker);
        }
    }

    function _getCurrentBlockNumber() internal view returns(uint256) {
        return block.number;
    }

    function _getMaxCandidates() internal pure returns(uint256) {
        return MAX_CANDIDATES;
    }

    function _isPoolToBeElected(address _stakingAddress) internal view returns(bool, uint256) {
        address[] storage pools = addressArrayStorage[POOLS_TO_BE_ELECTED];
        if (pools.length != 0) {
            uint256 index = poolToBeElectedIndex(_stakingAddress);
            if (pools[index] == _stakingAddress) {
                return (true, index);
            }
        }
        return (false, 0);
    }

    function _isWithdrawAllowed(address _miningAddress) internal view returns(bool) {
        if (validatorSetContract().isValidatorBanned(_miningAddress)) {
            // No one can withdraw from `_poolStakingAddress` until the ban is expired
            return false;
        }

        if (!areStakeAndWithdrawAllowed()) {
            return false;
        }

        return true;
    }
}
