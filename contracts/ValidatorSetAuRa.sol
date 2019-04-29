pragma solidity 0.5.7;

import "./abstracts/ValidatorSetBase.sol";
import "./interfaces/IValidatorSetAuRa.sol";
import "./interfaces/IStakingAuRa.sol";


contract ValidatorSetAuRa is IValidatorSetAuRa, ValidatorSetBase {

    // ================================================ Events ========================================================

    /// @dev Emitted by the `reportMalicious` function to signal that a specified validator reported
    /// misbehavior by a specified malicious validator at a specified block number.
    /// @param reportingValidator The mining address of the reporting validator.
    /// @param maliciousValidator The mining address of the malicious validator.
    /// @param blockNumber The block number at which the `maliciousValidator` misbehaved.
    event ReportedMalicious(address reportingValidator, address maliciousValidator, uint256 blockNumber);

    // ============================================== Modifiers =======================================================

    /// @dev Ensures the caller is the BlockRewardAuRa contract address
    /// (EternalStorageProxy proxy contract for the BlockRewardAuRa).
    modifier onlyBlockRewardContract() {
        require(msg.sender == blockRewardContract());
        _;
    }

    /// @dev Ensures the caller is the RandomAuRa contract address
    /// (EternalStorageProxy proxy contract for the RandomAuRa).
    modifier onlyRandomContract() {
        require(msg.sender == randomContract());
        _;
    }

    // =============================================== Setters ========================================================

    /// @dev Implements the logic which forms a new validator set. Calls the internal `_newValidatorSet` function of
    /// the base contract. Automatically called by the `BlockRewardAuRa.reward` function on every block.
    /// @return called A boolean flag indicating whether the internal `_newValidatorSet` function was called.
    /// @return poolsToBeElectedLength The number of pools ready to be elected (see the `Staking.getPoolsToBeElected`
    /// function). Equals `0` if the `called` flag is `false`.
    function newValidatorSet() external onlyBlockRewardContract returns(bool called, uint256 poolsToBeElectedLength) {
        uint256 currentBlock = _getCurrentBlockNumber();
        IStakingAuRa stakingContract = IStakingAuRa(stakingContract());
        if (currentBlock != stakingContract.stakingEpochEndBlock()) return (false, 0);
        called = true;
        poolsToBeElectedLength = super._newValidatorSet();
        stakingContract.setStakingEpochStartBlock(currentBlock + 1);
    }

    /// @dev Removes a malicious validator. Called by the `RandomAuRa.onFinishCollectRound` function.
    /// @param _miningAddress The mining address of the malicious validator.
    function removeMaliciousValidator(address _miningAddress) external onlyRandomContract {
        _removeMaliciousValidatorAuRa(_miningAddress);
    }

    /// @dev Reports that the malicious validator misbehaved at the specified block.
    /// Called by the node of each honest validator after the specified validator misbehaved.
    /// See https://wiki.parity.io/Validator-Set.html#reporting-contract
    /// Can only be called when the `reportMaliciousCallable` getter returns `true`.
    /// @param _maliciousMiningAddress The mining address of the malicious validator.
    /// @param _blockNumber The block number where the misbehavior was observed.
    function reportMalicious(address _maliciousMiningAddress, uint256 _blockNumber, bytes calldata) external {
        address reportingMiningAddress = msg.sender;

        _incrementReportingCounter(reportingMiningAddress);

        (
            bool callable,
            bool removeReportingValidator
        ) = reportMaliciousCallable(
            reportingMiningAddress,
            _maliciousMiningAddress,
            _blockNumber
        );

        if (!callable) {
            if (removeReportingValidator) {
                // Reporting validator reported too often, so
                // treat them as a malicious as well
                _removeMaliciousValidatorAuRa(reportingMiningAddress);
            }
            return;
        }

        address[] storage reportedValidators = addressArrayStorage[keccak256(abi.encode(
            MALICE_REPORTED_FOR_BLOCK, _maliciousMiningAddress, _blockNumber
        ))];

        reportedValidators.push(reportingMiningAddress);

        emit ReportedMalicious(reportingMiningAddress, _maliciousMiningAddress, _blockNumber);

        // If more than 2/3 of validators reported about malicious validator
        // for the same `blockNumber`
        if (reportedValidators.length.mul(3) > getValidators().length.mul(2)) {
            _removeMaliciousValidatorAuRa(_maliciousMiningAddress);
        }
    }

    // =============================================== Getters ========================================================

    /// @dev Returns an array of the validators (their mining addresses) which reported that the specified malicious
    /// validator misbehaved at the specified block.
    /// @param _maliciousMiningAddress The mining address of the malicious validator.
    /// @param _blockNumber The block number at which the misbehavior was observed.
    function maliceReportedForBlock(
        address _maliciousMiningAddress,
        uint256 _blockNumber
    ) public view returns(address[] memory) {
        return addressArrayStorage[keccak256(abi.encode(
            MALICE_REPORTED_FOR_BLOCK, _maliciousMiningAddress, _blockNumber
        ))];
    }

    /// @dev Returns the number of times the specified validator reported misbehaviors during the specified
    /// staking epoch. Used by the `reportMaliciousCallable` getter to determine whether a validator reported too often.
    /// @param _reportingMiningAddress The mining address of the reporting validator.
    /// @param _stakingEpoch The serial number of the staking epoch.
    function reportingCounter(address _reportingMiningAddress, uint256 _stakingEpoch) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(REPORTING_COUNTER, _reportingMiningAddress, _stakingEpoch))];
    }

    /// @dev Returns how many times all validators reported misbehaviors during the specified staking epoch.
    /// Used by the `reportMaliciousCallable` getter to determine whether a validator reported too often.
    /// @param _stakingEpoch The serial number of the staking epoch.
    function reportingCounterTotal(uint256 _stakingEpoch) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(REPORTING_COUNTER_TOTAL, _stakingEpoch))];
    }

    /// @dev Returns whether the `reportMalicious` function can be called by the specified validator with the
    /// given parameters. Used by the `reportMalicious` function and `TxPermission` contract. Also, returns
    /// a boolean flag indicating whether the reporting validator should be removed as malicious due to
    /// excessive reporting during the current staking epoch.
    /// @param _reportingMiningAddress The mining address of the reporting validator which is calling
    /// the `reportMalicious` function.
    /// @param _maliciousMiningAddress The mining address of the malicious validator which is passed to
    /// the `reportMalicious` function.
    /// @param _blockNumber The block number which is passed to the `reportMalicious` function.
    /// @return callable The boolean flag indicating whether the `reportMalicious` function can be called at the moment.
    /// @return removeReportingValidator The boolean flag indicating whether the reporting validator should be 
    /// removed as malicious due to excessive reporting. This flag is only used by the `reportMalicious` function.
    function reportMaliciousCallable(
        address _reportingMiningAddress,
        address _maliciousMiningAddress,
        uint256 _blockNumber
    ) public view returns(bool callable, bool removeReportingValidator) {
        if (!isReportValidatorValid(_reportingMiningAddress)) return (false, false);
        if (!isReportValidatorValid(_maliciousMiningAddress)) return (false, false);

        uint256 validatorsNumber = getValidators().length;

        if (validatorsNumber > 1) {
            uint256 currentStakingEpoch = IStaking(stakingContract()).stakingEpoch();
            uint256 reportsNumber = reportingCounter(_reportingMiningAddress, currentStakingEpoch);
            uint256 reportsTotalNumber = reportingCounterTotal(currentStakingEpoch);
            uint256 averageReportsNumber = 0;

            if (reportsTotalNumber >= reportsNumber) {
                averageReportsNumber = (reportsTotalNumber - reportsNumber) / (validatorsNumber - 1);
            }

            if (reportsNumber > validatorsNumber * 50 && reportsNumber > averageReportsNumber * 10) {
                return (false, true);
            }
        }

        uint256 currentBlock = _getCurrentBlockNumber();

        if (_blockNumber > currentBlock) return (false, false); // avoid reporting about future blocks

        uint256 ancientBlocksLimit = 100;
        if (currentBlock > ancientBlocksLimit && _blockNumber < currentBlock - ancientBlocksLimit) {
            return (false, false); // avoid reporting about ancient blocks
        }

        address[] storage reportedValidators = addressArrayStorage[keccak256(abi.encode(
            MALICE_REPORTED_FOR_BLOCK, _maliciousMiningAddress, _blockNumber
        ))];

        // Don't allow reporting validator to report about the same misbehavior more than once
        for (uint256 m = 0; m < reportedValidators.length; m++) {
            if (reportedValidators[m] == _reportingMiningAddress) {
                return (false, false);
            }
        }

        return (true, false);
    }

    // =============================================== Private ========================================================

    bytes32 internal constant MALICE_REPORTED_FOR_BLOCK = "maliceReportedForBlock";
    bytes32 internal constant REPORTING_COUNTER = "reportingCounter";
    bytes32 internal constant REPORTING_COUNTER_TOTAL = "reportingCounterTotal";

    /// @dev Returns the current block number for the `isValidatorBanned`, `_banUntil`, and `_banValidator` functions.
    function _banStart() internal view returns(uint256) {
        return _getCurrentBlockNumber();
    }

    /// @dev Returns the future block number until which a validator is banned. Used by the `_banValidator` function.
    function _banUntil() internal view returns(uint256) {
        return _banStart() + 1555200; // 90 days (for 5 seconds block)
    }

    /// @dev Updates the total reporting counter (see the `reportingCounterTotal` getter) for the current staking epoch
    /// after the specified validator is removed as malicious. The `reportMaliciousCallable` getter uses this counter
    /// for reporting checks so it must be up-to-date. Called by the `_removeMaliciousValidatorAuRa` internal function.
    /// @param _miningAddress The mining address of the removed malicious validator.
    function _clearReportingCounter(address _miningAddress) internal {
        uint256 currentStakingEpoch = IStaking(stakingContract()).stakingEpoch();
        uint256 total = reportingCounterTotal(currentStakingEpoch);
        uint256 counter = reportingCounter(_miningAddress, currentStakingEpoch);

        uintStorage[keccak256(abi.encode(REPORTING_COUNTER, _miningAddress, currentStakingEpoch))] = 0;

        if (total >= counter) {
            uintStorage[keccak256(abi.encode(REPORTING_COUNTER_TOTAL, currentStakingEpoch))] -= counter;
        } else {
            uintStorage[keccak256(abi.encode(REPORTING_COUNTER_TOTAL, currentStakingEpoch))] = 0;
        }
    }

    /// @dev Increments the reporting counter for the specified validator and the current staking epoch.
    /// See the `reportingCounter` and `reportingCounterTotal` getters. Called by the `reportMalicious`
    /// function when the validator reports a misbehavior.
    /// @param _reportingMiningAddress The mining address of reporting validator.
    function _incrementReportingCounter(address _reportingMiningAddress) internal {
        if (!isReportValidatorValid(_reportingMiningAddress)) return;
        uint256 currentStakingEpoch = IStaking(stakingContract()).stakingEpoch();
        uintStorage[keccak256(abi.encode(REPORTING_COUNTER, _reportingMiningAddress, currentStakingEpoch))]++;
        uintStorage[keccak256(abi.encode(REPORTING_COUNTER_TOTAL, currentStakingEpoch))]++;
    }

    /// @dev Removes the specified validator as malicious from the pending validator set and enqueues the updated
    /// pending validator set to be dequeued by the `emitInitiateChange` function. Does nothing if the specified
    /// validator is already banned, non-removable, or does not exist in the pending validator set.
    /// @param _miningAddress The mining address of the malicious validator.
    function _removeMaliciousValidatorAuRa(address _miningAddress) internal {
        if (isValidatorBanned(_miningAddress)) {
            // The malicious validator is already banned
            return;
        }

        if (_removeMaliciousValidator(_miningAddress)) {
            // From this moment `getPendingValidators()` will return the new validator set
            _incrementChangeRequestCount();
            _enqueuePendingValidators(false);
            _clearReportingCounter(_miningAddress);
        }
    }
}
