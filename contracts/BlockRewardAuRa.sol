pragma solidity 0.5.7;

import "./abstracts/BlockRewardBase.sol";
import "./interfaces/IERC20Minting.sol";
import "./interfaces/IRandomAuRa.sol";
import "./interfaces/IStakingAuRa.sol";
import "./interfaces/IValidatorSetAuRa.sol";


/// @dev Generates and distributes rewards according to the logic and formulas described in the white paper.
contract BlockRewardAuRa is BlockRewardBase {

    /// @dev Called by the validator's node when producing and closing a block,
    /// see https://wiki.parity.io/Block-Reward-Contract.html.
    /// This function performs all of the automatic operations needed for controlling secrets revealing by validators,
    /// accumulating block producing statistics, starting a new staking epoch, snapshotting reward coefficients 
    /// at the beginning of a new staking epoch, rewards distributing at the end of a staking epoch, and minting
    /// native coins needed for the `erc-to-native` bridge.
    function reward(address[] calldata benefactors, uint16[] calldata kind)
        external
        onlySystem
        returns(address[] memory receiversNative, uint256[] memory rewardsNative)
    {
        if (benefactors.length != kind.length || benefactors.length != 1 || kind[0] != 0) {
            return (new address[](0), new uint256[](0));
        }

        IValidatorSet validatorSetContract = IValidatorSet(VALIDATOR_SET_CONTRACT);

        // Check if the validator is existed
        if (!validatorSetContract.isValidator(benefactors[0])) {
            return (new address[](0), new uint256[](0));
        }

        receiversNative = new address[](0);
        rewardsNative = new uint256[](0);

        // Check the current validators at the end of each collection round whether
        // they revealed their secrets, and remove a validator as a malicious if needed
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
        uint256 bridgeQueueLimit = 50;
        uint256 stakingEpoch = stakingContract.stakingEpoch();
        uint256 rewardPointBlock = _rewardPointBlock(IStakingAuRa(address(stakingContract)), validatorSetContract);

        if (validatorSetContract.validatorSetApplyBlock() != 0 && block.number <= rewardPointBlock) {
            if (stakingEpoch != 0) {
                // Accumulate blocks producing statistics for each of the
                // active validators during the current staking epoch
                uintStorage[keccak256(abi.encode(BLOCKS_CREATED, stakingEpoch, benefactors[0]))]++;
            }
        }

        // Start a new staking epoch every `stakingEpochDuration()` blocks
        (bool newStakingEpochHasBegun, uint256 poolsToBeElectedLength) = validatorSetContract.newValidatorSet();

        if (newStakingEpochHasBegun) {
            // A new staking epoch has begun, so prepare for reward coefficients snapshotting
            // process which begins right from the following block
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
            // Snapshot reward coefficients for each new validator and their delegators
            // during the very first blocks of a new staking epoch
            address stakingAddress = _dequeueValidator();

            if (stakingAddress != address(0)) {
                uint256 validatorsQueueSize = _validatorsQueueSize();
                _setSnapshot(stakingAddress, stakingContract, (validatorsQueueSize + 1) % DELEGATORS_ALIQUOT);
                if (validatorsQueueSize == 0) {
                    // Snapshotting process has been finished
                    boolStorage[IS_SNAPSHOTTING] = false;
                }
                bridgeQueueLimit = 25;
            }
        } else if (stakingEpoch != 0) {
            // Distribute rewards at the end of staking epoch during the last
            // MAX_VALIDATORS * DELEGATORS_ALIQUOT blocks
            bool noop;
            (receiversNative, rewardsNative, noop) = _distributeRewards(
                validatorSetContract,
                stakingContract.erc20TokenContract(),
                IStakingAuRa(address(stakingContract)),
                stakingEpoch,
                rewardPointBlock
            );
            if (!noop) {
                bridgeQueueLimit = 25;
            }
        }

        // Mint native coins if needed
        return _mintNativeCoinsByErcToNativeBridge(receiversNative, rewardsNative, bridgeQueueLimit);
    }

    // =============================================== Getters ========================================================

    /// @dev Returns a number of blocks produced by the specified validator during the specified staking epoch
    /// (beginning from the block when the `finalizeChange` function is called until the block specified by the
    /// `_rewardPointBlock` function). The results are used by the `_distributeRewards` function to track
    /// each validator's downtime (when a validator's node is not running and doesn't produce blocks).
    /// @param _stakingEpoch The number of the staking epoch for which the statistics should be returned.
    /// @param _validatorMiningAddress The mining address of the validator for which the statistics should be returned.
    function getBlocksCreated(
        uint256 _stakingEpoch,
        address _validatorMiningAddress
    ) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(BLOCKS_CREATED, _stakingEpoch, _validatorMiningAddress))];
    }

    /// @dev Returns the reward amount to be distributed in native coins among participants (the validator and their
    /// delegators) of the specified pool at the end of the specified staking epoch.
    /// @param _stakingEpoch The number of the staking epoch for which the amount should be returned.
    /// @param _poolStakingAddress The staking address of the pool for which the amount should be returned.
    function getEpochPoolNativeReward(
        uint256 _stakingEpoch,
        address _poolStakingAddress
    ) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(
            EPOCH_POOL_NATIVE_REWARD, _stakingEpoch, _poolStakingAddress
        ))];
    }

    /// @dev Returns the reward amount to be distributed in staking tokens among participants (the validator and their
    /// delegators) of the specified pool at the end of the specified staking epoch.
    /// @param _stakingEpoch The number of the staking epoch for which the amount should be returned.
    /// @param _poolStakingAddress The staking address of the pool for which the amount should be returned.
    function getEpochPoolTokenReward(
        uint256 _stakingEpoch,
        address _poolStakingAddress
    ) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(
            EPOCH_POOL_TOKEN_REWARD, _stakingEpoch, _poolStakingAddress
        ))];
    }

    /// @dev Returns the total reward amount in native coins which is not yet distributed among participants.
    function getNativeRewardUndistributed() public view returns(uint256) {
        return uintStorage[NATIVE_REWARD_UNDISTRIBUTED];
    }

    /// @dev Returns the total reward amount in staking tokens which is not yet distributed among participants.
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

    /// @dev Distributes rewards among participants during the last MAX_VALIDATORS * DELEGATORS_ALIQUOT
    /// blocks of a staking epoch. This function is called by the `reward` function.
    /// @param _validatorSetContract The address of the ValidatorSet contract.
    /// @param _erc20TokenContract The address of the ERC20 staking token contract.
    /// @param _stakingContract The address of the Staking contract.
    /// @param _stakingEpoch The number of the current staking epoch.
    /// @param _rewardPointBlock The number of the block within the current staking epoch when the rewarding process
    /// should start. This number is calculated by the `_rewardPointBlock` getter.
    /// @return receivers The array of fee receivers (the fee is in native coins) which should be rewarded at the
    /// current block by the `erc-to-native` bridge.
    /// @return rewards The array of amounts corresponding to the `receivers` array.
    /// @return noop The boolean flag which is set to `true` when there are no complex operations during the
    /// function launch. The flag is used by the `reward` function to control the load on the block inside the
    /// `_mintNativeCoinsByErcToNativeBridge` function.
    function _distributeRewards(
        IValidatorSet _validatorSetContract,
        address _erc20TokenContract,
        IStakingAuRa _stakingContract,
        uint256 _stakingEpoch,
        uint256 _rewardPointBlock
    ) internal returns(address[] memory receivers, uint256[] memory rewards, bool noop) {
        uint256 i;
        uint256 j;

        receivers = new address[](0);
        rewards = new uint256[](0);
        noop = true;

        if (block.number == _rewardPointBlock - 1) {
            boolStorage[IS_REWARDING] = true;
        } else if (block.number == _rewardPointBlock) {
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
        } else if (block.number > _rewardPointBlock) {
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
            uint256[] memory range = new uint256[](3); // array instead of local vars because the stack is too deep
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

    /// @dev Dequeues a validator enqueued for the snapshotting or rewarding process.
    /// Used by the `reward` and `_distributeRewards` functions.
    /// If the queue is empty, the function returns a zero address.
    function _dequeueValidator() internal returns(address validatorStakingAddress) {
        uint256 queueFirst = uintStorage[QUEUE_V_FIRST];
        uint256 queueLast = uintStorage[QUEUE_V_LAST];

        if (queueLast < queueFirst) {
            validatorStakingAddress = address(0);
        } else {
            bytes32 hash = keccak256(abi.encode(QUEUE_V_LIST, queueFirst));
            validatorStakingAddress = addressStorage[hash];
            delete addressStorage[hash];
            uintStorage[QUEUE_V_FIRST]++;
        }
    }

    /// @dev Enqueues the specified validator for the snapshotting or rewarding process.
    /// Used by the `reward` and `_distributeRewards` functions. See also DELEGATORS_ALIQUOT.
    /// @param _validatorStakingAddress The staking address of a validator to be enqueued.
    function _enqueueValidator(address _validatorStakingAddress) internal {
        uint256 queueLast = uintStorage[QUEUE_V_LAST];
        for (uint256 i = 0; i < DELEGATORS_ALIQUOT; i++) {
            addressStorage[keccak256(abi.encode(QUEUE_V_LIST, ++queueLast))] = _validatorStakingAddress;
        }
        uintStorage[QUEUE_V_LAST] = queueLast;
    }

    /// @dev Reduces an undistributed amount of native coins.
    /// This function is used by the `_distributeRewards` function.
    /// @param _minus The subtraction value.
    function _subNativeRewardUndistributed(uint256 _minus) internal {
        if (uintStorage[NATIVE_REWARD_UNDISTRIBUTED] < _minus) {
            uintStorage[NATIVE_REWARD_UNDISTRIBUTED] = 0;
        } else {
            uintStorage[NATIVE_REWARD_UNDISTRIBUTED] -= _minus;
        }
    }

    /// @dev Reduces an undistributed amount of staking tokens.
    /// This function is used by the `_distributeRewards` function.
    /// @param _minus The subtraction value.
    function _subTokenRewardUndistributed(uint256 _minus) internal {
        if (uintStorage[TOKEN_REWARD_UNDISTRIBUTED] < _minus) {
            uintStorage[TOKEN_REWARD_UNDISTRIBUTED] = 0;
        } else {
            uintStorage[TOKEN_REWARD_UNDISTRIBUTED] -= _minus;
        }
    }

    /// @dev Calculates the starting block number for the rewarding process
    /// at the end of the current staking epoch.
    /// Used by the `reward` and `_distributeRewards` functions.
    /// @param _stakingContract The address of the StakingAuRa contract.
    /// @param _validatorSetContract The address of the ValidatorSet contract.
    function _rewardPointBlock(
        IStakingAuRa _stakingContract,
        IValidatorSet _validatorSetContract
    ) internal view returns(uint256) {
        return _stakingContract.stakingEpochEndBlock() - _validatorSetContract.MAX_VALIDATORS()*DELEGATORS_ALIQUOT - 1;
    }

    /// @dev Returns the size of the validator queue used for the snapshotting and rewarding processes.
    /// See `_enqueueValidator` and `_dequeueValidator` functions.
    /// This function is used by the `reward` and `_distributeRewards` functions.
    function _validatorsQueueSize() internal view returns(uint256) {
        return uintStorage[QUEUE_V_LAST] + 1 - uintStorage[QUEUE_V_FIRST];
    }

}
