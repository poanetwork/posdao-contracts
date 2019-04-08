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
        } else if (stakingContract.stakingEpoch() != 0) {
            bool noop;
            (receiversNative, rewardsNative, noop) = _distributeRewards(
                validatorSetContract,
                stakingContract.erc20TokenContract(),
                IStakingAuRa(address(stakingContract))
            );
            if (!noop) {
                bridgeQueueLimit = 25;
            }
        }

        // Mint native coins by bridge if needed.
        return _mintNativeCoinsByErcToNativeBridge(receiversNative, rewardsNative, bridgeQueueLimit);
    }

    // =============================================== Getters ========================================================

    function getEpochPoolNativeReward() public view returns(uint256) {
        return uintStorage[EPOCH_POOL_NATIVE_REWARD];
    }

    function getEpochPoolTokenReward() public view returns(uint256) {
        return uintStorage[EPOCH_POOL_TOKEN_REWARD];
    }

    function getNativeRewardUndistributed() public view returns(uint256) {
        return uintStorage[NATIVE_REWARD_UNDISTRIBUTED];
    }

    function getTokenRewardUndistributed() public view returns(uint256) {
        return uintStorage[TOKEN_REWARD_UNDISTRIBUTED];
    }

    // =============================================== Private ========================================================

    bytes32 internal constant EPOCH_POOL_NATIVE_REWARD = keccak256("epochPoolNativeReward");
    bytes32 internal constant EPOCH_POOL_TOKEN_REWARD = keccak256("epochPoolTokenReward");
    bytes32 internal constant NATIVE_REWARD_UNDISTRIBUTED = keccak256("nativeRewardUndistributed");
    bytes32 internal constant QUEUE_V_FIRST = keccak256("queueVFirst");
    bytes32 internal constant QUEUE_V_INITIALIZED = keccak256("queueVInitialized");
    bytes32 internal constant QUEUE_V_LAST = keccak256("queueVLast");
    bytes32 internal constant TOKEN_REWARD_UNDISTRIBUTED = keccak256("tokenRewardUndistributed");

    bytes32 internal constant QUEUE_V_LIST = "queueVList";

    function _distributeRewards(
        IValidatorSet _validatorSetContract,
        address _erc20TokenContract,
        IStakingAuRa _stakingContract
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

            uint256 poolReward;
            uint256 totalReward;

            poolReward = 0;
            totalReward = uintStorage[BRIDGE_TOKEN_FEE];
            // Accumulated bridge fee plus 1% per year inflation
            totalReward += snapshotTotalStakeAmount() * _stakingContract.stakingEpochDuration() / 630720000;
            if (totalReward != 0) {
                uintStorage[BRIDGE_TOKEN_FEE] = 0;

                totalReward += uintStorage[TOKEN_REWARD_UNDISTRIBUTED];

                if (validators.length != 0) {
                    poolReward = totalReward / validators.length;
                }

                uintStorage[TOKEN_REWARD_UNDISTRIBUTED] = totalReward;
            }
            if (_erc20TokenContract == address(0)) {
                poolReward = 0;
            }
            uintStorage[EPOCH_POOL_TOKEN_REWARD] = poolReward;

            poolReward = 0;
            totalReward = uintStorage[BRIDGE_NATIVE_FEE];
            if (totalReward != 0) {
                uintStorage[BRIDGE_NATIVE_FEE] = 0;

                totalReward += uintStorage[NATIVE_REWARD_UNDISTRIBUTED];

                if (validators.length != 0) {
                    poolReward = totalReward / validators.length;
                }

                uintStorage[NATIVE_REWARD_UNDISTRIBUTED] = totalReward;
            }
            uintStorage[EPOCH_POOL_NATIVE_REWARD] = poolReward;

            if (uintStorage[EPOCH_POOL_TOKEN_REWARD] != 0 || uintStorage[EPOCH_POOL_NATIVE_REWARD] != 0) {
                for (i = 0; i < validators.length; i++) {
                    _enqueueValidator(_validatorSetContract.stakingByMiningAddress(validators[i]));
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

            uint256 queueSize = _validatorsQueueSize();

            if (queueSize == 0) {
                boolStorage[IS_REWARDING] = false;
            }

            if (_validatorSetContract.isValidatorBanned(_validatorSetContract.miningByStakingAddress(stakingAddress))) {
                return (receivers, rewards, true);
            }

            address[] storage stakers = addressArrayStorage[keccak256(abi.encode(SNAPSHOT_STAKERS, stakingAddress))];
            uint256 offset = (queueSize + 1) % DELEGATORS_ALIQUOT;
            uint256 from = stakers.length / DELEGATORS_ALIQUOT * offset;
            uint256 to = stakers.length / DELEGATORS_ALIQUOT * (offset + 1);

            if (offset == 0) {
                to += stakers.length % DELEGATORS_ALIQUOT;
            } else {
                from += stakers.length % DELEGATORS_ALIQUOT;
            }

            if (to <= from) {
                if (queueSize == 0) {
                    uintStorage[EPOCH_POOL_TOKEN_REWARD] = 0;
                    uintStorage[EPOCH_POOL_NATIVE_REWARD] = 0;
                }
                return (receivers, rewards, true);
            }

            uint256[] storage rewardPercents = uintArrayStorage[keccak256(abi.encode(
                SNAPSHOT_REWARD_PERCENTS, stakingAddress
            ))];
            uint256 accrued;

            receivers = new address[](to - from);
            rewards = new uint256[](receivers.length);

            if (uintStorage[EPOCH_POOL_TOKEN_REWARD] != 0) {
                accrued = 0;
                for (i = from; i < to; i++) {
                    j = i - from;
                    receivers[j] = stakers[i];
                    rewards[j] = uintStorage[EPOCH_POOL_TOKEN_REWARD] * rewardPercents[i] / REWARD_PERCENT_MULTIPLIER;
                    accrued += rewards[j];
                }
                IERC20Minting(_erc20TokenContract).mintReward(receivers, rewards);
                _subTokenRewardUndistributed(accrued);
                noop = false;
            }

            if (uintStorage[EPOCH_POOL_NATIVE_REWARD] == 0) {
                if (queueSize == 0) {
                    uintStorage[EPOCH_POOL_TOKEN_REWARD] = 0;
                }
                return (new address[](0), new uint256[](0), noop);
            }

            accrued = 0;
            for (i = from; i < to; i++) {
                j = i - from;
                receivers[j] = stakers[i];
                rewards[j] = uintStorage[EPOCH_POOL_NATIVE_REWARD] * rewardPercents[i] / REWARD_PERCENT_MULTIPLIER;
                accrued += rewards[j];
            }
            _subNativeRewardUndistributed(accrued);
            noop = false;

            if (queueSize == 0) {
                uintStorage[EPOCH_POOL_TOKEN_REWARD] = 0;
                uintStorage[EPOCH_POOL_NATIVE_REWARD] = 0;
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
