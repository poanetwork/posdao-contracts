pragma solidity 0.5.2;

import "./abstracts/StakingBase.sol";
import "./interfaces/IBlockReward.sol";
import "./interfaces/IStakingAuRa.sol";


contract StakingAuRa is IStakingAuRa, StakingBase {

    // TODO: add a description for each function

    // =============================================== Setters ========================================================

    function addPool(uint256 _amount, address _miningAddress) external gasPriceIsValid {
        address stakingAddress = msg.sender;
        validatorSetContract().setStakingAddress(_miningAddress, stakingAddress);
        _stake(stakingAddress, _amount);
    }

    /// Must be called by the constructor of `InitializerAuRa` contract on genesis block.
    /// This is used instead of `constructor()` because this contract is upgradable.
    function initialize(
        address _validatorSetContract,
        address _erc20TokenContract,
        address[] calldata _initialStakingAddresses,
        uint256 _delegatorMinStake, // in STAKE_UNITs
        uint256 _candidateMinStake, // in STAKE_UNITs
        uint256 _stakingEpochDuration, // in blocks (e.g., 120960 = 1 week)
        uint256 _stakeWithdrawDisallowPeriod // in blocks (e.g., 4320 = 6 hours)
    ) external {
        require(_stakingEpochDuration != 0);
        require(_stakingEpochDuration > _stakeWithdrawDisallowPeriod);
        IValidatorSet validatorSet = IValidatorSet(_validatorSetContract);
        IBlockReward blockReward = IBlockReward(validatorSet.blockRewardContract());
        require(_stakingEpochDuration >= validatorSet.MAX_VALIDATORS() * blockReward.DELEGATORS_ALIQUOT() * 2 + 1);
        require(_stakeWithdrawDisallowPeriod != 0);
        super._initialize(
            _validatorSetContract,
            _erc20TokenContract,
            _initialStakingAddresses,
            _delegatorMinStake,
            _candidateMinStake
        );
        _setStakingEpochDuration(_stakingEpochDuration);
        _setStakeWithdrawDisallowPeriod(_stakeWithdrawDisallowPeriod);
        _setStakingEpochStartBlock(_getCurrentBlockNumber());
    }

    function setStakingEpochStartBlock(uint256 _blockNumber) external onlyValidatorSetContract {
        _setStakingEpochStartBlock(_blockNumber);
    }

    // =============================================== Getters ========================================================

    function areStakeAndWithdrawAllowed() public view returns(bool) {
        bool isSnapshotting = IBlockReward(validatorSetContract().blockRewardContract()).isSnapshotting();
        uint256 currentBlock = _getCurrentBlockNumber();
        uint256 allowedDuration = stakingEpochDuration() - stakeWithdrawDisallowPeriod();
        return !isSnapshotting && currentBlock.sub(stakingEpochStartBlock()) <= allowedDuration;
    }

    function stakeWithdrawDisallowPeriod() public view returns(uint256) {
        return uintStorage[STAKE_WITHDRAW_DISALLOW_PERIOD];
    }

    function stakingEpochDuration() public view returns(uint256) {
        return uintStorage[STAKING_EPOCH_DURATION];
    }

    function stakingEpochStartBlock() public view returns(uint256) {
        return uintStorage[STAKING_EPOCH_START_BLOCK];
    }

    function stakingEpochEndBlock() public view returns(uint256) {
        uint256 startBlock = stakingEpochStartBlock();
        return startBlock + stakingEpochDuration() - (startBlock == 0 ? 0 : 1);
    }

    // =============================================== Private ========================================================

    bytes32 internal constant STAKE_WITHDRAW_DISALLOW_PERIOD = keccak256("stakeWithdrawDisallowPeriod");
    bytes32 internal constant STAKING_EPOCH_DURATION = keccak256("stakingEpochDuration");
    bytes32 internal constant STAKING_EPOCH_START_BLOCK = keccak256("stakingEpochStartBlock");

    function _setStakeWithdrawDisallowPeriod(uint256 _period) internal {
        uintStorage[STAKE_WITHDRAW_DISALLOW_PERIOD] = _period;
    }

    function _setStakingEpochDuration(uint256 _duration) internal {
        uintStorage[STAKING_EPOCH_DURATION] = _duration;
    }

    function _setStakingEpochStartBlock(uint256 _blockNumber) internal {
        uintStorage[STAKING_EPOCH_START_BLOCK] = _blockNumber;
    }
}
