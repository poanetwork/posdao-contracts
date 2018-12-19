pragma solidity 0.4.25;

import "./abstracts/BlockRewardBase.sol";


contract BlockRewardAuRa is BlockRewardBase {

    function reward(address[] benefactors, uint16[] kind)
        external
        onlySystem
        returns(address[], uint256[])
    {
        require(benefactors.length == kind.length);
        require(benefactors.length == 1);
        require(kind[0] == 0);

        address[] memory receivers;
        uint256[] memory rewards;
        uint256 i;

        // Distribute bridge's fee
        uint256 stakingEpoch = _getStakingEpoch();
        
        (receivers, rewards) = _distributeBridgeFee(stakingEpoch, false);
        for (i = 0; i < receivers.length; i++) {
            addressArrayStorage[REWARD_TEMPORARY_ARRAY].push(receivers[i]);
            uintArrayStorage[REWARD_TEMPORARY_ARRAY].push(rewards[i]);
        }

        if (stakingEpoch > 0) {
            // Handle previous staking epoch as well
            (receivers, rewards) = _distributeBridgeFee(stakingEpoch - 1, true);
            for (i = 0; i < receivers.length; i++) {
                addressArrayStorage[REWARD_TEMPORARY_ARRAY].push(receivers[i]);
                uintArrayStorage[REWARD_TEMPORARY_ARRAY].push(rewards[i]);
            }
        }

        // We don't accrue any block reward in native coins to validator here.
        // We just mint native coins by bridge if needed.
        (receivers, rewards) = _mintNativeCoinsByBridge();
        for (i = 0; i < receivers.length; i++) {
            addressArrayStorage[REWARD_TEMPORARY_ARRAY].push(receivers[i]);
            uintArrayStorage[REWARD_TEMPORARY_ARRAY].push(rewards[i]);
        }

        receivers = addressArrayStorage[REWARD_TEMPORARY_ARRAY];
        rewards = uintArrayStorage[REWARD_TEMPORARY_ARRAY];

        delete addressArrayStorage[REWARD_TEMPORARY_ARRAY];
        delete uintArrayStorage[REWARD_TEMPORARY_ARRAY];

        return (receivers, rewards);
    }

    function _distributeBridgeFee(uint256 _stakingEpoch, bool _previousEpoch)
        internal
        returns(address[], uint256[])
    {
        IValidatorSet validatorSetContract = IValidatorSet(VALIDATOR_SET_CONTRACT);
        uint256 bridgeFeeAmount = _getBridgeFee(_stakingEpoch);
        address[] memory validators;
        uint256[] memory rewards;
        uint256 poolReward;
        uint256 i;

        _clearBridgeFee(_stakingEpoch);

        if (!_previousEpoch) {
            validators = validatorSetContract.getValidators();
        } else {
            validators = validatorSetContract.getPreviousValidators();
        }
        if (_stakingEpoch == 0) {
            // On initial staking epoch only initial validators get reward

            poolReward = bridgeFeeAmount / validators.length;

            rewards = new uint256[](validators.length);

            for (i = 0; i < validators.length; i++) {
                rewards[i] = poolReward;
            }

            return (validators, rewards);
        } else {
            poolReward = bridgeFeeAmount / snapshotValidators(_stakingEpoch).length;

            for (i = 0; i < validators.length; i++) {
                // Distribute the reward among validators and their stakers
                (
                    address[] memory poolReceivers,
                    uint256[] memory poolRewards
                ) = _distributePoolReward(_stakingEpoch, validators[i], poolReward);

                for (uint256 r = 0; r < poolReceivers.length; r++) {
                    addressArrayStorage[DISTRIBUTE_TEMPORARY_ARRAY].push(poolReceivers[r]);
                    uintArrayStorage[DISTRIBUTE_TEMPORARY_ARRAY].push(poolRewards[r]);
                }
            }

            address[] memory receivers = addressArrayStorage[DISTRIBUTE_TEMPORARY_ARRAY];
            rewards = uintArrayStorage[DISTRIBUTE_TEMPORARY_ARRAY];

            delete addressArrayStorage[DISTRIBUTE_TEMPORARY_ARRAY];
            delete uintArrayStorage[DISTRIBUTE_TEMPORARY_ARRAY];

            return (receivers, rewards);
        }
    }

    bytes32 internal constant DISTRIBUTE_TEMPORARY_ARRAY = keccak256("distributeTemporaryArray");
    bytes32 internal constant REWARD_TEMPORARY_ARRAY = keccak256("rewardTemporaryArray");

}
