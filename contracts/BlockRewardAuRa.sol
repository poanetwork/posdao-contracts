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

        uint256 i;

        if (block.number == 1) {
            uintStorage[QUEUE_NV_FIRST] = 1;
            uintStorage[QUEUE_NV_LAST] = 0;
        }

        // Start new staking epoch every `stakingEpochDuration()` blocks
        if (validatorSetContract.newValidatorSet()) {
            address[] memory newValidatorSet = validatorSetContract.getPendingValidators();

            for (i = 0; i < newValidatorSet.length; i++) {
                _enqueueNewValidator(newValidatorSet[i]);
            }
        } else if (validatorSetContract.validatorSetApplyBlock() == 0) {
            address newValidator = _dequeueNewValidator();

            if (newValidator != address(0)) {
                _setSnapshot(validatorSetContract.stakingByMiningAddress(newValidator), stakingContract);
            } else if (!pendingValidatorsEnqueued()) {
                IValidatorSetAuRa(VALIDATOR_SET_CONTRACT).enqueuePendingValidators();
                _setPendingValidatorsEnqueued(true);
            }
        }

        // Distribute fees
        address[] memory receivers;
        uint256[] memory rewards;

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
            // Distribute the bridge's token fee and 1%/year staking token inflation
            uint256 distributeAmount = _getBridgeTokenFee(stakingEpoch);
            _clearBridgeTokenFee(stakingEpoch);
            distributeAmount += snapshotTotalStakeAmount(stakingEpoch) * 1585489599 / 1 ether; // 1% per year
            if (distributeAmount > 0) {
                (receivers, rewards) = _distributeAmount(stakingEpoch, false, distributeAmount);
                if (receivers.length > 0) {
                    erc20TokenContract.mintReward(receivers, rewards);
                }
            }

            if (stakingEpoch > 0) {
                // Handle previous staking epoch as well (just in case)
                (receivers, rewards) = _distributeBridgeFee(stakingEpoch - 1, true, false);
                if (receivers.length > 0) {
                    erc20TokenContract.mintReward(receivers, rewards);
                }
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
        } else {
            bridgeFeeAmount = _getBridgeTokenFee(_stakingEpoch);
        }

        if (bridgeFeeAmount == 0) {
            return (new address[](0), new uint256[](0));
        }

        if (_native) {
            _clearBridgeNativeFee(_stakingEpoch);
        } else {
            _clearBridgeTokenFee(_stakingEpoch);
        }

        return _distributeAmount(_stakingEpoch, _previousEpoch, bridgeFeeAmount);
    }

    function _enqueueNewValidator(address _newValidator) internal {
        addressStorage[keccak256(abi.encode(QUEUE_NV_LIST, ++uintStorage[QUEUE_NV_LAST]))] = _newValidator;
    }

    bytes32 internal constant DISTRIBUTE_TEMPORARY_ARRAY = keccak256("distributeTemporaryArray");
    bytes32 internal constant QUEUE_NV_FIRST = keccak256("queueNVFirst");
    bytes32 internal constant QUEUE_NV_LAST = keccak256("queueNVLast");
    bytes32 internal constant REWARD_TEMPORARY_ARRAY = keccak256("rewardTemporaryArray");

    bytes32 internal constant QUEUE_NV_LIST = "queueNVList";

}
