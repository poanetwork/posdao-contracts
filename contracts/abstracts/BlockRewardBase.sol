pragma solidity 0.4.25;

import "../interfaces/IBlockReward.sol";
import "../interfaces/IValidatorSet.sol";
import "../eternal-storage/EternalStorage.sol";
import "../libs/SafeMath.sol";


contract BlockRewardBase is EternalStorage, IBlockReward {
    using SafeMath for uint256;

    // ============================================== Constants =======================================================

    // These value must be set before deploy
    uint256 public constant BRIDGES_ALLOWED_LENGTH = 1; // see also the `bridgesAllowed()` getter
    address public constant ERC20_TOKEN_CONTRACT = address(0);
    address public constant VALIDATOR_SET_CONTRACT = address(0);

    // ================================================ Events ========================================================

    event AddedReceiver(uint256 amount, address indexed receiver, address indexed bridge);
    event MintedByBridge(address[] receivers, uint256[] rewards);

    // ============================================== Modifiers =======================================================

    modifier onlyBridgeContract {
        require(_isBridgeContract(msg.sender));
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

    function addBridgeNativeFeeReceivers(uint256 _amount) external onlyBridgeContract {
        require(_amount != 0);
        _addBridgeNativeFee(_getStakingEpoch(), _amount);
    }

    function addBridgeTokenFeeReceivers(uint256 _amount) external onlyBridgeContract {
        require(_amount != 0);
        _addBridgeTokenFee(_getStakingEpoch(), _amount);
    }

    function addExtraReceiver(uint256 _amount, address _receiver) external onlyBridgeContract {
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

    function setSnapshot() external onlyValidatorSet {
        IValidatorSet validatorSet = IValidatorSet(VALIDATOR_SET_CONTRACT);

        address validator;
        address[] memory validators;
        address[] memory stakers;
        uint256 i;
        uint256 s;

        uint256 stakingEpoch = validatorSet.stakingEpoch();

        // Clear the snapshot of the staking epoch before last
        if (stakingEpoch >= 2) {
            uint256 stakingEpochBeforeLast = stakingEpoch - 2;

            validators = snapshotValidators(stakingEpochBeforeLast);
            for (i = 0; i < validators.length; i++) {
                validator = validators[i];
                _setSnapshotStakeAmount(stakingEpochBeforeLast, validator, validator, 0);
                stakers = snapshotStakers(stakingEpochBeforeLast, validator);
                for (s = 0; s < stakers.length; s++) {
                    _setSnapshotStakeAmount(stakingEpochBeforeLast, validator, stakers[s], 0);
                }
                _clearSnapshotStakers(stakingEpochBeforeLast, validator);
            }
        }

        // Set a new snapshot of the current staking epoch
        validators = validatorSet.getValidators();
        _setSnapshotValidators(stakingEpoch, validators);
        for (i = 0; i < validators.length; i++) {
            validator = validators[i];
            _setSnapshotStakeAmount(
                stakingEpoch,
                validator,
                validator,
                validatorSet.stakeAmount(validator, validator)
            );
            stakers = validatorSet.poolStakers(validator);
            for (s = 0; s < stakers.length; s++) {
                _setSnapshotStakeAmount(
                    stakingEpoch,
                    validator,
                    stakers[s],
                    validatorSet.stakeAmount(validator, stakers[s])
                );
            }
            _setSnapshotStakers(stakingEpoch, validator, stakers);
        }
    }

    // =============================================== Getters ========================================================

    function bridgesAllowed() public pure returns(address[BRIDGES_ALLOWED_LENGTH]) {
        // These addresses must be set before deploy
        return([
            address(0)
        ]);
    }

    function bridgeAmount(address _bridge) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(BRIDGE_AMOUNT, _bridge))
        ];
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

    function mintedTotally() public view returns(uint256) {
        return uintStorage[MINTED_TOTALLY];
    }

    function mintedTotallyByBridge(address _bridge) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(MINTED_TOTALLY_BY_BRIDGE, _bridge))
        ];
    }

    function snapshotStakeAmount(
        uint256 _stakingEpoch,
        address _validator,
        address _staker
    ) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(SNAPSHOT_STAKE_AMOUNT, _stakingEpoch, _validator, _staker))
        ];
    }

    function snapshotStakers(uint256 _stakingEpoch, address _validator) public view returns(address[]) {
        return addressArrayStorage[
            keccak256(abi.encode(SNAPSHOT_STAKERS, _stakingEpoch, _validator))
        ];
    }

    function snapshotValidators(uint256 _stakingEpoch) public view returns(address[]) {
        return addressArrayStorage[
            keccak256(abi.encode(SNAPSHOT_VALIDATORS, _stakingEpoch))
        ];
    }

    // =============================================== Private ========================================================

    bytes32 internal constant EXTRA_RECEIVERS = keccak256("extraReceivers");
    bytes32 internal constant MINTED_TOTALLY = keccak256("mintedTotally");

    bytes32 internal constant BRIDGE_AMOUNT = "bridgeAmount";
    bytes32 internal constant BRIDGE_NATIVE_FEE = "bridgeNativeFee";
    bytes32 internal constant BRIDGE_TOKEN_FEE = "bridgeTokenFee";
    bytes32 internal constant EXTRA_RECEIVER_AMOUNT = "extraReceiverAmount";
    bytes32 internal constant MINTED_FOR_ACCOUNT = "mintedForAccount";
    bytes32 internal constant MINTED_FOR_ACCOUNT_IN_BLOCK = "mintedForAccountInBlock";
    bytes32 internal constant MINTED_IN_BLOCK = "mintedInBlock";
    bytes32 internal constant MINTED_TOTALLY_BY_BRIDGE = "mintedTotallyByBridge";
    bytes32 internal constant SNAPSHOT_STAKERS = "snapshotStakers";
    bytes32 internal constant SNAPSHOT_STAKE_AMOUNT = "snapshotStakeAmount";
    bytes32 internal constant SNAPSHOT_VALIDATORS = "snapshotValidators";

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

    function _clearSnapshotStakers(uint256 _stakingEpoch, address _validator) internal {
        delete addressArrayStorage[
            keccak256(abi.encode(SNAPSHOT_STAKERS, _stakingEpoch, _validator))
        ];
    }

    // Accrue native coins to bridge's receivers if any
    function _mintNativeCoinsByBridge() internal returns(address[], uint256[]) {
        uint256 extraLength = extraReceiversLength();

        address[] memory receivers = new address[](extraLength);
        uint256[] memory rewards = new uint256[](extraLength);

        uint256 i;
        
        for (i = 0; i < extraLength; i++) {
            address extraAddress = extraReceiverByIndex(i);
            uint256 extraAmount = extraReceiverAmount(extraAddress);
            _setExtraReceiverAmount(0, extraAddress);
            receivers[i] = extraAddress;
            rewards[i] = extraAmount;
            _setMinted(extraAmount, extraAddress);
        }

        for (i = 0; i < BRIDGES_ALLOWED_LENGTH; i++) {
            address bridgeAddress = bridgesAllowed()[i];
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
        address _validator,
        address _staker,
        uint256 _amount
    ) internal {
        uintStorage[
            keccak256(abi.encode(SNAPSHOT_STAKE_AMOUNT, _stakingEpoch, _validator, _staker))
        ] = _amount;
    }

    function _setSnapshotStakers(uint256 _stakingEpoch, address _validator, address[] _stakers) internal {
        addressArrayStorage[
            keccak256(abi.encode(SNAPSHOT_STAKERS, _stakingEpoch, _validator))
        ] = _stakers;
    }

    function _setSnapshotValidators(uint256 _stakingEpoch, address[] _validators) internal {
        addressArrayStorage[
            keccak256(abi.encode(SNAPSHOT_VALIDATORS, _stakingEpoch))
        ] = _validators;
    }

    function _distributePoolReward(
        uint256 _stakingEpoch,
        address _validator,
        uint256 _poolReward
    ) internal view returns(address[], uint256[]) {
        uint256 s;
        address[] memory stakers = snapshotStakers(_stakingEpoch, _validator);
        address[] memory receivers = new address[](stakers.length.add(1));
        uint256[] memory rewards = new uint256[](receivers.length);

        uint256 validatorStake = snapshotStakeAmount(_stakingEpoch, _validator, _validator);
        uint256 stakersAmount = 0;

        for (s = 0; s < stakers.length; s++) {
            stakersAmount += snapshotStakeAmount(_stakingEpoch, _validator, stakers[s]);
        }

        // Calculate reward for each staker
        for (s = 0; s < stakers.length; s++) {
            uint256 stakerStake = snapshotStakeAmount(_stakingEpoch, _validator, stakers[s]);
            receivers[s] = stakers[s];
            if (validatorStake > stakersAmount) {
                rewards[s] = _poolReward.mul(stakerStake).div(validatorStake + stakersAmount);
            } else {
                rewards[s] = _poolReward.mul(stakerStake).mul(7).div(stakersAmount.mul(10));
            }
        }

        // Calculate reward for validator
        receivers[s] = _validator;
        if (validatorStake > stakersAmount) {
            rewards[s] = _poolReward.mul(validatorStake).div(validatorStake + stakersAmount);
        } else {
            rewards[s] = _poolReward.mul(3).div(10);
        }

        // Give remainder to validator
        for (s = 0; s < rewards.length; s++) {
            _poolReward -= rewards[s];
        }
        rewards[s - 1] += _poolReward;

        return (receivers, rewards);
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

    function _isBridgeContract(address _addr) internal pure returns(bool) {
        address[BRIDGES_ALLOWED_LENGTH] memory bridges = bridgesAllowed();
        
        for (uint256 i = 0; i < bridges.length; i++) {
            if (_addr == bridges[i]) {
                return true;
            }
        }

        return false;
    }
}
