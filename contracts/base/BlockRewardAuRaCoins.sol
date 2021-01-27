pragma solidity 0.5.10;

import "./BlockRewardAuRaBase.sol";
import "../interfaces/IBlockRewardAuRaCoins.sol";


contract BlockRewardAuRaCoins is BlockRewardAuRaBase, IBlockRewardAuRaCoins {

    // ============================================== Constants =======================================================

    /// @dev Inflation rate per staking epoch. Calculated as follows:
    /// 2.5% annual rate * 48 staking weeks per staking year / 100 * 10**18
    /// This assumes that 1 staking epoch = 1 week
    /// i.e. Inflation Rate = 2.5/48/100 * 1 ether
    /// Recalculate it for different annual rate and/or different staking epoch duration.
    uint256 public constant NATIVE_COIN_INFLATION_RATE = 520833333333333;

    // =============================================== Setters ========================================================

    /// @dev Called by the `StakingAuRa.claimReward` function to transfer native coins
    /// from the balance of the `BlockRewardAuRa` contract to the specified address as a reward.
    /// @param _nativeCoins The amount of native coins to transfer as a reward.
    /// @param _to The target address to transfer the amounts to.
    function transferReward(uint256 _nativeCoins, address payable _to) external onlyStakingContract {
        _transferNativeReward(_nativeCoins, _to);
    }

    // =============================================== Getters ========================================================

    /// @dev Returns the reward amount in native coins for
    /// some delegator with the specified stake amount placed into the specified
    /// pool before the specified staking epoch. Used by the `StakingAuRa.claimReward` function.
    /// @param _delegatorStake The stake amount placed by some delegator into the `_poolMiningAddress` pool.
    /// @param _stakingEpoch The serial number of staking epoch.
    /// @param _poolMiningAddress The pool mining address.
    /// @return `uint256 nativeReward` - the reward amount in native coins.
    function getDelegatorReward(
        uint256 _delegatorStake,
        uint256 _stakingEpoch,
        address _poolMiningAddress
    ) external view returns(uint256 nativeReward) {
        uint256 validatorStake = snapshotPoolValidatorStakeAmount[_stakingEpoch][_poolMiningAddress];
        uint256 totalStake = snapshotPoolTotalStakeAmount[_stakingEpoch][_poolMiningAddress];

        nativeReward = delegatorShare(
            _stakingEpoch,
            _delegatorStake,
            validatorStake,
            totalStake,
            epochPoolNativeReward[_stakingEpoch][_poolMiningAddress]
        );
    }

    /// @dev Returns the reward amount in native coins for
    /// the specified validator and for the specified staking epoch.
    /// Used by the `StakingAuRa.claimReward` function.
    /// @param _stakingEpoch The serial number of staking epoch.
    /// @param _poolMiningAddress The pool mining address.
    /// @return `uint256 nativeReward` - the reward amount in native coins.
    function getValidatorReward(
        uint256 _stakingEpoch,
        address _poolMiningAddress
    ) external view returns(uint256 nativeReward) {
        uint256 validatorStake = snapshotPoolValidatorStakeAmount[_stakingEpoch][_poolMiningAddress];
        uint256 totalStake = snapshotPoolTotalStakeAmount[_stakingEpoch][_poolMiningAddress];

        nativeReward = validatorShare(
            _stakingEpoch,
            validatorStake,
            totalStake,
            epochPoolNativeReward[_stakingEpoch][_poolMiningAddress]
        );
    }

    // ============================================== Internal ========================================================

    /// @dev Calculates and returns inflation amount based on the specified
    /// staking epoch and validator set. Uses NATIVE_COIN_INFLATION_RATE constant.
    /// Used by `_distributeNativeRewards` internal function.
    /// @param _stakingEpoch The number of the current staking epoch.
    /// @param _validators The array of the current validators (their mining addresses).
    function _coinInflationAmount(
        uint256 _stakingEpoch,
        address[] memory _validators
    ) internal view returns(uint256) {
        return _inflationAmount(_stakingEpoch, _validators, NATIVE_COIN_INFLATION_RATE);
    }

    function _distributeTokenRewards(
        address, uint256, uint256, uint256, address[] memory, uint256[] memory, uint256
    ) internal {
    }

}
