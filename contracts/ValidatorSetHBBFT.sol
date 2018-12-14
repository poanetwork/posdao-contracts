pragma solidity 0.4.25;

import "./abstracts/ValidatorSetBase.sol";


contract ValidatorSetHBBFT is ValidatorSetBase {

    // TODO: add a description for each function

    // =============================================== Setters ========================================================

    function addPool(bytes _publicKey) public payable {
        stake(msg.sender);
        savePublicKey(_publicKey);
    }

    /// Creates an initial set of validators at the start of the network.
    /// Must be called by the constructor of `Initializer` contract on genesis block.
    /// This is used instead of `constructor()` because this contract is upgradable.
    function initialize(address[] _initialValidators) external {
        super._initialize(_initialValidators);
    }

    function newValidatorSet() public onlySystem {
        super._newValidatorSet();
    }

    function reportMaliciousValidators(address[] _validators, address[] _reportingValidators)
        public
        onlySystem
    {
        require(_validators.length == _reportingValidators.length);

        bool validatorSetChanged = false;

        uint256 validatorsLength = _getValidatorsLength();

        // Handle each perpetrator-reporter pair
        for (uint256 i = 0; i < _validators.length; i++) {
            address maliciousValidator = _validators[i];
            address reportingValidator = _reportingValidators[i];

            if (!_isReportingValidatorValid(reportingValidator)) {
                continue;
            }

            bool alreadyReported = false;

            address[] storage reportedValidators =
                addressArrayStorage[keccak256(abi.encode(MALICE_REPORTED, maliciousValidator))];

            // Don't allow `reportingValidator` to report about `maliciousValidator` more than once
            for (uint256 m = 0; m < reportedValidators.length; m++) {
                if (reportedValidators[m] == reportingValidator) {
                    alreadyReported = true;
                    break;
                }
            }

            if (alreadyReported) {
                continue;
            } else {
                reportedValidators.push(reportingValidator);
            }

            if (isValidatorBanned(maliciousValidator)) {
                // The `maliciousValidator` is already banned
                continue;
            }

            uint256 reportCount = reportedValidators.length;

            // If at least 1/3 of validators reported about `maliciousValidator`
            if (reportCount.mul(3) >= validatorsLength) {
                if (_removeMaliciousValidator(maliciousValidator)) {
                    validatorSetChanged = true;
                }
            }
        }

        if (validatorSetChanged) {
            _incrementChangeRequestCount();
            // From this moment `getValidators()` will return the new validator set
        }
    }

    function savePublicKey(bytes _key) public {
        require(_key.length == 48); // https://github.com/poanetwork/threshold_crypto/issues/63
        require(stakeAmount(msg.sender, msg.sender) != 0);
        bytesStorage[keccak256(abi.encode(PUBLIC_KEY, msg.sender))] = _key;

        if (!isValidatorBanned(msg.sender)) {
            _addToPools(msg.sender);
        }
    }

    // =============================================== Getters ========================================================

    function maliceReported(address _validator) public view returns(address[]) {
        return addressArrayStorage[keccak256(abi.encode(MALICE_REPORTED, _validator))];
    }

    // Returns the serialized public key of observer/ validator
    function publicKey(address _who) public view returns(bytes) {
        return bytesStorage[
            keccak256(abi.encode(PUBLIC_KEY, _who))
        ];
    }

    // =============================================== Private ========================================================

    bytes32 internal constant MALICE_REPORTED = "maliceReported";
    bytes32 internal constant PUBLIC_KEY = "publicKey";

    // Adds `_who` to the array of pools
    function _addToPools(address _who) internal {
        if (publicKey(_who).length == 0) {
            return;
        }
        super._addToPools(_who);
        delete addressArrayStorage[keccak256(abi.encode(MALICE_REPORTED, _who))];
    }

    function _areStakeAndWithdrawAllowed() internal view returns(bool) {
        return true;
    }
}
