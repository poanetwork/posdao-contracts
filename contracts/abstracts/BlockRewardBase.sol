pragma solidity 0.5.7;

import "../interfaces/IBlockReward.sol";
import "../interfaces/IValidatorSet.sol";
import "../interfaces/IStaking.sol";
import "../eternal-storage/OwnedEternalStorage.sol";
import "../libs/SafeMath.sol";


/// @dev The base contract for the BlockRewardAuRa and BlockRewardHBBFT contracts.
contract BlockRewardBase is OwnedEternalStorage, IBlockReward {
    using SafeMath for uint256;

    // ============================================== Constants =======================================================

    /// @dev A constant that defines the number of sections the reward distribution
    /// and stakes snapshotting processes are split into for each pool. This is used to
    /// reduce the load on each block when reward distribution (at the end of staking epoch)
    /// and stakes snapshotting (at the beginning of staking epoch) occur. See the `_setSnapshot`
    /// and `_distributeRewards` functions.
    uint256 public constant DELEGATORS_ALIQUOT = 2;

    // ================================================ Events ========================================================

    /// @dev Emitted by the `addExtraReceiver` function.
    /// @param amount The amount of native coins which must be minted for the `receiver` by the `erc-to-native`
    /// `bridge` with the `reward` function.
    /// @param receiver The address for which the `amount` of native coins must be minted.
    /// @param bridge The bridge address which called the `addExtraReceiver` function.
    event AddedReceiver(uint256 amount, address indexed receiver, address indexed bridge);

    /// @dev Emitted by the `_mintNativeCoins` function which is called by the `reward` function.
    /// This event is only used by the unit tests because the `reward` function cannot emit events.
    /// @param receivers The array of receiver addresses for which native coins are minted. The length of this
    /// array is equal to the length of the `rewards` array.
    /// @param rewards The array of amounts minted for the relevant `receivers`. The length of this array
    /// is equal to the length of the `receivers` array.
    event MintedNative(address[] receivers, uint256[] rewards);

    // ============================================== Modifiers =======================================================

    /// @dev Ensures the caller is the `erc-to-native` bridge contract address.
    modifier onlyErcToNativeBridge {
        require(boolStorage[keccak256(abi.encode(ERC_TO_NATIVE_BRIDGE_ALLOWED, msg.sender))]);
        _;
    }

    /// @dev Ensures the caller is the `erc-to-erc` or `native-to-erc` bridge contract address.
    modifier onlyXToErcBridge {
        require(
            boolStorage[keccak256(abi.encode(ERC_TO_ERC_BRIDGE_ALLOWED, msg.sender))] ||
            boolStorage[keccak256(abi.encode(NATIVE_TO_ERC_BRIDGE_ALLOWED, msg.sender))]
        );
        _;
    }

    /// @dev Ensures the caller is the SYSTEM_ADDRESS. See https://wiki.parity.io/Block-Reward-Contract.html
    modifier onlySystem {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    // =============================================== Setters ========================================================

    /// @dev Called by the `erc-to-native` bridge contract when a portion of the bridge fee should be distributed to
    /// participants (validators and their delegators) in native coins. The specified amount is used by the
    /// `_distributeRewards` function.
    /// @param _amount The fee amount distributed to participants.
    function addBridgeNativeFeeReceivers(uint256 _amount) external onlyErcToNativeBridge {
        require(_amount != 0);
        uintStorage[BRIDGE_NATIVE_FEE] = uintStorage[BRIDGE_NATIVE_FEE].add(_amount);
    }

    /// @dev Called by the `erc-to-erc` or `native-to-erc` bridge contract when a portion of the bridge fee should be
    /// distributed to participants in staking tokens. The specified amount is used by the `_distributeRewards`
    /// function.
    /// @param _amount The fee amount distributed to participants.
    function addBridgeTokenFeeReceivers(uint256 _amount) external onlyXToErcBridge {
        require(_amount != 0);
        uintStorage[BRIDGE_TOKEN_FEE] = uintStorage[BRIDGE_TOKEN_FEE].add(_amount);
    }

    /// @dev Called by the `erc-to-native` bridge contract when the bridge needs to mint a specified amount of native
    /// coins for a specified address using the `reward` function.
    /// @param _amount The amount of native coins which must be minted for the `_receiver` address.
    /// @param _receiver The address for which the `_amount` of native coins must be minted.
    function addExtraReceiver(uint256 _amount, address _receiver) external onlyErcToNativeBridge {
        require(_amount != 0);
        require(_receiver != address(0));
        require(boolStorage[QUEUE_ER_INITIALIZED]);
        _enqueueExtraReceiver(_amount, _receiver, msg.sender);
        emit AddedReceiver(_amount, _receiver, msg.sender);
    }

    /// @dev Initializes the contract at network startup.
    /// Must be called by the constructor of the `Initializer` contract.
    /// @param _validatorSet The address of the `ValidatorSet` contract.
    function initialize(address _validatorSet) external {
        require(addressStorage[VALIDATOR_SET_CONTRACT] == address(0));
        require(_validatorSet != address(0));
        addressStorage[VALIDATOR_SET_CONTRACT] = _validatorSet;
    }

    /// @dev Sets the array of `erc-to-native` bridge addresses which are allowed to call some of the functions with
    /// the `onlyErcToNativeBridge` modifier. This setter can only be called by the `owner`.
    /// @param _bridgesAllowed The array of bridge addresses.
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

    /// @dev Sets the array of `native-to-erc` bridge addresses which are allowed to call some of the functions with
    /// the `onlyXToErcBridge` modifier. This setter can only be called by the `owner`.
    /// @param _bridgesAllowed The array of bridge addresses.
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

    /// @dev Sets the array of `erc-to-erc` bridge addresses which are allowed to call some of the functions with
    /// the `onlyXToErcBridge` modifier. This setter can only be called by the `owner`.
    /// @param _bridgesAllowed The array of bridge addresses.
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

    /// @dev Returns the array of `erc-to-erc` bridge addresses set by the `setErcToErcBridgesAllowed` setter.
    function ercToErcBridgesAllowed() public view returns(address[] memory) {
        return addressArrayStorage[ERC_TO_ERC_BRIDGES_ALLOWED];
    }

    /// @dev Returns the array of `erc-to-native` bridge addresses set by the `setErcToNativeBridgesAllowed` setter.
    function ercToNativeBridgesAllowed() public view returns(address[] memory) {
        return addressArrayStorage[ERC_TO_NATIVE_BRIDGES_ALLOWED];
    }

    /// @dev Returns the current size of the address queue created by the `addExtraReceiver` function.
    function extraReceiversQueueSize() public view returns(uint256) {
        return uintStorage[QUEUE_ER_LAST] + 1 - uintStorage[QUEUE_ER_FIRST];
    }

    /// @dev Returns the current total fee amount of native coins accumulated by
    /// the `addBridgeNativeFeeReceivers` function.
    function getBridgeNativeFee() public view returns(uint256) {
        return uintStorage[BRIDGE_NATIVE_FEE];
    }

    /// @dev Returns the current total fee amount of staking tokens accumulated by
    /// the `addBridgeTokenFeeReceivers` function.
    function getBridgeTokenFee() public view returns(uint256) {
        return uintStorage[BRIDGE_TOKEN_FEE];
    }

    /// @dev Returns a boolean flag indicating if the reward process is occuring for the current block.
    /// The value of this boolean flag is changed by the `_distributeRewards` function.
    function isRewarding() public view returns(bool) {
        return boolStorage[IS_REWARDING];
    }

    /// @dev Returns a boolean flag indicating if the snapshotting process is occuring for the current block.
    /// The value of this boolean flag is changed by the `reward` function.
    function isSnapshotting() public view returns(bool) {
        return boolStorage[IS_SNAPSHOTTING];
    }

    /// @dev Returns the total amount of native coins minted for the specified address
    /// by the `erc-to-native` bridges through the `addExtraReceiver` function.
    /// @param _account The address for which the getter must return the minted amount.
    function mintedForAccount(address _account) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(MINTED_FOR_ACCOUNT, _account))];
    }

    /// @dev Returns the amount of native coins minted at the specified block for the specified
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

    /// @dev Returns the total amount of native coins minted at the specified block
    /// by the `erc-to-native` bridges through the `addExtraReceiver` function.
    /// @param _blockNumber The block number for which the getter must return the minted amount.
    function mintedInBlock(uint256 _blockNumber) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(MINTED_IN_BLOCK, _blockNumber))];
    }

    /// @dev Returns the total amount of native coins minted by the specified
    /// `erc-to-native` bridge through the `addExtraReceiver` function.
    /// @param _bridge The address of the bridge contract.
    function mintedTotallyByBridge(address _bridge) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(MINTED_TOTALLY_BY_BRIDGE, _bridge))];
    }

    /// @dev Returns the total amount of native coins minted by the
    /// `erc-to-native` bridges through the `addExtraReceiver` function.
    function mintedTotally() public view returns(uint256) {
        return uintStorage[MINTED_TOTALLY];
    }

    /// @dev Returns the array of `native-to-erc` bridge addresses which were set by
    /// the `setNativeToErcBridgesAllowed` setter.
    function nativeToErcBridgesAllowed() public view returns(address[] memory) {
        return addressArrayStorage[NATIVE_TO_ERC_BRIDGES_ALLOWED];
    }

    /// @dev Returns an array of reward coefficients which corresponds to the array of stakers
    /// for a specified validator and the current staking epoch. The size of the returned array
    /// is the same as the size of the staker array returned by the `snapshotStakers` getter. The reward
    /// coefficients are calculated by the `_setSnapshot` function at the beginning of the staking epoch
    /// and then used by the `_distributeRewards` function at the end of the staking epoch.
    /// @param _validatorStakingAddress The staking address of the validator pool for which the getter
    /// must return the coefficient array.
    function snapshotRewardPercents(address _validatorStakingAddress) public view returns(uint256[] memory) {
        return uintArrayStorage[
            keccak256(abi.encode(SNAPSHOT_REWARD_PERCENTS, _validatorStakingAddress))
        ];
    }

    /// @dev Returns an array of stakers for the specified validator and the current staking epoch
    /// snapshotted at the beginning of the staking epoch by the `_setSnapshot` function. This array is
    /// used by the `_distributeRewards` function at the end of the staking epoch.
    /// @param _validatorStakingAddress The staking address of the validator pool for which the getter
    /// must return the array of stakers.
    function snapshotStakers(address _validatorStakingAddress) public view returns(address[] memory) {
        return addressArrayStorage[
            keccak256(abi.encode(SNAPSHOT_STAKERS, _validatorStakingAddress))
        ];
    }

    /// @dev Returns an array of the pools snapshotted by the `_setSnapshot` function
    /// at the beginning of the current staking epoch.
    /// The getter returns the staking addresses of the pools.
    function snapshotStakingAddresses() public view returns(address[] memory) {
        return addressArrayStorage[SNAPSHOT_STAKING_ADDRESSES];
    }

    /// @dev Returns the total amount staked during the previous staking epoch. This value is used by the
    /// `_distributeRewards` function at the end of the current staking epoch to calculate the inflation amount 
    /// for the staking token in the current staking epoch.
    function snapshotTotalStakeAmount() public view returns(uint256) {
        return uintStorage[SNAPSHOT_TOTAL_STAKE_AMOUNT];
    }

    /// @dev Returns the address of the `ValidatorSet` contract.
    function validatorSetContract() public view returns(IValidatorSet) {
        return IValidatorSet(addressStorage[VALIDATOR_SET_CONTRACT]);
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
    bytes32 internal constant VALIDATOR_SET_CONTRACT = keccak256("validatorSetContract");

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

    /// @dev Joins two native coin receiver elements into a single set and returns the result
    /// to the `reward` function: the first element comes from the `erc-to-native` bridge fee distribution
    /// (or from native coins fixed distribution), the second from the `erc-to-native` bridge when native
    /// coins are minted for the specified addresses.
    /// Dequeues the addresses enqueued with the `addExtraReceiver` function by the `erc-to-native` bridge.
    /// Accumulates minting statistics for the `erc-to-native` bridges.
    /// @param _receivers The array of native coin receivers formed by the `_distributeRewards` function.
    /// @param _rewards The array of native coin amounts to be minted for the corresponding
    /// `_receivers`. The size of this array is equal to the size of the `_receivers` array.
    /// @param _queueLimit Max number of addresses which can be dequeued from the queue formed by the
    /// `addExtraReceiver` function.
    function _mintNativeCoins(
        address[] memory _receivers,
        uint256[] memory _rewards,
        uint256 _queueLimit
    )
        internal
        returns(address[] memory receivers, uint256[] memory rewards)
    {
        uint256 extraLength = extraReceiversQueueSize();

        if (extraLength > _queueLimit) {
            extraLength = _queueLimit;
        }

        receivers = new address[](extraLength + _receivers.length);
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
            receivers[i] = _receivers[j];
            rewards[i] = _rewards[j];
            j++;
        }

        emit MintedNative(receivers, rewards);

        return (receivers, rewards);
    }

    /// @dev Dequeues the information about the native coins receiver enqueued with the `addExtraReceiver`
    /// function by the `erc-to-native` bridge. This function is used by `_mintNativeCoins`.
    /// @return `uint256 amount` - The amount to be minted for the `receiver` address.
    /// `address receiver` - The address for which the `amount` is minted.
    /// `address bridge` - The address of the bridge contract which called the `addExtraReceiver` function.
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
    /// @param _bridge The address of the bridge contract which requested the minting of native coins.
    function _enqueueExtraReceiver(uint256 _amount, address _receiver, address _bridge) internal {
        uint256 queueLast = uintStorage[QUEUE_ER_LAST] + 1;
        uintStorage[keccak256(abi.encode(QUEUE_ER_AMOUNT, queueLast))] = _amount;
        addressStorage[keccak256(abi.encode(QUEUE_ER_RECEIVER, queueLast))] = _receiver;
        addressStorage[keccak256(abi.encode(QUEUE_ER_BRIDGE, queueLast))] = _bridge;
        uintStorage[QUEUE_ER_LAST] = queueLast;
    }

    /// @dev Accumulates minting statistics for the `erc-to-native` bridge.
    /// This function is used by the `_mintNativeCoins` function.
    /// @param _amount The amount minted for the `_account` address.
    /// @param _account The address for which the `_amount` is minted.
    /// @param _bridge The address of the bridge contract which called the `addExtraReceiver` function.
    function _setMinted(uint256 _amount, address _account, address _bridge) internal {
        uintStorage[keccak256(abi.encode(MINTED_FOR_ACCOUNT_IN_BLOCK, _account, block.number))] = _amount;
        uintStorage[keccak256(abi.encode(MINTED_FOR_ACCOUNT, _account))] += _amount;
        uintStorage[keccak256(abi.encode(MINTED_IN_BLOCK, block.number))] += _amount;
        uintStorage[keccak256(abi.encode(MINTED_TOTALLY_BY_BRIDGE, _bridge))] += _amount;
        uintStorage[MINTED_TOTALLY] += _amount;
    }

    /// @dev Calculates the reward coefficient for each pool's staker and saves it so it can be used at
    /// the end of the staking epoch for the reward distribution phase. Specifies a section of the coefficients'
    /// snapshot thus limiting the coefficient calculations for each block. This function is called by
    /// the `reward` function at the beginning of the staking epoch.
    /// @param _stakingAddress The staking address of a pool for which the snapshot must be done.
    /// @param _stakingContract The address of the `Staking` contract.
    /// @param _offset The section of the delegator array to snapshot at the current block.
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

        uint256 from = _offset * delegators.length / DELEGATORS_ALIQUOT;
        uint256 to = (_offset + 1) * delegators.length / DELEGATORS_ALIQUOT;

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
