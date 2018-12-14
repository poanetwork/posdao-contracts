pragma solidity 0.4.25;

import "./interfaces/IBlockReward.sol";
import "./interfaces/IERC20Token.sol";
import "./interfaces/IValidatorSet.sol";
import "./eternal-storage/EternalStorage.sol";
import "./libs/SafeMath.sol";


contract BlockReward is EternalStorage, IBlockReward {
    using SafeMath for uint256;

    // ============================================== Constants =======================================================

    // These value must be changed before deploy
    uint256 public constant BLOCK_REWARD = 100 ether;
    uint256 public constant BRIDGES_ALLOWED_LENGTH = 1;
    address public constant ERC20_TOKEN_CONTRACT = address(0);
    address public constant VALIDATOR_SET_CONTRACT = address(0);

    // ================================================ Events ========================================================

    event AddedReceiver(uint256 amount, address indexed receiver, address indexed bridge);
    event RewardedByBlock(address[] receivers, uint256[] rewards);
    event RewardedERC20ByBlock(address[] receivers, uint256[] rewards);

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

    function reward(address[] benefactors, uint16[] /*kind*/)
        external
        onlySystem
        returns (address[], uint256[])
    {
        _mintTokensForStakers(benefactors);
        return _mintCoinsByBridge();
    }

    function setSnapshot(uint256 _poolBlockReward, address[] _validators) external onlyValidatorSet {
        IValidatorSet validatorSet = IValidatorSet(VALIDATOR_SET_CONTRACT);
        address validator;
        address[] memory stakers;
        uint256 i;
        uint256 s;

        // Clear the previous snapshot
        address[] memory validators = snapshotValidators();
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
        _setSnapshotPoolBlockReward(_poolBlockReward);

        _setSnapshotValidators(_validators);
        for (i = 0; i < _validators.length; i++) {
            validator = _validators[i];

            _setSnapshotStakeAmount(validator, validator, validatorSet.snapshotStakeAmount(validator, validator));

            stakers = validatorSet.snapshotStakers(validator);
            for (s = 0; s < stakers.length; s++) {
                _setSnapshotStakeAmount(validator, stakers[s], validatorSet.snapshotStakeAmount(validator, stakers[s]));
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

    function snapshotPoolBlockReward() public view returns(uint256) {
        return uintStorage[SNAPSHOT_POOL_BLOCK_REWARD];
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
    bytes32 internal constant SNAPSHOT_POOL_BLOCK_REWARD = keccak256("snapshotPoolBlockReward");
    bytes32 internal constant SNAPSHOT_VALIDATORS = keccak256("snapshotValidators");

    bytes32 internal constant BRIDGE_AMOUNT = "bridgeAmount";
    bytes32 internal constant EXTRA_RECEIVER_AMOUNT = "extraReceiverAmount";
    bytes32 internal constant MINTED_FOR_ACCOUNT = "mintedForAccount";
    bytes32 internal constant MINTED_FOR_ACCOUNT_IN_BLOCK = "mintedForAccountInBlock";
    bytes32 internal constant MINTED_IN_BLOCK = "mintedInBlock";
    bytes32 internal constant MINTED_TOTALLY_BY_BRIDGE = "mintedTotallyByBridge";
    bytes32 internal constant SNAPSHOT_STAKERS = "snapshotStakers";
    bytes32 internal constant SNAPSHOT_STAKE_AMOUNT = "snapshotStakeAmount";

    function _addExtraReceiver(address _receiver) private {
        addressArrayStorage[EXTRA_RECEIVERS].push(_receiver);
    }

    function _addMintedTotallyByBridge(uint256 _amount, address _bridge) private {
        bytes32 hash = keccak256(abi.encode(MINTED_TOTALLY_BY_BRIDGE, _bridge));
        uintStorage[hash] = uintStorage[hash].add(_amount);
    }

    function _clearExtraReceivers() private {
        addressArrayStorage[EXTRA_RECEIVERS].length = 0;
    }

    function _clearSnapshotStakers(address _validator) private {
        delete addressArrayStorage[
            keccak256(abi.encode(SNAPSHOT_STAKERS, _validator))
        ];
    }

    // Accrue native coins to bridge's receivers if any
    function _mintCoinsByBridge() internal returns(address[], uint256[]) {
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

    // Mint ERC20 tokens for each staker of each active validator
    function _mintTokensForStakers(address[] benefactors) internal {
        IERC20Token erc20Contract = IERC20Token(ERC20_TOKEN_CONTRACT);

        if (erc20Contract == address(0)) {
            return;
        }

        uint256 poolReward = snapshotPoolBlockReward();

        for (uint256 i = 0; i < benefactors.length; i++) {
            uint256 s;
            address[] memory stakers = snapshotStakers(benefactors[i]);
            address[] memory erc20Receivers = new address[](stakers.length.add(1));
            uint256[] memory erc20Rewards = new uint256[](erc20Receivers.length);

            uint256 validatorStake = snapshotStakeAmount(benefactors[i], benefactors[i]);
            uint256 stakersAmount = 0;

            for (s = 0; s < stakers.length; s++) {
                stakersAmount += snapshotStakeAmount(benefactors[i], stakers[s]);
            }

            uint256 totalAmount = validatorStake + stakersAmount;
            bool validatorDominates = validatorStake > stakersAmount;

            // Calculate reward for each staker
            for (s = 0; s < stakers.length; s++) {
                uint256 stakerStake = snapshotStakeAmount(benefactors[i], stakers[s]);

                erc20Receivers[s] = stakers[s];
                if (validatorDominates) {
                    erc20Rewards[s] = poolReward.mul(stakerStake).div(totalAmount);
                } else {
                    erc20Rewards[s] = poolReward.mul(stakerStake).mul(7).div(stakersAmount.mul(10));
                }
            }

            // Calculate reward for each validator
            erc20Receivers[s] = benefactors[i];
            if (validatorDominates) {
                erc20Rewards[s] = poolReward.mul(validatorStake).div(totalAmount);
            } else {
                erc20Rewards[s] = poolReward.mul(3).div(10);
            }

            erc20Contract.mintReward(erc20Receivers, erc20Rewards);
            
            emit RewardedERC20ByBlock(erc20Receivers, erc20Rewards);
        }
    }

    function _setBridgeAmount(uint256 _amount, address _bridge) private {
        uintStorage[
            keccak256(abi.encode(BRIDGE_AMOUNT, _bridge))
        ] = _amount;
    }

    function _setExtraReceiverAmount(uint256 _amount, address _receiver) private {
        uintStorage[
            keccak256(abi.encode(EXTRA_RECEIVER_AMOUNT, _receiver))
        ] = _amount;
    }

    function _setMinted(uint256 _amount, address _account) private {
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

    function _setSnapshotPoolBlockReward(uint256 _reward) private {
        uintStorage[SNAPSHOT_POOL_BLOCK_REWARD] = _reward;
    }

    function _setSnapshotStakeAmount(address _validator, address _staker, uint256 _amount) private {
        uintStorage[
            keccak256(abi.encode(SNAPSHOT_STAKE_AMOUNT, _validator, _staker))
        ] = _amount;
    }

    function _setSnapshotStakers(address _validator, address[] _stakers) private {
        addressArrayStorage[
            keccak256(abi.encode(SNAPSHOT_STAKERS, _validator))
        ] = _stakers;
    }

    function _setSnapshotValidators(address[] _validators) private {
        addressArrayStorage[SNAPSHOT_VALIDATORS] = _validators;
    }

    function _isBridgeContract(address _addr) private pure returns(bool) {
        address[BRIDGES_ALLOWED_LENGTH] memory bridges = bridgesAllowed();
        
        for (uint256 i = 0; i < bridges.length; i++) {
            if (_addr == bridges[i]) {
                return true;
            }
        }

        return false;
    }
}
