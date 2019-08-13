pragma solidity 0.5.9;

import "./interfaces/IBlockRewardAuRa.sol";
import "./interfaces/IERC20Minting.sol";
import "./interfaces/IRandomAuRa.sol";
import "./interfaces/IStakingAuRa.sol";
import "./interfaces/IValidatorSetAuRa.sol";
import "./upgradeability/UpgradeableOwned.sol";
import "./libs/SafeMath.sol";


/// @dev Generates and distributes rewards according to the logic and formulas described in the POSDAO white paper.
contract BlockRewardAuRa is UpgradeableOwned, IBlockRewardAuRa {
    using SafeMath for uint256;

    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables and do not change their types!

    mapping(address => bool) internal _ercToErcBridgeAllowed;
    mapping(address => bool) internal _ercToNativeBridgeAllowed;
    mapping(address => bool) internal _nativeToErcBridgeAllowed;
    address[] internal _ercToErcBridgesAllowed;
    address[] internal _ercToNativeBridgesAllowed;
    address[] internal _nativeToErcBridgesAllowed;
    bool internal _queueERInitialized;
    uint256 internal _queueERFirst;
    uint256 internal _queueERLast;
    struct ExtraReceiverQueue {
        uint256 amount;
        address bridge;
        address receiver;
    }
    mapping(uint256 => ExtraReceiverQueue) internal _queueER;
    bool internal _queueVInitialized;
    uint256 internal _queueVFirst;
    uint256 internal _queueVLast;
    mapping(uint256 => address) internal _queueVList;
    mapping(address => uint256[]) internal _snapshotRewardPercents;
    mapping(address => address[]) internal _snapshotStakers;
    mapping(address => uint256) internal _snapshotStakersLength;
    address[] internal _snapshotStakingAddresses;
    uint256 internal _snapshotRewardPercentsTotal;

    /// @dev A number of blocks produced by the specified validator during the specified staking epoch
    /// (beginning from the block when the `finalizeChange` function is called until the block specified by the
    /// `_rewardPointBlock` function). The results are used by the `_distributeRewards` function to track
    /// each validator's downtime (when a validator's node is not running and doesn't produce blocks).
    mapping(uint256 => mapping(address => uint256)) public blocksCreated;

    /// @dev The current total fee amount of native coins accumulated by
    /// the `addBridgeNativeFeeReceivers` function.
    uint256 public bridgeNativeFee;

    /// @dev The current total fee amount of staking tokens accumulated by
    /// the `addBridgeTokenFeeReceivers` function.
    uint256 public bridgeTokenFee;

    /// @dev The reward amount to be distributed in native coins among participants (the validator and their
    /// delegators) of the specified pool at the end of the specified staking epoch.
    mapping(uint256 => mapping(address => uint256)) public epochPoolNativeReward;

    /// @dev The reward amount to be distributed in staking tokens among participants (the validator and their
    /// delegators) of the specified pool at the end of the specified staking epoch.
    mapping(uint256 => mapping(address => uint256)) public epochPoolTokenReward;

    /// @dev A boolean flag indicating if the reward process is occuring for the current block.
    /// The value of this boolean flag is changed by the `_distributeRewards` function.
    bool public isRewarding;

    /// @dev A boolean flag indicating if the snapshotting process is occuring for the current block.
    /// The value of this boolean flag is changed by the `reward` function.
    bool public isSnapshotting;

    /// @dev The total amount of native coins minted for the specified address
    /// by the `erc-to-native` bridges through the `addExtraReceiver` function.
    mapping(address => uint256) public mintedForAccount;

    /// @dev The amount of native coins minted at the specified block for the specified
    /// address by the `erc-to-native` bridges through the `addExtraReceiver` function.
    mapping(address => mapping(uint256 => uint256)) public mintedForAccountInBlock;

    /// @dev The total amount of native coins minted at the specified block
    /// by the `erc-to-native` bridges through the `addExtraReceiver` function.
    mapping(uint256 => uint256) public mintedInBlock;

    /// @dev The total amount of native coins minted by the
    /// `erc-to-native` bridges through the `addExtraReceiver` function.
    uint256 public mintedTotally;

    /// @dev The total amount of native coins minted by the specified
    /// `erc-to-native` bridge through the `addExtraReceiver` function.
    mapping(address => uint256) public mintedTotallyByBridge;

    /// @dev The total reward amount in native coins which is not yet distributed among participants.
    uint256 public nativeRewardUndistributed;

    /// @dev The total reward amount in staking tokens which is not yet distributed among participants.
    uint256 public tokenRewardUndistributed;

    /// @dev The total amount staked during the previous staking epoch. This value is used by the
    /// `_distributeRewards` function at the end of the current staking epoch to calculate the inflation amount 
    /// for the staking token in the current staking epoch.
    uint256 public snapshotTotalStakeAmount;

    /// @dev The address of the `ValidatorSet` contract.
    IValidatorSetAuRa public validatorSetContract;

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
        require(_ercToNativeBridgeAllowed[msg.sender]);
        _;
    }

    /// @dev Ensures the caller is the `erc-to-erc` or `native-to-erc` bridge contract address.
    modifier onlyXToErcBridge {
        require(_ercToErcBridgeAllowed[msg.sender] || _nativeToErcBridgeAllowed[msg.sender]);
        _;
    }

    /// @dev Ensures the `initialize` function was called before.
    modifier onlyInitialized {
        require(isInitialized());
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
        bridgeNativeFee = bridgeNativeFee.add(_amount);
    }

    /// @dev Called by the `erc-to-erc` or `native-to-erc` bridge contract when a portion of the bridge fee should be
    /// distributed to participants in staking tokens. The specified amount is used by the `_distributeRewards`
    /// function.
    /// @param _amount The fee amount distributed to participants.
    function addBridgeTokenFeeReceivers(uint256 _amount) external onlyXToErcBridge {
        require(_amount != 0);
        bridgeTokenFee = bridgeTokenFee.add(_amount);
    }

    /// @dev Called by the `erc-to-native` bridge contract when the bridge needs to mint a specified amount of native
    /// coins for a specified address using the `reward` function.
    /// @param _amount The amount of native coins which must be minted for the `_receiver` address.
    /// @param _receiver The address for which the `_amount` of native coins must be minted.
    function addExtraReceiver(uint256 _amount, address _receiver) external onlyErcToNativeBridge {
        require(_amount != 0);
        require(_receiver != address(0));
        require(_queueERInitialized);
        _enqueueExtraReceiver(_amount, _receiver, msg.sender);
        emit AddedReceiver(_amount, _receiver, msg.sender);
    }

    /// @dev Initializes the contract at network startup.
    /// Can only be called by the constructor of the `Initializer` contract or owner.
    /// @param _validatorSet The address of the `ValidatorSet` contract.
    function initialize(address _validatorSet) external {
        require(block.number == 0 || msg.sender == _admin());
        require(!isInitialized());
        require(_validatorSet != address(0));
        validatorSetContract = IValidatorSetAuRa(_validatorSet);
    }

    /// @dev Copies the minting statistics from the previous BlockReward contract
    /// for the `mintedTotally` and `mintedTotallyByBridge` getters. Can only be called once by the owner.
    /// This function assumes that the bridge contract address is not changed due to its upgradable nature.
    /// @param _bridge The address of a bridge contract.
    /// @param _prevBlockRewardContract The address of the previous BlockReward contract.
    function migrateMintingStatistics(address _bridge, IBlockRewardAuRa _prevBlockRewardContract) external onlyOwner {
        require(mintedTotally == 0);
        uint256 prevMinted = _prevBlockRewardContract.mintedTotally();
        uint256 prevMintedByBridge = _prevBlockRewardContract.mintedTotallyByBridge(_bridge);
        require(prevMinted != 0);
        require(prevMintedByBridge != 0);
        mintedTotally = prevMinted;
        mintedTotallyByBridge[_bridge] = prevMintedByBridge;
    }

    /// @dev Called by the validator's node when producing and closing a block,
    /// see https://wiki.parity.io/Block-Reward-Contract.html.
    /// This function performs all of the automatic operations needed for controlling secrets revealing by validators,
    /// accumulating block producing statistics, starting a new staking epoch, snapshotting reward coefficients 
    /// at the beginning of a new staking epoch, rewards distributing at the end of a staking epoch, and minting
    /// native coins needed for the `erc-to-native` bridge.
    function reward(address[] calldata benefactors, uint16[] calldata kind)
        external
        onlySystem
        returns(address[] memory receiversNative, uint256[] memory rewardsNative)
    {
        if (benefactors.length != kind.length || benefactors.length != 1 || kind[0] != 0) {
            return (new address[](0), new uint256[](0));
        }

        // Check if the validator is existed
        if (!validatorSetContract.isValidator(benefactors[0])) {
            return (new address[](0), new uint256[](0));
        }

        receiversNative = new address[](0);
        rewardsNative = new uint256[](0);

        // Check the current validators at the end of each collection round whether
        // they revealed their secrets, and remove a validator as a malicious if needed
        IRandomAuRa(validatorSetContract.randomContract()).onFinishCollectRound();

        // Initialize queues
        if (!_queueVInitialized) {
            _queueVFirst = 1;
            _queueVLast = 0;
            _queueVInitialized = true;
        }
        if (!_queueERInitialized) {
            _queueERFirst = 1;
            _queueERLast = 0;
            _queueERInitialized = true;
        }

        IStakingAuRa stakingContract = IStakingAuRa(validatorSetContract.stakingContract());
        uint256 bridgeQueueLimit = 100;
        uint256 stakingEpoch = stakingContract.stakingEpoch();
        uint256 rewardPointBlock = _rewardPointBlock(IStakingAuRa(address(stakingContract)));

        if (validatorSetContract.validatorSetApplyBlock() != 0 && block.number <= rewardPointBlock) {
            if (stakingEpoch != 0) {
                // Accumulate blocks producing statistics for each of the
                // active validators during the current staking epoch
                blocksCreated[stakingEpoch][benefactors[0]]++;
            }
        }

        if (block.number == IStakingAuRa(address(stakingContract)).stakingEpochStartBlock()) {
            delete _snapshotStakingAddresses;
            snapshotTotalStakeAmount = 0;
        }

        // Start a new staking epoch every `stakingEpochDuration()` blocks
        (bool newStakingEpochHasBegun, uint256 poolsToBeElectedLength) = validatorSetContract.newValidatorSet();

        if (newStakingEpochHasBegun) {
            // A new staking epoch has begun, so prepare for reward coefficients snapshotting
            // process which begins right from the following block
            address[] memory newValidatorSet = validatorSetContract.getPendingValidators();

            for (uint256 i = 0; i < newValidatorSet.length; i++) {
                _enqueueValidator(validatorSetContract.stakingByMiningAddress(newValidatorSet[i]));
            }

            isSnapshotting = (newValidatorSet.length != 0);

            if (poolsToBeElectedLength > stakingContract.MAX_CANDIDATES() * 2 / 3) {
                bridgeQueueLimit = 0;
            } else if (poolsToBeElectedLength > stakingContract.MAX_CANDIDATES() / 3) {
                bridgeQueueLimit = 30;
            } else {
                bridgeQueueLimit = 50;
            }
        } else if (isSnapshotting) {
            // Snapshot reward coefficients for each new validator and their delegators
            // during the very first blocks of a new staking epoch
            address stakingAddress = _dequeueValidator();

            if (stakingAddress != address(0)) {
                uint256 validatorsQueueSize = _validatorsQueueSize();
                uint256 offset = (validatorsQueueSize + 1) % DELEGATORS_ALIQUOT;
                if (offset != 0) {
                    offset = DELEGATORS_ALIQUOT - offset;
                }
                _setSnapshot(stakingAddress, stakingContract, offset);
                if (validatorsQueueSize == 0) {
                    // Snapshotting process has been finished
                    isSnapshotting = false;
                }
                bridgeQueueLimit = 50;
            }
        } else if (stakingEpoch != 0) {
            // Distribute rewards at the end of staking epoch during the last
            // MAX_VALIDATORS * DELEGATORS_ALIQUOT blocks
            bool noop;
            (receiversNative, rewardsNative, noop) = _distributeRewards(
                stakingContract.erc20TokenContract(),
                stakingContract.erc20Restricted(),
                IStakingAuRa(address(stakingContract)),
                stakingEpoch,
                rewardPointBlock
            );
            if (!noop) {
                bridgeQueueLimit = 50;
            }
        }

        // Mint native coins if needed
        return _mintNativeCoins(receiversNative, rewardsNative, bridgeQueueLimit);
    }

    /// @dev Sets the array of `erc-to-native` bridge addresses which are allowed to call some of the functions with
    /// the `onlyErcToNativeBridge` modifier. This setter can only be called by the `owner`.
    /// @param _bridgesAllowed The array of bridge addresses.
    function setErcToNativeBridgesAllowed(address[] calldata _bridgesAllowed) external onlyOwner onlyInitialized {
        uint256 i;

        for (i = 0; i < _ercToNativeBridgesAllowed.length; i++) {
            _ercToNativeBridgeAllowed[_ercToNativeBridgesAllowed[i]] = false;
        }

        _ercToNativeBridgesAllowed = _bridgesAllowed;

        for (i = 0; i < _bridgesAllowed.length; i++) {
            _ercToNativeBridgeAllowed[_bridgesAllowed[i]] = true;
        }
    }

    /// @dev Sets the array of `native-to-erc` bridge addresses which are allowed to call some of the functions with
    /// the `onlyXToErcBridge` modifier. This setter can only be called by the `owner`.
    /// @param _bridgesAllowed The array of bridge addresses.
    function setNativeToErcBridgesAllowed(address[] calldata _bridgesAllowed) external onlyOwner onlyInitialized {
        uint256 i;

        for (i = 0; i < _nativeToErcBridgesAllowed.length; i++) {
            _nativeToErcBridgeAllowed[_nativeToErcBridgesAllowed[i]] = false;
        }

        _nativeToErcBridgesAllowed = _bridgesAllowed;

        for (i = 0; i < _bridgesAllowed.length; i++) {
            _nativeToErcBridgeAllowed[_bridgesAllowed[i]] = true;
        }
    }

    /// @dev Sets the array of `erc-to-erc` bridge addresses which are allowed to call some of the functions with
    /// the `onlyXToErcBridge` modifier. This setter can only be called by the `owner`.
    /// @param _bridgesAllowed The array of bridge addresses.
    function setErcToErcBridgesAllowed(address[] calldata _bridgesAllowed) external onlyOwner onlyInitialized {
        uint256 i;

        for (i = 0; i < _ercToErcBridgesAllowed.length; i++) {
            _ercToErcBridgeAllowed[_ercToErcBridgesAllowed[i]] = false;
        }

        _ercToErcBridgesAllowed = _bridgesAllowed;

        for (i = 0; i < _bridgesAllowed.length; i++) {
            _ercToErcBridgeAllowed[_bridgesAllowed[i]] = true;
        }
    }

    // =============================================== Getters ========================================================

    /// @dev Returns an identifier for the bridge contract so that the latter could
    /// ensure it works with the BlockReward contract.
    function blockRewardContractId() public pure returns(bytes4) {
        return bytes4(keccak256("blockReward"));
    }

    /// @dev Returns the array of `erc-to-erc` bridge addresses set by the `setErcToErcBridgesAllowed` setter.
    function ercToErcBridgesAllowed() public view returns(address[] memory) {
        return _ercToErcBridgesAllowed;
    }

    /// @dev Returns the array of `erc-to-native` bridge addresses set by the `setErcToNativeBridgesAllowed` setter.
    function ercToNativeBridgesAllowed() public view returns(address[] memory) {
        return _ercToNativeBridgesAllowed;
    }

    /// @dev Returns the current size of the address queue created by the `addExtraReceiver` function.
    function extraReceiversQueueSize() public view returns(uint256) {
        return _queueERLast + 1 - _queueERFirst;
    }

    /// @dev Returns a boolean flag indicating if the `initialize` function has been called.
    function isInitialized() public view returns(bool) {
        return validatorSetContract != IValidatorSetAuRa(0);
    }

    /// @dev Returns the array of `native-to-erc` bridge addresses which were set by
    /// the `setNativeToErcBridgesAllowed` setter.
    function nativeToErcBridgesAllowed() public view returns(address[] memory) {
        return _nativeToErcBridgesAllowed;
    }

    /// @dev Returns an array of reward coefficients which corresponds to the array of stakers
    /// for a specified validator and the current staking epoch. The size of the returned array
    /// is the same as the size of the staker array returned by the `snapshotStakers` getter. The reward
    /// coefficients are calculated by the `_setSnapshot` function at the beginning of the staking epoch
    /// and then used by the `_distributeRewards` function at the end of the staking epoch.
    /// @param _validatorStakingAddress The staking address of the validator pool for which the getter
    /// must return the coefficient array.
    function snapshotRewardPercents(address _validatorStakingAddress) public view returns(uint256[] memory result) {
        uint256 length = _snapshotStakersLength[_validatorStakingAddress];

        uint256[] storage coefficients = _snapshotRewardPercents[_validatorStakingAddress];

        if (length < coefficients.length) {
            result = new uint256[](length);
            for (uint256 i = 0; i < length; i++) {
                result[i] = coefficients[i];
            }
        } else {
            result = coefficients;
        }
    }

    /// @dev Returns an array of stakers for the specified validator and the current staking epoch
    /// snapshotted at the beginning of the staking epoch by the `_setSnapshot` function. This array is
    /// used by the `_distributeRewards` function at the end of the staking epoch.
    /// @param _validatorStakingAddress The staking address of the validator pool for which the getter
    /// must return the array of stakers.
    function snapshotStakers(address _validatorStakingAddress) public view returns(address[] memory result) {
        uint256 length = _snapshotStakersLength[_validatorStakingAddress];

        address[] storage stakers = _snapshotStakers[_validatorStakingAddress];

        if (length < stakers.length) {
            result = new address[](length);
            for (uint256 i = 0; i < length; i++) {
                result[i] = stakers[i];
            }
        } else {
            result = stakers;
        }
    }

    /// @dev Returns an array of the pools snapshotted by the `_setSnapshot` function
    /// at the beginning of the current staking epoch.
    /// The getter returns the staking addresses of the pools.
    function snapshotStakingAddresses() public view returns(address[] memory) {
        return _snapshotStakingAddresses;
    }

    /// @dev Returns the reward coefficient for the specified validator. The given value should be divided by 10000
    /// to get the value of the reward percent (since EVM doesn't support float values). If the specified staking
    /// address is an address of a candidate, the potentially possible reward coefficient is returned for the specified
    /// candidate instead.
    /// @param _stakingAddress The staking address of the validator/candidate
    /// pool for which the getter must return the coefficient.
    function validatorRewardPercent(address _stakingAddress) public view returns(uint256) {
        if (_snapshotRewardPercents[_stakingAddress].length != 0) {
            return _snapshotRewardPercents[_stakingAddress][0];
        }

        IStakingAuRa stakingContract = IStakingAuRa(validatorSetContract.stakingContract());

        if (stakingContract.stakingEpoch() == 0) {
            if (validatorSetContract.isValidator(validatorSetContract.miningByStakingAddress(_stakingAddress))) {
                return 0;
            }
        }

        return _validatorRewardPercent(
            stakingContract.stakeAmountMinusOrderedWithdraw(_stakingAddress, _stakingAddress),
            stakingContract.stakeAmountTotalMinusOrderedWithdraw(_stakingAddress)
        );
    }

    // =============================================== Private ========================================================

    uint256 internal constant REWARD_PERCENT_MULTIPLIER = 1000000;

    /// @dev Distributes rewards among participants during the last MAX_VALIDATORS * DELEGATORS_ALIQUOT
    /// blocks of a staking epoch. This function is called by the `reward` function.
    /// @param _erc20TokenContract The address of the ERC20 staking token contract.
    /// @param _erc20Restricted A boolean flag indicating whether the StakingAuRa contract restricts using ERC20/677
    /// contract. If it's set to `true`, native staking coins are used instead of ERC staking tokens.
    /// @param _stakingContract The address of the Staking contract.
    /// @param _stakingEpoch The number of the current staking epoch.
    /// @param _rewardPointBlock The number of the block within the current staking epoch when the rewarding process
    /// should start. This number is calculated by the `_rewardPointBlock` getter.
    /// @return `address[] receivers` - The array of native coins receivers which should be
    /// rewarded at the current block by the `erc-to-native` bridge or by the fixed native reward.
    /// `uint256[] rewards` - The array of amounts corresponding to the `receivers` array.
    /// `bool noop` - The boolean flag which is set to `true` when there are no complex operations during the
    /// function launch. The flag is used by the `reward` function to control the load on the block inside the
    /// `_mintNativeCoins` function.
    function _distributeRewards(
        address _erc20TokenContract,
        bool _erc20Restricted,
        IStakingAuRa _stakingContract,
        uint256 _stakingEpoch,
        uint256 _rewardPointBlock
    ) internal returns(address[] memory receivers, uint256[] memory rewards, bool noop) {
        uint256 i;

        receivers = new address[](0);
        rewards = new uint256[](0);
        noop = true;

        if (block.number == _rewardPointBlock - 1) {
            isRewarding = true;
        } else if (block.number == _rewardPointBlock) {
            address[] memory validators = validatorSetContract.getValidators();
            uint256[] memory ratio = new uint256[](validators.length);

            uint256 totalReward;
            bool isRewardingLocal = false;

            totalReward = bridgeTokenFee;

            if (!_erc20Restricted) {
                // Accumulated bridge fee plus token inflation
                uint256 inflationPercent;
                if (_stakingEpoch <= 24) {
                    inflationPercent = 32;
                } else if (_stakingEpoch <= 48) {
                    inflationPercent = 16;
                } else if (_stakingEpoch <= 72) {
                    inflationPercent = 8;
                } else {
                    inflationPercent = 4;
                }
                totalReward += snapshotTotalStakeAmount * inflationPercent / 4800;
            }

            if (
                totalReward != 0 && _erc20TokenContract != address(0) ||
                bridgeNativeFee != 0 ||
                _erc20Restricted
            ) {
                uint256 j = 0;
                for (i = 0; i < validators.length; i++) {
                    ratio[i] = blocksCreated[_stakingEpoch][validators[i]];
                    j += ratio[i];
                    validators[i] = validatorSetContract.stakingByMiningAddress(validators[i]);
                }
                if (j != 0) {
                    for (i = 0; i < validators.length; i++) {
                        ratio[i] = REWARD_PERCENT_MULTIPLIER * ratio[i] / j;
                    }
                }
            }
            if (totalReward != 0) {
                bridgeTokenFee = 0;

                totalReward += tokenRewardUndistributed;

                if (_erc20TokenContract != address(0)) {
                    for (i = 0; i < validators.length; i++) {
                        epochPoolTokenReward[_stakingEpoch][validators[i]] =
                            totalReward * ratio[i] / REWARD_PERCENT_MULTIPLIER;
                    }
                    isRewardingLocal = true;
                }

                tokenRewardUndistributed = totalReward;
            }

            totalReward = bridgeNativeFee;

            if (_erc20Restricted) {
                // Accumulated bridge fee plus 2.5% per year coin inflation
                totalReward += _stakingContract.stakingEpochDuration() * 1 ether;
            }

            if (totalReward != 0) {
                bridgeNativeFee = 0;

                totalReward += nativeRewardUndistributed;

                for (i = 0; i < validators.length; i++) {
                    epochPoolNativeReward[_stakingEpoch][validators[i]] =
                        totalReward * ratio[i] / REWARD_PERCENT_MULTIPLIER;
                }
                isRewardingLocal = true;

                nativeRewardUndistributed = totalReward;
            }

            if (isRewardingLocal) {
                for (i = 0; i < validators.length; i++) {
                    _enqueueValidator(validators[i]);
                }
                if (validators.length == 0) {
                    isRewarding = false;
                }
            } else {
                isRewarding = false;
            }

            noop = false;
        } else if (block.number > _rewardPointBlock) {
            address stakingAddress = _dequeueValidator();

            if (stakingAddress == address(0)) {
                return (receivers, rewards, true);
            }

            if (_validatorsQueueSize() == 0) {
                isRewarding = false;
            }

            if (validatorSetContract.isValidatorBanned(validatorSetContract.miningByStakingAddress(stakingAddress))) {
                return (receivers, rewards, true);
            }

            address[] storage stakers = _snapshotStakers[stakingAddress];
            uint256 stakersLength = _snapshotStakersLength[stakingAddress];
            uint256[] memory range = new uint256[](3); // array instead of local vars because the stack is too deep
            range[0] = (_validatorsQueueSize() + 1) % DELEGATORS_ALIQUOT; // offset
            if (range[0] != 0) {
                range[0] = DELEGATORS_ALIQUOT - range[0];
            }
            range[1] = stakersLength / DELEGATORS_ALIQUOT * range[0]; // from
            if (range[0] == DELEGATORS_ALIQUOT - 1) {
                range[2] = stakersLength; // to
            } else {
                range[2] = stakersLength / DELEGATORS_ALIQUOT * (range[0] + 1); // to
            }

            if (range[1] >= range[2]) {
                return (receivers, rewards, true);
            }

            uint256[] storage rewardPercents = _snapshotRewardPercents[stakingAddress];

            uint256 poolReward;

            receivers = new address[](range[2] - range[1]);
            rewards = new uint256[](receivers.length);

            poolReward = epochPoolTokenReward[_stakingEpoch][stakingAddress];
            if (poolReward != 0) {
                uint256 accrued = 0;
                for (i = range[1]; i < range[2]; i++) {
                    uint256 j = i - range[1];
                    receivers[j] = stakers[i];
                    rewards[j] = poolReward * rewardPercents[i] / REWARD_PERCENT_MULTIPLIER;
                    accrued += rewards[j];
                }
                IERC20Minting(_erc20TokenContract).mintReward(receivers, rewards);
                _subTokenRewardUndistributed(accrued);
                noop = false;
            }

            poolReward = epochPoolNativeReward[_stakingEpoch][stakingAddress];
            if (poolReward != 0) {
                uint256 accrued = 0;
                for (i = range[1]; i < range[2]; i++) {
                    uint256 j = i - range[1];
                    receivers[j] = stakers[i];
                    rewards[j] = poolReward * rewardPercents[i] / REWARD_PERCENT_MULTIPLIER;
                    accrued += rewards[j];
                }
                _subNativeRewardUndistributed(accrued);
                noop = false;
            } else {
                return (new address[](0), new uint256[](0), noop);
            }
        }
    }

    /// @dev Dequeues a validator enqueued for the snapshotting or rewarding process.
    /// Used by the `reward` and `_distributeRewards` functions.
    /// If the queue is empty, the function returns a zero address.
    function _dequeueValidator() internal returns(address validatorStakingAddress) {
        uint256 queueFirst = _queueVFirst;
        uint256 queueLast = _queueVLast;

        if (queueLast < queueFirst) {
            validatorStakingAddress = address(0);
        } else {
            validatorStakingAddress = _queueVList[queueFirst];
            delete _queueVList[queueFirst];
            _queueVFirst++;
        }
    }

    /// @dev Enqueues the specified validator for the snapshotting or rewarding process.
    /// Used by the `reward` and `_distributeRewards` functions. See also DELEGATORS_ALIQUOT.
    /// @param _validatorStakingAddress The staking address of a validator to be enqueued.
    function _enqueueValidator(address _validatorStakingAddress) internal {
        uint256 queueLast = _queueVLast;
        for (uint256 i = 0; i < DELEGATORS_ALIQUOT; i++) {
            _queueVList[++queueLast] = _validatorStakingAddress;
        }
        _queueVLast = queueLast;
    }

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
        uint256 queueFirst = _queueERFirst;
        uint256 queueLast = _queueERLast;

        if (queueLast < queueFirst) {
            amount = 0;
            receiver = address(0);
            bridge = address(0);
        } else {
            amount = _queueER[queueFirst].amount;
            receiver = _queueER[queueFirst].receiver;
            bridge = _queueER[queueFirst].bridge;
            delete _queueER[queueFirst];
            _queueERFirst++;
        }
    }

    /// @dev Enqueues the information about the receiver of native coins which must be minted for the
    /// specified `erc-to-native` bridge. This function is used by the `addExtraReceiver` function.
    /// @param _amount The amount of native coins which must be minted for the `_receiver` address.
    /// @param _receiver The address for which the `_amount` of native coins must be minted.
    /// @param _bridge The address of the bridge contract which requested the minting of native coins.
    function _enqueueExtraReceiver(uint256 _amount, address _receiver, address _bridge) internal {
        uint256 queueLast = _queueERLast + 1;
        _queueER[queueLast] = ExtraReceiverQueue({
            amount: _amount,
            bridge: _bridge,
            receiver: _receiver
        });
        _queueERLast = queueLast;
    }

    /// @dev Accumulates minting statistics for the `erc-to-native` bridge.
    /// This function is used by the `_mintNativeCoins` function.
    /// @param _amount The amount minted for the `_account` address.
    /// @param _account The address for which the `_amount` is minted.
    /// @param _bridge The address of the bridge contract which called the `addExtraReceiver` function.
    function _setMinted(uint256 _amount, address _account, address _bridge) internal {
        mintedForAccountInBlock[_account][block.number] = _amount;
        mintedForAccount[_account] += _amount;
        mintedInBlock[block.number] += _amount;
        mintedTotallyByBridge[_bridge] += _amount;
        mintedTotally += _amount;
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
    function _setSnapshot(address _stakingAddress, IStakingAuRa _stakingContract, uint256 _offset) internal {
        uint256 validatorStake = _stakingContract.stakeAmountMinusOrderedWithdraw(_stakingAddress, _stakingAddress);
        uint256 totalStaked = _stakingContract.stakeAmountTotalMinusOrderedWithdraw(_stakingAddress);
        uint256 delegatorsAmount = totalStaked >= validatorStake ? totalStaked - validatorStake : 0;
        bool validatorHasMore30Per = validatorStake * 7 > delegatorsAmount * 3;

        address[] memory delegators = _stakingContract.poolDelegators(_stakingAddress);
        address[] storage stakers = _snapshotStakers[_stakingAddress];
        uint256[] storage rewardPercents = _snapshotRewardPercents[_stakingAddress];
        uint256 stakersLength;

        if (_offset == 0) {
            // Calculate reward percent for validator
            uint256 rewardPercent = _validatorRewardPercent(validatorStake, totalStaked);
            if (stakers.length == 0) {
                stakers.push(_stakingAddress);
                rewardPercents.push(rewardPercent);
            } else {
                stakers[0] = _stakingAddress;
                rewardPercents[0] = rewardPercent;
            }
            stakersLength = 1;
            _snapshotStakingAddresses.push(_stakingAddress);
            snapshotTotalStakeAmount += totalStaked;
            _snapshotRewardPercentsTotal = rewardPercent;
        } else {
            stakersLength = _snapshotStakersLength[_stakingAddress];
        }

        uint256[] memory mem = new uint256[](3); // array instead of local vars because the stack is too deep
        mem[0] = delegators.length / DELEGATORS_ALIQUOT * _offset; // from

        if (_offset == DELEGATORS_ALIQUOT - 1) {
            mem[1] = delegators.length; // to
        } else {
            mem[1] = delegators.length / DELEGATORS_ALIQUOT * (_offset + 1); // to
        }

        // Calculate reward percent for each delegator
        mem[2] = _snapshotRewardPercentsTotal; // rewardPercentsTotal

        for (uint256 i = mem[0]; i < mem[1]; i++) {
            uint256 rewardPercent = 0;

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

            if (stakers.length > stakersLength) {
                stakers[stakersLength] = delegators[i];
                rewardPercents[stakersLength] = rewardPercent;
            } else {
                stakers.push(delegators[i]);
                rewardPercents.push(rewardPercent);
            }

            mem[2] += rewardPercent;
            stakersLength++;
        }

        _snapshotRewardPercentsTotal = mem[2];
        _snapshotStakersLength[_stakingAddress] = stakersLength;

        if (_offset == DELEGATORS_ALIQUOT - 1 && mem[2] < REWARD_PERCENT_MULTIPLIER) {
            rewardPercents[0] += REWARD_PERCENT_MULTIPLIER - mem[2];
        }
    }

    /// @dev Reduces an undistributed amount of native coins.
    /// This function is used by the `_distributeRewards` function.
    /// @param _minus The subtraction value.
    function _subNativeRewardUndistributed(uint256 _minus) internal {
        if (nativeRewardUndistributed < _minus) {
            nativeRewardUndistributed = 0;
        } else {
            nativeRewardUndistributed -= _minus;
        }
    }

    /// @dev Reduces an undistributed amount of staking tokens.
    /// This function is used by the `_distributeRewards` function.
    /// @param _minus The subtraction value.
    function _subTokenRewardUndistributed(uint256 _minus) internal {
        if (tokenRewardUndistributed < _minus) {
            tokenRewardUndistributed = 0;
        } else {
            tokenRewardUndistributed -= _minus;
        }
    }

    /// @dev Calculates the starting block number for the rewarding process
    /// at the end of the current staking epoch.
    /// Used by the `reward` and `_distributeRewards` functions.
    /// @param _stakingContract The address of the StakingAuRa contract.
    function _rewardPointBlock(
        IStakingAuRa _stakingContract
    ) internal view returns(uint256) {
        return _stakingContract.stakingEpochEndBlock() - validatorSetContract.MAX_VALIDATORS()*DELEGATORS_ALIQUOT - 1;
    }

    /// @dev Calculates the reward coefficient for a validator (or candidate).
    /// Used by the `validatorRewardPercent` and `_setSnapshot` functions.
    /// @param _validatorStaked The amount staked by a validator.
    /// @param _totalStaked The total amount staked by a validator and their delegators.
    function _validatorRewardPercent(
        uint256 _validatorStaked,
        uint256 _totalStaked
    ) internal pure returns(uint256 rewardPercent) {
        rewardPercent = 0;
        if (_validatorStaked != 0 && _totalStaked != 0) {
            uint256 delegatorsStaked = _totalStaked >= _validatorStaked ? _totalStaked - _validatorStaked : 0;
            if (_validatorStaked * 7 > delegatorsStaked * 3) {
                // Validator has more than 30%
                rewardPercent = REWARD_PERCENT_MULTIPLIER * _validatorStaked / _totalStaked;
            } else {
                rewardPercent = REWARD_PERCENT_MULTIPLIER * 3 / 10;
            }
        }
    }

    /// @dev Returns the size of the validator queue used for the snapshotting and rewarding processes.
    /// See `_enqueueValidator` and `_dequeueValidator` functions.
    /// This function is used by the `reward` and `_distributeRewards` functions.
    function _validatorsQueueSize() internal view returns(uint256) {
        return _queueVLast + 1 - _queueVFirst;
    }
}
