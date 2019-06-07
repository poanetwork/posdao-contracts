pragma solidity 0.5.9;

import "../interfaces/IBlockReward.sol";
import "../interfaces/IERC20Minting.sol";
import "../interfaces/IStaking.sol";
import "../interfaces/IValidatorSet.sol";
import "../eternal-storage/OwnedEternalStorage.sol";
import "../libs/SafeMath.sol";


/// @dev The base contract for the StakingAuRa and StakingHBBFT contracts.
contract StakingBase is OwnedEternalStorage, IStaking {
    using SafeMath for uint256;

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
        require(msg.sender == validatorSetContract().blockRewardContract());
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
        require(msg.sender == address(validatorSetContract()));
        _;
    }

    // =============================================== Setters ========================================================

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
        uintStorage[STAKING_EPOCH]++;
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
        IValidatorSet validatorSet = validatorSetContract();
        address stakingAddress = msg.sender;
        address miningAddress = validatorSet.miningByStakingAddress(stakingAddress);
        // initial validator cannot remove their pool during the initial staking epoch
        require(stakingEpoch() > 0 || !validatorSet.isValidator(miningAddress));
        require(stakingAddress != validatorSet.unremovableValidator());
        _removePool(stakingAddress);
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
        emit StakeMoved(_fromPoolStakingAddress, _toPoolStakingAddress, staker, stakingEpoch(), _amount);
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
        IERC20Minting tokenContract = IERC20Minting(erc20TokenContract());
        if (address(tokenContract) != address(0)) {
            tokenContract.withdraw(staker, _amount);
        } else {
            require(boolStorage[ERC20_RESTRICTED]);
            staker.transfer(_amount);
        }
        emit Withdrawn(_fromPoolStakingAddress, staker, stakingEpoch(), _amount);
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

    /// @dev Withdraws the staking tokens/coins from the specified pool ordered during the previous staking epochs with
    /// the `orderWithdraw` function. The ordered amount can be retrieved by the `orderedWithdrawAmount` getter.
    /// @param _poolStakingAddress The staking address of the pool from which the ordered tokens/coins are withdrawn.
    function claimOrderedWithdraw(address _poolStakingAddress) external gasPriceIsValid onlyInitialized {
        IValidatorSet validatorSetContract = validatorSetContract();
        uint256 epoch = stakingEpoch();
        address payable staker = msg.sender;

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

        IERC20Minting tokenContract = IERC20Minting(erc20TokenContract());
        if (address(tokenContract) != address(0)) {
            tokenContract.withdraw(staker, claimAmount);
        } else {
            require(boolStorage[ERC20_RESTRICTED]);
            staker.transfer(claimAmount);
        }

        emit Claimed(_poolStakingAddress, staker, epoch, claimAmount);
    }

    /// @dev Sets (updates) the address of the ERC20/ERC677 staking token contract. Can only be called by the `owner`.
    /// Cannot be called if there was at least one stake in native coins before.
    /// @param _erc20TokenContract The address of the contract.
    function setErc20TokenContract(address _erc20TokenContract) external onlyOwner onlyInitialized {
        require(_erc20TokenContract != address(0));
        require(!boolStorage[ERC20_RESTRICTED]);
        addressStorage[ERC20_TOKEN_CONTRACT] = _erc20TokenContract;
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
        return addressArrayStorage[POOLS];
    }

    /// @dev Returns an array of the current inactive pools (the staking addresses of former candidates).
    /// A pool can be added to this array with the `_addPoolInactive` function which is called by `_removePool`.
    /// A pool is considered inactive if it is banned for some reason, if its address has zero stake, or 
    /// if its entire stake is ordered to be withdrawn.
    function getPoolsInactive() external view returns(address[] memory) {
        return addressArrayStorage[POOLS_INACTIVE];
    }

    /// @dev Returns the list of probability coefficients of being selected as a validator for each corresponding
    /// address in the `poolsToBeElected` array (see the `getPoolsToBeElected` getter) and a sum of these coefficients.
    /// Used by the `ValidatorSet._newValidatorSet` function when randomly selecting new validators at the last
    /// block of a staking epoch. A pool's coefficient is updated every time any staked amount is changed in this pool
    /// (see the `_setLikelihood` function).
    /// @return `int256[] likelihoods` - The array of the coefficients. The array length is always equal to the length
    /// of the `poolsToBeElected` array.
    /// `int256 sum` - The sum of the coefficients.
    function getPoolsLikelihood() external view returns(int256[] memory likelihoods, int256 sum) {
        return (intArrayStorage[POOLS_LIKELIHOOD], intStorage[POOLS_LIKELIHOOD_SUM]);
    }

    /// @dev Returns the list of pools (their staking addresses) which will participate in a new validator set
    /// selection process in the `ValidatorSet._newValidatorSet` function. This is an array of pools
    /// which will be considered as candidates when forming a new validator set (at the last block of a staking epoch).
    /// This array is kept updated by the `_addPoolToBeElected` and `_deletePoolToBeElected` functions.
    function getPoolsToBeElected() external view returns(address[] memory) {
        return addressArrayStorage[POOLS_TO_BE_ELECTED];
    }

    /// @dev Returns the list of pools (their staking addresses) which will be removed by the
    /// `ValidatorSet._newValidatorSet` function from the active `pools` array (at the last block
    /// of a staking epoch). This array is kept updated by the `_addPoolToBeRemoved`
    /// and `_deletePoolToBeRemoved` functions. A pool is added to this array when the pool's address
    /// withdraws all of its own staking tokens from the pool, inactivating the pool.
    function getPoolsToBeRemoved() external view returns(address[] memory) {
        return addressArrayStorage[POOLS_TO_BE_REMOVED];
    }

    /// @dev Returns a boolean flag indicating whether the stake and withdraw operations are allowed
    /// at the moment.
    function areStakeAndWithdrawAllowed() public view returns(bool);

    /// @dev Returns a boolean flag indicating whether this contract restricts
    /// using ERC20/677 contract. If it returns `true`, native staking coins
    /// are used instead of ERC staking tokens.
    function erc20Restricted() public view returns(bool) {
        return boolStorage[ERC20_RESTRICTED];
    }

    /// @dev Returns the address of the ERC20/677 staking token contract.
    function erc20TokenContract() public view returns(address) {
        return addressStorage[ERC20_TOKEN_CONTRACT];
    }

    /// @dev Returns the limit of the minimum candidate stake (CANDIDATE_MIN_STAKE).
    function getCandidateMinStake() public view returns(uint256) {
        return uintStorage[CANDIDATE_MIN_STAKE];
    }

    /// @dev Returns the limit of the minimum delegator stake (DELEGATOR_MIN_STAKE).
    function getDelegatorMinStake() public view returns(uint256) {
        return uintStorage[DELEGATOR_MIN_STAKE];
    }

    /// @dev Returns a boolean flag indicating if the `initialize` function has been called.
    function isInitialized() public view returns(bool) {
        return addressStorage[VALIDATOR_SET_CONTRACT] != address(0);
    }

    /// @dev Returns a flag indicating whether a specified address is in the `pools` array.
    /// See the `getPools` getter.
    /// @param _stakingAddress The staking address of the pool.
    function isPoolActive(address _stakingAddress) public view returns(bool) {
        address[] storage pools = addressArrayStorage[POOLS];
        return pools.length != 0 && pools[poolIndex(_stakingAddress)] == _stakingAddress;
    }

    /// @dev Returns the maximum amount which can be withdrawn from the specified pool by the specified staker
    /// at the moment. Used by the `withdraw` function.
    /// @param _poolStakingAddress The pool staking address from which the withdrawal will be made.
    /// @param _staker The staker address that is going to withdraw.
    function maxWithdrawAllowed(address _poolStakingAddress, address _staker) public view returns(uint256) {
        IValidatorSet validatorSetContract = validatorSetContract();
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
        IValidatorSet validatorSetContract = validatorSetContract();
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
        return false;
    }

    /// @dev Returns the current amount of staking tokens/coins ordered for withdrawal from the specified
    /// pool by the specified staker. Used by the `orderWithdraw` and `claimOrderedWithdraw` functions.
    /// @param _poolStakingAddress The pool staking address from which the amount will be withdrawn.
    /// @param _staker The staker address that ordered the withdrawal.
    function orderedWithdrawAmount(address _poolStakingAddress, address _staker) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(ORDERED_WITHDRAW_AMOUNT, _poolStakingAddress, _staker))];
    }

    /// @dev Returns the current total amount of staking tokens/coins ordered for withdrawal from
    /// the specified pool by all of its stakers.
    /// @param _poolStakingAddress The pool staking address from which the amount will be withdrawn.
    function orderedWithdrawAmountTotal(address _poolStakingAddress) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(ORDERED_WITHDRAW_AMOUNT_TOTAL, _poolStakingAddress))];
    }

    /// @dev Returns the number of the staking epoch during which the specified staker ordered
    /// the latest withdraw from the specified pool. Used by the `claimOrderedWithdraw` function
    /// to allow the ordered amount to be claimed only in future staking epochs.
    /// @param _poolStakingAddress The pool staking address from which the withdrawal will occur.
    /// @param _staker The staker address that ordered the withdrawal.
    function orderWithdrawEpoch(address _poolStakingAddress, address _staker) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(ORDER_WITHDRAW_EPOCH, _poolStakingAddress, _staker))];
    }

    /// @dev Returns the total amount of staking tokens/coins currently staked into the specified pool.
    /// Doesn't take into account the ordered amounts to be withdrawn (use the
    /// `stakeAmountTotalMinusOrderedWithdraw` instead).
    /// @param _poolStakingAddress The pool staking address.
    function stakeAmountTotal(address _poolStakingAddress) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(STAKE_AMOUNT_TOTAL, _poolStakingAddress))];
    }

    /// @dev Returns an array of the current active delegators of the specified pool.
    /// A delegator is considered active if they have staked into the specified
    /// pool and their stake is not ordered to be withdrawn.
    /// @param _poolStakingAddress The pool staking address.
    function poolDelegators(address _poolStakingAddress) public view returns(address[] memory) {
        return addressArrayStorage[keccak256(abi.encode(POOL_DELEGATORS, _poolStakingAddress))];
    }

    /// @dev Returns the delegator's index in the array returned by the `poolDelegators` getter.
    /// Used by the `_removePoolDelegator` function.
    /// @param _poolStakingAddress The pool staking address.
    /// @param _delegator The delegator's address.
    /// @return If the returned value is zero, it may mean the array doesn't contain the delegator.
    /// Check if the delegator is in the array using the `poolDelegators` getter.
    function poolDelegatorIndex(address _poolStakingAddress, address _delegator) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(POOL_DELEGATOR_INDEX, _poolStakingAddress, _delegator))];
    }

    /// @dev Returns the delegator's index in the `poolDelegatorsInactive` array.
    /// Used by the `_removePoolDelegatorInactive` function.
    /// A delegator is considered inactive if they have withdrawn all their tokens from
    /// the specified pool or their entire stake is ordered to be withdrawn.
    /// @param _poolStakingAddress The pool staking address for which the inactive delegator's index is returned.
    /// @param _delegator The delegator address.
    function poolDelegatorInactiveIndex(address _poolStakingAddress, address _delegator) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(POOL_DELEGATOR_INACTIVE_INDEX, _poolStakingAddress, _delegator))];
    }

    /// @dev Returns the pool's index in the array returned by the `getPools` getter.
    /// Used by the `_removePool` function.
    /// @param _stakingAddress The pool staking address.
    /// @return If the returned value is zero, it may mean the array doesn't contain the address.
    /// Check the address is in the array using the `isPoolActive` getter.
    function poolIndex(address _stakingAddress) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(POOL_INDEX, _stakingAddress))];
    }

    /// @dev Returns the pool's index in the array returned by the `getPoolsInactive` getter.
    /// Used by the `_removePoolInactive` function.
    /// @param _stakingAddress The pool staking address.
    function poolInactiveIndex(address _stakingAddress) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(POOL_INACTIVE_INDEX, _stakingAddress))];
    }

    /// @dev Returns the pool's index in the array returned by the `getPoolsToBeElected` getter.
    /// Used by the `_deletePoolToBeElected` and `_isPoolToBeElected` functions.
    /// @param _stakingAddress The pool staking address.
    /// @return If the returned value is zero, it may mean the array doesn't contain the address.
    /// Check the address is in the array using the `getPoolsToBeElected` getter.
    function poolToBeElectedIndex(address _stakingAddress) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(POOL_TO_BE_ELECTED_INDEX, _stakingAddress))];
    }

    /// @dev Returns the pool's index in the array returned by the `getPoolsToBeRemoved` getter.
    /// Used by the `_deletePoolToBeRemoved` function.
    /// @param _stakingAddress The pool staking address.
    /// @return If the returned value is zero, it may mean the array doesn't contain the address.
    /// Check the address is in the array using the `getPoolsToBeRemoved` getter.
    function poolToBeRemovedIndex(address _stakingAddress) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(POOL_TO_BE_REMOVED_INDEX, _stakingAddress))];
    }

    /// @dev Returns the amount of staking tokens/coins currently staked into the specified pool by the specified
    /// staker. Doesn't take into account the ordered amount to be withdrawn (use the
    /// `stakeAmountMinusOrderedWithdraw` instead).
    /// @param _poolStakingAddress The pool staking address.
    /// @param _staker The staker's address.
    function stakeAmount(address _poolStakingAddress, address _staker) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(STAKE_AMOUNT, _poolStakingAddress, _staker))];
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
        return uintStorage[
            keccak256(abi.encode(STAKE_AMOUNT_BY_EPOCH, _poolStakingAddress, _staker, stakingEpoch()))
        ];
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
        uint256 amount = stakeAmount(_poolStakingAddress, _staker);
        uint256 orderedAmount = orderedWithdrawAmount(_poolStakingAddress, _staker);
        return amount >= orderedAmount ? amount - orderedAmount : 0;
    }

    /// @dev Returns the total amount of staking tokens/coins currently staked into the specified pool taking into
    /// account the ordered amounts to be withdrawn. See also the `stakeAmountTotal` and `orderedWithdrawAmountTotal`
    /// getters.
    /// @param _poolStakingAddress The pool staking address.
    function stakeAmountTotalMinusOrderedWithdraw(address _poolStakingAddress) public view returns(uint256) {
        uint256 amount = stakeAmountTotal(_poolStakingAddress);
        uint256 orderedAmount = orderedWithdrawAmountTotal(_poolStakingAddress);
        return amount >= orderedAmount ? amount - orderedAmount : 0;
    }

    /// @dev Returns the serial number of the current staking epoch.
    function stakingEpoch() public view returns(uint256) {
        return uintStorage[STAKING_EPOCH];
    }

    /// @dev Returns the address of the `ValidatorSet` contract.
    function validatorSetContract() public view returns(IValidatorSet) {
        return IValidatorSet(addressStorage[VALIDATOR_SET_CONTRACT]);
    }

    // =============================================== Private ========================================================

    bytes32 internal constant CANDIDATE_MIN_STAKE = keccak256("candidateMinStake");
    bytes32 internal constant DELEGATOR_MIN_STAKE = keccak256("delegatorMinStake");
    bytes32 internal constant ERC20_RESTRICTED = keccak256("erc20Restricted");
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

    /// @dev Adds the specified staking address to the array of active pools returned by
    /// the `getPools` getter. Used by the `stake` and `orderWithdraw` functions.
    /// @param _stakingAddress The pool added to the array of active pools.
    /// @param _toBeElected The boolean flag which defines whether the specified address should be
    /// added simultaneously to the `poolsToBeElected` array. See the `getPoolsToBeElected` getter.
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

    /// @dev Adds the specified staking address to the array of inactive pools returned by
    /// the `getPoolsInactive` getter. Used by the `_removePool` function.
    /// @param _stakingAddress The pool added to the array of inactive pools.
    function _addPoolInactive(address _stakingAddress) internal {
        address[] storage pools = addressArrayStorage[POOLS_INACTIVE];
        uint256 index = poolInactiveIndex(_stakingAddress);
        if (index >= pools.length || pools[index] != _stakingAddress) {
            _setPoolInactiveIndex(_stakingAddress, pools.length);
            pools.push(_stakingAddress);
        }
    }

    /// @dev Adds the specified staking address to the array of pools returned by the `getPoolsToBeElected`
    /// getter. Used by the `_addPoolActive` function. See the `getPoolsToBeElected` getter.
    /// @param _stakingAddress The pool added to the `poolsToBeElected` array.
    function _addPoolToBeElected(address _stakingAddress) internal {
        address[] storage pools = addressArrayStorage[POOLS_TO_BE_ELECTED];
        uint256 index = poolToBeElectedIndex(_stakingAddress);
        if (index >= pools.length || pools[index] != _stakingAddress) {
            _setPoolToBeElectedIndex(_stakingAddress, pools.length);
            pools.push(_stakingAddress);
            intArrayStorage[POOLS_LIKELIHOOD].push(0);
        }
        _deletePoolToBeRemoved(_stakingAddress);
    }

    /// @dev Adds the specified staking address to the array of pools returned by the `getPoolsToBeRemoved`
    /// getter. Used by withdrawal functions. See the `getPoolsToBeRemoved` getter.
    /// @param _stakingAddress The pool added to the `poolsToBeRemoved` array.
    function _addPoolToBeRemoved(address _stakingAddress) internal {
        address[] storage pools = addressArrayStorage[POOLS_TO_BE_REMOVED];
        uint256 index = poolToBeRemovedIndex(_stakingAddress);
        if (index >= pools.length || pools[index] != _stakingAddress) {
            _setPoolToBeRemovedIndex(_stakingAddress, pools.length);
            pools.push(_stakingAddress);
        }
        _deletePoolToBeElected(_stakingAddress);
    }

    /// @dev Deletes the specified staking address from the array of pools returned by the
    /// `getPoolsToBeElected` getter. Used by the `_addPoolToBeRemoved` and `_removePool` functions.
    /// See the `getPoolsToBeElected` getter.
    /// @param _stakingAddress The pool deleted from the `poolsToBeElected` array.
    function _deletePoolToBeElected(address _stakingAddress) internal {
        address[] storage pools = addressArrayStorage[POOLS_TO_BE_ELECTED];
        int256[] storage likelihood = intArrayStorage[POOLS_LIKELIHOOD];
        if (pools.length != likelihood.length) return;
        uint256 indexToDelete = poolToBeElectedIndex(_stakingAddress);
        if (pools.length > indexToDelete && pools[indexToDelete] == _stakingAddress) {
            intStorage[POOLS_LIKELIHOOD_SUM] -= likelihood[indexToDelete];
            if (intStorage[POOLS_LIKELIHOOD_SUM] < 0) {
                intStorage[POOLS_LIKELIHOOD_SUM] = 0;
            }
            pools[indexToDelete] = pools[pools.length - 1];
            likelihood[indexToDelete] = likelihood[pools.length - 1];
            _setPoolToBeElectedIndex(pools[indexToDelete], indexToDelete);
            _setPoolToBeElectedIndex(_stakingAddress, 0);
            pools.length--;
            likelihood.length--;
        }
    }

    /// @dev Deletes the specified staking address from the array of pools returned by the
    /// `getPoolsToBeRemoved` getter. Used by the `_addPoolToBeElected` and `_removePool` functions.
    /// See the `getPoolsToBeRemoved` getter.
    /// @param _stakingAddress The pool deleted from the `poolsToBeRemoved` array.
    function _deletePoolToBeRemoved(address _stakingAddress) internal {
        address[] storage pools = addressArrayStorage[POOLS_TO_BE_REMOVED];
        uint256 indexToDelete = poolToBeRemovedIndex(_stakingAddress);
        if (pools.length > indexToDelete && pools[indexToDelete] == _stakingAddress) {
            pools[indexToDelete] = pools[pools.length - 1];
            _setPoolToBeRemovedIndex(pools[indexToDelete], indexToDelete);
            _setPoolToBeRemovedIndex(_stakingAddress, 0);
            pools.length--;
        }
    }

    /// @dev Removes the specified staking address from the array of active pools returned by
    /// the `getPools` getter. Used by the `removePool` and withdrawal functions.
    /// @param _stakingAddress The pool removed from the array of active pools.
    function _removePool(address _stakingAddress) internal {
        uint256 indexToRemove = poolIndex(_stakingAddress);
        address[] storage pools = addressArrayStorage[POOLS];
        if (pools.length > indexToRemove && pools[indexToRemove] == _stakingAddress) {
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

    /// @dev Removes the specified staking address from the array of inactive pools returned by
    /// the `getPoolsInactive` getter. Used by the `_addPoolActive` and `_removePool` functions.
    /// @param _stakingAddress The pool removed from the array of inactive pools.
    function _removePoolInactive(address _stakingAddress) internal {
        address[] storage pools = addressArrayStorage[POOLS_INACTIVE];
        uint256 indexToRemove = poolInactiveIndex(_stakingAddress);
        if (pools.length > indexToRemove && pools[indexToRemove] == _stakingAddress) {
            pools[indexToRemove] = pools[pools.length - 1];
            _setPoolInactiveIndex(pools[indexToRemove], indexToRemove);
            _setPoolInactiveIndex(_stakingAddress, 0);
            pools.length--;
        }
    }

    /// @dev Initializes the network parameters. Used by the `initialize` function of a child contract.
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
        require(!isInitialized()); // initialization can only be done once
        require(_validatorSetContract != address(0));
        require(_initialStakingAddresses.length > 0);
        require(_delegatorMinStake != 0);
        require(_candidateMinStake != 0);

        IBlockReward blockRewardContract = IBlockReward(IValidatorSet(_validatorSetContract).blockRewardContract());
        require(MAX_DELEGATORS_PER_POOL % blockRewardContract.DELEGATORS_ALIQUOT() == 0);

        addressStorage[VALIDATOR_SET_CONTRACT] = _validatorSetContract;

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

        boolStorage[ERC20_RESTRICTED] = _erc20Restricted;
    }

    /// @dev Sets the number of the staking epoch during which the specified staker ordered
    /// the latest withdraw from the specified pool. Used by the `orderWithdraw` function
    /// to allow the ordered amount to be claimed only in future staking epochs.
    /// See also the `orderWithdrawEpoch` getter.
    /// @param _poolStakingAddress The pool staking address from which the withdrawal will occur.
    /// @param _staker The staker's address that ordered the withdrawal.
    /// @param _stakingEpoch The number of the current staking epoch.
    function _setOrderWithdrawEpoch(address _poolStakingAddress, address _staker, uint256 _stakingEpoch) internal {
        uintStorage[keccak256(abi.encode(ORDER_WITHDRAW_EPOCH, _poolStakingAddress, _staker))] = _stakingEpoch;
    }

    /// @dev Sets the delegator's index in the array returned by the `poolDelegators` getter.
    /// Used by the `_addPoolDelegator` and `_removePoolDelegator` functions.
    /// @param _poolStakingAddress The pool staking address.
    /// @param _delegator The delegator's address.
    /// @param _index The index of the delegator in the `poolDelegators` array.
    function _setPoolDelegatorIndex(address _poolStakingAddress, address _delegator, uint256 _index) internal {
        uintStorage[keccak256(abi.encode(POOL_DELEGATOR_INDEX, _poolStakingAddress, _delegator))] = _index;
    }

    /// @dev Sets the delegator's index in the `poolDelegatorsInactive` array.
    /// Used by the `_addPoolDelegatorInactive` and `_removePoolDelegatorInactive` functions.
    /// @param _poolStakingAddress The pool staking address.
    /// @param _delegator The delegator's address.
    /// @param _index The index of the delegator in the `poolDelegatorsInactive` array.
    function _setPoolDelegatorInactiveIndex(address _poolStakingAddress, address _delegator, uint256 _index) internal {
        uintStorage[keccak256(abi.encode(POOL_DELEGATOR_INACTIVE_INDEX, _poolStakingAddress, _delegator))] = _index;
    }

    /// @dev Sets the index for the specified address which indicates the position of the address in the array
    /// returned by the `getPools` getter. Used by the `_addPoolActive` and `_removePool` functions.
    /// @param _stakingAddress The pool staking address.
    /// @param _index The index value.
    function _setPoolIndex(address _stakingAddress, uint256 _index) internal {
        uintStorage[keccak256(abi.encode(POOL_INDEX, _stakingAddress))] = _index;
    }

    /// @dev Sets the index for the specified address which indicates the position of the address in the array
    /// returned by the `getPoolsInactive` getter. Used by the `_addPoolInactive` and `_removePoolInactive` functions.
    /// @param _stakingAddress The pool staking address.
    /// @param _index The index value.
    function _setPoolInactiveIndex(address _stakingAddress, uint256 _index) internal {
        uintStorage[keccak256(abi.encode(POOL_INACTIVE_INDEX, _stakingAddress))] = _index;
    }

    /// @dev Sets the index for the specified address which indicates the position of the address in the array
    /// returned by the `getPoolsToBeElected` getter.
    /// Used by the `_addPoolToBeElected` and `_deletePoolToBeElected` functions.
    /// @param _stakingAddress The pool staking address.
    /// @param _index The index value.
    function _setPoolToBeElectedIndex(address _stakingAddress, uint256 _index) internal {
        uintStorage[keccak256(abi.encode(POOL_TO_BE_ELECTED_INDEX, _stakingAddress))] = _index;
    }

    /// @dev Sets the index for the specified address which indicates the position of the address in the array
    /// returned by the `getPoolsToBeRemoved` getter.
    /// Used by the `_addPoolToBeRemoved` and `_deletePoolToBeRemoved` functions.
    /// @param _stakingAddress The pool staking address.
    /// @param _index The index value.
    function _setPoolToBeRemovedIndex(address _stakingAddress, uint256 _index) internal {
        uintStorage[keccak256(abi.encode(POOL_TO_BE_REMOVED_INDEX, _stakingAddress))] = _index;
    }

    /// @dev Adds the specified address to the array of the current active delegators of the specified pool.
    /// Used by the `stake` and `orderWithdraw` functions. See the `poolDelegators` getter.
    /// @param _poolStakingAddress The pool staking address.
    /// @param _delegator The delegator's address.
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

    /// @dev Adds the specified address to the array of the current inactive delegators of the specified pool.
    /// Used by the `_removePoolDelegator` function.
    /// @param _poolStakingAddress The pool staking address.
    /// @param _delegator The delegator's address.
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

    /// @dev Removes the specified address from the array of the current active delegators of the specified pool.
    /// Used by the withdrawal functions. See the `poolDelegators` getter.
    /// @param _poolStakingAddress The pool staking address.
    /// @param _delegator The delegator's address.
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

    /// @dev Removes the specified address from the array of the inactive delegators of the specified pool.
    /// Used by the `_addPoolDelegator` and `_removePoolDelegator` functions.
    /// @param _poolStakingAddress The pool staking address.
    /// @param _delegator The delegator's address.
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

    /// @dev Calculates (updates) the probability of being selected as a validator for the specified pool
    /// and updates the total sum of probability coefficients. See the `getPoolsLikelihood` getter.
    /// Used by the staking and withdrawal functions.
    /// @param _poolStakingAddress The address of the pool for which the probability coefficient must be updated.
    function _setLikelihood(address _poolStakingAddress) internal {
        (bool isToBeElected, uint256 index) = _isPoolToBeElected(_poolStakingAddress);

        if (!isToBeElected) return;

        int256 oldValue = intArrayStorage[POOLS_LIKELIHOOD][index];
        int256 newValue = int256(stakeAmountTotalMinusOrderedWithdraw(_poolStakingAddress) * 100 / STAKE_UNIT);

        intArrayStorage[POOLS_LIKELIHOOD][index] = newValue;
        intStorage[POOLS_LIKELIHOOD_SUM] += newValue - oldValue;
    }

    /// @dev Sets the current amount of staking tokens/coins ordered for withdrawal from the specified
    /// pool by the specified staker. Used by the `orderWithdraw` and `claimOrderedWithdraw` functions.
    /// @param _poolStakingAddress The pool staking address from which the amount will be withdrawn.
    /// @param _staker The staker's address that ordered the withdrawal.
    /// @param _amount The amount of staking tokens ordered for withdrawal.
    function _setOrderedWithdrawAmount(address _poolStakingAddress, address _staker, uint256 _amount) internal {
        uintStorage[keccak256(abi.encode(ORDERED_WITHDRAW_AMOUNT, _poolStakingAddress, _staker))] = _amount;
    }

    /// @dev Sets the total amount of staking tokens/coins ordered for withdrawal from
    /// the specified pool by all its stakers.
    /// @param _poolStakingAddress The pool staking address from which the amount will be withdrawn.
    /// @param _amount The total amount of staking tokens/coins ordered for withdrawal.
    function _setOrderedWithdrawAmountTotal(address _poolStakingAddress, uint256 _amount) internal {
        uintStorage[keccak256(abi.encode(ORDERED_WITHDRAW_AMOUNT_TOTAL, _poolStakingAddress))] = _amount;
    }

    /// @dev Sets the amount of staking tokens/coins currently staked into the specified pool by the specified staker.
    /// Used by the `stake`, `withdraw`, and `claimOrderedWithdraw` functions. See the `stakeAmount` getter.
    /// @param _poolStakingAddress The pool staking address.
    /// @param _staker The staker's address.
    /// @param _amount The amount of staking tokens/coins.
    function _setStakeAmount(address _poolStakingAddress, address _staker, uint256 _amount) internal {
        uintStorage[keccak256(abi.encode(STAKE_AMOUNT, _poolStakingAddress, _staker))] = _amount;
    }

    /// @dev Sets the amount of staking tokens/coins staked into the specified pool by the specified staker during the
    /// current staking epoch (see the `stakingEpoch` getter). See also the `stakeAmountByCurrentEpoch` getter.
    /// Used by the `_stake` and `_withdraw` functions.
    /// @param _poolStakingAddress The pool staking address.
    /// @param _staker The staker's address.
    /// @param _amount The amount of staking tokens/coins.
    function _setStakeAmountByCurrentEpoch(
        address _poolStakingAddress,
        address _staker,
        uint256 _amount
    ) internal {
        uintStorage[keccak256(abi.encode(
            STAKE_AMOUNT_BY_EPOCH, _poolStakingAddress, _staker, stakingEpoch()
        ))] = _amount;
    }

    /// @dev Sets the total amount of staking tokens/coins currently staked into the specified pool.
    /// @param _poolStakingAddress The pool staking address.
    /// @param _amount The total amount of staking tokens/coins.
    function _setStakeAmountTotal(address _poolStakingAddress, uint256 _amount) internal {
        uintStorage[keccak256(abi.encode(STAKE_AMOUNT_TOTAL, _poolStakingAddress))] = _amount;
    }

    /// @dev Sets (updates) the limit of the minimum delegator stake (DELEGATOR_MIN_STAKE).
    /// Used by the `_initialize` and `setDelegatorMinStake` functions.
    /// @param _minStake The value of a new limit in STAKE_UNITs.
    function _setDelegatorMinStake(uint256 _minStake) internal {
        uintStorage[DELEGATOR_MIN_STAKE] = _minStake * STAKE_UNIT;
    }

    /// @dev Sets (updates) the limit of the minimum candidate stake (CANDIDATE_MIN_STAKE).
    /// Used by the `_initialize` and `setCandidateMinStake` functions.
    /// @param _minStake The value of a new limit in STAKE_UNITs.
    function _setCandidateMinStake(uint256 _minStake) internal {
        uintStorage[CANDIDATE_MIN_STAKE] = _minStake * STAKE_UNIT;
    }

    /// @dev The internal function used by the `stake` and `addPool` functions.
    /// See the `stake` public function for more details.
    /// @param _toPoolStakingAddress The staking address of the pool where the tokens/coins should be staked.
    /// @param _amount The amount of tokens/coins to be staked.
    function _stake(address _toPoolStakingAddress, uint256 _amount) internal {
        IERC20Minting tokenContract = IERC20Minting(erc20TokenContract());
        if (address(tokenContract) != address(0)) {
            require(msg.value == 0);
        }
        address staker = msg.sender;
        _stake(_toPoolStakingAddress, staker, _amount);
        if (address(tokenContract) != address(0)) {
            tokenContract.stake(staker, _amount);
        } else {
            require(boolStorage[ERC20_RESTRICTED]);
        }
        emit Staked(_toPoolStakingAddress, staker, stakingEpoch(), _amount);
    }

    /// @dev The internal function used by the `_stake` and `moveStake` functions.
    /// See the `stake` public function for more details.
    /// @param _poolStakingAddress The staking address of the pool where the tokens/coins should be staked.
    /// @param _staker The staker's address.
    /// @param _amount The amount of tokens/coins to be staked.
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

    /// @dev The internal function used by the `_withdraw` and `claimOrderedWithdraw` functions.
    /// Contains a common logic for these functions.
    /// @param _poolStakingAddress The staking address of the pool from which the tokens/coins are withdrawn.
    /// @param _staker The staker's address.
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
        address[] storage pools = addressArrayStorage[POOLS_TO_BE_ELECTED];
        if (pools.length != 0) {
            index = poolToBeElectedIndex(_stakingAddress);
            if (pools[index] == _stakingAddress) {
                return (true, index);
            }
        }
        return (false, 0);
    }

    /// @dev Returns `true` if withdrawal from the pool of the specified validator is allowed at the moment.
    /// Used by all withdrawal functions.
    /// @param _miningAddress The mining address of the validator's pool.
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
