pragma solidity 0.5.2;

import "./abstracts/ValidatorSetBase.sol";
import "./interfaces/IValidatorSetAuRa.sol";
import "./interfaces/IStakingAuRa.sol";


contract ValidatorSetAuRa is IValidatorSetAuRa, ValidatorSetBase {

    // TODO: add a description for each function

    // ================================================ Events ========================================================

    event ReportedMalicious(address reportingValidator, address maliciousValidator, uint256 blockNumber);

    // ============================================== Modifiers =======================================================

    modifier onlyBlockRewardContract() {
        require(msg.sender == blockRewardContract());
        _;
    }

    modifier onlyRandomContract() {
        require(msg.sender == randomContract());
        _;
    }

    // =============================================== Setters ========================================================

    function enqueuePendingValidators() external onlyBlockRewardContract {
        _incrementChangeRequestCount();
        _enqueuePendingValidators(true);
    }

    function newValidatorSet() external onlyBlockRewardContract returns(bool) {
        uint256 currentBlock = _getCurrentBlockNumber();
        IStakingAuRa stakingContract = IStakingAuRa(stakingContract());
        if (currentBlock != stakingContract.stakingEpochEndBlock()) return false;
        super._newValidatorSet();
        stakingContract.setStakingEpochStartBlock(currentBlock + 1);
        return true;
    }

    function removeMaliciousValidator(address _miningAddress) external onlyRandomContract {
        _removeMaliciousValidatorAuRa(_miningAddress);
    }

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
                // treat them as malicious as well
                _removeMaliciousValidatorAuRa(reportingMiningAddress);
            }
            return;
        }

        address[] storage reportedValidators = addressArrayStorage[keccak256(abi.encode(
            MALICE_REPORTED_FOR_BLOCK, _maliciousMiningAddress, _blockNumber
        ))];

        reportedValidators.push(reportingMiningAddress);

        emit ReportedMalicious(reportingMiningAddress, _maliciousMiningAddress, _blockNumber);

        // If more than 50% of validators reported about malicious validator
        // for the same `blockNumber`
        if (reportedValidators.length.mul(2) > getValidators().length) {
            _removeMaliciousValidatorAuRa(_maliciousMiningAddress);
        }
    }

    // =============================================== Getters ========================================================

    function maliceReportedForBlock(
        address _maliciousMiningAddress,
        uint256 _blockNumber
    ) public view returns(address[] memory) {
        return addressArrayStorage[keccak256(abi.encode(
            MALICE_REPORTED_FOR_BLOCK, _maliciousMiningAddress, _blockNumber
        ))];
    }

    function reportingCounter(address _reportingMiningAddress, uint256 _stakingEpoch) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(REPORTING_COUNTER, _reportingMiningAddress, _stakingEpoch))];
    }

    function reportingCounterTotal(uint256 _stakingEpoch) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(REPORTING_COUNTER_TOTAL, _stakingEpoch))];
    }

    function reportMaliciousCallable(
        address _reportingMiningAddress,
        address _maliciousMiningAddress,
        uint256 _blockNumber
    ) public view returns(bool, bool) {
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

        // Don't allow reporting validator to report about malicious validator more than once
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

    function _banStart() internal view returns(uint256) {
        return _getCurrentBlockNumber();
    }

    function _banUntil() internal view returns(uint256) {
        return _banStart() + 1555200; // 90 days (for 5 seconds block)
    }

    function _clearReportingCounter(address _reportingMiningAddress) internal {
        uint256 currentStakingEpoch = IStaking(stakingContract()).stakingEpoch();
        uint256 total = reportingCounterTotal(currentStakingEpoch);
        uint256 counter = reportingCounter(_reportingMiningAddress, currentStakingEpoch);

        uintStorage[keccak256(abi.encode(REPORTING_COUNTER, _reportingMiningAddress, currentStakingEpoch))] = 0;

        if (total >= counter) {
            uintStorage[keccak256(abi.encode(REPORTING_COUNTER_TOTAL, currentStakingEpoch))] -= counter;
        } else {
            uintStorage[keccak256(abi.encode(REPORTING_COUNTER_TOTAL, currentStakingEpoch))] = 0;
        }
    }

    function _incrementReportingCounter(address _reportingMiningAddress) internal {
        if (!isReportValidatorValid(_reportingMiningAddress)) return;
        uint256 currentStakingEpoch = IStaking(stakingContract()).stakingEpoch();
        uintStorage[keccak256(abi.encode(REPORTING_COUNTER, _reportingMiningAddress, currentStakingEpoch))]++;
        uintStorage[keccak256(abi.encode(REPORTING_COUNTER_TOTAL, currentStakingEpoch))]++;
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
            _clearReportingCounter(_miningAddress);
        }
    }
}
