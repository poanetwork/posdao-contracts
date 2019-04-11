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

        // Initialize queues
        if (!boolStorage[QUEUE_V_INITIALIZED]) {
            uintStorage[QUEUE_V_FIRST] = 1;
            uintStorage[QUEUE_V_LAST] = 0;
            boolStorage[QUEUE_V_INITIALIZED] = true;
        }
        if (!boolStorage[QUEUE_ER_INITIALIZED]) {
            uintStorage[QUEUE_ER_FIRST] = 1;
            uintStorage[QUEUE_ER_LAST] = 0;
            boolStorage[QUEUE_ER_INITIALIZED] = true;
        }

        IStaking stakingContract = IStaking(validatorSetContract.stakingContract());
        address[] memory receiversNative = new address[](0);
        uint256[] memory rewardsNative = new uint256[](0);
        uint256 bridgeQueueLimit = 50;
        uint256 stakingEpoch = stakingContract.stakingEpoch();

        if (validatorSetContract.validatorSetApplyBlock() != 0) {
            uintStorage[keccak256(abi.encode(BLOCKS_CREATED, stakingEpoch, benefactors[0]))]++;
        }

        // Start new staking epoch every `stakingEpochDuration()` blocks
        (bool newValidatorSetCalled, uint256 poolsToBeElectedLength) = validatorSetContract.newValidatorSet();

        if (newValidatorSetCalled) {
            address[] memory newValidatorSet = validatorSetContract.getPendingValidators();

            for (uint256 i = 0; i < newValidatorSet.length; i++) {
                address stakingAddress = validatorSetContract.stakingByMiningAddress(newValidatorSet[i]);

                _enqueueValidator(stakingAddress);

                delete addressArrayStorage[keccak256(abi.encode(SNAPSHOT_STAKERS, stakingAddress))];
                delete uintArrayStorage[keccak256(abi.encode(SNAPSHOT_REWARD_PERCENTS, stakingAddress))];
            }

            delete addressArrayStorage[SNAPSHOT_STAKING_ADDRESSES];
            uintStorage[SNAPSHOT_TOTAL_STAKE_AMOUNT] = 0;
            boolStorage[IS_SNAPSHOTTING] = (newValidatorSet.length != 0);

            if (poolsToBeElectedLength > 1000) {
                bridgeQueueLimit = 0;
            } else if (poolsToBeElectedLength > 500) {
                bridgeQueueLimit = 15;
            } else {
                bridgeQueueLimit = 25;
            }
        } else if (boolStorage[IS_SNAPSHOTTING]) {
            address stakingAddress = _dequeueValidator();

            if (stakingAddress != address(0)) {
                uint256 validatorsQueueSize = _validatorsQueueSize();
                _setSnapshot(stakingAddress, stakingContract, (validatorsQueueSize + 1) % DELEGATORS_ALIQUOT);
                if (validatorsQueueSize == 0) {
                    boolStorage[IS_SNAPSHOTTING] = false;
                }
                bridgeQueueLimit = 25;
            }
        } else if (stakingEpoch != 0) {
            bool noop;
            (receiversNative, rewardsNative, noop) = _distributeRewards(
                validatorSetContract,
                stakingContract.erc20TokenContract(),
                IStakingAuRa(address(stakingContract)),
                stakingEpoch
            );
            if (!noop) {
                bridgeQueueLimit = 25;
            }
        }

        // Mint native coins by bridge if needed.
        return _mintNativeCoinsByErcToNativeBridge(receiversNative, rewardsNative, bridgeQueueLimit);
    }

    // =============================================== Getters ========================================================

    function getBlocksCreated(
        uint256 _stakingEpoch,
        address _validatorMiningAddress
    ) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(BLOCKS_CREATED, _stakingEpoch, _validatorMiningAddress))];
    }

    function getEpochPoolNativeReward(
        uint256 _stakingEpoch,
        address _poolStakingAddress
    ) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(
            EPOCH_POOL_NATIVE_REWARD, _stakingEpoch, _poolStakingAddress
        ))];
    }

    function getEpochPoolTokenReward(
        uint256 _stakingEpoch,
        address _poolStakingAddress
    ) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(
            EPOCH_POOL_TOKEN_REWARD, _stakingEpoch, _poolStakingAddress
        ))];
    }

    function getNativeRewardUndistributed() public view returns(uint256) {
        return uintStorage[NATIVE_REWARD_UNDISTRIBUTED];
    }

    function getTokenRewardUndistributed() public view returns(uint256) {
        return uintStorage[TOKEN_REWARD_UNDISTRIBUTED];
    }

    // =============================================== Private ========================================================

    bytes32 internal constant NATIVE_REWARD_UNDISTRIBUTED = keccak256("nativeRewardUndistributed");
    bytes32 internal constant QUEUE_V_FIRST = keccak256("queueVFirst");
    bytes32 internal constant QUEUE_V_INITIALIZED = keccak256("queueVInitialized");
    bytes32 internal constant QUEUE_V_LAST = keccak256("queueVLast");
    bytes32 internal constant TOKEN_REWARD_UNDISTRIBUTED = keccak256("tokenRewardUndistributed");

    bytes32 internal constant BLOCKS_CREATED = "blocksCreated";
    bytes32 internal constant EPOCH_POOL_NATIVE_REWARD = "epochPoolNativeReward";
    bytes32 internal constant EPOCH_POOL_TOKEN_REWARD = "epochPoolTokenReward";
    bytes32 internal constant QUEUE_V_LIST = "queueVList";

    function _distributeRewards(
        IValidatorSet _validatorSetContract,
        address _erc20TokenContract,
        IStakingAuRa _stakingContract,
        uint256 _stakingEpoch
    ) internal returns(address[] memory receivers, uint256[] memory rewards, bool noop) {
        uint256 i;
        uint256 j;
        uint256 rewardPointBlock =
            _stakingContract.stakingEpochEndBlock() - _validatorSetContract.MAX_VALIDATORS() * DELEGATORS_ALIQUOT - 1;

        receivers = new address[](0);
        rewards = new uint256[](0);
        noop = true;

        if (block.number == rewardPointBlock - 1) {
            boolStorage[IS_REWARDING] = true;
        } else if (block.number == rewardPointBlock) {
            address[] memory validators = _validatorSetContract.getValidators();
            uint256[] memory ratio = new uint256[](validators.length);

            uint256 totalReward;
            bool isRewarding = false;

            totalReward = uintStorage[BRIDGE_TOKEN_FEE];
            // Accumulated bridge fee plus 1% per year inflation
            totalReward += snapshotTotalStakeAmount() * _stakingContract.stakingEpochDuration() / 630720000;
            if (totalReward != 0 && _erc20TokenContract != address(0) || uintStorage[BRIDGE_NATIVE_FEE] != 0) {
                j = 0;
                for (i = 0; i < validators.length; i++) {
                    ratio[i] = uintStorage[keccak256(abi.encode(
                        BLOCKS_CREATED, _stakingEpoch, validators[i]
                    ))];
                    j += ratio[i];
                    validators[i] = _validatorSetContract.stakingByMiningAddress(validators[i]);
                }
                if (j != 0) {
                    for (i = 0; i < validators.length; i++) {
                        ratio[i] = ratio[i] * REWARD_PERCENT_MULTIPLIER / j;
                    }
                }
            }
            if (totalReward != 0) {
                uintStorage[BRIDGE_TOKEN_FEE] = 0;

                totalReward += uintStorage[TOKEN_REWARD_UNDISTRIBUTED];

                if (_erc20TokenContract != address(0)) {
                    for (i = 0; i < validators.length; i++) {
                        uintStorage[keccak256(abi.encode(
                            EPOCH_POOL_TOKEN_REWARD, _stakingEpoch, validators[i]
                        ))] = totalReward * ratio[i] / REWARD_PERCENT_MULTIPLIER;
                    }
                    isRewarding = true;
                }

                uintStorage[TOKEN_REWARD_UNDISTRIBUTED] = totalReward;
            }

            totalReward = uintStorage[BRIDGE_NATIVE_FEE];
            if (totalReward != 0) {
                uintStorage[BRIDGE_NATIVE_FEE] = 0;

                totalReward += uintStorage[NATIVE_REWARD_UNDISTRIBUTED];

                for (i = 0; i < validators.length; i++) {
                    uintStorage[keccak256(abi.encode(
                        EPOCH_POOL_NATIVE_REWARD, _stakingEpoch, validators[i]
                    ))] = totalReward * ratio[i] / REWARD_PERCENT_MULTIPLIER;
                }
                isRewarding = true;

                uintStorage[NATIVE_REWARD_UNDISTRIBUTED] = totalReward;
            }

            if (isRewarding) {
                for (i = 0; i < validators.length; i++) {
                    _enqueueValidator(validators[i]);
                }
                if (validators.length == 0) {
                    boolStorage[IS_REWARDING] = false;
                }
            } else {
                boolStorage[IS_REWARDING] = false;
            }

            noop = false;
        } else if (block.number > rewardPointBlock) {
            address stakingAddress = _dequeueValidator();

            if (stakingAddress == address(0)) {
                return (receivers, rewards, true);
            }

            if (_validatorsQueueSize() == 0) {
                boolStorage[IS_REWARDING] = false;
            }

            if (_validatorSetContract.isValidatorBanned(_validatorSetContract.miningByStakingAddress(stakingAddress))) {
                return (receivers, rewards, true);
            }

            address[] storage stakers = addressArrayStorage[keccak256(abi.encode(SNAPSHOT_STAKERS, stakingAddress))];
            uint256[] memory range = new uint256[](3);
            range[0] = (_validatorsQueueSize() + 1) % DELEGATORS_ALIQUOT; // offset
            range[1] = stakers.length / DELEGATORS_ALIQUOT * range[0]; // from
            range[2] = stakers.length / DELEGATORS_ALIQUOT * (range[0] + 1); // to

            if (range[0] == 0) {
                range[2] += stakers.length % DELEGATORS_ALIQUOT;
            } else {
                range[1] += stakers.length % DELEGATORS_ALIQUOT;
            }

            if (range[1] >= range[2]) {
                return (receivers, rewards, true);
            }

            uint256[] storage rewardPercents = uintArrayStorage[keccak256(abi.encode(
                SNAPSHOT_REWARD_PERCENTS, stakingAddress
            ))];
            uint256 accrued;
            uint256 poolReward;

            receivers = new address[](range[2] - range[1]);
            rewards = new uint256[](receivers.length);

            poolReward = uintStorage[keccak256(abi.encode(
                EPOCH_POOL_TOKEN_REWARD, _stakingEpoch, stakingAddress
            ))];
            if (poolReward != 0) {
                accrued = 0;
                for (i = range[1]; i < range[2]; i++) {
                    j = i - range[1];
                    receivers[j] = stakers[i];
                    rewards[j] = poolReward * rewardPercents[i] / REWARD_PERCENT_MULTIPLIER;
                    accrued += rewards[j];
                }
                IERC20Minting(_erc20TokenContract).mintReward(receivers, rewards);
                _subTokenRewardUndistributed(accrued);
                noop = false;
            }

            poolReward = uintStorage[keccak256(abi.encode(
                EPOCH_POOL_NATIVE_REWARD, _stakingEpoch, stakingAddress
            ))];
            if (poolReward != 0) {
                accrued = 0;
                for (i = range[1]; i < range[2]; i++) {
                    j = i - range[1];
                    receivers[j] = stakers[i];
                    rewards[j] = poolReward * rewardPercents[i] / REWARD_PERCENT_MULTIPLIER;
                    accrued += rewards[j];
                }
                _subNativeRewardUndistributed(accrued);
                noop = false;
            } else {
                return (new address[](0), new uint256[](0), noop);
            }
        }
    }

    function _dequeueValidator() internal returns(address newValidator) {
        uint256 queueFirst = uintStorage[QUEUE_V_FIRST];
        uint256 queueLast = uintStorage[QUEUE_V_LAST];

        if (queueLast < queueFirst) {
            newValidator = address(0);
        } else {
            bytes32 hash = keccak256(abi.encode(QUEUE_V_LIST, queueFirst));
            newValidator = addressStorage[hash];
            delete addressStorage[hash];
            uintStorage[QUEUE_V_FIRST]++;
        }
    }

    function _enqueueValidator(address _newValidator) internal {
        uint256 queueLast = uintStorage[QUEUE_V_LAST];
        for (uint256 i = 0; i < DELEGATORS_ALIQUOT; i++) {
            addressStorage[keccak256(abi.encode(QUEUE_V_LIST, ++queueLast))] = _newValidator;
        }
        uintStorage[QUEUE_V_LAST] = queueLast;
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

    function _validatorsQueueSize() internal view returns(uint256) {
        return uintStorage[QUEUE_V_LAST] + 1 - uintStorage[QUEUE_V_FIRST];
    }

}
