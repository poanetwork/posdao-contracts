pragma solidity 0.5.9;

import "./interfaces/IBlockRewardAuRa.sol";
import "./interfaces/IERC20Minting.sol";
import "./interfaces/IRandomAuRa.sol";
import "./interfaces/IStakingAuRa.sol";
import "./interfaces/IValidatorSetAuRa.sol";
import "./upgradeability/UpgradeableOwned.sol";
import "./libs/SafeMath.sol";


contract Sacrifice {
    constructor(address payable _recipient) public payable {
        selfdestruct(_recipient);
    }
}


/// @dev Generates and distributes rewards according to the logic and formulas described in the POSDAO white paper.
contract BlockRewardAuRa is UpgradeableOwned, IBlockRewardAuRa {
    using SafeMath for uint256;

    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables and do not change their types!

    mapping(address => uint256[]) internal _epochsPoolGotRewardFor;
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

    /// @dev A number of blocks produced by the specified validator during the specified staking epoch
    /// (beginning from the block when the `finalizeChange` function is called until the block specified by the
    /// `_rewardPointBlock` function). The results are used by the `_distributeRewards` function to track
    /// each validator's downtime (when a validator's node is not running and doesn't produce blocks).
    /// While the validator is banned, the block producing statistics is not accumulated for them.
    mapping(uint256 => mapping(address => uint256)) public blocksCreated;

    /// @dev The current total fee amount of native coins accumulated by
    /// the `addBridgeNativeFeeReceivers` function.
    uint256 public bridgeNativeFee;

    /// @dev The current total fee amount of staking tokens accumulated by
    /// the `addBridgeTokenFeeReceivers` function.
    uint256 public bridgeTokenFee;

    /// @dev The reward amount to be distributed in native coins among participants (the validator and their
    /// delegators) of the specified pool (mining address) for the specified staking epoch.
    mapping(uint256 => mapping(address => uint256)) public epochPoolNativeReward;

    /// @dev The reward amount to be distributed in staking tokens among participants (the validator and their
    /// delegators) of the specified pool (mining address) for the specified staking epoch.
    mapping(uint256 => mapping(address => uint256)) public epochPoolTokenReward;

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

    /// @dev The total reward amount in native coins which is not yet distributed among pools.
    uint256 public nativeRewardUndistributed;

    /// @dev The total reward amount in staking tokens which is not yet distributed among pools.
    uint256 public tokenRewardUndistributed;

    /// @dev The total amount staked into the specified pool (mining address)
    /// before the specified staking epoch. Filled by the `_snapshotPoolStakeAmounts` function.
    mapping(uint256 => mapping(address => uint256)) public snapshotPoolTotalStakeAmount;

    /// @dev The validator's amount staked into the specified pool (mining address)
    /// before the specified staking epoch. Filled by the `_snapshotPoolStakeAmounts` function.
    mapping(uint256 => mapping(address => uint256)) public snapshotPoolValidatorStakeAmount;

    /// @dev The total amount staked during the previous staking epoch. This value is used by the
    /// `_distributeRewards` function at the end of the current staking epoch to calculate the inflation amount
    /// for the staking token in the current staking epoch.
    uint256 public snapshotTotalStakeAmount;

    /// @dev The address of the `ValidatorSet` contract.
    IValidatorSetAuRa public validatorSetContract;

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

    /// @dev Ensures the caller is the StakingAuRa contract address.
    modifier onlyStakingContract() {
        require(msg.sender == address(validatorSetContract.stakingContract()));
        _;
    }

    /// @dev Ensures the caller is the ValidatorSetAuRa contract address.
    modifier onlyValidatorSetContract() {
        require(msg.sender == address(validatorSetContract));
        _;
    }

    // =============================================== Setters ========================================================

    /// @dev Fallback function. Prevents sending native coins to `address(this)`.
    function () payable external {
        revert();
    }

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
        require(_getCurrentBlockNumber() == 0 || msg.sender == _admin());
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

        // Initialize the extra receivers queue
        if (!_queueERInitialized) {
            _queueERFirst = 1;
            _queueERLast = 0;
            _queueERInitialized = true;
        }

        uint256 bridgeQueueLimit = 100;
        IStakingAuRa stakingContract = IStakingAuRa(validatorSetContract.stakingContract());
        uint256 stakingEpoch = stakingContract.stakingEpoch();
        uint256 stakingEpochEndBlock = stakingContract.stakingEpochEndBlock();

        if (validatorSetContract.validatorSetApplyBlock() != 0) {
            if (stakingEpoch != 0 && !validatorSetContract.isValidatorBanned(benefactors[0])) {
                // Accumulate blocks producing statistics for each of the
                // active validators during the current staking epoch
                blocksCreated[stakingEpoch][benefactors[0]]++;
            }
        }

        if (_getCurrentBlockNumber() == stakingEpochEndBlock) {
            // Distribute rewards among validator pools
            if (stakingEpoch != 0) {
                (receiversNative, rewardsNative) = _distributeRewards(
                    stakingContract,
                    stakingEpoch,
                    stakingEpochEndBlock
                );
            }

            // Choose new validators
            validatorSetContract.newValidatorSet();

            // Snapshot total amounts staked into the pools
            uint256 i;
            uint256 nextStakingEpoch = stakingEpoch + 1;
            address[] memory miningAddresses;

            // We need to remember the total staked amounts for the pending addresses
            // for the possible case when these pending addresses are finalized
            // by the `ValidatorSetAuRa.finalizeChange` function and thus become validators
            miningAddresses = validatorSetContract.getPendingValidators();
            for (i = 0; i < miningAddresses.length; i++) {
                _snapshotPoolStakeAmounts(stakingContract, nextStakingEpoch, miningAddresses[i]);
            }

            // We need to remember the total staked amounts for the current validators
            // for the possible case when these validators continue to be validators
            // throughout the upcoming staking epoch (if the new validator set is not finalized
            // for some reason)
            miningAddresses = validatorSetContract.getValidators();
            for (i = 0; i < miningAddresses.length; i++) {
                _snapshotPoolStakeAmounts(stakingContract, nextStakingEpoch, miningAddresses[i]);
            }

            // We need to remember the total staked amounts for the addresses currently
            // being finalized but not yet finalized (i.e. the `InitiateChange` event is emitted
            // for them but not yet handled by validator nodes thus the `ValidatorSetAuRa.finalizeChange`
            // function is not called yet) for the possible case when these addresses finally
            // become validators on the upcoming staking epoch
            (miningAddresses, ) = validatorSetContract.validatorsToBeFinalized();
            for (i = 0; i < miningAddresses.length; i++) {
                _snapshotPoolStakeAmounts(stakingContract, nextStakingEpoch, miningAddresses[i]);
            }

            snapshotTotalStakeAmount = 0;
            bridgeQueueLimit = 0;
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

    /// @dev Called by the `ValidatorSetAuRa.finalizeChange` to set the value of
    /// `snapshotTotalStakeAmount`.
    function setSnapshotTotalStakeAmount() external onlyValidatorSetContract {
        IStakingAuRa stakingContract = IStakingAuRa(validatorSetContract.stakingContract());
        uint256 stakingEpoch = stakingContract.stakingEpoch();
        address[] memory validators = validatorSetContract.getValidators();
        uint256 totalStakeAmount = 0;
        for (uint256 i = 0; i < validators.length; i++) {
            totalStakeAmount += snapshotPoolTotalStakeAmount[stakingEpoch][validators[i]];
            blocksCreated[stakingEpoch][validators[i]] = 0;
        }
        snapshotTotalStakeAmount = totalStakeAmount;
    }

    /// @dev Called by the `StakingAuRa.claimReward` function to transfer tokens and native coins
    /// from the balance of the `BlockRewardAuRa` contract to the specified address as a reward.
    /// @param _tokens The amount of tokens to transfer as a reward.
    /// @param _nativeCoins The amount of native coins to transfer as a reward.
    /// @param _to The target address to transfer to.
    function transferReward(uint256 _tokens, uint256 _nativeCoins, address payable _to) external onlyStakingContract {
        if (_tokens != 0) {
            IStakingAuRa stakingContract = IStakingAuRa(msg.sender);
            IERC20Minting erc20TokenContract = IERC20Minting(stakingContract.erc20TokenContract());
            erc20TokenContract.transfer(_to, _tokens);
        }

        if (_nativeCoins != 0 && !_to.send(_nativeCoins)) {
            // We use the `Sacrifice` trick to be sure the coins can be 100% sent to the receiver.
            // Otherwise, if the receiver is a contract which has a revert in its fallback function,
            // the sending will fail.
            (new Sacrifice).value(_nativeCoins)(_to);
        }
    }

    // =============================================== Getters ========================================================

    /// @dev Returns an identifier for the bridge contract so that the latter could
    /// ensure it works with the BlockReward contract.
    function blockRewardContractId() public pure returns(bytes4) {
        return bytes4(keccak256("blockReward"));
    }

    /// @dev Returns an array of epoch numbers for which the specified pool (mining address)
    /// got a non-zero reward.
    function epochsPoolGotRewardFor(address _miningAddress) public view returns(uint256[] memory) {
        return _epochsPoolGotRewardFor[_miningAddress];
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

    /// @dev Prevents sending tokens directly to the `BlockRewardAuRa` contract address
    /// by the `ERC677BridgeTokenRewardable.transferAndCall` function.
    function onTokenTransfer(address, uint256, bytes memory) public pure returns(bool) {
        revert();
    }

    /// @dev Returns the reward coefficient for the specified validator. The given value should be divided by 10000
    /// to get the value of the reward percent (since EVM doesn't support float values). If the specified staking
    /// address is an address of a candidate that is not about to be a validator on the current staking epoch
    /// the potentially possible reward coefficient is returned.
    /// @param _stakingAddress The staking address of the validator/candidate
    /// pool for which the getter must return the coefficient.
    function validatorRewardPercent(address _stakingAddress) public view returns(uint256) {
        IStakingAuRa stakingContract = IStakingAuRa(validatorSetContract.stakingContract());
        uint256 stakingEpoch = stakingContract.stakingEpoch();
        address miningAddress = validatorSetContract.miningByStakingAddress(_stakingAddress);

        if (validatorSetContract.isValidator(miningAddress)) {
            // For the validator we return the coefficient based on
            // snapshotted total amounts
            if (stakingEpoch != 0) {
                return validatorShare(
                    snapshotPoolValidatorStakeAmount[stakingEpoch][miningAddress],
                    snapshotPoolTotalStakeAmount[stakingEpoch][miningAddress],
                    REWARD_PERCENT_MULTIPLIER
                );
            } else {
                // No one gets a reward for the initial staking epoch, so we return zero
                return 0;
            }
        }

        if (validatorSetContract.validatorSetApplyBlock() == 0) {
            // For the candidate that is about to be a validator on the current
            // staking epoch we return the coefficient based on snapshotted total amounts

            address[] memory miningAddresses;
            uint256 i;
            
            miningAddresses = validatorSetContract.getPendingValidators();
            for (i = 0; i < miningAddresses.length; i++) {
                if (miningAddress == miningAddresses[i]) {
                    return validatorShare(
                        snapshotPoolValidatorStakeAmount[stakingEpoch][miningAddress],
                        snapshotPoolTotalStakeAmount[stakingEpoch][miningAddress],
                        REWARD_PERCENT_MULTIPLIER
                    );
                }
            }

            (miningAddresses, ) = validatorSetContract.validatorsToBeFinalized();
            for (i = 0; i < miningAddresses.length; i++) {
                if (miningAddress == miningAddresses[i]) {
                    return validatorShare(
                        snapshotPoolValidatorStakeAmount[stakingEpoch][miningAddress],
                        snapshotPoolTotalStakeAmount[stakingEpoch][miningAddress],
                        REWARD_PERCENT_MULTIPLIER
                    );
                }
            }
        }

        // For the candidate that is not about to be a validator on the current staking epoch,
        // we return the potentially possible reward coefficient
        return validatorShare(
            stakingContract.stakeAmountMinusOrderedWithdraw(_stakingAddress, _stakingAddress),
            stakingContract.stakeAmountTotalMinusOrderedWithdraw(_stakingAddress),
            REWARD_PERCENT_MULTIPLIER
        );
    }

    /// @dev Calculates delegator's share for the given pool reward amount.
    /// Used by the `StakingAuRa.claimReward` function.
    /// @param _delegatorStaked The amount staked by a delegator.
    /// @param _validatorStaked The amount staked by a validator.
    /// @param _totalStaked The total amount staked by a validator and their delegators.
    /// @param _poolReward The value of pool reward.
    function delegatorShare(
        uint256 _delegatorStaked,
        uint256 _validatorStaked,
        uint256 _totalStaked,
        uint256 _poolReward
    ) public pure returns(uint256) {
        if (_delegatorStaked == 0 || _validatorStaked == 0 || _totalStaked == 0) {
            return 0;
        }
        uint256 share = 0;
        uint256 delegatorsStaked = _totalStaked >= _validatorStaked ? _totalStaked - _validatorStaked : 0;
        if (_validatorStaked * (100 - REWARD_VALIDATOR_MIN_SHARE) > delegatorsStaked * REWARD_VALIDATOR_MIN_SHARE) {
            // Validator has more than REWARD_VALIDATOR_MIN_SHARE %
            share = _poolReward * _delegatorStaked / _totalStaked;
        } else {
            // Validator has REWARD_VALIDATOR_MIN_SHARE %
            share = _poolReward * _delegatorStaked * (100 - REWARD_VALIDATOR_MIN_SHARE) / (delegatorsStaked * 100);
        }
        return share;
    }

    /// @dev Calculates validator's share for the given pool reward amount.
    /// Used by the `validatorRewardPercent` and `StakingAuRa.claimReward` functions.
    /// @param _validatorStaked The amount staked by a validator.
    /// @param _totalStaked The total amount staked by a validator and their delegators.
    /// @param _poolReward The value of pool reward.
    function validatorShare(
        uint256 _validatorStaked,
        uint256 _totalStaked,
        uint256 _poolReward
    ) public pure returns(uint256) {
        if (_validatorStaked == 0 || _totalStaked == 0) {
            return 0;
        }
        uint256 share = 0;
        uint256 delegatorsStaked = _totalStaked >= _validatorStaked ? _totalStaked - _validatorStaked : 0;
        if (_validatorStaked * (100 - REWARD_VALIDATOR_MIN_SHARE) > delegatorsStaked * REWARD_VALIDATOR_MIN_SHARE) {
            // Validator has more than REWARD_VALIDATOR_MIN_SHARE %
            share = _poolReward * _validatorStaked / _totalStaked;
        } else {
            // Validator has REWARD_VALIDATOR_MIN_SHARE %
            share = _poolReward * REWARD_VALIDATOR_MIN_SHARE / 100;
        }
        return share;
    }

    // =============================================== Private ========================================================

    uint256 internal constant REWARD_VALIDATOR_MIN_SHARE = 30; // 30%
    uint256 internal constant REWARD_PERCENT_MULTIPLIER = 1000000;

    /// @dev Distributes rewards among pools at the latest block of a staking epoch.
    /// This function is called by the `reward` function.
    /// @param _stakingContract The address of the StakingAuRa contract.
    /// @param _stakingEpoch The number of the current staking epoch.
    /// @param _stakingEpochEndBlock The number of the latest block of the current staking epoch.
    /// @return `address[] receivers` - The array of native coins receivers which should be
    /// rewarded at the current block by the `erc-to-native` bridge or by the fixed native reward.
    /// `uint256[] rewards` - The array of amounts corresponding to the `receivers` array.
    function _distributeRewards(
        IStakingAuRa _stakingContract,
        uint256 _stakingEpoch,
        uint256 _stakingEpochEndBlock
    ) internal returns(address[] memory receivers, uint256[] memory rewards) {
        bool erc20Restricted = _stakingContract.erc20Restricted();
        address[] memory validators = validatorSetContract.getValidators();

        // Determine shares
        uint256 totalRewardShareNum = 0;
        uint256 totalRewardShareDenom = 1;
        uint256 realFinalizeBlock = validatorSetContract.validatorSetApplyBlock();
        if (realFinalizeBlock != 0) {
            uint256 idealFinalizeBlock =
                _stakingContract.stakingEpochStartBlock() + validatorSetContract.MAX_VALIDATORS()*2/3 + 1;

            if (realFinalizeBlock < idealFinalizeBlock) {
                realFinalizeBlock = idealFinalizeBlock;
            }

            totalRewardShareNum = _stakingEpochEndBlock - realFinalizeBlock + 1;
            totalRewardShareDenom = _stakingEpochEndBlock - idealFinalizeBlock + 1;
        }

        uint256[] memory blocksCreatedShareNum = new uint256[](validators.length);
        uint256 blocksCreatedShareDenom = 0;
        if (totalRewardShareNum != 0) {
            for (uint256 i = 0; i < validators.length; i++) {
                if (
                    !validatorSetContract.isValidatorBanned(validators[i]) &&
                    snapshotPoolValidatorStakeAmount[_stakingEpoch][validators[i]] != 0
                ) {
                    blocksCreatedShareNum[i] = blocksCreated[_stakingEpoch][validators[i]];
                } else {
                    blocksCreatedShareNum[i] = 0;
                }
                blocksCreatedShareDenom += blocksCreatedShareNum[i];
            }
        }

        // Distribute ERC tokens among pools
        _distributeTokenRewards(
            _stakingContract,
            _stakingEpoch,
            totalRewardShareNum,
            totalRewardShareDenom,
            erc20Restricted,
            validators,
            blocksCreatedShareNum,
            blocksCreatedShareDenom
        );

        // Distribute native coins among pools
        receivers = new address[](1);
        rewards = new uint256[](1);

        receivers[0] = address(this);
        rewards[0] = _distributeNativeRewards(
            _stakingContract,
            _stakingEpoch,
            totalRewardShareNum,
            totalRewardShareDenom,
            erc20Restricted,
            validators,
            blocksCreatedShareNum,
            blocksCreatedShareDenom
        );

        return (receivers, rewards);
    }

    /// @dev Distributes rewards in native coins among pools at the latest block of a staking epoch.
    /// This function is called by the `_distributeRewards` function.
    /// @param _stakingContract The address of the StakingAuRa contract.
    /// @param _stakingEpoch The number of the current staking epoch.
    /// @param _totalRewardShareNum Numerator of the total reward share.
    /// @param _totalRewardShareDenom Denominator of the total reward share.
    /// @param _erc20Restricted A boolean flag indicating whether StakingAuRa contract restricts
    /// using ERC20/677 contract.
    /// @param _validators The array of the current validators (their mining addresses).
    /// @param _blocksCreatedShareNum Numerators of blockCreated share for each of the validators.
    /// @param _blocksCreatedShareDenom Denominator of blockCreated share.
    /// @return Returns the amount of native coins which need to be minted.
    function _distributeNativeRewards(
        IStakingAuRa _stakingContract,
        uint256 _stakingEpoch,
        uint256 _totalRewardShareNum,
        uint256 _totalRewardShareDenom,
        bool _erc20Restricted,
        address[] memory _validators,
        uint256[] memory _blocksCreatedShareNum,
        uint256 _blocksCreatedShareDenom
    ) internal returns(uint256) {
        uint256 totalReward = bridgeNativeFee;
        if (_erc20Restricted) {
            // Accumulated bridge fee plus 2.5% per year coin inflation
            totalReward += _stakingContract.stakingEpochDuration() * 1 ether;
        }
        totalReward += nativeRewardUndistributed;

        if (totalReward == 0) {
            return 0;
        }

        bridgeNativeFee = 0;

        uint256 rewardToDistribute = 0;
        uint256 distributedAmount = 0;

        if (_blocksCreatedShareDenom != 0 && _totalRewardShareDenom != 0) {
            rewardToDistribute = totalReward * _totalRewardShareNum / _totalRewardShareDenom;

            if (rewardToDistribute != 0) {
                for (uint256 i = 0; i < _validators.length; i++) {
                    uint256 poolReward =
                        rewardToDistribute * _blocksCreatedShareNum[i] / _blocksCreatedShareDenom;
                    epochPoolNativeReward[_stakingEpoch][_validators[i]] = poolReward;
                    distributedAmount += poolReward;
                    if (poolReward != 0 && epochPoolTokenReward[_stakingEpoch][_validators[i]] == 0) {
                        _epochsPoolGotRewardFor[_validators[i]].push(_stakingEpoch);
                    }
                }
            }
        }

        nativeRewardUndistributed = totalReward - distributedAmount;

        return distributedAmount;
    }

    /// @dev Distributes rewards in tokens among pools at the latest block of a staking epoch.
    /// This function is called by the `_distributeRewards` function.
    /// @param _stakingContract The address of the StakingAuRa contract.
    /// @param _stakingEpoch The number of the current staking epoch.
    /// @param _totalRewardShareNum Numerator of the total reward share.
    /// @param _totalRewardShareDenom Denominator of the total reward share.
    /// @param _erc20Restricted A boolean flag indicating whether StakingAuRa contract restricts
    /// using ERC20/677 contract.
    /// @param _validators The array of the current validators (their mining addresses).
    /// @param _blocksCreatedShareNum Numerators of blockCreated share for each of the validators.
    /// @param _blocksCreatedShareDenom Denominator of blockCreated share.
    function _distributeTokenRewards(
        IStakingAuRa _stakingContract,
        uint256 _stakingEpoch,
        uint256 _totalRewardShareNum,
        uint256 _totalRewardShareDenom,
        bool _erc20Restricted,
        address[] memory _validators,
        uint256[] memory _blocksCreatedShareNum,
        uint256 _blocksCreatedShareDenom
    ) internal {
        address erc20TokenContract = _stakingContract.erc20TokenContract();

        uint256 totalReward = bridgeTokenFee;
        if (!_erc20Restricted) {
            uint256 inflationPercent;
            if (_stakingEpoch <= 24) inflationPercent = 32;
            else if (_stakingEpoch <= 48) inflationPercent = 16;
            else if (_stakingEpoch <= 72) inflationPercent = 8;
            else inflationPercent = 4; // solhint-disable-line indent
            totalReward += snapshotTotalStakeAmount * inflationPercent / 4800;
        }
        totalReward += tokenRewardUndistributed;

        if (totalReward == 0) {
            return;
        }

        bridgeTokenFee = 0;

        uint256 distributedAmount = 0;
        if (erc20TokenContract != address(0) && _blocksCreatedShareDenom != 0 && _totalRewardShareDenom != 0) {
            uint256 rewardToDistribute = totalReward * _totalRewardShareNum / _totalRewardShareDenom;

            if (rewardToDistribute != 0) {
                for (uint256 i = 0; i < _validators.length; i++) {
                    uint256 poolReward =
                        rewardToDistribute * _blocksCreatedShareNum[i] / _blocksCreatedShareDenom;
                    epochPoolTokenReward[_stakingEpoch][_validators[i]] = poolReward;
                    distributedAmount += poolReward;
                    if (poolReward != 0 && epochPoolNativeReward[_stakingEpoch][_validators[i]] == 0) {
                        _epochsPoolGotRewardFor[_validators[i]].push(_stakingEpoch);
                    }
                }

                IERC20Minting(erc20TokenContract).mintReward(address(this), distributedAmount);
            }
        }

        tokenRewardUndistributed = totalReward - distributedAmount;
    }

    /// @dev Returns the current block number. Needed mostly for unit tests.
    function _getCurrentBlockNumber() internal view returns(uint256) {
        return block.number;
    }

    /// @dev Joins two native coin receiver elements into a single set and returns the result
    /// to the `reward` function: the first element comes from the `erc-to-native` bridge fee distribution
    /// (or from native coins fixed distribution), the second - from the `erc-to-native` bridge when native
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
        uint256 blockNumber = _getCurrentBlockNumber();
        mintedForAccountInBlock[_account][blockNumber] = _amount;
        mintedForAccount[_account] += _amount;
        mintedInBlock[blockNumber] += _amount;
        mintedTotallyByBridge[_bridge] += _amount;
        mintedTotally += _amount;
    }

    /// @dev Makes snapshots of total amount staked into the specified pool
    /// before the specified staking epoch. Used by the `reward` function.
    /// @param _stakingContract The address of the `StakingAuRa` contract.
    /// @param _stakingEpoch The number of staking epoch.
    /// @param _miningAddress The mining address of the pool.
    function _snapshotPoolStakeAmounts(
        IStakingAuRa _stakingContract,
        uint256 _stakingEpoch,
        address _miningAddress
    ) internal {
        if (snapshotPoolTotalStakeAmount[_stakingEpoch][_miningAddress] != 0) {
            return;
        }
        address stakingAddress = validatorSetContract.stakingByMiningAddress(_miningAddress);
        uint256 totalAmount = _stakingContract.stakeAmountTotalMinusOrderedWithdraw(stakingAddress);
        if (totalAmount == 0) {
            return;
        }
        snapshotPoolTotalStakeAmount[_stakingEpoch][_miningAddress] = totalAmount;
        snapshotPoolValidatorStakeAmount[_stakingEpoch][_miningAddress] =
            _stakingContract.stakeAmountMinusOrderedWithdraw(stakingAddress, stakingAddress);
    }
}
