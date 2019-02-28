pragma solidity 0.5.2;

import "../interfaces/IBlockReward.sol";
import "../interfaces/IValidatorSet.sol";
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

    modifier onlyNativeToErcBridge {
        require(_isNativeToErcBridge(msg.sender));
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

    function addBridgeNativeFeeReceivers(uint256 _amount) external onlyErcToNativeBridge {
        require(_amount != 0);
        _addBridgeNativeFee(_getStakingEpoch(), _amount);
    }

    function addBridgeTokenFeeReceivers(uint256 _amount) external onlyNativeToErcBridge {
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

    function setSnapshot() external onlyValidatorSet {
        IValidatorSet validatorSet = IValidatorSet(VALIDATOR_SET_CONTRACT);

        address validatorStakingAddress;
        address[] memory validatorsStakingAddresses;
        address[] memory delegators;
        uint256 i;
        uint256 s;

        uint256 stakingEpoch = validatorSet.stakingEpoch();

        // Clear the snapshot of the staking epoch before last
        if (stakingEpoch >= 2) {
            uint256 stakingEpochBeforeLast = stakingEpoch - 2;

            validatorsStakingAddresses = snapshotStakingAddresses(stakingEpochBeforeLast);
            for (i = 0; i < validatorsStakingAddresses.length; i++) {
                validatorStakingAddress = validatorsStakingAddresses[i];
                _setSnapshotStakeAmount(stakingEpochBeforeLast, validatorStakingAddress, validatorStakingAddress, 0);
                delegators = snapshotDelegators(stakingEpochBeforeLast, validatorStakingAddress);
                for (s = 0; s < delegators.length; s++) {
                    _setSnapshotStakeAmount(stakingEpochBeforeLast, validatorStakingAddress, delegators[s], 0);
                }
                _clearSnapshotDelegators(stakingEpochBeforeLast, validatorStakingAddress);
            }
        }

        // Set a new snapshot of the current staking epoch
        address[] memory validators = validatorSet.getValidators();
        validatorsStakingAddresses = new address[](validators.length);
        for (i = 0; i < validators.length; i++) {
            validatorsStakingAddresses[i] = validatorSet.stakingByMiningAddress(validators[i]);
        }
        _setSnapshotStakingAddresses(stakingEpoch, validatorsStakingAddresses);
        for (i = 0; i < validatorsStakingAddresses.length; i++) {
            validatorStakingAddress = validatorsStakingAddresses[i];
            _setSnapshotStakeAmount(
                stakingEpoch,
                validatorStakingAddress,
                validatorStakingAddress,
                validatorSet.stakeAmountMinusOrderedWithdraw(validatorStakingAddress, validatorStakingAddress)
            );
            delete addressArrayStorage[DELEGATORS_TEMPORARY_ARRAY];
            delegators = validatorSet.poolDelegators(validatorStakingAddress);
            for (s = 0; s < delegators.length; s++) {
                uint256 delegatorStakeAmount = validatorSet.stakeAmountMinusOrderedWithdraw(
                    validatorStakingAddress,
                    delegators[s]
                );
                if (delegatorStakeAmount == 0) {
                    continue;
                }
                _setSnapshotStakeAmount(
                    stakingEpoch,
                    validatorStakingAddress,
                    delegators[s],
                    delegatorStakeAmount
                );
                addressArrayStorage[DELEGATORS_TEMPORARY_ARRAY].push(delegators[s]);
            }
            _setSnapshotDelegators(
                stakingEpoch,
                validatorStakingAddress,
                addressArrayStorage[DELEGATORS_TEMPORARY_ARRAY]
            );
            delete addressArrayStorage[DELEGATORS_TEMPORARY_ARRAY];
        }
    }

    // =============================================== Getters ========================================================

    function bridgeAmount(address _bridge) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(BRIDGE_AMOUNT, _bridge))
        ];
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

    // =============================================== Private ========================================================

    bytes32 internal constant DELEGATORS_TEMPORARY_ARRAY = keccak256("delegatorsTemporaryArray");
    bytes32 internal constant ERC_TO_NATIVE_BRIDGES_ALLOWED = keccak256("ercToNativeBridgesAllowed");
    bytes32 internal constant EXTRA_RECEIVERS = keccak256("extraReceivers");
    bytes32 internal constant MINTED_TOTALLY = keccak256("mintedTotally");
    bytes32 internal constant NATIVE_TO_ERC_BRIDGES_ALLOWED = keccak256("nativeToErcBridgesAllowed");

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

    function _clearSnapshotDelegators(uint256 _stakingEpoch, address _validatorStakingAddress) internal {
        delete addressArrayStorage[keccak256(abi.encode(
            SNAPSHOT_DELEGATORS, _stakingEpoch, _validatorStakingAddress
        ))];
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

    function _setSnapshotDelegators(
        uint256 _stakingEpoch,
        address _validatorStakingAddress,
        address[] memory _delegators
    ) internal {
        addressArrayStorage[keccak256(abi.encode(
            SNAPSHOT_DELEGATORS, _stakingEpoch, _validatorStakingAddress
        ))] = _delegators;
    }

    function _setSnapshotStakingAddresses(uint256 _stakingEpoch, address[] memory _stakingAddresses) internal {
        addressArrayStorage[
            keccak256(abi.encode(SNAPSHOT_STAKING_ADDRESSES, _stakingEpoch))
        ] = _stakingAddresses;
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

        uint256 stakingEpoch = validatorSetContract.stakingEpoch();

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
