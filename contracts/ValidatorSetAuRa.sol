pragma solidity 0.4.25;

import "./abstracts/ValidatorSetBase.sol";


contract ValidatorSetAuRa is ValidatorSetBase {

    // TODO: add a description for each function

    // ============================================== Constants =======================================================

    uint256 public constant STAKING_EPOCH_DURATION = 120960; // 1 week in blocks (5 seconds per block)
    uint256 public constant STAKE_WITHDRAW_DISALLOW_PERIOD = 4320; // 6 hours in blocks (staking epoch last blocks)

    // =============================================== Setters ========================================================

    function addPool() public payable {
        stake(msg.sender);
    }

    /// Creates an initial set of validators at the start of the network.
    /// Must be called by the constructor of `Initializer` contract on genesis block.
    /// This is used instead of `constructor()` because this contract is upgradable.
    function initialize(
        address _blockRewardContract,
        address _randomContract,
        address[] _initialValidators,
        uint256 _stakerMinStake,
        uint256 _validatorMinStake
    ) external {
        super._initialize(
            _blockRewardContract,
            _randomContract,
            _initialValidators,
            _stakerMinStake,
            _validatorMinStake
        );
        _setStakingEpochStartBlock(block.number);
    }

    function newValidatorSet() public onlySystem {
        require(newValidatorSetCallable());
        super._newValidatorSet();
        _setStakingEpochStartBlock(block.number);
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
        if (reportCount.mul(2) > getValidators().length) {
            if (_removeMaliciousValidator(maliciousValidator)) {
                // From this moment `getPendingValidators()` will return the new validator set
                _incrementChangeRequestCount();
            }
        }
    }

    // =============================================== Getters ========================================================

    function maliceReportedForBlock(address _validator, uint256 _blockNumber) public view returns(address[]) {
        return addressArrayStorage[keccak256(abi.encode(MALICE_REPORTED_FOR_BLOCK, _validator, _blockNumber))];
    }

    function newValidatorSetCallable() public view returns(bool) {
        return block.number.sub(stakingEpochStartBlock()) > STAKING_EPOCH_DURATION;
    }

    function stakingEpochStartBlock() public view returns(uint256) {
        return uintStorage[STAKING_EPOCH_START_BLOCK];
    }

    // =============================================== Private ========================================================

    bytes32 internal constant STAKING_EPOCH_START_BLOCK = keccak256("stakingEpochStartBlock");
    bytes32 internal constant MALICE_REPORTED_FOR_BLOCK = "maliceReportedForBlock";

    function _setStakingEpochStartBlock(uint256 _blockNumber) internal {
        uintStorage[STAKING_EPOCH_START_BLOCK] = _blockNumber;
    }

    function _areStakeAndWithdrawAllowed() internal view returns(bool) {
        uint256 allowedDuration = STAKING_EPOCH_DURATION - STAKE_WITHDRAW_DISALLOW_PERIOD;
        uint256 applyBlock = validatorSetApplyBlock();
        bool afterValidatorSetApplied = applyBlock != 0 && block.number > applyBlock;
        return afterValidatorSetApplied && block.number.sub(stakingEpochStartBlock()) <= allowedDuration;
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
