pragma solidity 0.4.25;

import "./abstracts/ValidatorSetBase.sol";


contract ValidatorSetAuRa is ValidatorSetBase {

    // TODO: add a description for each function

    // ============================================== Constants =======================================================

    uint256 public constant STAKING_EPOCH_DURATION = 1 weeks;
    uint256 public constant STAKE_WITHDRAW_DISALLOW_PERIOD = 6 hours; // the last hours of staking epoch

    // =============================================== Setters ========================================================

    function addPool() public payable {
        stake(msg.sender);
    }

    /// Creates an initial set of validators at the start of the network.
    /// Must be called by the constructor of `Initializer` contract on genesis block.
    /// This is used instead of `constructor()` because this contract is upgradable.
    function initialize(address[] _initialValidators) external {
        super._initialize(_initialValidators);
        _setStakingEpochTimestamp(now);
    }

    function newValidatorSet() public onlySystem {
        super._newValidatorSet();
        _setStakingEpochTimestamp(now);
    }

    function reportMaliciousValidator(bytes _message, bytes _signature)
        public
        onlySystem
    {
        address maliciousValidator;
        uint256 blockNumber;
        assembly {
            maliciousValidator := and(mload(add(_message, 20)), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            blockNumber := mload(add(_message, 52))
        }
        address reportingValidator = _recoverAddressFromSignedMessage(_message, _signature);

        require(_isReportingValidatorValid(reportingValidator));

        bool validatorSetChanged = false;

        uint256 validatorsLength = _getValidatorsLength();

        address[] storage reportedValidators =
            addressArrayStorage[keccak256(abi.encode(MALICE_REPORTED_FOR_BLOCK, maliciousValidator, blockNumber))];

        // Don't allow reporting validator to report about malicious validator more than once
        for (uint256 m = 0; m < reportedValidators.length; m++) {
            if (reportedValidators[m] == reportingValidator) {
                return;
            }
        }

        reportedValidators.push(reportingValidator);

        if (isValidatorBanned(maliciousValidator)) {
            // The malicious validator is already banned
            return;
        }

        uint256 reportCount = reportedValidators.length;

        // If more than 50% of validators reported about malicious validator
        // for the same `blockNumber`
        if (reportCount.mul(2) > validatorsLength) {
            validatorSetChanged = _removeMaliciousValidator(maliciousValidator);
        }

        if (validatorSetChanged) {
            _incrementChangeRequestCount();
            // From this moment `getValidators()` will return the new validator set
        }
    }

    // =============================================== Getters ========================================================

    function maliceReportedForBlock(address _validator, uint256 _blockNumber) public view returns(address[]) {
        return addressArrayStorage[keccak256(abi.encode(MALICE_REPORTED_FOR_BLOCK, _validator, _blockNumber))];
    }

    // =============================================== Private ========================================================

    bytes32 internal constant STAKING_EPOCH_TIMESTAMP = keccak256("stakingEpochTimestamp");
    bytes32 internal constant MALICE_REPORTED_FOR_BLOCK = "maliceReportedForBlock";

    function _setStakingEpochTimestamp(uint256 _timestamp) internal {
        uintStorage[STAKING_EPOCH_TIMESTAMP] = _timestamp;
    }

    function _areStakeAndWithdrawAllowed() internal view returns(bool) {
        return now - uintStorage[STAKING_EPOCH_TIMESTAMP] <= STAKING_EPOCH_DURATION - STAKE_WITHDRAW_DISALLOW_PERIOD;
    }

    function _recoverAddressFromSignedMessage(bytes _message, bytes _signature)
        internal
        pure
        returns(address)
    {
        require(_signature.length == 65);
        bytes32 r;
        bytes32 s;
        bytes1 v;
        assembly {
            r := mload(add(_signature, 0x20))
            s := mload(add(_signature, 0x40))
            v := mload(add(_signature, 0x60))
        }
        bytes memory prefix = "\x19Ethereum Signed Message:\n";
        string memory msgLength = "52";
        require(_message.length == 52);
        bytes32 messageHash = keccak256(abi.encodePacked(prefix, msgLength, _message));
        return ecrecover(messageHash, uint8(v), r, s);
    }
}
