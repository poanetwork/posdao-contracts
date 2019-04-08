pragma solidity 0.5.2;

import "../interfaces/IBlockReward.sol";
import "../interfaces/IValidatorSet.sol";
import "../interfaces/IStaking.sol";
import "../eternal-storage/OwnedEternalStorage.sol";
import "../libs/SafeMath.sol";


contract BlockRewardBase is OwnedEternalStorage, IBlockReward {
    using SafeMath for uint256;

    // ============================================== Constants =======================================================

    // This address must be set before deploy
    address public constant VALIDATOR_SET_CONTRACT = address(0x1000000000000000000000000000000000000001);

    uint256 public constant DELEGATORS_ALIQUOT = 2;

    // ================================================ Events ========================================================

    event AddedReceiver(uint256 amount, address indexed receiver, address indexed bridge);
    event MintedNative(address[] receivers, uint256[] rewards);

    // ============================================== Modifiers =======================================================

    modifier onlyErcToNativeBridge {
        require(boolStorage[keccak256(abi.encode(ERC_TO_NATIVE_BRIDGE_ALLOWED, msg.sender))]);
        _;
    }

    modifier onlyXToErcBridge {
        require(
            boolStorage[keccak256(abi.encode(ERC_TO_ERC_BRIDGE_ALLOWED, msg.sender))] ||
            boolStorage[keccak256(abi.encode(NATIVE_TO_ERC_BRIDGE_ALLOWED, msg.sender))]
        );
        _;
    }

    modifier onlySystem {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    modifier onlyValidatorSet {
        require(msg.sender == VALIDATOR_SET_CONTRACT);
        _;
    }

    // =============================================== Setters ========================================================

    // This function can only be called by erc-to-native
    function addBridgeNativeFeeReceivers(uint256 _amount) external onlyErcToNativeBridge {
        require(_amount != 0);
        _addBridgeNativeFee(_amount);
    }

    // This function can only be called by native-to-erc or erc-to-erc bridge
    function addBridgeTokenFeeReceivers(uint256 _amount) external onlyXToErcBridge {
        require(_amount != 0);
        _addBridgeTokenFee(_amount);
    }

    function addExtraReceiver(uint256 _amount, address _receiver) external onlyErcToNativeBridge {
        require(_amount != 0);
        require(_receiver != address(0));
        require(boolStorage[QUEUE_ER_INITIALIZED]);
        _enqueueExtraReceiver(_amount, _receiver, msg.sender);
        emit AddedReceiver(_amount, _receiver, msg.sender);
    }

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

    function ercToErcBridgesAllowed() public view returns(address[] memory ) {
        return addressArrayStorage[ERC_TO_ERC_BRIDGES_ALLOWED];
    }

    function ercToNativeBridgesAllowed() public view returns(address[] memory) {
        return addressArrayStorage[ERC_TO_NATIVE_BRIDGES_ALLOWED];
    }

    function extraReceiversQueueSize() public view returns(uint256) {
        return _extraReceiversQueueSize();
    }

    function getBridgeNativeFee() public view returns(uint256) {
        return uintStorage[BRIDGE_NATIVE_FEE];
    }

    function getBridgeTokenFee() public view returns(uint256) {
        return uintStorage[BRIDGE_TOKEN_FEE];
    }

    function isRewarding() public view returns(bool) {
        return boolStorage[IS_REWARDING];
    }

    function isSnapshotting() public view returns(bool) {
        return boolStorage[IS_SNAPSHOTTING];
    }

    function mintedForAccount(address _account)
        public
        view
        returns(uint256)
    {
        return uintStorage[
            keccak256(abi.encode(MINTED_FOR_ACCOUNT, _account))
        ];
    }

    function mintedForAccountInBlock(address _account, uint256 _blockNumber)
        public
        view
        returns(uint256)
    {
        return uintStorage[
            keccak256(abi.encode(MINTED_FOR_ACCOUNT_IN_BLOCK, _account, _blockNumber))
        ];
    }

    function mintedInBlock(uint256 _blockNumber) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(MINTED_IN_BLOCK, _blockNumber))
        ];
    }

    function mintedTotallyByBridge(address _bridge) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(MINTED_TOTALLY_BY_BRIDGE, _bridge))
        ];
    }

    function mintedTotally() public view returns(uint256) {
        return uintStorage[MINTED_TOTALLY];
    }

    function nativeToErcBridgesAllowed() public view returns(address[] memory ) {
        return addressArrayStorage[NATIVE_TO_ERC_BRIDGES_ALLOWED];
    }

    function snapshotRewardPercents(address _validatorStakingAddress) public view returns(uint256[] memory) {
        return uintArrayStorage[
            keccak256(abi.encode(SNAPSHOT_REWARD_PERCENTS, _validatorStakingAddress))
        ];
    }

    function snapshotStakers(address _validatorStakingAddress) public view returns(address[] memory) {
        return addressArrayStorage[
            keccak256(abi.encode(SNAPSHOT_STAKERS, _validatorStakingAddress))
        ];
    }

    function snapshotStakingAddresses() public view returns(address[] memory) {
        return addressArrayStorage[SNAPSHOT_STAKING_ADDRESSES];
    }

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

    function _addBridgeNativeFee(uint256 _amount) internal {
        uintStorage[BRIDGE_NATIVE_FEE] = uintStorage[BRIDGE_NATIVE_FEE].add(_amount);
    }

    function _addBridgeTokenFee(uint256 _amount) internal {
        uintStorage[BRIDGE_TOKEN_FEE] = uintStorage[BRIDGE_TOKEN_FEE].add(_amount);
    }

    // Accrue native coins to bridge's receivers if any
    function _mintNativeCoinsByErcToNativeBridge(
        address[] memory _bridgeFeeReceivers,
        uint256[] memory _bridgeFeeRewards,
        uint256 _queueLimit
    )
        internal
        returns(address[] memory receivers, uint256[] memory rewards)
    {
        uint256 extraLength = _extraReceiversQueueSize();

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

    function _enqueueExtraReceiver(uint256 _amount, address _receiver, address _bridge) internal {
        uint256 queueLast = uintStorage[QUEUE_ER_LAST] + 1;
        uintStorage[keccak256(abi.encode(QUEUE_ER_AMOUNT, queueLast))] = _amount;
        addressStorage[keccak256(abi.encode(QUEUE_ER_RECEIVER, queueLast))] = _receiver;
        addressStorage[keccak256(abi.encode(QUEUE_ER_BRIDGE, queueLast))] = _bridge;
        uintStorage[QUEUE_ER_LAST] = queueLast;
    }

    function _setMinted(uint256 _amount, address _account, address _bridge) internal {
        uintStorage[keccak256(abi.encode(MINTED_FOR_ACCOUNT_IN_BLOCK, _account, block.number))] = _amount;
        uintStorage[keccak256(abi.encode(MINTED_FOR_ACCOUNT, _account))] += _amount;
        uintStorage[keccak256(abi.encode(MINTED_IN_BLOCK, block.number))] += _amount;
        uintStorage[keccak256(abi.encode(MINTED_TOTALLY_BY_BRIDGE, _bridge))] += _amount;
        uintStorage[MINTED_TOTALLY] += _amount;
    }

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

    function _extraReceiversQueueSize() internal view returns(uint256) {
        return uintStorage[QUEUE_ER_LAST] + 1 - uintStorage[QUEUE_ER_FIRST];
    }
}
