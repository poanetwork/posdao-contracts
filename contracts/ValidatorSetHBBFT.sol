pragma solidity 0.5.2;
pragma experimental ABIEncoderV2;

import "./abstracts/ValidatorSetBase.sol";
import "./interfaces/IValidatorSetHBBFT.sol";


contract ValidatorSetHBBFT is IValidatorSetHBBFT, ValidatorSetBase {

    // TODO: add a description for each function

    // =============================================== Setters ========================================================

    function clearMaliceReported(address _miningAddress) external onlyStakingContract {
        delete addressArrayStorage[keccak256(abi.encode(MALICE_REPORTED, _miningAddress))];
    }

    function newValidatorSet() external onlySystem {
        super._newValidatorSet();
    }

    function reportMaliciousValidators(
        address[] calldata _miningAddresses,
        address[] calldata _reportingMiningAddresses
    ) external onlySystem {
        require(_miningAddresses.length == _reportingMiningAddresses.length);

        bool validatorSetChanged = false;

        uint256 validatorsLength = getValidators().length;

        // Handle each perpetrator-reporter pair
        for (uint256 i = 0; i < _miningAddresses.length; i++) {
            address maliciousValidator = _miningAddresses[i];
            address reportingValidator = _reportingMiningAddresses[i];

            if (!isReportValidatorValid(reportingValidator)) {
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
            // From this moment `getPendingValidators()` will return the new validator set
            _incrementChangeRequestCount();
            _enqueuePendingValidators(false);
        }
    }

    function savePublicKey(address _miningAddress, bytes calldata _key) external onlyStakingContract {
        _savePublicKey(_miningAddress, _key);
    }

    function initializePublicKeys(bytes[] memory _keys) public {
        require(_getCurrentBlockNumber() == 0); // initialization must be done on genesis block

        address[] memory miningAddresses = getValidators();

        require(_keys.length == miningAddresses.length);

        for (uint256 i = 0; i < _keys.length; i++) {
            _savePublicKey(miningAddresses[i], _keys[i]);
        }
    }

    // =============================================== Getters ========================================================

    function isValidatorBanned(address _miningAddress) public view returns(bool) {
        return now < bannedUntil(_miningAddress);
    }

    function maliceReported(address _miningAddress) public view returns(address[] memory) {
        return addressArrayStorage[keccak256(abi.encode(MALICE_REPORTED, _miningAddress))];
    }

    // Returns the serialized public key of candidate/ validator
    function publicKey(address _miningAddress) public view returns(bytes memory) {
        return bytesStorage[
            keccak256(abi.encode(PUBLIC_KEY, _miningAddress))
        ];
    }

    // =============================================== Private ========================================================

    bytes32 internal constant MALICE_REPORTED = "maliceReported";
    bytes32 internal constant PUBLIC_KEY = "publicKey";

    function _banUntil() internal view returns(uint256) {
        return now + 90 days;
    }

    function _savePublicKey(address _miningAddress, bytes memory _key) internal {
        require(_key.length == 48); // https://github.com/poanetwork/threshold_crypto/issues/63
        bytesStorage[keccak256(abi.encode(PUBLIC_KEY, _miningAddress))] = _key;
    }
}
