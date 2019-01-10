pragma solidity 0.4.25;

import "./abstracts/ValidatorSetBase.sol";


contract ValidatorSetAuRa is ValidatorSetBase {

    // TODO: add a description for each function

    // ============================================== Constants =======================================================

    uint256 public constant STAKING_EPOCH_DURATION = 120960; // 1 week in blocks (5 seconds per block)
    uint256 public constant STAKE_WITHDRAW_DISALLOW_PERIOD = 4320; // 6 hours in blocks (staking epoch last blocks)

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

    function addPool(uint256 _amount) public {
        stake(msg.sender, _amount);
    }

    /// Creates an initial set of validators at the start of the network.
    /// Must be called by the constructor of `Initializer` contract on genesis block.
    /// This is used instead of `constructor()` because this contract is upgradable.
    function initialize(
        address _blockRewardContract,
        address _randomContract,
        address _erc20TokenContract,
        address[] _initialValidators,
        uint256 _stakerMinStake,
        uint256 _validatorMinStake
    ) external {
        super._initialize(
            _blockRewardContract,
            _randomContract,
            _erc20TokenContract,
            _initialValidators,
            _stakerMinStake,
            _validatorMinStake
        );
        _setStakingEpochStartBlock(block.number);
    }

    function newValidatorSet() external onlyBlockRewardContract {
        if (!_newValidatorSetCallable()) return;
        super._newValidatorSet();
        _setStakingEpochStartBlock(block.number);
    }

    function removeMaliciousValidator(address _validator) external onlyRandomContract {
        _removeMaliciousValidatorAuRa(_validator);
    }

    function reportBenign(address, uint256) public {
        // does nothing
    }

    function reportMalicious(address _maliciousValidator, uint256 _blockNumber, bytes) public {
        address reportingValidator = msg.sender;

        require(_isReportValidatorValid(_maliciousValidator));
        require(_blockNumber <= block.number); // avoid reporting about future blocks
        require(_isReportValidatorValid(reportingValidator));

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

    function maliceReportedForBlock(address _validator, uint256 _blockNumber) public view returns(address[]) {
        return addressArrayStorage[keccak256(abi.encode(MALICE_REPORTED_FOR_BLOCK, _validator, _blockNumber))];
    }

    function stakingEpochStartBlock() public view returns(uint256) {
        return uintStorage[STAKING_EPOCH_START_BLOCK];
    }

    // =============================================== Private ========================================================

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
        }
    }

    function _setStakingEpochStartBlock(uint256 _blockNumber) internal {
        uintStorage[STAKING_EPOCH_START_BLOCK] = _blockNumber;
    }

    function _areStakeAndWithdrawAllowed() internal view returns(bool) {
        uint256 allowedDuration = STAKING_EPOCH_DURATION - STAKE_WITHDRAW_DISALLOW_PERIOD;
        uint256 applyBlock = validatorSetApplyBlock();
        bool afterValidatorSetApplied = applyBlock != 0 && block.number > applyBlock;
        return afterValidatorSetApplied && block.number.sub(stakingEpochStartBlock()) <= allowedDuration;
    }

    function _newValidatorSetCallable() internal view returns(bool) {
        return block.number.sub(stakingEpochStartBlock()) >= STAKING_EPOCH_DURATION - 1;
    }
}
