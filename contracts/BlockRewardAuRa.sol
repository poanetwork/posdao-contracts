pragma solidity 0.5.2;

import "./abstracts/BlockRewardBase.sol";
import "./interfaces/IERC20Minting.sol";
import "./interfaces/IRandomAuRa.sol";
import "./interfaces/IStakingAuRa.sol";
import "./interfaces/IValidatorSetAuRa.sol";


contract BlockRewardAuRa is BlockRewardBase {

    function reward(address[] calldata benefactors, uint16[] calldata kind)
        external
        onlySystem
        returns(address[] memory, uint256[] memory)
    {
        if (benefactors.length != kind.length || benefactors.length != 1 || kind[0] != 0) {
            return (new address[](0), new uint256[](0));
        }

        IValidatorSet validatorSetContract = IValidatorSet(VALIDATOR_SET_CONTRACT);

        // Check if the validator is existed
        if (!validatorSetContract.isValidator(benefactors[0])) {
            return (new address[](0), new uint256[](0));
        }

        // Publish current random number at the end of the current collection round.
        // Remove malicious validators if any.
        IRandomAuRa(validatorSetContract.randomContract()).onFinishCollectRound();

        IStaking stakingContract = IStaking(validatorSetContract.stakingContract());

        // Perform ordered withdrawals at the starting of a new staking epoch
        stakingContract.performOrderedWithdrawals();

        if (!boolStorage[QUEUE_NV_INITIALIZED]) {
            uintStorage[QUEUE_NV_FIRST] = 1;
            uintStorage[QUEUE_NV_LAST] = 0;
            boolStorage[QUEUE_NV_INITIALIZED] = true;
        }
        if (!boolStorage[QUEUE_ER_INITIALIZED]) {
            uintStorage[QUEUE_ER_FIRST] = 1;
            uintStorage[QUEUE_ER_LAST] = 0;
            boolStorage[QUEUE_ER_INITIALIZED] = true;
        }

        address[] memory receiversNative = new address[](0);
        uint256[] memory rewardsNative = new uint256[](0);
        uint256 i;

        if (validatorSetContract.newValidatorSet()) {
            // Start new staking epoch every `stakingEpochDuration()` blocks
            address[] memory newValidatorSet = validatorSetContract.getPendingValidators();

            for (i = 0; i < newValidatorSet.length; i++) {
                _enqueueNewValidator(newValidatorSet[i]);
            }

            delete addressArrayStorage[SNAPSHOT_STAKING_ADDRESSES];
            uintStorage[SNAPSHOT_TOTAL_STAKE_AMOUNT] = 0;
            uintStorage[ROUND_POOL_NATIVE_REWARD] = 0;
            uintStorage[ROUND_POOL_TOKEN_REWARD] = 0;
        } else if (validatorSetContract.validatorSetApplyBlock() == 0) {
            address newValidator = _dequeueNewValidator();

            if (newValidator != address(0)) {
                _setSnapshot(validatorSetContract.stakingByMiningAddress(newValidator), stakingContract);
            } else if (!pendingValidatorsEnqueued()) {
                IValidatorSetAuRa(VALIDATOR_SET_CONTRACT).enqueuePendingValidators();
                _setPendingValidatorsEnqueued(true);
            }
        } else if (stakingContract.stakingEpoch() != 0) {
            (receiversNative, rewardsNative) = _distributeRewards(
                benefactors[0],
                stakingContract.erc20TokenContract(),
                IStakingAuRa(address(stakingContract))
            );
        }

        uintStorage[PREVIOUS_VALIDATOR_INDEX] = validatorSetContract.validatorIndex(benefactors[0]);

        // Mint native coins by bridge if needed.
        return _mintNativeCoinsByErcToNativeBridge(receiversNative, rewardsNative);
    }

    function getNativeRewardUndistributed() public view returns(uint256) {
        return uintStorage[NATIVE_REWARD_UNDISTRIBUTED];
    }

    function getRoundPoolNativeReward() public view returns(uint256) {
        return uintStorage[ROUND_POOL_NATIVE_REWARD];
    }

    function getRoundPoolTokenReward() public view returns(uint256) {
        return uintStorage[ROUND_POOL_TOKEN_REWARD];
    }

    function getTokenRewardUndistributed() public view returns(uint256) {
        return uintStorage[TOKEN_REWARD_UNDISTRIBUTED];
    }

    function _distributeRewards(
        address _miningAddress,
        address _erc20TokenContract,
        IStakingAuRa _stakingContract
    ) internal returns(address[] memory receivers, uint256[] memory rewards) {
        uint256 poolTokenReward = 0;
        uint256 poolNativeReward = 0;

        if (
            IValidatorSet(VALIDATOR_SET_CONTRACT).validatorIndex(_miningAddress) <=
            uintStorage[PREVIOUS_VALIDATOR_INDEX]
        ) {
            // New Authority Round started

            uint256 poolsCount = IValidatorSet(VALIDATOR_SET_CONTRACT).getValidators().length;

            if (block.number + poolsCount > _stakingContract.stakingEpochEndBlock()) {
                // Don't distribute rewards during the last incomplete Authority Round
                // in the current staking epoch
                uintStorage[ROUND_POOL_NATIVE_REWARD] = 0;
                uintStorage[ROUND_POOL_TOKEN_REWARD] = 0;
                return (new address[](0), new uint256[](0));
            }

            uint256 totalReward;

            if (_erc20TokenContract != address(0)) {
                totalReward = uintStorage[BRIDGE_TOKEN_FEE];
                totalReward += snapshotTotalStakeAmount() * 1585489599 / 1 ether; // 1% per year inflation
                if (totalReward != 0) {
                    uintStorage[BRIDGE_TOKEN_FEE] = 0;

                    totalReward += uintStorage[TOKEN_REWARD_UNDISTRIBUTED];
                    poolTokenReward = totalReward / poolsCount;

                    uintStorage[TOKEN_REWARD_UNDISTRIBUTED] = totalReward;
                }
                uintStorage[ROUND_POOL_TOKEN_REWARD] = poolTokenReward;
            }

            totalReward = uintStorage[BRIDGE_NATIVE_FEE];
            if (totalReward != 0) {
                uintStorage[BRIDGE_NATIVE_FEE] = 0;

                totalReward += uintStorage[NATIVE_REWARD_UNDISTRIBUTED];
                poolNativeReward = totalReward / poolsCount;

                uintStorage[NATIVE_REWARD_UNDISTRIBUTED] = totalReward;
            }
            uintStorage[ROUND_POOL_NATIVE_REWARD] = poolNativeReward;
        } else {
            poolTokenReward = uintStorage[ROUND_POOL_TOKEN_REWARD];
            poolNativeReward = uintStorage[ROUND_POOL_NATIVE_REWARD];
        }

        if (poolTokenReward == 0 && poolNativeReward == 0) {
            return (new address[](0), new uint256[](0));
        }

        address validatorStakingAddress = IValidatorSet(VALIDATOR_SET_CONTRACT).stakingByMiningAddress(_miningAddress);

        receivers = addressArrayStorage[keccak256(abi.encode(SNAPSHOT_STAKERS, validatorStakingAddress))];
        rewards = new uint256[](receivers.length);
        uint256[] storage rewardPercents = uintArrayStorage[
            keccak256(abi.encode(SNAPSHOT_REWARD_PERCENTS, validatorStakingAddress))
        ];

        if (rewardPercents.length != 0) {
            uint256 remainder;
            uint256 i;

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

            if (poolNativeReward != 0) {
                remainder = poolNativeReward;

                for (i = 0; i < rewardPercents.length; i++) {
                    rewards[i] = poolNativeReward * rewardPercents[i] / REWARD_PERCENT_MULTIPLIER;
                    remainder -= rewards[i];
                }
                rewards[i - 1] += remainder;

                _subNativeRewardUndistributed(poolNativeReward);
            } else {
                return (new address[](0), new uint256[](0));
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

    function _subNativeRewardUndistributed(uint256 _minus) internal {
        if (uintStorage[NATIVE_REWARD_UNDISTRIBUTED] < _minus) {
            uintStorage[NATIVE_REWARD_UNDISTRIBUTED] = 0;
        } else {
            uintStorage[NATIVE_REWARD_UNDISTRIBUTED] -= _minus;
        }
    }

    function _subTokenRewardUndistributed(uint256 _minus) internal {
        if (uintStorage[TOKEN_REWARD_UNDISTRIBUTED] < _minus) {
            uintStorage[TOKEN_REWARD_UNDISTRIBUTED] = 0;
        } else {
            uintStorage[TOKEN_REWARD_UNDISTRIBUTED] -= _minus;
        }
    }

    bytes32 internal constant NATIVE_REWARD_UNDISTRIBUTED = keccak256("nativeRewardUndistributed");
    bytes32 internal constant PREVIOUS_VALIDATOR_INDEX = keccak256("previousValidatorIndex");
    bytes32 internal constant QUEUE_NV_FIRST = keccak256("queueNVFirst");
    bytes32 internal constant QUEUE_NV_INITIALIZED = keccak256("queueNVInitialized");
    bytes32 internal constant QUEUE_NV_LAST = keccak256("queueNVLast");
    bytes32 internal constant ROUND_POOL_NATIVE_REWARD = keccak256("roundPoolNativeReward");
    bytes32 internal constant ROUND_POOL_TOKEN_REWARD = keccak256("roundPoolTokenReward");
    bytes32 internal constant TOKEN_REWARD_UNDISTRIBUTED = keccak256("tokenRewardUndistributed");

    bytes32 internal constant QUEUE_NV_LIST = "queueNVList";

}
