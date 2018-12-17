pragma solidity 0.4.25;

import "../interfaces/IBlockReward.sol";
import "../interfaces/IValidatorSet.sol";
import "../eternal-storage/EternalStorage.sol";
import "../libs/SafeMath.sol";


contract BlockRewardBase is EternalStorage, IBlockReward {
    using SafeMath for uint256;

    // ============================================== Constants =======================================================

    // These value must be changed before deploy
    uint256 public constant BRIDGES_ALLOWED_LENGTH = 1;
    address public constant VALIDATOR_SET_CONTRACT = address(0);

    // ================================================ Events ========================================================

    event AddedReceiver(uint256 amount, address indexed receiver, address indexed bridge);
    event RewardedByBlock(address[] receivers, uint256[] rewards);

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

    function addExtraReceiver(uint256 _amount, address _receiver)
        external
        onlyBridgeContract
    {
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

        // Clear the previous snapshot
        validators = snapshotValidators();
        for (i = 0; i < validators.length; i++) {
            validator = validators[i];
            _setSnapshotStakeAmount(validator, validator, 0);
            stakers = snapshotStakers(validator);
            for (s = 0; s < stakers.length; s++) {
                _setSnapshotStakeAmount(validator, stakers[s], 0);
            }
            _clearSnapshotStakers(validator);
        }

        // Set a new snapshot
        validators = validatorSet.getValidators();
        _setSnapshotValidators(validators);
        for (i = 0; i < validators.length; i++) {
            validator = validators[i];
            _setSnapshotStakeAmount(validator, validator, validatorSet.stakeAmount(validator, validator));
            stakers = validatorSet.poolStakers(validator);
            for (s = 0; s < stakers.length; s++) {
                _setSnapshotStakeAmount(validator, stakers[s], validatorSet.stakeAmount(validator, stakers[s]));
            }
            _setSnapshotStakers(validator, stakers);
        }
    }

    // =============================================== Getters ========================================================

    function bridgesAllowed() public pure returns(address[BRIDGES_ALLOWED_LENGTH]) {
        // These values must be changed before deploy
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

    function snapshotStakeAmount(address _validator, address _staker) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(SNAPSHOT_STAKE_AMOUNT, _validator, _staker))
        ];
    }

    function snapshotStakers(address _validator) public view returns(address[]) {
        return addressArrayStorage[
            keccak256(abi.encode(SNAPSHOT_STAKERS, _validator))
        ];
    }

    function snapshotValidators() public view returns(address[]) {
        return addressArrayStorage[SNAPSHOT_VALIDATORS];
    }

    // =============================================== Private ========================================================

    bytes32 internal constant EXTRA_RECEIVERS = keccak256("extraReceivers");
    bytes32 internal constant MINTED_TOTALLY = keccak256("mintedTotally");
    bytes32 internal constant SNAPSHOT_VALIDATORS = keccak256("snapshotValidators");

    bytes32 internal constant BRIDGE_AMOUNT = "bridgeAmount";
    bytes32 internal constant EXTRA_RECEIVER_AMOUNT = "extraReceiverAmount";
    bytes32 internal constant MINTED_FOR_ACCOUNT = "mintedForAccount";
    bytes32 internal constant MINTED_FOR_ACCOUNT_IN_BLOCK = "mintedForAccountInBlock";
    bytes32 internal constant MINTED_IN_BLOCK = "mintedInBlock";
    bytes32 internal constant MINTED_TOTALLY_BY_BRIDGE = "mintedTotallyByBridge";
    bytes32 internal constant SNAPSHOT_STAKERS = "snapshotStakers";
    bytes32 internal constant SNAPSHOT_STAKE_AMOUNT = "snapshotStakeAmount";

    function _addExtraReceiver(address _receiver) internal {
        addressArrayStorage[EXTRA_RECEIVERS].push(_receiver);
    }

    function _addMintedTotallyByBridge(uint256 _amount, address _bridge) internal {
        bytes32 hash = keccak256(abi.encode(MINTED_TOTALLY_BY_BRIDGE, _bridge));
        uintStorage[hash] = uintStorage[hash].add(_amount);
    }

    function _clearExtraReceivers() internal {
        addressArrayStorage[EXTRA_RECEIVERS].length = 0;
    }

    function _clearSnapshotStakers(address _validator) internal {
        delete addressArrayStorage[
            keccak256(abi.encode(SNAPSHOT_STAKERS, _validator))
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

        emit RewardedByBlock(receivers, rewards);

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

    function _setSnapshotStakeAmount(address _validator, address _staker, uint256 _amount) internal {
        uintStorage[
            keccak256(abi.encode(SNAPSHOT_STAKE_AMOUNT, _validator, _staker))
        ] = _amount;
    }

    function _setSnapshotStakers(address _validator, address[] _stakers) internal {
        addressArrayStorage[
            keccak256(abi.encode(SNAPSHOT_STAKERS, _validator))
        ] = _stakers;
    }

    function _setSnapshotValidators(address[] _validators) internal {
        addressArrayStorage[SNAPSHOT_VALIDATORS] = _validators;
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
