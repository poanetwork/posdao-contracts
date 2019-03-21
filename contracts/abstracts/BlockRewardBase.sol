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
    event MintedByBridge(address[] receivers, uint256[] rewards);

    // ============================================== Modifiers =======================================================

    modifier onlyErcToNativeBridge {
        require(_isErcToNativeBridge(msg.sender));
        _;
    }

    modifier onlyXToErcBridge {
        require(_isErcToErcBridge(msg.sender) || _isNativeToErcBridge(msg.sender));
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
        _addBridgeNativeFee(_getStakingEpoch(), _amount);
    }

    // This function can only be called by native-to-erc or erc-to-erc bridge
    function addBridgeTokenFeeReceivers(uint256 _amount) external onlyXToErcBridge {
        require(_amount != 0);
        _addBridgeTokenFee(_getStakingEpoch(), _amount);
    }

    function addExtraReceiver(uint256 _amount, address _receiver) external onlyErcToNativeBridge {
        require(_amount != 0);
        require(_receiver != address(0));
        uint256 oldAmount = extraReceiverAmount(_receiver);
        if (oldAmount == 0) {
            _addExtraReceiver(_receiver);
        }
        _setExtraReceiverAmount(oldAmount.add(_amount), _receiver);
        _setBridgeAmount(bridgeAmount(msg.sender).add(_amount), msg.sender);
        emit AddedReceiver(_amount, _receiver, msg.sender);
    }

    function setErcToNativeBridgesAllowed(address[] calldata _bridgesAllowed) external onlyOwner {
        addressArrayStorage[ERC_TO_NATIVE_BRIDGES_ALLOWED] = _bridgesAllowed;
    }

    function setNativeToErcBridgesAllowed(address[] calldata _bridgesAllowed) external onlyOwner {
        addressArrayStorage[NATIVE_TO_ERC_BRIDGES_ALLOWED] = _bridgesAllowed;
    }

    function setErcToErcBridgesAllowed(address[] calldata _bridgesAllowed) external onlyOwner {
        addressArrayStorage[ERC_TO_ERC_BRIDGES_ALLOWED] = _bridgesAllowed;
    }

    function setPendingValidatorsEnqueued(bool _enqueued) external onlyValidatorSet {
        _setPendingValidatorsEnqueued(_enqueued);
    }

    // =============================================== Getters ========================================================

    function bridgeAmount(address _bridge) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(BRIDGE_AMOUNT, _bridge))
        ];
    }

    function ercToErcBridgesAllowed() public view returns(address[] memory ) {
        return addressArrayStorage[ERC_TO_ERC_BRIDGES_ALLOWED];
    }

    function ercToNativeBridgesAllowed() public view returns(address[] memory) {
        return addressArrayStorage[ERC_TO_NATIVE_BRIDGES_ALLOWED];
    }

    function extraReceiverByIndex(uint256 _index) public view returns(address) {
        return addressArrayStorage[EXTRA_RECEIVERS][_index];
    }

    function extraReceiverAmount(address _receiver) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(EXTRA_RECEIVER_AMOUNT, _receiver))
        ];
    }

    function extraReceiversLength() public view returns(uint256) {
        return addressArrayStorage[EXTRA_RECEIVERS].length;
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

    function snapshotStakeAmount(
        uint256 _stakingEpoch,
        address _validatorStakingAddress,
        address _delegator
    ) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(SNAPSHOT_STAKE_AMOUNT, _stakingEpoch, _validatorStakingAddress, _delegator))
        ];
    }

    function snapshotDelegators(
        uint256 _stakingEpoch,
        address _validatorStakingAddress
    ) public view returns(address[] memory) {
        return addressArrayStorage[
            keccak256(abi.encode(SNAPSHOT_DELEGATORS, _stakingEpoch, _validatorStakingAddress))
        ];
    }

    function snapshotStakingAddresses(uint256 _stakingEpoch) public view returns(address[] memory) {
        return addressArrayStorage[
            keccak256(abi.encode(SNAPSHOT_STAKING_ADDRESSES, _stakingEpoch))
        ];
    }

    function snapshotTotalStakeAmount(uint256 _stakingEpoch) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(SNAPSHOT_TOTAL_STAKE_AMOUNT, _stakingEpoch))
        ];
    }

    // =============================================== Private ========================================================

    bytes32 internal constant ERC_TO_ERC_BRIDGES_ALLOWED = keccak256("ercToErcBridgesAllowed");
    bytes32 internal constant ERC_TO_NATIVE_BRIDGES_ALLOWED = keccak256("ercToNativeBridgesAllowed");
    bytes32 internal constant EXTRA_RECEIVERS = keccak256("extraReceivers");
    bytes32 internal constant MINTED_TOTALLY = keccak256("mintedTotally");
    bytes32 internal constant NATIVE_TO_ERC_BRIDGES_ALLOWED = keccak256("nativeToErcBridgesAllowed");
    bytes32 internal constant PENDING_VALIDATORS_ENQUEUED = keccak256("pendingValidatorsEnqueued");

    bytes32 internal constant BRIDGE_AMOUNT = "bridgeAmount";
    bytes32 internal constant BRIDGE_NATIVE_FEE = "bridgeNativeFee";
    bytes32 internal constant BRIDGE_TOKEN_FEE = "bridgeTokenFee";
    bytes32 internal constant EXTRA_RECEIVER_AMOUNT = "extraReceiverAmount";
    bytes32 internal constant MINTED_FOR_ACCOUNT = "mintedForAccount";
    bytes32 internal constant MINTED_FOR_ACCOUNT_IN_BLOCK = "mintedForAccountInBlock";
    bytes32 internal constant MINTED_IN_BLOCK = "mintedInBlock";
    bytes32 internal constant MINTED_TOTALLY_BY_BRIDGE = "mintedTotallyByBridge";
    bytes32 internal constant SNAPSHOT_DELEGATORS = "snapshotDelegators";
    bytes32 internal constant SNAPSHOT_STAKE_AMOUNT = "snapshotStakeAmount";
    bytes32 internal constant SNAPSHOT_STAKING_ADDRESSES = "snapshotStakingAddresses";
    bytes32 internal constant SNAPSHOT_TOTAL_STAKE_AMOUNT = "snapshotTotalStakeAmount";

    function _addBridgeNativeFee(uint256 _stakingEpoch, uint256 _amount) internal {
        bytes32 hash = keccak256(abi.encode(BRIDGE_NATIVE_FEE, _stakingEpoch));
        uintStorage[hash] = uintStorage[hash].add(_amount);
    }

    function _addBridgeTokenFee(uint256 _stakingEpoch, uint256 _amount) internal {
        bytes32 hash = keccak256(abi.encode(BRIDGE_TOKEN_FEE, _stakingEpoch));
        uintStorage[hash] = uintStorage[hash].add(_amount);
    }

    function _addExtraReceiver(address _receiver) internal {
        addressArrayStorage[EXTRA_RECEIVERS].push(_receiver);
    }

    function _addMintedTotallyByBridge(uint256 _amount, address _bridge) internal {
        bytes32 hash = keccak256(abi.encode(MINTED_TOTALLY_BY_BRIDGE, _bridge));
        uintStorage[hash] = uintStorage[hash].add(_amount);
    }

    function _addSnapshotStakingAddress(uint256 _stakingEpoch, address _stakingAddress) internal {
        addressArrayStorage[
            keccak256(abi.encode(SNAPSHOT_STAKING_ADDRESSES, _stakingEpoch))
        ].push(_stakingAddress);
    }

    function _addSnapshotTotalStakeAmount(uint256 _stakingEpoch, uint256 _amount) internal {
        uintStorage[
            keccak256(abi.encode(SNAPSHOT_TOTAL_STAKE_AMOUNT, _stakingEpoch))
        ] += _amount;
    }

    function _clearBridgeNativeFee(uint256 _stakingEpoch) internal {
        uintStorage[
            keccak256(abi.encode(BRIDGE_NATIVE_FEE, _stakingEpoch))
        ] = 0;
    }

    function _clearBridgeTokenFee(uint256 _stakingEpoch) internal {
        uintStorage[
            keccak256(abi.encode(BRIDGE_TOKEN_FEE, _stakingEpoch))
        ] = 0;
    }

    function _clearExtraReceivers() internal {
        addressArrayStorage[EXTRA_RECEIVERS].length = 0;
    }

    // Accrue native coins to bridge's receivers if any
    function _mintNativeCoinsByErcToNativeBridge()
        internal
        returns(address[] memory receivers, uint256[] memory rewards)
    {
        uint256 extraLength = extraReceiversLength();

        receivers = new address[](extraLength);
        rewards = new uint256[](extraLength);

        uint256 i;

        for (i = 0; i < extraLength; i++) {
            address extraAddress = extraReceiverByIndex(i);
            uint256 extraAmount = extraReceiverAmount(extraAddress);
            _setExtraReceiverAmount(0, extraAddress);
            receivers[i] = extraAddress;
            rewards[i] = extraAmount;
            _setMinted(extraAmount, extraAddress);
        }

        address[] memory bridgesAllowed = ercToNativeBridgesAllowed();
        for (i = 0; i < bridgesAllowed.length; i++) {
            address bridgeAddress = bridgesAllowed[i];
            uint256 bridgeAmountForBlock = bridgeAmount(bridgeAddress);

            if (bridgeAmountForBlock > 0) {
                _setBridgeAmount(0, bridgeAddress);
                _addMintedTotallyByBridge(bridgeAmountForBlock, bridgeAddress);
            }
        }

        _clearExtraReceivers();

        emit MintedByBridge(receivers, rewards);

        return (receivers, rewards);
    }

    function _setBridgeAmount(uint256 _amount, address _bridge) internal {
        uintStorage[
            keccak256(abi.encode(BRIDGE_AMOUNT, _bridge))
        ] = _amount;
    }

    function _setExtraReceiverAmount(uint256 _amount, address _receiver) internal {
        uintStorage[
            keccak256(abi.encode(EXTRA_RECEIVER_AMOUNT, _receiver))
        ] = _amount;
    }

    function _setMinted(uint256 _amount, address _account) internal {
        bytes32 hash;

        hash = keccak256(abi.encode(MINTED_FOR_ACCOUNT_IN_BLOCK, _account, block.number));
        uintStorage[hash] = _amount;

        hash = keccak256(abi.encode(MINTED_FOR_ACCOUNT, _account));
        uintStorage[hash] = uintStorage[hash].add(_amount);

        hash = keccak256(abi.encode(MINTED_IN_BLOCK, block.number));
        uintStorage[hash] = uintStorage[hash].add(_amount);

        hash = MINTED_TOTALLY;
        uintStorage[hash] = uintStorage[hash].add(_amount);
    }

    function _setPendingValidatorsEnqueued(bool _enqueued) internal {
        boolStorage[PENDING_VALIDATORS_ENQUEUED] = _enqueued;
    }

    function _setSnapshot(address _stakingAddress, IStaking _stakingContract) internal {
        uint256 stakingEpoch = _stakingContract.stakingEpoch();

        uint256 stakeAmount = _stakingContract.stakeAmountMinusOrderedWithdraw(_stakingAddress, _stakingAddress);
        uint256 totalStakeAmount = stakeAmount;

        _addSnapshotStakingAddress(stakingEpoch, _stakingAddress);
        _setSnapshotStakeAmount(stakingEpoch, _stakingAddress, _stakingAddress, stakeAmount);
        
        address[] memory delegators = _stakingContract.poolDelegators(_stakingAddress);

        for (uint256 i = 0; i < delegators.length; i++) {
            stakeAmount = _stakingContract.stakeAmountMinusOrderedWithdraw(_stakingAddress, delegators[i]);
            if (stakeAmount == 0) continue;
            _setSnapshotStakeAmount(stakingEpoch, _stakingAddress, delegators[i], stakeAmount);
            totalStakeAmount += stakeAmount;
        }

        addressArrayStorage[keccak256(abi.encode(
            SNAPSHOT_DELEGATORS, stakingEpoch, _stakingAddress
        ))] = delegators;

        _addSnapshotTotalStakeAmount(stakingEpoch, totalStakeAmount);
    }

    function _setSnapshotStakeAmount(
        uint256 _stakingEpoch,
        address _validatorStakingAddress,
        address _delegator,
        uint256 _amount
    ) internal {
        uintStorage[keccak256(abi.encode(
            SNAPSHOT_STAKE_AMOUNT, _stakingEpoch, _validatorStakingAddress, _delegator
        ))] = _amount;
    }

    function _distributePoolReward(
        uint256 _stakingEpoch,
        address _validatorStakingAddress,
        uint256 _poolReward
    ) internal view returns(address[] memory receivers, uint256[] memory rewards) {
        uint256 s;
        address[] memory delegators = snapshotDelegators(_stakingEpoch, _validatorStakingAddress);
        receivers = new address[](delegators.length.add(1));
        rewards = new uint256[](receivers.length);

        uint256 validatorStake = snapshotStakeAmount(_stakingEpoch, _validatorStakingAddress, _validatorStakingAddress);
        uint256 delegatorsAmount = 0;

        for (s = 0; s < delegators.length; s++) {
            delegatorsAmount += snapshotStakeAmount(_stakingEpoch, _validatorStakingAddress, delegators[s]);
        }

        uint256 totalStaked = validatorStake + delegatorsAmount;
        bool validatorHasMore30Per = validatorStake.mul(7) > delegatorsAmount.mul(3);

        // Calculate reward for each delegator
        for (s = 0; s < delegators.length; s++) {
            uint256 delegatorStake = snapshotStakeAmount(_stakingEpoch, _validatorStakingAddress, delegators[s]);
            receivers[s] = delegators[s];
            if (validatorHasMore30Per) {
                rewards[s] = _poolReward.mul(delegatorStake).div(totalStaked);
            } else {
                rewards[s] = _poolReward.mul(delegatorStake).mul(7).div(delegatorsAmount.mul(10));
            }
        }

        // Calculate reward for validator
        receivers[s] = _validatorStakingAddress;
        if (validatorStake > 0) {
            if (validatorHasMore30Per) {
                rewards[s] = _poolReward.mul(validatorStake).div(totalStaked);
            } else {
                rewards[s] = _poolReward.mul(3).div(10);
            }

            // Give remainder to validator
            for (s = 0; s < rewards.length; s++) {
                _poolReward -= rewards[s];
            }
            rewards[s - 1] += _poolReward;
        } else {
            rewards[s] = 0;
        }
    }

    function _getBridgeNativeFee(uint256 _stakingEpoch) internal view returns(uint256) {
        return uintStorage[keccak256(abi.encode(BRIDGE_NATIVE_FEE, _stakingEpoch))];
    }

    function _getBridgeTokenFee(uint256 _stakingEpoch) internal view returns(uint256) {
        return uintStorage[keccak256(abi.encode(BRIDGE_TOKEN_FEE, _stakingEpoch))];
    }

    function _getStakingEpoch() internal view returns(uint256) {
        IValidatorSet validatorSetContract = IValidatorSet(VALIDATOR_SET_CONTRACT);
        IStaking stakingContract = IStaking(validatorSetContract.stakingContract());

        uint256 stakingEpoch = stakingContract.stakingEpoch();

        if (stakingEpoch == 0) {
            return 0;
        }

        if (validatorSetContract.validatorSetApplyBlock() == 0) {
            stakingEpoch--; // use the previous staking epoch because the current one is not applied yet
        }

        return stakingEpoch;
    }

    function _isErcToNativeBridge(address _addr) internal view returns(bool) {
        address[] memory bridges = ercToNativeBridgesAllowed();

        for (uint256 i = 0; i < bridges.length; i++) {
            if (_addr == bridges[i]) {
                return true;
            }
        }

        return false;
    }

    function _isErcToErcBridge(address _addr) internal view returns(bool) {
        address[] memory bridges = ercToErcBridgesAllowed();

        for (uint256 i = 0; i < bridges.length; i++) {
            if (_addr == bridges[i]) {
                return true;
            }
        }

        return false;
    }

    function _isNativeToErcBridge(address _addr) internal view returns(bool) {
        address[] memory bridges = nativeToErcBridgesAllowed();

        for (uint256 i = 0; i < bridges.length; i++) {
            if (_addr == bridges[i]) {
                return true;
            }
        }

        return false;
    }
}
