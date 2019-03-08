pragma solidity 0.5.2;

import "./abstracts/BlockRewardBase.sol";
import "./interfaces/IERC20Minting.sol";
import "./interfaces/IRandomAuRa.sol";


contract BlockRewardAuRa is BlockRewardBase {

    function reward(address[] calldata benefactors, uint16[] calldata kind)
        external
        onlySystem
        returns(address[] memory, uint256[] memory)
    {
        require(benefactors.length == kind.length);
        require(benefactors.length == 1);
        require(kind[0] == 0);

        IValidatorSet validatorSetContract = IValidatorSet(VALIDATOR_SET_CONTRACT);

        // Check if the validator is existed
        if (!validatorSetContract.isValidator(benefactors[0])) {
            return (new address[](0), new uint256[](0));
        }

        // Publish current random number at the end of the current collection round.
        // Remove malicious validators if any.
        IRandomAuRa(validatorSetContract.randomContract()).onBlockClose();

        IStaking stakingContract = IStaking(validatorSetContract.stakingContract());

        // Perform ordered withdrawals at the starting of a new staking epoch
        stakingContract.performOrderedWithdrawals();

        // Start new staking epoch every `stakingEpochDuration()` blocks
        validatorSetContract.newValidatorSet();

        // Distribute fees
        address[] memory receivers;
        uint256[] memory rewards;
        uint256 i;

        uint256 stakingEpoch = _getStakingEpoch();

        // Distribute bridge's native fee
        (receivers, rewards) = _distributeBridgeFee(stakingEpoch, false, true);
        for (i = 0; i < receivers.length; i++) {
            addressArrayStorage[REWARD_TEMPORARY_ARRAY].push(receivers[i]);
            uintArrayStorage[REWARD_TEMPORARY_ARRAY].push(rewards[i]);
        }
        if (stakingEpoch > 0) {
            // Handle previous staking epoch as well (just in case)
            (receivers, rewards) = _distributeBridgeFee(stakingEpoch - 1, true, true);
            for (i = 0; i < receivers.length; i++) {
                addressArrayStorage[REWARD_TEMPORARY_ARRAY].push(receivers[i]);
                uintArrayStorage[REWARD_TEMPORARY_ARRAY].push(rewards[i]);
            }
        }

        IERC20Minting erc20TokenContract = IERC20Minting(
            stakingContract.erc20TokenContract()
        );
        if (address(erc20TokenContract) != address(0)) {
            // Distribute bridge's token fee
            (receivers, rewards) = _distributeBridgeFee(stakingEpoch, false, false);
            if (receivers.length > 0) {
                erc20TokenContract.mintReward(receivers, rewards);
            }
            if (stakingEpoch > 0) {
                // Handle previous staking epoch as well (just in case)
                (receivers, rewards) = _distributeBridgeFee(stakingEpoch - 1, true, false);
                if (receivers.length > 0) {
                    erc20TokenContract.mintReward(receivers, rewards);
                }
            }

            // 1%/year staking token inflation
            (receivers, rewards) = _distributeInflation(stakingEpoch);
            if (receivers.length > 0) {
                erc20TokenContract.mintReward(receivers, rewards);
            }
        }

        // We don't accrue any block reward in native coins to validator here.
        // We just mint native coins by bridge if needed.
        (receivers, rewards) = _mintNativeCoinsByErcToNativeBridge();
        for (i = 0; i < receivers.length; i++) {
            addressArrayStorage[REWARD_TEMPORARY_ARRAY].push(receivers[i]);
            uintArrayStorage[REWARD_TEMPORARY_ARRAY].push(rewards[i]);
        }

        // Move the arrays of receivers and their rewards from storage to memory
        receivers = addressArrayStorage[REWARD_TEMPORARY_ARRAY];
        rewards = uintArrayStorage[REWARD_TEMPORARY_ARRAY];

        delete addressArrayStorage[REWARD_TEMPORARY_ARRAY];
        delete uintArrayStorage[REWARD_TEMPORARY_ARRAY];

        return (receivers, rewards);
    }

    function _distributeAmount(uint256 _stakingEpoch, bool _previousEpoch, uint256 _amount)
        internal
        returns(address[] memory receivers, uint256[] memory rewards)
    {
        IValidatorSet validatorSetContract = IValidatorSet(VALIDATOR_SET_CONTRACT);
        address[] memory validators;
        uint256 poolReward;
        uint256 remainder;
        uint256 i;

        if (!_previousEpoch) {
            validators = validatorSetContract.getValidators();
        } else {
            validators = validatorSetContract.getPreviousValidators();
        }
        if (_stakingEpoch == 0) {
            // On initial staking epoch only initial validators get reward

            poolReward = _amount / validators.length;
            remainder = _amount % validators.length;

            receivers = new address[](validators.length);
            rewards = new uint256[](validators.length);

            for (i = 0; i < validators.length; i++) {
                receivers[i] = validatorSetContract.stakingByMiningAddress(validators[i]);
                rewards[i] = poolReward;
            }
            rewards[0] += remainder;

            return (receivers, rewards);
        } else {
            poolReward = _amount / snapshotStakingAddresses(_stakingEpoch).length;
            remainder = _amount % snapshotStakingAddresses(_stakingEpoch).length;

            for (i = 0; i < validators.length; i++) {
                // Distribute the reward among validators and their delegators
                (
                    receivers,
                    rewards
                ) = _distributePoolReward(
                    _stakingEpoch,
                    validatorSetContract.stakingByMiningAddress(validators[i]),
                    i == 0 ? poolReward + remainder : poolReward
                );

                for (uint256 r = 0; r < receivers.length; r++) {
                    addressArrayStorage[DISTRIBUTE_TEMPORARY_ARRAY].push(receivers[r]);
                    uintArrayStorage[DISTRIBUTE_TEMPORARY_ARRAY].push(rewards[r]);
                }
            }

            receivers = addressArrayStorage[DISTRIBUTE_TEMPORARY_ARRAY];
            rewards = uintArrayStorage[DISTRIBUTE_TEMPORARY_ARRAY];

            delete addressArrayStorage[DISTRIBUTE_TEMPORARY_ARRAY];
            delete uintArrayStorage[DISTRIBUTE_TEMPORARY_ARRAY];
        }
    }

    function _distributeBridgeFee(uint256 _stakingEpoch, bool _previousEpoch, bool _native)
        internal
        returns(address[] memory receivers, uint256[] memory rewards)
    {
        uint256 bridgeFeeAmount;

        if (_native) {
            bridgeFeeAmount = _getBridgeNativeFee(_stakingEpoch);
            _clearBridgeNativeFee(_stakingEpoch);
        } else {
            bridgeFeeAmount = _getBridgeTokenFee(_stakingEpoch);
            _clearBridgeTokenFee(_stakingEpoch);
        }

        if (bridgeFeeAmount == 0) {
            return (new address[](0), new uint256[](0));
        }

        return _distributeAmount(_stakingEpoch, _previousEpoch, bridgeFeeAmount);
    }

    function _distributeInflation(uint256 _stakingEpoch)
        internal
        returns(address[] memory receivers, uint256[] memory rewards)
    {
        uint256 amount = snapshotTotalStakeAmount(_stakingEpoch) * 1585489599 / 1 ether; // 1% per year

        if (amount == 0) {
            return (new address[](0), new uint256[](0));
        }

        return _distributeAmount(_stakingEpoch, false, amount);
    }

    bytes32 internal constant DISTRIBUTE_TEMPORARY_ARRAY = keccak256("distributeTemporaryArray");
    bytes32 internal constant REWARD_TEMPORARY_ARRAY = keccak256("rewardTemporaryArray");

}
