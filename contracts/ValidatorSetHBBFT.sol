pragma solidity 0.5.2;

import "./abstracts/ValidatorSetBase.sol";


contract ValidatorSetHBBFT is ValidatorSetBase {

    // TODO: add a description for each function

    // =============================================== Setters ========================================================

    function addPool(bytes calldata _publicKey, uint256 _amount, address _miningAddress) external {
        address stakingAddress = msg.sender;
        _setStakingAddress(_miningAddress, stakingAddress);
        stake(stakingAddress, _amount);
        savePublicKey(_publicKey);
    }

    /// Creates an initial set of validators at the start of the network.
    /// Must be called by the constructor of `InitializerHBBFT` contract on genesis block.
    /// This is used instead of `constructor()` because this contract is upgradable.
    function initialize(
        address _blockRewardContract,
        address _randomContract,
        address _erc20TokenContract,
        address[] calldata _initialMiningAddresses,
        address[] calldata _initialStakingAddresses,
        uint256 _delegatorMinStake,
        uint256 _candidateMinStake
    ) external {
        super._initialize(
            _blockRewardContract,
            _randomContract,
            _erc20TokenContract,
            _initialMiningAddresses,
            _initialStakingAddresses,
            _delegatorMinStake,
            _candidateMinStake
        );
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

    function savePublicKey(bytes memory _key) public {
        address stakingAddress = msg.sender;
        require(_key.length == 48); // https://github.com/poanetwork/threshold_crypto/issues/63
        require(stakeAmount(stakingAddress, stakingAddress) != 0);
        address miningAddress = miningByStakingAddress(stakingAddress);
        bytesStorage[keccak256(abi.encode(PUBLIC_KEY, miningAddress))] = _key;

        if (!isValidatorBanned(miningAddress)) {
            _addToPools(stakingAddress);
        }
    }

    // =============================================== Getters ========================================================

    function areStakeAndWithdrawAllowed() public view returns(bool) {
        uint256 applyBlock = validatorSetApplyBlock();
        return applyBlock != 0 && _getCurrentBlockNumber() > applyBlock;
    }

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

    // Adds `_stakingAddress` to the array of pools
    function _addToPools(address _stakingAddress) internal {
        address miningAddress = miningByStakingAddress(_stakingAddress);
        if (publicKey(miningAddress).length == 0) {
            return;
        }
        super._addToPools(_stakingAddress);
        delete addressArrayStorage[keccak256(abi.encode(MALICE_REPORTED, miningAddress))];
    }

    function _banUntil() internal view returns(uint256) {
        return now + 90 days;
    }
}
