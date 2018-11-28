pragma solidity 0.4.25;

import "./interfaces/IBlockReward.sol";
import "./interfaces/IERC20Token.sol";
import "./interfaces/IReportingValidatorSet.sol";
import "./eternal-storage/EternalStorage.sol";
import "./libs/SafeMath.sol";


contract BlockReward is EternalStorage, IBlockReward {
    using SafeMath for uint256;

    bytes32 internal constant EXTRA_RECEIVERS = keccak256("extraReceivers");
    bytes32 internal constant POOL_REWARD = keccak256("poolReward");
    bytes32 internal constant MINTED_TOTALLY = keccak256("mintedTotally");
    bytes32 internal constant REWARD_DISTRIBUTION_VALIDATORS = keccak256("rewardDistributionValidators");

    bytes32 internal constant BRIDGE_AMOUNT = "bridgeAmount";
    bytes32 internal constant EXTRA_RECEIVER_AMOUNT = "extraReceiverAmount";
    bytes32 internal constant MINTED_FOR_ACCOUNT = "mintedForAccount";
    bytes32 internal constant MINTED_FOR_ACCOUNT_IN_BLOCK = "mintedForAccountInBlock";
    bytes32 internal constant MINTED_IN_BLOCK = "mintedInBlock";
    bytes32 internal constant MINTED_TOTALLY_BY_BRIDGE = "mintedTotallyByBridge";
    bytes32 internal constant REWARD_DISTRIBUTION = "rewardDistribution";
    bytes32 internal constant REWARD_DISTRIBUTION_STAKERS = "rewardDistributionStakers";

    // ============================================== Constants =======================================================

    // These value must be changed before deploy
    uint256 public constant BLOCK_REWARD = 100 ether;
    uint256 public constant BRIDGES_ALLOWED_LENGTH = 1;
    address public constant ERC20_TOKEN_CONTRACT = 0x0000000000000000000000000000000000000000;
    address public constant VALIDATOR_SET_CONTRACT = 0x0000000000000000000000000000000000000000;

    // ================================================ Events ========================================================

    event AddedReceiver(uint256 amount, address indexed receiver, address indexed bridge);
    event Rewarded(address[] receivers, uint256[] rewards);
    event RewardedERC20(address[] receivers, uint256[] rewards);

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
        // Accrue native coins to bridge's receivers
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

        emit Rewarded(receivers, rewards);

        // Mint ERC20 tokens for each staker of each active validator
        IERC20Token erc20Contract = IERC20Token(ERC20_TOKEN_CONTRACT);
        for (i = 0; i < benefactors.length; i++) {
            uint256 s;
            address[] memory stakers = rewardDistributionStakers(benefactors[i]);
            address[] memory erc20Receivers = new address[](stakers.length.add(1));
            uint256[] memory erc20Rewards = new uint256[](erc20Receivers.length);

            for (s = 0; s < stakers.length; s++) {
                erc20Receivers[s] = stakers[s];
                erc20Rewards[s] = rewardDistribution(benefactors[i], stakers[s]);
            }

            erc20Receivers[s] = benefactors[i];
            erc20Rewards[s] = rewardDistribution(benefactors[i], benefactors[i]);

            erc20Contract.mintReward(erc20Receivers, erc20Rewards);
            
            emit RewardedERC20(erc20Receivers, erc20Rewards);
        }
    
        return (receivers, rewards);
    }

    function setRewardDistribution(uint256 _poolReward, address[] _validators) external onlyValidatorSet {
        IReportingValidatorSet validatorSet = IReportingValidatorSet(VALIDATOR_SET_CONTRACT);
        address validator;
        address[] memory stakers;
        uint256 i;
        uint256 s;

        // Clear the previous distribution
        address[] memory validators = rewardDistributionValidators();
        for (i = 0; i < validators.length; i++) {
            validator = validators[i];
            _setRewardDistribution(validator, validator, 0);
            stakers = rewardDistributionStakers(validator);
            for (s = 0; s < stakers.length; s++) {
                _setRewardDistribution(validator, stakers[s], 0);
            }
            _clearRewardDistributionStakers(validator);
        }

        // Set a new distribution
        _setPoolReward(_poolReward);

        _setRewardDistributionValidators(_validators);
        for (i = 0; i < _validators.length; i++) {
            validator = _validators[i];

            _setRewardDistribution(validator, validator, validatorSet.rewardDistribution(validator, validator));

            stakers = validatorSet.rewardDistributionStakers(validator);
            _setRewardDistributionStakers(validator, stakers);
            for (s = 0; s < stakers.length; s++) {
                _setRewardDistribution(validator, stakers[s], validatorSet.rewardDistribution(validator, stakers[s]));
            }
        }
    }

    // =============================================== Getters ========================================================

    function bridgesAllowed() public pure returns(address[BRIDGES_ALLOWED_LENGTH]) {
        // These values must be changed before deploy
        return([
            address(0x0000000000000000000000000000000000000000)
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

    function poolReward() public view returns(uint256) {
        return uintStorage[POOL_REWARD];
    }

    function rewardDistribution(address _validator, address _staker) public view returns(uint256) {
        return uintStorage[
            keccak256(abi.encode(REWARD_DISTRIBUTION, _validator, _staker))
        ];
    }

    function rewardDistributionStakers(address _validator) public view returns(address[]) {
        return addressArrayStorage[
            keccak256(abi.encode(REWARD_DISTRIBUTION_STAKERS, _validator))
        ];
    }

    function rewardDistributionValidators() public view returns(address[]) {
        return addressArrayStorage[REWARD_DISTRIBUTION_VALIDATORS];
    }

    // =============================================== Private ========================================================

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

    function _clearRewardDistributionStakers(address _validator) private {
        delete addressArrayStorage[
            keccak256(abi.encode(REWARD_DISTRIBUTION_STAKERS, _validator))
        ];
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

    function _setPoolReward(uint256 _reward) private {
        uintStorage[POOL_REWARD] = _reward;
    }

    function _setRewardDistribution(address _validator, address _staker, uint256 _amount) private {
        uintStorage[
            keccak256(abi.encode(REWARD_DISTRIBUTION, _validator, _staker))
        ] = _amount;
    }

    function _setRewardDistributionStakers(address _validator, address[] _stakers) private {
        addressArrayStorage[
            keccak256(abi.encode(REWARD_DISTRIBUTION_STAKERS, _validator))
        ] = _stakers;
    }

    function _setRewardDistributionValidators(address[] _validators) private {
        addressArrayStorage[REWARD_DISTRIBUTION_VALIDATORS] = _validators;
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
