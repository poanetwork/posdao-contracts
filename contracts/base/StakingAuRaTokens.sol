pragma solidity 0.5.10;

import "./StakingAuRaBase.sol";
import "../interfaces/IBlockRewardAuRaTokens.sol";
import "../interfaces/IStakingAuRaTokens.sol";


/// @dev Implements staking and withdrawal logic.
contract StakingAuRaTokens is IStakingAuRaTokens, StakingAuRaBase {

    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables and do not change their types!

    /// @dev The address of the ERC677 staking token contract.
    IERC677Minting public erc677TokenContract;

    // =============================================== Structs ========================================================

    /// @dev Used by the `claimReward` function to reduce stack depth.
    struct RewardAmounts {
        uint256 tokenAmount;
        uint256 nativeAmount;
    }

    // ================================================ Events ========================================================

    /// @dev Emitted by the `claimReward` function to signal the staker withdrew the specified
    /// amount of tokens and native coins from the specified pool for the specified staking epoch.
    /// @param fromPoolStakingAddress The pool from which the `staker` withdrew the amounts.
    /// @param staker The address of the staker that withdrew the amounts.
    /// @param stakingEpoch The serial number of the staking epoch for which the claim was made.
    /// @param tokensAmount The withdrawal amount of tokens.
    /// @param nativeCoinsAmount The withdrawal amount of native coins.
    event ClaimedReward(
        address indexed fromPoolStakingAddress,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 tokensAmount,
        uint256 nativeCoinsAmount
    );

    // =============================================== Setters ========================================================

    /// @dev Withdraws a reward from the specified pool for the specified staking epochs
    /// to the staker address (msg.sender).
    /// @param _stakingEpochs The list of staking epochs in ascending order.
    /// If the list is empty, it is taken with `BlockRewardAuRa.epochsPoolGotRewardFor` getter.
    /// @param _poolStakingAddress The staking address of the pool from which the reward needs to be withdrawn.
    function claimReward(
        uint256[] memory _stakingEpochs,
        address _poolStakingAddress
    ) public gasPriceIsValid onlyInitialized {
        address payable staker = msg.sender;
        uint256 firstEpoch;
        uint256 lastEpoch;

        if (_poolStakingAddress != staker) { // this is a delegator
            firstEpoch = stakeFirstEpoch[_poolStakingAddress][staker];
            require(firstEpoch != 0);
            lastEpoch = stakeLastEpoch[_poolStakingAddress][staker];
        }

        IBlockRewardAuRaTokens blockRewardContract = IBlockRewardAuRaTokens(validatorSetContract.blockRewardContract());
        address miningAddress = validatorSetContract.miningByStakingAddress(_poolStakingAddress);
        RewardAmounts memory rewardSum = RewardAmounts(0, 0);
        uint256 delegatorStake = 0;

        if (_stakingEpochs.length == 0) {
            _stakingEpochs = IBlockRewardAuRa(address(blockRewardContract)).epochsPoolGotRewardFor(miningAddress);
        }

        for (uint256 i = 0; i < _stakingEpochs.length; i++) {
            uint256 epoch = _stakingEpochs[i];

            require(i == 0 || epoch > _stakingEpochs[i - 1]);
            require(epoch < stakingEpoch);

            if (rewardWasTaken[_poolStakingAddress][staker][epoch]) continue;
            
            RewardAmounts memory reward;

            if (_poolStakingAddress != staker) { // this is a delegator
                if (epoch < firstEpoch) {
                    // If the delegator staked for the first time before
                    // the `epoch`, skip this staking epoch
                    continue;
                }

                if (lastEpoch <= epoch && lastEpoch != 0) {
                    // If the delegator withdrew all their stake before the `epoch`,
                    // don't check this and following epochs since it makes no sense
                    break;
                }

                delegatorStake = _getDelegatorStake(epoch, firstEpoch, delegatorStake, _poolStakingAddress, staker);
                firstEpoch = epoch + 1;

                (reward.tokenAmount, reward.nativeAmount) =
                    blockRewardContract.getDelegatorReward(delegatorStake, epoch, miningAddress);
            } else { // this is a validator
                (reward.tokenAmount, reward.nativeAmount) =
                    blockRewardContract.getValidatorReward(epoch, miningAddress);
            }

            rewardSum.tokenAmount = rewardSum.tokenAmount.add(reward.tokenAmount);
            rewardSum.nativeAmount = rewardSum.nativeAmount.add(reward.nativeAmount);

            rewardWasTaken[_poolStakingAddress][staker][epoch] = true;

            emit ClaimedReward(_poolStakingAddress, staker, epoch, reward.tokenAmount, reward.nativeAmount);
        }

        blockRewardContract.transferReward(rewardSum.tokenAmount, rewardSum.nativeAmount, staker);
    }

    /// @dev Sets the address of the ERC677 staking token contract. Can only be called by the `owner`.
    /// Cannot be called if there was at least one stake in staking tokens before.
    /// @param _erc677TokenContract The address of the contract.
    function setErc677TokenContract(IERC677Minting _erc677TokenContract) external onlyOwner onlyInitialized {
        require(_erc677TokenContract != IERC677Minting(0));
        require(erc677TokenContract == IERC677Minting(0));
        require(_erc677TokenContract.balanceOf(address(this)) == 0);
        erc677TokenContract = _erc677TokenContract;
    }

    // =============================================== Getters ========================================================

    /// @dev Returns reward amounts for the specified pool, the specified staking epochs,
    /// and the specified staker address (delegator or validator).
    /// @param _stakingEpochs The list of staking epochs in ascending order.
    /// If the list is empty, it is taken with `BlockRewardAuRa.epochsPoolGotRewardFor` getter.
    /// @param _poolStakingAddress The staking address of the pool for which the amounts need to be returned.
    /// @param _staker The staker address (validator's staking address or delegator's address).
    function getRewardAmount(
        uint256[] memory _stakingEpochs,
        address _poolStakingAddress,
        address _staker
    ) public view returns(uint256 tokenRewardSum, uint256 nativeRewardSum) {
        uint256 firstEpoch;
        uint256 lastEpoch;

        if (_poolStakingAddress != _staker) { // this is a delegator
            firstEpoch = stakeFirstEpoch[_poolStakingAddress][_staker];
            require(firstEpoch != 0);
            lastEpoch = stakeLastEpoch[_poolStakingAddress][_staker];
        }

        IBlockRewardAuRaTokens blockRewardContract = IBlockRewardAuRaTokens(validatorSetContract.blockRewardContract());
        address miningAddress = validatorSetContract.miningByStakingAddress(_poolStakingAddress);
        uint256 delegatorStake = 0;
        tokenRewardSum = 0;
        nativeRewardSum = 0;

        if (_stakingEpochs.length == 0) {
            _stakingEpochs = IBlockRewardAuRa(address(blockRewardContract)).epochsPoolGotRewardFor(miningAddress);
        }

        for (uint256 i = 0; i < _stakingEpochs.length; i++) {
            uint256 epoch = _stakingEpochs[i];

            require(i == 0 || epoch > _stakingEpochs[i - 1]);
            require(epoch < stakingEpoch);

            if (rewardWasTaken[_poolStakingAddress][_staker][epoch]) continue;

            if (_poolStakingAddress != _staker) { // this is a delegator
                if (epoch < firstEpoch) continue;
                if (lastEpoch <= epoch && lastEpoch != 0) break;

                delegatorStake = _getDelegatorStake(epoch, firstEpoch, delegatorStake, _poolStakingAddress, _staker);
                firstEpoch = epoch + 1;

                (uint256 tokenAmount, uint256 nativeAmount) =
                    blockRewardContract.getDelegatorReward(delegatorStake, epoch, miningAddress);
                tokenRewardSum += tokenAmount;
                nativeRewardSum += nativeAmount;
            } else { // this is a validator
                (uint256 tokenAmount, uint256 nativeAmount) =
                    blockRewardContract.getValidatorReward(epoch, miningAddress);
                tokenRewardSum += tokenAmount;
                nativeRewardSum += nativeAmount;
            }
        }
    }

    // ============================================== Internal ========================================================

    /// @dev Sends tokens from this contract to the specified address.
    /// @param _to The target address to send amount to.
    /// @param _amount The amount to send.
    function _sendWithdrawnStakeAmount(address payable _to, uint256 _amount) internal {
        require(erc677TokenContract != IERC677Minting(0));
        erc677TokenContract.transfer(_to, _amount);
    }

    /// @dev The internal function used by the `stake` and `addPool` functions.
    /// See the `stake` public function for more details.
    /// @param _toPoolStakingAddress The staking address of the pool where the tokens should be staked.
    /// @param _amount The amount of tokens to be staked.
    function _stake(address _toPoolStakingAddress, uint256 _amount) internal gasPriceIsValid onlyInitialized {
        address staker = msg.sender;
        _stake(_toPoolStakingAddress, staker, _amount);
        require(msg.value == 0);
        require(erc677TokenContract != IERC677Minting(0));
        erc677TokenContract.stake(staker, _amount);
        emit PlacedStake(_toPoolStakingAddress, staker, stakingEpoch, _amount);
    }
}
