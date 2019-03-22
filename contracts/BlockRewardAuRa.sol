pragma solidity 0.5.2;

import "./abstracts/BlockRewardBase.sol";
import "./interfaces/IERC20Minting.sol";
import "./interfaces/IRandomAuRa.sol";
import "./interfaces/IValidatorSetAuRa.sol";


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

        if (block.number == 1) {
            uintStorage[QUEUE_NV_FIRST] = 1;
            uintStorage[QUEUE_NV_LAST] = 0;
        }

        uint256 i;

        if (validatorSetContract.newValidatorSet()) {
            // Start new staking epoch every `stakingEpochDuration()` blocks
            address[] memory newValidatorSet = validatorSetContract.getPendingValidators();

            for (i = 0; i < newValidatorSet.length; i++) {
                _enqueueNewValidator(newValidatorSet[i]);
            }

            delete addressArrayStorage[SNAPSHOT_STAKING_ADDRESSES];
            delete uintStorage[SNAPSHOT_TOTAL_STAKE_AMOUNT];
        } else if (validatorSetContract.validatorSetApplyBlock() == 0) {
            address newValidator = _dequeueNewValidator();

            if (newValidator != address(0)) {
                _setSnapshot(validatorSetContract.stakingByMiningAddress(newValidator), stakingContract);
            } else if (!pendingValidatorsEnqueued()) {
                IValidatorSetAuRa(VALIDATOR_SET_CONTRACT).enqueuePendingValidators();
                _setPendingValidatorsEnqueued(true);
            }
        } else {
            _distributeRewards(
                benefactors[0],
                stakingContract.stakingEpoch(),
                stakingContract.erc20TokenContract()
            );
        }

        uintStorage[PREVIOUS_VALIDATOR_INDEX] = validatorSetContract.validatorIndex(benefactors[0]);

        // We don't accrue any block reward in native coins to validator here.
        // We just mint native coins by bridge if needed.
        address[] memory receivers;
        uint256[] memory rewards;
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

    function _distributeRewards(
        address _miningAddress,
        uint256 _stakingEpoch,
        address _erc20TokenContract
    ) internal {
        uint256 poolNativeReward = 0;
        uint256 poolTokenReward = 0;

        if (
            IValidatorSet(VALIDATOR_SET_CONTRACT).validatorIndex(_miningAddress) <=
            uintStorage[PREVIOUS_VALIDATOR_INDEX]
        ) {
            // New Authority Round started

            uint256 poolsCount;
            uint256 totalReward;

            if (_stakingEpoch != 0) {
                poolsCount = snapshotStakingAddresses().length;
            } else {
                poolsCount = IValidatorSet(VALIDATOR_SET_CONTRACT).getValidators().length;
            }

            totalReward = _getBridgeNativeFee();
            if (totalReward != 0) {
                _clearBridgeNativeFee();

                totalReward += _getNativeRewardUndistributed();
                poolNativeReward = totalReward / poolsCount;

                _setNativeRewardUndistributed(totalReward);
            }
            _setRoundPoolNativeReward(poolNativeReward);

            if (_erc20TokenContract != address(0)) {
                totalReward = _getBridgeTokenFee();
                totalReward += snapshotTotalStakeAmount() * 1585489599 / 1 ether; // 1% per year inflation
                if (totalReward != 0) {
                    _clearBridgeTokenFee();

                    totalReward += _getTokenRewardUndistributed();
                    poolTokenReward = totalReward / poolsCount;

                    _setTokenRewardUndistributed(totalReward);
                }
                _setRoundPoolTokenReward(poolTokenReward);
            }
        } else {
            poolNativeReward = _getRoundPoolNativeReward();
            poolTokenReward = _getRoundPoolTokenReward();
        }

        address[] memory receivers;
        uint256[] memory rewards;
        uint256[] memory rewardPercents;
        address validatorStakingAddress = IValidatorSet(VALIDATOR_SET_CONTRACT).stakingByMiningAddress(_miningAddress);

        if (_stakingEpoch > 0) {
            // Distribute the reward among validator and their delegators
            receivers = snapshotStakers(validatorStakingAddress);
            rewardPercents = snapshotRewardPercents(validatorStakingAddress);
        } else {
            // Give the reward to the validator
            receivers = new address[](1);
            rewardPercents = new uint256[](1);
            receivers[0] = validatorStakingAddress;
            rewardPercents[0] = REWARD_PERCENT_MULTIPLIER;
        }

        rewards = new uint256[](receivers.length);

        if (rewardPercents.length > 0) {
            uint256 remainder;
            uint256 i;

            if (poolNativeReward != 0) {
                remainder = poolNativeReward;

                for (i = 0; i < rewardPercents.length; i++) {
                    rewards[i] = poolNativeReward * rewardPercents[i] / REWARD_PERCENT_MULTIPLIER;
                    remainder -= rewards[i];
                }
                rewards[i - 1] += remainder;

                addressArrayStorage[REWARD_TEMPORARY_ARRAY] = receivers;
                uintArrayStorage[REWARD_TEMPORARY_ARRAY] = rewards;
                _subNativeRewardUndistributed(poolNativeReward);
            }

            if (_erc20TokenContract != address(0) && poolTokenReward != 0) {
                remainder = poolTokenReward;

                for (i = 0; i < rewardPercents.length; i++) {
                    rewards[i] = poolTokenReward * rewardPercents[i] / REWARD_PERCENT_MULTIPLIER;
                    remainder -= rewards[i];
                }
                rewards[i - 1] += remainder;

                IERC20Minting(_erc20TokenContract).mintReward(receivers, rewards);
                _subTokenRewardUndistributed(poolTokenReward);
            }
        }
    }

    function _dequeueNewValidator() internal returns(address newValidator) {
        uint256 queueFirst = uintStorage[QUEUE_NV_FIRST];
        uint256 queueLast = uintStorage[QUEUE_NV_LAST];

        if (queueLast < queueFirst) {
            newValidator = address(0);
        } else {
            bytes32 hash = keccak256(abi.encode(QUEUE_NV_LIST, queueFirst));
            newValidator = addressStorage[hash];
            delete addressStorage[hash];
            uintStorage[QUEUE_NV_FIRST]++;
        }
    }

    function _enqueueNewValidator(address _newValidator) internal {
        addressStorage[keccak256(abi.encode(QUEUE_NV_LIST, ++uintStorage[QUEUE_NV_LAST]))] = _newValidator;
    }

    function _getNativeRewardUndistributed() internal view returns(uint256) {
        return uintStorage[NATIVE_REWARD_UNDISTRIBUTED];
    }

    function _getRoundPoolNativeReward() internal view returns(uint256) {
        return uintStorage[ROUND_POOL_NATIVE_REWARD];
    }

    function _getRoundPoolTokenReward() internal view returns(uint256) {
        return uintStorage[ROUND_POOL_TOKEN_REWARD];
    }

    function _getTokenRewardUndistributed() internal view returns(uint256) {
        return uintStorage[TOKEN_REWARD_UNDISTRIBUTED];
    }

    function _setNativeRewardUndistributed(uint256 _reward) internal {
        uintStorage[NATIVE_REWARD_UNDISTRIBUTED] = _reward;
    }

    function _setRoundPoolNativeReward(uint256 _poolReward) internal {
        uintStorage[ROUND_POOL_NATIVE_REWARD] = _poolReward;
    }

    function _setRoundPoolTokenReward(uint256 _poolReward) internal {
        uintStorage[ROUND_POOL_TOKEN_REWARD] = _poolReward;
    }

    function _setTokenRewardUndistributed(uint256 _reward) internal {
        uintStorage[TOKEN_REWARD_UNDISTRIBUTED] = _reward;
    }

    function _subNativeRewardUndistributed(uint256 _minus) internal {
        uintStorage[NATIVE_REWARD_UNDISTRIBUTED] -= _minus;
    }

    function _subTokenRewardUndistributed(uint256 _minus) internal {
        uintStorage[TOKEN_REWARD_UNDISTRIBUTED] -= _minus;
    }

    bytes32 internal constant NATIVE_REWARD_UNDISTRIBUTED = keccak256("nativeRewardUndistributed");
    bytes32 internal constant PREVIOUS_VALIDATOR_INDEX = keccak256("previousValidatorIndex");
    bytes32 internal constant QUEUE_NV_FIRST = keccak256("queueNVFirst");
    bytes32 internal constant QUEUE_NV_LAST = keccak256("queueNVLast");
    bytes32 internal constant REWARD_TEMPORARY_ARRAY = keccak256("rewardTemporaryArray");
    bytes32 internal constant ROUND_POOL_NATIVE_REWARD = keccak256("roundPoolNativeReward");
    bytes32 internal constant ROUND_POOL_TOKEN_REWARD = keccak256("roundPoolTokenReward");
    bytes32 internal constant TOKEN_REWARD_UNDISTRIBUTED = keccak256("tokenRewardUndistributed");

    bytes32 internal constant QUEUE_NV_LIST = "queueNVList";

}
