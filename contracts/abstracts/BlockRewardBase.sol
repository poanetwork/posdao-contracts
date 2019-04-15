pragma solidity 0.5.2;

import "../interfaces/IBlockReward.sol";
import "../interfaces/IValidatorSet.sol";
import "../interfaces/IStaking.sol";
import "../eternal-storage/OwnedEternalStorage.sol";
import "../libs/SafeMath.sol";


contract BlockRewardBase is OwnedEternalStorage, IBlockReward {
    using SafeMath for uint256;

    // ============================================== Constants =======================================================

    /// @dev The address of ValidatorSet contract (EternalStorageProxy proxy contract for ValidatorSet).
    address public constant VALIDATOR_SET_CONTRACT = address(0x1000000000000000000000000000000000000001);

    /// @dev The constant defining a number of parts into which the reward distribution
    /// and stakes snapshotting processes are split for each pool. This is used for
    /// reducing the load on each block when reward distribution (at the end of staking epoch)
    /// and stakes snapshotting (at the beginning of staking epoch). See the `_setSnapshot`
    /// and `_distributeRewards` functions.
    uint256 public constant DELEGATORS_ALIQUOT = 2;

    // ================================================ Events ========================================================

    /// @dev Emitted by the `addExtraReceiver` function.
    /// @param amount The amount of native coins which must be minted for the `receiver` by the `erc-to-native`
    /// `bridge` with the `reward` function.
    /// @param receiver The address for which the `amount` of native coins must be minted.
    /// @param bridge The address of the bridge which called the `addExtraReceiver` function.
    event AddedReceiver(uint256 amount, address indexed receiver, address indexed bridge);

    /// @dev Emitted by the `_mintNativeCoinsByErcToNativeBridge` function which is called by the `reward` function.
    /// This event is only used by the unit tests because event emitting by the `reward` function is not possible.
    /// @param receivers The array of receiver addresses for which the native coins are minted. The length of this
    /// array is equal to the length of the `rewards` array.
    /// @param rewards The array of amounts which are minted for the relevant `receivers`. The length of this array
    /// is equal to the length of the `receivers` array.
    event MintedNative(address[] receivers, uint256[] rewards);

    // ============================================== Modifiers =======================================================

    /// @dev Ensures that the caller is the address of `erc-to-native` bridge contract.
    modifier onlyErcToNativeBridge {
        require(boolStorage[keccak256(abi.encode(ERC_TO_NATIVE_BRIDGE_ALLOWED, msg.sender))]);
        _;
    }

    /// @dev Ensures that the caller is the address of `erc-to-erc` or `native-to-erc` bridge contract.
    modifier onlyXToErcBridge {
        require(
            boolStorage[keccak256(abi.encode(ERC_TO_ERC_BRIDGE_ALLOWED, msg.sender))] ||
            boolStorage[keccak256(abi.encode(NATIVE_TO_ERC_BRIDGE_ALLOWED, msg.sender))]
        );
        _;
    }

    /// @dev Ensures that the caller is the SYSTEM_ADDRESS.
    modifier onlySystem {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    /// @dev Ensures that the caller is the address of ValidatorSet contract
    /// (EternalStorageProxy proxy contract for ValidatorSet).
    modifier onlyValidatorSet {
        require(msg.sender == VALIDATOR_SET_CONTRACT);
        _;
    }

    // =============================================== Setters ========================================================

    /// @dev Called by the `erc-to-native` bridge contract when some amount of bridge fee should be accrued to
    /// participants in native coins. The specified amount is used by the `_distributeRewards` function.
    /// @param _amount The amount of fee to be accrued to participants.
    function addBridgeNativeFeeReceivers(uint256 _amount) external onlyErcToNativeBridge {
        require(_amount != 0);
        uintStorage[BRIDGE_NATIVE_FEE] = uintStorage[BRIDGE_NATIVE_FEE].add(_amount);
    }

    /// @dev Called by the `erc-to-erc` or `native-to-erc` bridge contract when some amount of bridge fee should be
    /// accrued to participants in staking tokens. The specified amount is used by the `_distributeRewards` function.
    /// @param _amount The amount of fee to be accrued to participants.
    function addBridgeTokenFeeReceivers(uint256 _amount) external onlyXToErcBridge {
        require(_amount != 0);
        uintStorage[BRIDGE_TOKEN_FEE] = uintStorage[BRIDGE_TOKEN_FEE].add(_amount);
    }

    /// @dev Called by the `erc-to-native` bridge contract when the bridge needs to mint the specified amount of native
    /// coins for the specified address with the `reward` function.
    /// @param _amount The amount of native coins which must be minted for the `_receiver` address.
    /// @param _receiver The address for which the `_amount` of native coins must be minted.
    function addExtraReceiver(uint256 _amount, address _receiver) external onlyErcToNativeBridge {
        require(_amount != 0);
        require(_receiver != address(0));
        require(boolStorage[QUEUE_ER_INITIALIZED]);
        _enqueueExtraReceiver(_amount, _receiver, msg.sender);
        emit AddedReceiver(_amount, _receiver, msg.sender);
    }

    /// @dev Sets the array of `erc-to-native` bridges addresses which are allowed to call some of the functions with
    /// the `onlyErcToNativeBridge` modifier. This setter can only be called by the `owner`.
    /// @param _bridgesAllowed The array of bridges addresses.
    function setErcToNativeBridgesAllowed(address[] calldata _bridgesAllowed) external onlyOwner {
        uint256 i;

        address[] storage oldBridgesAllowed = addressArrayStorage[ERC_TO_NATIVE_BRIDGES_ALLOWED];
        for (i = 0; i < oldBridgesAllowed.length; i++) {
            boolStorage[keccak256(abi.encode(ERC_TO_NATIVE_BRIDGE_ALLOWED, oldBridgesAllowed[i]))] = false;
        }

        addressArrayStorage[ERC_TO_NATIVE_BRIDGES_ALLOWED] = _bridgesAllowed;

        for (i = 0; i < _bridgesAllowed.length; i++) {
            boolStorage[keccak256(abi.encode(ERC_TO_NATIVE_BRIDGE_ALLOWED, _bridgesAllowed[i]))] = true;
        }
    }

    /// @dev Sets the array of `native-to-erc` bridges addresses which are allowed to call some of the functions with
    /// the `onlyXToErcBridge` modifier. This setter can only be called by the `owner`.
    /// @param _bridgesAllowed The array of bridges addresses.
    function setNativeToErcBridgesAllowed(address[] calldata _bridgesAllowed) external onlyOwner {
        uint256 i;

        address[] storage oldBridgesAllowed = addressArrayStorage[NATIVE_TO_ERC_BRIDGES_ALLOWED];
        for (i = 0; i < oldBridgesAllowed.length; i++) {
            boolStorage[keccak256(abi.encode(NATIVE_TO_ERC_BRIDGE_ALLOWED, oldBridgesAllowed[i]))] = false;
        }

        addressArrayStorage[NATIVE_TO_ERC_BRIDGES_ALLOWED] = _bridgesAllowed;

        for (i = 0; i < _bridgesAllowed.length; i++) {
            boolStorage[keccak256(abi.encode(NATIVE_TO_ERC_BRIDGE_ALLOWED, _bridgesAllowed[i]))] = true;
        }
    }

    /// @dev Sets the array of `erc-to-erc` bridges addresses which are allowed to call some of the functions with
    /// the `onlyXToErcBridge` modifier. This setter can only be called by the `owner`.
    /// @param _bridgesAllowed The array of bridges addresses.
    function setErcToErcBridgesAllowed(address[] calldata _bridgesAllowed) external onlyOwner {
        uint256 i;

        address[] storage oldBridgesAllowed = addressArrayStorage[ERC_TO_ERC_BRIDGES_ALLOWED];
        for (i = 0; i < oldBridgesAllowed.length; i++) {
            boolStorage[keccak256(abi.encode(ERC_TO_ERC_BRIDGE_ALLOWED, oldBridgesAllowed[i]))] = false;
        }

        addressArrayStorage[ERC_TO_ERC_BRIDGES_ALLOWED] = _bridgesAllowed;

        for (i = 0; i < _bridgesAllowed.length; i++) {
            boolStorage[keccak256(abi.encode(ERC_TO_ERC_BRIDGE_ALLOWED, _bridgesAllowed[i]))] = true;
        }
    }

    // =============================================== Getters ========================================================

    /// @dev Returns the array of `erc-to-erc` bridges addresses which were set by
    /// the `setErcToErcBridgesAllowed` setter before.
    function ercToErcBridgesAllowed() public view returns(address[] memory) {
        return addressArrayStorage[ERC_TO_ERC_BRIDGES_ALLOWED];
    }

    /// @dev Returns the array of `erc-to-native` bridges addresses which were set by
    /// the `setErcToNativeBridgesAllowed` setter before.
    function ercToNativeBridgesAllowed() public view returns(address[] memory) {
        return addressArrayStorage[ERC_TO_NATIVE_BRIDGES_ALLOWED];
    }

    /// @dev Returns the current size of the address queue which is formed by the `addExtraReceiver` function.
    function extraReceiversQueueSize() public view returns(uint256) {
        return uintStorage[QUEUE_ER_LAST] + 1 - uintStorage[QUEUE_ER_FIRST];
    }

    /// @dev Returns the current total fee amount of native coins which has been accumulated by
    /// the `addBridgeNativeFeeReceivers` function.
    function getBridgeNativeFee() public view returns(uint256) {
        return uintStorage[BRIDGE_NATIVE_FEE];
    }

    /// @dev Returns the current total fee amount of staking tokens which has been accumulated by
    /// the `addBridgeTokenFeeReceivers` function.
    function getBridgeTokenFee() public view returns(uint256) {
        return uintStorage[BRIDGE_TOKEN_FEE];
    }

    /// @dev Returns a boolean flag of whether the rewarding process is occuring for the current block.
    /// The value of this boolean flag is changed by the `_distributeRewards` function.
    function isRewarding() public view returns(bool) {
        return boolStorage[IS_REWARDING];
    }

    /// @dev Returns a boolean flag of whether the snapshotting process is occuring for the current block.
    /// The value of this boolean flag is changed by the `reward` function.
    function isSnapshotting() public view returns(bool) {
        return boolStorage[IS_SNAPSHOTTING];
    }

    /// @dev Returns how many native coins were minted in total for the specified address
    /// by the `erc-to-native` bridges through the `addExtraReceiver` function.
    /// @param _account The address for which the getter must return the minted amount.
    function mintedForAccount(address _account) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(MINTED_FOR_ACCOUNT, _account))];
    }

    /// @dev Returns how many native coins were minted at the specified block for the specified
    /// address by the `erc-to-native` bridges through the `addExtraReceiver` function.
    /// @param _account The address for which the getter must return the amount minted at the `_blockNumber`.
    /// @param _blockNumber The block number for which the getter must return the amount minted for the `_account`.
    function mintedForAccountInBlock(address _account, uint256 _blockNumber)
        public
        view
        returns(uint256)
    {
        return uintStorage[
            keccak256(abi.encode(MINTED_FOR_ACCOUNT_IN_BLOCK, _account, _blockNumber))
        ];
    }

    /// @dev Returns how many native coins in total were minted at the specified block
    /// by the `erc-to-native` bridges through the `addExtraReceiver` function.
    /// @param _blockNumber The block number for which the getter must return the minted amount.
    function mintedInBlock(uint256 _blockNumber) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(MINTED_IN_BLOCK, _blockNumber))];
    }

    /// @dev Returns how many native coins in total were minted by the specified
    /// `erc-to-native` bridge through the `addExtraReceiver` function.
    /// @param _bridge The address of bridge contract.
    function mintedTotallyByBridge(address _bridge) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(MINTED_TOTALLY_BY_BRIDGE, _bridge))];
    }

    /// @dev Returns how many native coins in total were minted by the
    /// `erc-to-native` bridges through the `addExtraReceiver` function.
    function mintedTotally() public view returns(uint256) {
        return uintStorage[MINTED_TOTALLY];
    }

    /// @dev Returns the array of `native-to-erc` bridges addresses which were set by
    /// the `setNativeToErcBridgesAllowed` setter before.
    function nativeToErcBridgesAllowed() public view returns(address[] memory) {
        return addressArrayStorage[NATIVE_TO_ERC_BRIDGES_ALLOWED];
    }

    /// @dev Returns the array of reward coefficients which corresponds to the array of stakers
    /// for the specified validator and the current staking epoch. The size of the returned array
    /// is the same as the size of staker array returned by the `snapshotStakers` getter. The reward
    /// coefficients are calculated by the `_setSnapshot` function at the beginning of staking epoch
    /// and then used by the `_distributeRewards` function at the end of staking epoch.
    /// @param _validatorStakingAddress The staking address of the validator pool for which the getter
    /// must return the coefficient array.
    function snapshotRewardPercents(address _validatorStakingAddress) public view returns(uint256[] memory) {
        return uintArrayStorage[
            keccak256(abi.encode(SNAPSHOT_REWARD_PERCENTS, _validatorStakingAddress))
        ];
    }

    /// @dev Returns the array of stakers for the specified validator and the current staking epoch
    /// snapshotted at the beginning of the staking epoch by the `_setSnapshot` function. This array is
    /// used by the `_distributeRewards` function at the end of staking epoch.
    /// @param _validatorStakingAddress The staking address of the validator pool for which the getter
    /// must return the array of stakers.
    function snapshotStakers(address _validatorStakingAddress) public view returns(address[] memory) {
        return addressArrayStorage[
            keccak256(abi.encode(SNAPSHOT_STAKERS, _validatorStakingAddress))
        ];
    }

    /// @dev Returns the array of the pools for which the snapshots were made
    /// at the beginning of the current staking epoch by the `_setSnapshot` function.
    /// The getter returns the staking addresses of the pools.
    function snapshotStakingAddresses() public view returns(address[] memory) {
        return addressArrayStorage[SNAPSHOT_STAKING_ADDRESSES];
    }

    /// @dev Returns a total amount staked during the previous staking epoch. This value is used by the
    /// `_distributeRewards` function at the end of the current staking epoch to calculate inflation amount of
    /// the staking token for the current staking epoch.
    function snapshotTotalStakeAmount() public view returns(uint256) {
        return uintStorage[SNAPSHOT_TOTAL_STAKE_AMOUNT];
    }

    // =============================================== Private ========================================================

    bytes32 internal constant BRIDGE_NATIVE_FEE = keccak256("bridgeNativeFee");
    bytes32 internal constant BRIDGE_TOKEN_FEE = keccak256("bridgeTokenFee");
    bytes32 internal constant ERC_TO_ERC_BRIDGES_ALLOWED = keccak256("ercToErcBridgesAllowed");
    bytes32 internal constant ERC_TO_NATIVE_BRIDGES_ALLOWED = keccak256("ercToNativeBridgesAllowed");
    bytes32 internal constant IS_REWARDING = keccak256("isRewarding");
    bytes32 internal constant IS_SNAPSHOTTING = keccak256("isSnapshotting");
    bytes32 internal constant MINTED_TOTALLY = keccak256("mintedTotally");
    bytes32 internal constant NATIVE_TO_ERC_BRIDGES_ALLOWED = keccak256("nativeToErcBridgesAllowed");
    bytes32 internal constant QUEUE_ER_FIRST = keccak256("queueERFirst");
    bytes32 internal constant QUEUE_ER_INITIALIZED = keccak256("queueERInitialized");
    bytes32 internal constant QUEUE_ER_LAST = keccak256("queueERLast");
    bytes32 internal constant SNAPSHOT_STAKING_ADDRESSES = keccak256("snapshotStakingAddresses");
    bytes32 internal constant SNAPSHOT_TOTAL_STAKE_AMOUNT = keccak256("snapshotTotalStakeAmount");

    bytes32 internal constant ERC_TO_ERC_BRIDGE_ALLOWED = "ercToErcBridgeAllowed";
    bytes32 internal constant ERC_TO_NATIVE_BRIDGE_ALLOWED = "ercToNativeBridgeAllowed";
    bytes32 internal constant MINTED_FOR_ACCOUNT = "mintedForAccount";
    bytes32 internal constant MINTED_FOR_ACCOUNT_IN_BLOCK = "mintedForAccountInBlock";
    bytes32 internal constant MINTED_IN_BLOCK = "mintedInBlock";
    bytes32 internal constant MINTED_TOTALLY_BY_BRIDGE = "mintedTotallyByBridge";
    bytes32 internal constant NATIVE_TO_ERC_BRIDGE_ALLOWED = "nativeToErcBridgeAllowed";
    bytes32 internal constant QUEUE_ER_AMOUNT = "queueERAmount";
    bytes32 internal constant QUEUE_ER_BRIDGE = "queueERBridge";
    bytes32 internal constant QUEUE_ER_RECEIVER = "queueERReceiver";
    bytes32 internal constant SNAPSHOT_REWARD_PERCENTS = "snapshotRewardPercents";
    bytes32 internal constant SNAPSHOT_STAKERS = "snapshotStakers";

    uint256 internal constant REWARD_PERCENT_MULTIPLIER = 1000000;

    /// @dev Joins two parts of native coin receivers into a single set and returns the result
    /// to the `reward` function: one part of receivers comes from the `erc-to-native` bridge fee distribution,
    /// another one - from the `erc-to-native` bridge when it needs to mint native coins for the specified addresses.
    /// Dequeues the addresses enqueued with the `addExtraReceiver` function by the `erc-to-native` bridge.
    /// Accumulates minting statistics for the `erc-to-native` bridges.
    /// @param _bridgeFeeReceivers The array of native coin receivers formed by the `_distributeRewards` function.
    /// @param _bridgeFeeRewards The array of native coin amounts to be minted for the corresponding
    /// `_bridgeFeeReceivers`. The size if this array is equal to the size of `_bridgeFeeReceivers` array.
    /// @param _queueLimit Max number of addresses which can be dequeued from the queue formed by the
    /// `addExtraReceiver` function.
    function _mintNativeCoinsByErcToNativeBridge(
        address[] memory _bridgeFeeReceivers,
        uint256[] memory _bridgeFeeRewards,
        uint256 _queueLimit
    )
        internal
        returns(address[] memory receivers, uint256[] memory rewards)
    {
        uint256 extraLength = extraReceiversQueueSize();

        if (extraLength > _queueLimit) {
            extraLength = _queueLimit;
        }

        receivers = new address[](extraLength + _bridgeFeeReceivers.length);
        rewards = new uint256[](receivers.length);

        uint256 i;
        uint256 j = 0;

        for (i = 0; i < extraLength; i++) {
            (uint256 amount, address receiver, address bridge) = _dequeueExtraReceiver();
            receivers[i] = receiver;
            rewards[i] = amount;
            _setMinted(amount, receiver, bridge);
        }

        for (i = extraLength; i < receivers.length; i++) {
            receivers[i] = _bridgeFeeReceivers[j];
            rewards[i] = _bridgeFeeRewards[j];
            j++;
        }

        emit MintedNative(receivers, rewards);

        return (receivers, rewards);
    }

    /// @dev Dequeues the information about native coins receiver enqueued with the `addExtraReceiver`
    /// function by the `erc-to-native` bridge. This function is used by the `_mintNativeCoinsByErcToNativeBridge`.
    /// @return amount The amount to be minted for the `receiver` address.
    /// @return receiver The address for which the `amount` to be minted.
    /// @return bridge The address of the bridge contract which called the `addExtraReceiver` function.
    function _dequeueExtraReceiver() internal returns(uint256 amount, address receiver, address bridge) {
        uint256 queueFirst = uintStorage[QUEUE_ER_FIRST];
        uint256 queueLast = uintStorage[QUEUE_ER_LAST];

        if (queueLast < queueFirst) {
            amount = 0;
            receiver = address(0);
            bridge = address(0);
        } else {
            bytes32 amountHash = keccak256(abi.encode(QUEUE_ER_AMOUNT, queueFirst));
            bytes32 receiverHash = keccak256(abi.encode(QUEUE_ER_RECEIVER, queueFirst));
            bytes32 bridgeHash = keccak256(abi.encode(QUEUE_ER_BRIDGE, queueFirst));
            amount = uintStorage[amountHash];
            receiver = addressStorage[receiverHash];
            bridge = addressStorage[bridgeHash];
            delete uintStorage[amountHash];
            delete addressStorage[receiverHash];
            delete addressStorage[bridgeHash];
            uintStorage[QUEUE_ER_FIRST]++;
        }
    }

    /// @dev Enqueues the information about the receiver of native coins which must be minted for the
    /// specified `erc-to-native` bridge. This function is used by the `addExtraReceiver` function.
    /// @param _amount The amount of native coins which must be minted for the `_receiver` address.
    /// @param _receiver The address for which the `_amount` of native coins must be minted.
    /// @param _bridge The address of the bridge's contract which requested native coins minting.
    function _enqueueExtraReceiver(uint256 _amount, address _receiver, address _bridge) internal {
        uint256 queueLast = uintStorage[QUEUE_ER_LAST] + 1;
        uintStorage[keccak256(abi.encode(QUEUE_ER_AMOUNT, queueLast))] = _amount;
        addressStorage[keccak256(abi.encode(QUEUE_ER_RECEIVER, queueLast))] = _receiver;
        addressStorage[keccak256(abi.encode(QUEUE_ER_BRIDGE, queueLast))] = _bridge;
        uintStorage[QUEUE_ER_LAST] = queueLast;
    }

    /// @dev Accumulates minting statistics for the `erc-to-native` bridge.
    /// This function is used by the `_mintNativeCoinsByErcToNativeBridge` function.
    /// @param _amount The amount being minted for the `_account` address.
    /// @param _account The address for which the `_amount` is being minted.
    /// @param _bridge The address of the bridge contract which called the `addExtraReceiver` function.
    function _setMinted(uint256 _amount, address _account, address _bridge) internal {
        uintStorage[keccak256(abi.encode(MINTED_FOR_ACCOUNT_IN_BLOCK, _account, block.number))] = _amount;
        uintStorage[keccak256(abi.encode(MINTED_FOR_ACCOUNT, _account))] += _amount;
        uintStorage[keccak256(abi.encode(MINTED_IN_BLOCK, block.number))] += _amount;
        uintStorage[keccak256(abi.encode(MINTED_TOTALLY_BY_BRIDGE, _bridge))] += _amount;
        uintStorage[MINTED_TOTALLY] += _amount;
    }

    /// @dev Calculates reward coefficient for each pool's staker and saves it so that it could be used at
    /// the end of staking epoch when reward distribution phase. Makes the specified part of coefficients'
    /// snapshot thus limiting the coefficient calculations for each block. This function is called by
    /// the `reward` function at the beginning of staking epoch.
    /// @param _stakingAddress The staking address of a pool for which the snapshot needs to be done.
    /// @param _stakingContract The address of the `Staking` contract.
    /// @param _offset The part of the delegator array for which the snapshot needs to be done at the current block.
    /// The `_offset` range is [0, DELEGATORS_ALIQUOT - 1]. The `_offset` value is set based on the `DELEGATORS_ALIQUOT`
    /// constant - see the code of the `reward` function.
    function _setSnapshot(address _stakingAddress, IStaking _stakingContract, uint256 _offset) internal {
        uint256 validatorStake = _stakingContract.stakeAmountMinusOrderedWithdraw(_stakingAddress, _stakingAddress);
        uint256 totalStaked = _stakingContract.stakeAmountTotalMinusOrderedWithdraw(_stakingAddress);
        uint256 delegatorsAmount = totalStaked >= validatorStake ? totalStaked - validatorStake : 0;
        bool validatorHasMore30Per = validatorStake * 7 > delegatorsAmount * 3;

        address[] memory delegators = _stakingContract.poolDelegators(_stakingAddress);
        uint256 rewardPercent;

        address[] storage stakers = addressArrayStorage[keccak256(abi.encode(
            SNAPSHOT_STAKERS, _stakingAddress
        ))];

        uint256[] storage rewardPercents = uintArrayStorage[keccak256(abi.encode(
            SNAPSHOT_REWARD_PERCENTS, _stakingAddress
        ))];

        if (_offset == 0) {
            // Calculate reward percent for validator
            rewardPercent = 0;
            if (validatorStake != 0 && totalStaked != 0) {
                if (validatorHasMore30Per) {
                    rewardPercent = REWARD_PERCENT_MULTIPLIER * validatorStake / totalStaked;
                } else {
                    rewardPercent = REWARD_PERCENT_MULTIPLIER * 3 / 10;
                }
            }
            stakers.push(_stakingAddress);
            rewardPercents.push(rewardPercent);
            addressArrayStorage[SNAPSHOT_STAKING_ADDRESSES].push(_stakingAddress);
            uintStorage[SNAPSHOT_TOTAL_STAKE_AMOUNT] += totalStaked;
        }

        uint256 from = delegators.length / DELEGATORS_ALIQUOT * _offset;
        uint256 to = delegators.length / DELEGATORS_ALIQUOT * (_offset + 1);

        if (_offset == 0) {
            to += delegators.length % DELEGATORS_ALIQUOT;
        } else {
            from += delegators.length % DELEGATORS_ALIQUOT;
        }

        // Calculate reward percent for each delegator
        for (uint256 i = from; i < to; i++) {
            rewardPercent = 0;

            if (validatorHasMore30Per) {
                if (totalStaked != 0) {
                    rewardPercent = _stakingContract.stakeAmountMinusOrderedWithdraw(_stakingAddress, delegators[i]);
                    rewardPercent = REWARD_PERCENT_MULTIPLIER * rewardPercent / totalStaked;
                }
            } else {
                if (delegatorsAmount != 0) {
                    rewardPercent = _stakingContract.stakeAmountMinusOrderedWithdraw(_stakingAddress, delegators[i]);
                    rewardPercent = REWARD_PERCENT_MULTIPLIER * rewardPercent * 7 / (delegatorsAmount * 10);
                }
            }

            stakers.push(delegators[i]);
            rewardPercents.push(rewardPercent);
        }
    }
}
