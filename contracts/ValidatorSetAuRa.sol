pragma solidity 0.5.2;

import "./abstracts/ValidatorSetBase.sol";
import "./interfaces/IValidatorSetAuRa.sol";


contract ValidatorSetAuRa is IValidatorSetAuRa, ValidatorSetBase {

    // TODO: add a description for each function

    // ================================================ Events ========================================================

    event ReportedBenign(address reportingValidator, address benignValidator, uint256 blockNumber);
    event ReportedMalicious(address reportingValidator, address maliciousValidator, uint256 blockNumber);

    // ============================================== Modifiers =======================================================

    modifier onlyBlockRewardContract() {
        require(msg.sender == address(blockRewardContract()));
        _;
    }

    modifier onlyRandomContract() {
        require(msg.sender == address(randomContract()));
        _;
    }

    // =============================================== Setters ========================================================

    function addPool(uint256 _amount, address _miningAddress) external {
        address stakingAddress = msg.sender;
        _setStakingAddress(_miningAddress, stakingAddress);
        stake(stakingAddress, _amount);
    }

    /// Creates an initial set of validators at the start of the network.
    /// Must be called by the constructor of `InitializerAuRa` contract on genesis block.
    /// This is used instead of `constructor()` because this contract is upgradable.
    function initialize(
        address _blockRewardContract,
        address _randomContract,
        address _erc20TokenContract,
        address[] calldata _initialMiningAddresses,
        address[] calldata _initialStakingAddresses,
        uint256 _delegatorMinStake, // in STAKE_UNITs
        uint256 _candidateMinStake, // in STAKE_UNITs
        uint256 _stakingEpochDuration, // in blocks (e.g., 120960 = 1 week)
        uint256 _stakeWithdrawDisallowPeriod // in blocks (e.g., 4320 = 6 hours)
    ) external {
        require(_stakingEpochDuration != 0);
        require(_stakingEpochDuration > _stakeWithdrawDisallowPeriod);
        require(_stakeWithdrawDisallowPeriod != 0);
        super._initialize(
            _blockRewardContract,
            _randomContract,
            _erc20TokenContract,
            _initialMiningAddresses,
            _initialStakingAddresses,
            _delegatorMinStake,
            _candidateMinStake
        );
        _setStakingEpochDuration(_stakingEpochDuration);
        _setStakeWithdrawDisallowPeriod(_stakeWithdrawDisallowPeriod);
        _setStakingEpochStartBlock(_getCurrentBlockNumber());
    }

    function newValidatorSet() external onlyBlockRewardContract {
        uint256 currentBlock = _getCurrentBlockNumber();
        if (currentBlock != stakingEpochEndBlock()) return;
        super._newValidatorSet();
        _setStakingEpochStartBlock(currentBlock + 1);
    }

    function removeMaliciousValidator(address _miningAddress) external onlyRandomContract {
        _removeMaliciousValidatorAuRa(_miningAddress);
    }

    function reportBenign(address _benignMiningAddress, uint256 _blockNumber) external {
        address reportingMiningAddress = msg.sender;
        require(isReportValidatorValid(reportingMiningAddress));
        require(isReportValidatorValid(_benignMiningAddress));
        uint256 currentBlock = _getCurrentBlockNumber();
        require(_blockNumber <= currentBlock); // avoid reporting about future blocks
        address[] storage reportedValidators = addressArrayStorage[keccak256(abi.encode(
            BENIGNANCY_REPORTED_FOR_BLOCK, _benignMiningAddress, _blockNumber
        ))];
        reportedValidators.push(reportingMiningAddress);
        emit ReportedBenign(reportingMiningAddress, _benignMiningAddress, _blockNumber);
    }

    function reportMalicious(address _maliciousMiningAddress, uint256 _blockNumber, bytes calldata) external {
        address reportingMiningAddress = msg.sender;
        uint256 currentBlock = _getCurrentBlockNumber();

        require(isReportValidatorValid(_maliciousMiningAddress));
        require(_blockNumber <= currentBlock); // avoid reporting about future blocks

        uint256 ancientBlocksLimit = 100;
        if (currentBlock >= ancientBlocksLimit) {
            require(_blockNumber >= currentBlock - ancientBlocksLimit); // avoid reporting about ancient blocks
        }

        require(isReportValidatorValid(reportingMiningAddress));

        address[] storage reportedValidators = addressArrayStorage[keccak256(abi.encode(
            MALICE_REPORTED_FOR_BLOCK, _maliciousMiningAddress, _blockNumber
        ))];

        // Don't allow reporting validator to report about malicious validator more than once
        for (uint256 m = 0; m < reportedValidators.length; m++) {
            if (reportedValidators[m] == reportingMiningAddress) {
                revert();
            }
        }

        reportedValidators.push(reportingMiningAddress);

        emit ReportedMalicious(reportingMiningAddress, _maliciousMiningAddress, _blockNumber);

        // If more than 50% of validators reported about malicious validator
        // for the same `blockNumber`
        if (reportedValidators.length.mul(2) > getValidators().length) {
            _removeMaliciousValidatorAuRa(_maliciousMiningAddress);
        }
    }

    // =============================================== Getters ========================================================

    function areStakeAndWithdrawAllowed() public view returns(bool) {
        uint256 allowedDuration = stakingEpochDuration() - stakeWithdrawDisallowPeriod();
        uint256 applyBlock = validatorSetApplyBlock();
        uint256 currentBlock = _getCurrentBlockNumber();
        bool afterValidatorSetApplied = applyBlock != 0 && currentBlock > applyBlock;
        return afterValidatorSetApplied && currentBlock.sub(stakingEpochStartBlock()) <= allowedDuration;
    }

    function isValidatorBanned(address _miningAddress) public view returns(bool) {
        return _getCurrentBlockNumber() < bannedUntil(_miningAddress);
    }

    function benignancyReportedForBlock(
        address _benignMiningAddress,
        uint256 _blockNumber
    ) public view returns(address[] memory) {
        return addressArrayStorage[keccak256(abi.encode(
            BENIGNANCY_REPORTED_FOR_BLOCK, _benignMiningAddress, _blockNumber
        ))];
    }

    function maliceReportedForBlock(
        address _maliciousMiningAddress,
        uint256 _blockNumber
    ) public view returns(address[] memory) {
        return addressArrayStorage[keccak256(abi.encode(
            MALICE_REPORTED_FOR_BLOCK, _maliciousMiningAddress, _blockNumber
        ))];
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
    bytes32 internal constant MALICE_REPORTED_FOR_BLOCK = "maliceReportedForBlock";
    bytes32 internal constant BENIGNANCY_REPORTED_FOR_BLOCK = "benignancyReportedForBlock";

    function _banUntil() internal view returns(uint256) {
        return block.number + 1555200; // 90 days (for 5 seconds block)
    }

    function _removeMaliciousValidatorAuRa(address _miningAddress) internal {
        if (isValidatorBanned(_miningAddress)) {
            // The malicious validator is already banned
            return;
        }

        if (_removeMaliciousValidator(_miningAddress)) {
            // From this moment `getPendingValidators()` will return the new validator set
            _incrementChangeRequestCount();
            _enqueuePendingValidators(false);
        }
    }

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
