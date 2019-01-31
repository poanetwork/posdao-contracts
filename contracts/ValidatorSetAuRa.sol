pragma solidity 0.5.2;

import "./abstracts/ValidatorSetBase.sol";
import "./interfaces/IValidatorSetAuRa.sol";


contract ValidatorSetAuRa is IValidatorSetAuRa, ValidatorSetBase {

    // TODO: add a description for each function

    // ================================================ Events ========================================================

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

    function addPool(uint256 _amount) external {
        stake(msg.sender, _amount);
    }

    /// Creates an initial set of validators at the start of the network.
    /// Must be called by the constructor of `Initializer` contract on genesis block.
    /// This is used instead of `constructor()` because this contract is upgradable.
    function initialize(
        address _blockRewardContract,
        address _randomContract,
        address _erc20TokenContract,
        address[] calldata _initialValidators,
        uint256 _delegatorMinStake, // in STAKE_UNITs
        uint256 _candidateMinStake, // in STAKE_UNITs
        uint256 _stakingEpochDuration // in blocks (e.g., 120960 = 1 week)
    ) external {
        super._initialize(
            _blockRewardContract,
            _randomContract,
            _erc20TokenContract,
            _initialValidators,
            _delegatorMinStake,
            _candidateMinStake
        );
        _setStakingEpochDuration(_stakingEpochDuration);
        require(stakeWithdrawDisallowPeriod() > 0);
        _setStakingEpochStartBlock(_getCurrentBlockNumber());
    }

    function newValidatorSet() external onlyBlockRewardContract {
        if (!_newValidatorSetCallable()) return;
        super._newValidatorSet();
        _setStakingEpochStartBlock(_getCurrentBlockNumber());
    }

    function removeMaliciousValidator(address _validator) external onlyRandomContract {
        _removeMaliciousValidatorAuRa(_validator);
    }

    // solhint-disable no-empty-blocks
    function reportBenign(address, uint256) external {
        // does nothing
    }
    // solhint-enable no-empty-blocks

    function reportMalicious(address _maliciousValidator, uint256 _blockNumber, bytes calldata) external {
        address reportingValidator = msg.sender;
        uint256 currentBlock = _getCurrentBlockNumber();

        require(isReportValidatorValid(_maliciousValidator));
        require(_blockNumber <= currentBlock); // avoid reporting about future blocks

        uint256 ancientBlocksLimit = 100;
        if (currentBlock >= ancientBlocksLimit) {
            require(_blockNumber >= currentBlock - ancientBlocksLimit); // avoid reporting about ancient blocks
        }

        require(isReportValidatorValid(reportingValidator));

        address[] storage reportedValidators =
            addressArrayStorage[keccak256(abi.encode(MALICE_REPORTED_FOR_BLOCK, _maliciousValidator, _blockNumber))];

        // Don't allow reporting validator to report about malicious validator more than once
        for (uint256 m = 0; m < reportedValidators.length; m++) {
            if (reportedValidators[m] == reportingValidator) {
                revert();
            }
        }

        reportedValidators.push(reportingValidator);

        emit ReportedMalicious(reportingValidator, _maliciousValidator, _blockNumber);

        // If more than 50% of validators reported about malicious validator
        // for the same `blockNumber`
        if (reportedValidators.length.mul(2) > getValidators().length) {
            _removeMaliciousValidatorAuRa(_maliciousValidator);
        }
    }

    // =============================================== Getters ========================================================

    function maliceReportedForBlock(address _validator, uint256 _blockNumber) external view returns(address[] memory) {
        return addressArrayStorage[keccak256(abi.encode(MALICE_REPORTED_FOR_BLOCK, _validator, _blockNumber))];
    }

    function stakeWithdrawDisallowPeriod() public view returns(uint256) {
        return stakingEpochDuration() / 28;
    }

    function stakingEpochDuration() public view returns(uint256) {
        return uintStorage[STAKING_EPOCH_DURATION];
    }

    function stakingEpochStartBlock() public view returns(uint256) {
        return uintStorage[STAKING_EPOCH_START_BLOCK];
    }

    // =============================================== Private ========================================================

    bytes32 internal constant STAKING_EPOCH_DURATION = keccak256("stakingEpochDuration");
    bytes32 internal constant STAKING_EPOCH_START_BLOCK = keccak256("stakingEpochStartBlock");
    bytes32 internal constant MALICE_REPORTED_FOR_BLOCK = "maliceReportedForBlock";

    function _removeMaliciousValidatorAuRa(address _validator) internal {
        if (isValidatorBanned(_validator)) {
            // The malicious validator is already banned
            return;
        }

        if (_removeMaliciousValidator(_validator)) {
            // From this moment `getPendingValidators()` will return the new validator set
            _incrementChangeRequestCount();
            _enqueuePendingValidators(false);
        }
    }

    function _setStakingEpochDuration(uint256 _duration) internal {
        uintStorage[STAKING_EPOCH_DURATION] = _duration;
    }

    function _setStakingEpochStartBlock(uint256 _blockNumber) internal {
        uintStorage[STAKING_EPOCH_START_BLOCK] = _blockNumber;
    }

    function _areStakeAndWithdrawAllowed() internal view returns(bool) {
        uint256 allowedDuration = stakingEpochDuration() - stakeWithdrawDisallowPeriod();
        uint256 applyBlock = validatorSetApplyBlock();
        uint256 currentBlock = _getCurrentBlockNumber();
        bool afterValidatorSetApplied = applyBlock != 0 && currentBlock > applyBlock;
        return afterValidatorSetApplied && currentBlock.sub(stakingEpochStartBlock()) <= allowedDuration;
    }

    function _newValidatorSetCallable() internal view returns(bool) {
        return _getCurrentBlockNumber().sub(stakingEpochStartBlock()) >= stakingEpochDuration();
    }
}
