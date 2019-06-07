pragma solidity 0.5.9;

import "./abstracts/StakingBase.sol";
import "./interfaces/IBlockReward.sol";
import "./interfaces/IStakingAuRa.sol";


/// @dev Implements staking and withdrawal logic.
contract StakingAuRa is IStakingAuRa, StakingBase {

    // =============================================== Setters ========================================================

    /// @dev Adds a new candidate's pool to the list of active pools (see the `getPools` getter) and
    /// moves the specified amount of staking tokens from the candidate's staking address to the candidate's pool.
    /// A participant calls this function using their staking address when they want to create a pool.
    /// This is a wrapper for the `stake` function.
    /// @param _amount The amount of tokens to be staked.
    /// @param _miningAddress The mining address of the candidate. The mining address is bound to the staking address
    /// (msg.sender). This address cannot be equal to `msg.sender`.
    function addPool(uint256 _amount, address _miningAddress) external gasPriceIsValid onlyInitialized {
        address stakingAddress = msg.sender;
        validatorSetContract().setStakingAddress(_miningAddress, stakingAddress);
        _stake(stakingAddress, _amount);
    }

    /// @dev Adds a new candidate's pool to the list of active pools (see the `getPools` getter) and
    /// moves the specified amount of staking coins from the candidate's staking address to the candidate's pool.
    /// A participant calls this function using their staking address when they want to create a pool.
    /// This is a wrapper for the `stake` function.
    /// @param _miningAddress The mining address of the candidate. The mining address is bound to the staking address
    /// (msg.sender). This address cannot be equal to `msg.sender`.
    function addPoolNative(address _miningAddress) external gasPriceIsValid onlyInitialized payable {
        address stakingAddress = msg.sender;
        validatorSetContract().setStakingAddress(_miningAddress, stakingAddress);
        _stake(stakingAddress, msg.value);
    }

    /// @dev Initializes the network parameters.
    /// Must be called by the constructor of the `InitializerAuRa` contract.
    /// @param _validatorSetContract The address of the `ValidatorSetAuRa` contract.
    /// @param _initialStakingAddresses The array of initial validators' staking addresses.
    /// @param _delegatorMinStake The minimum allowed amount of delegator stake in STAKE_UNITs.
    /// @param _candidateMinStake The minimum allowed amount of candidate/validator stake in STAKE_UNITs.
    /// @param _stakingEpochDuration The duration of a staking epoch in blocks
    /// (e.g., 120960 = 1 week for 5-seconds blocks in AuRa).
    /// @param _stakingEpochStartBlock The number of the first block of initial staking epoch
    /// (must be zero if the network is starting from genesis block).
    /// @param _stakeWithdrawDisallowPeriod The duration period (in blocks) at the end of a staking epoch
    /// during which participants cannot stake or withdraw their staking tokens/coins
    /// (e.g., 4320 = 6 hours for 5-seconds blocks in AuRa).
    /// @param _erc20Restricted Defines whether this staking contract restricts using ERC20/677 contract.
    /// If it's set to `true`, native staking coins are used instead of ERC staking tokens.
    function initialize(
        address _validatorSetContract,
        address[] calldata _initialStakingAddresses,
        uint256 _delegatorMinStake,
        uint256 _candidateMinStake,
        uint256 _stakingEpochDuration,
        uint256 _stakingEpochStartBlock,
        uint256 _stakeWithdrawDisallowPeriod,
        bool _erc20Restricted
    ) external {
        require(_stakingEpochDuration != 0);
        require(_stakingEpochDuration > _stakeWithdrawDisallowPeriod);
        IValidatorSet validatorSet = IValidatorSet(_validatorSetContract);
        IBlockReward blockReward = IBlockReward(validatorSet.blockRewardContract());
        require(_stakingEpochDuration >= validatorSet.MAX_VALIDATORS() * blockReward.DELEGATORS_ALIQUOT() * 2 + 1);
        require(_stakeWithdrawDisallowPeriod != 0);
        super._initialize(
            _validatorSetContract,
            _initialStakingAddresses,
            _delegatorMinStake,
            _candidateMinStake,
            _erc20Restricted
        );
        uintStorage[STAKING_EPOCH_DURATION] = _stakingEpochDuration;
        uintStorage[STAKE_WITHDRAW_DISALLOW_PERIOD] = _stakeWithdrawDisallowPeriod;
        uintStorage[STAKING_EPOCH_START_BLOCK] = _stakingEpochStartBlock;
    }

    /// @dev Sets the number of the first block in the upcoming staking epoch.
    /// Called by the `ValidatorSetAuRa.newValidatorSet` function at the last block of a staking epoch.
    /// @param _blockNumber The number of the very first block in the upcoming staking epoch.
    function setStakingEpochStartBlock(uint256 _blockNumber) external onlyValidatorSetContract {
        uintStorage[STAKING_EPOCH_START_BLOCK] = _blockNumber;
    }

    // =============================================== Getters ========================================================

    /// @dev Determines whether staking/withdrawal operations are allowed at the moment.
    /// Used by all staking/withdrawal functions.
    function areStakeAndWithdrawAllowed() public view returns(bool) {
        bool isSnapshotting = IBlockReward(validatorSetContract().blockRewardContract()).isSnapshotting();
        uint256 currentBlock = _getCurrentBlockNumber();
        uint256 allowedDuration = stakingEpochDuration() - stakeWithdrawDisallowPeriod();
        return !isSnapshotting && currentBlock.sub(stakingEpochStartBlock()) <= allowedDuration;
    }

    /// @dev Returns the duration period (in blocks) at the end of staking epoch during which
    /// participants are not allowed to stake and withdraw their staking tokens/coins.
    function stakeWithdrawDisallowPeriod() public view returns(uint256) {
        return uintStorage[STAKE_WITHDRAW_DISALLOW_PERIOD];
    }

    /// @dev Returns the duration of a staking epoch in blocks.
    function stakingEpochDuration() public view returns(uint256) {
        return uintStorage[STAKING_EPOCH_DURATION];
    }

    /// @dev Returns the number of the first block of the current staking epoch.
    function stakingEpochStartBlock() public view returns(uint256) {
        return uintStorage[STAKING_EPOCH_START_BLOCK];
    }

    /// @dev Returns the number of the last block of the current staking epoch.
    function stakingEpochEndBlock() public view returns(uint256) {
        uint256 startBlock = stakingEpochStartBlock();
        return startBlock + stakingEpochDuration() - (startBlock == 0 ? 0 : 1);
    }

    // =============================================== Private ========================================================

    bytes32 internal constant STAKE_WITHDRAW_DISALLOW_PERIOD = keccak256("stakeWithdrawDisallowPeriod");
    bytes32 internal constant STAKING_EPOCH_DURATION = keccak256("stakingEpochDuration");
    bytes32 internal constant STAKING_EPOCH_START_BLOCK = keccak256("stakingEpochStartBlock");

}
