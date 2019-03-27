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

    function setPendingValidatorsEnqueued(bool _enqueued) external onlyValidatorSet {
        _setPendingValidatorsEnqueued(_enqueued);
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

    function pendingValidatorsEnqueued() public view returns(bool) {
        return boolStorage[PENDING_VALIDATORS_ENQUEUED];
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
    bytes32 internal constant MINTED_TOTALLY = keccak256("mintedTotally");
    bytes32 internal constant NATIVE_TO_ERC_BRIDGES_ALLOWED = keccak256("nativeToErcBridgesAllowed");
    bytes32 internal constant PENDING_VALIDATORS_ENQUEUED = keccak256("pendingValidatorsEnqueued");
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

    uint256 internal constant MAX_EXTRA_RECEIVERS_PER_BLOCK = 25;
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
        uint256[] memory _bridgeFeeRewards
    )
        internal
        returns(address[] memory receivers, uint256[] memory rewards)
    {
        uint256 extraLength = _extraReceiversQueueSize();

        if (extraLength > MAX_EXTRA_RECEIVERS_PER_BLOCK) {
            extraLength = MAX_EXTRA_RECEIVERS_PER_BLOCK;
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

    function _setPendingValidatorsEnqueued(bool _enqueued) internal {
        boolStorage[PENDING_VALIDATORS_ENQUEUED] = _enqueued;
    }

    function _setSnapshot(address _stakingAddress, IStaking _stakingContract) internal {
        uint256 validatorStake = _stakingContract.stakeAmountMinusOrderedWithdraw(_stakingAddress, _stakingAddress);
        uint256 totalStaked = _stakingContract.stakeAmountTotalMinusOrderedWithdraw(_stakingAddress);
        uint256 delegatorsAmount = totalStaked - validatorStake;
        bool validatorHasMore30Per = validatorStake.mul(7) > delegatorsAmount.mul(3);
        
        address[] memory delegators = _stakingContract.poolDelegators(_stakingAddress);
        address[] memory stakers = new address[](delegators.length + 1);
        uint256[] memory rewardPercents = new uint256[](stakers.length);
        uint256 i;

        // Calculate reward percent for each delegator
        for (i = 0; i < delegators.length; i++) {
            stakers[i] = delegators[i];
            uint256 delegatorStake = _stakingContract.stakeAmountMinusOrderedWithdraw(_stakingAddress, delegators[i]);
            
            if (delegatorStake == 0) {
                rewardPercents[i] = 0;
                continue;
            }

            if (validatorHasMore30Per) {
                rewardPercents[i] = REWARD_PERCENT_MULTIPLIER.mul(delegatorStake).div(totalStaked);
            } else {
                rewardPercents[i] = REWARD_PERCENT_MULTIPLIER.mul(delegatorStake).mul(7).div(delegatorsAmount.mul(10));
            }
        }

        // Calculate reward percent for validator
        stakers[i] = _stakingAddress;
        if (validatorStake > 0) {
            if (validatorHasMore30Per) {
                rewardPercents[i] = REWARD_PERCENT_MULTIPLIER.mul(validatorStake).div(totalStaked);
            } else {
                rewardPercents[i] = REWARD_PERCENT_MULTIPLIER.mul(3).div(10);
            }
        } else {
            rewardPercents[i] = 0;
        }

        addressArrayStorage[keccak256(abi.encode(
            SNAPSHOT_STAKERS, _stakingAddress
        ))] = stakers;

        uintArrayStorage[keccak256(abi.encode(
            SNAPSHOT_REWARD_PERCENTS, _stakingAddress
        ))] = rewardPercents;

        addressArrayStorage[SNAPSHOT_STAKING_ADDRESSES].push(_stakingAddress);

        uintStorage[SNAPSHOT_TOTAL_STAKE_AMOUNT] += totalStaked;
    }

    function _extraReceiversQueueSize() internal view returns(uint256) {
        return uintStorage[QUEUE_ER_LAST] + 1 - uintStorage[QUEUE_ER_FIRST];
    }
}
