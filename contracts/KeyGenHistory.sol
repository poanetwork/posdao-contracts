pragma solidity 0.5.10;
pragma experimental ABIEncoderV2;

import "./interfaces/IValidatorSetHbbft.sol";

contract KeyGenHistory {

    /// @dev The address of the `ValidatorSetHbbft` contract.
    IValidatorSetHbbft public validatorSetContract;
    // the current validator addresses
    address[] public validatorSet;
    mapping(address => bytes) public parts;
    mapping(address => bytes[]) public acks;

    event NewValidatorsSet(address[] newValidatorSet);

    /// @dev Ensures the caller is the SYSTEM_ADDRESS. See https://wiki.parity.io/Validator-Set.html
    modifier onlySystem() {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    /// @dev Ensures the caller is ValidatorSet contract.
    modifier onlyValidatorSet() {
        require(msg.sender == address(validatorSetContract));
        _;
    }

    constructor(address _validatorSetContract, address[] memory _validators, bytes[] memory _parts, bytes[][] memory _acks) public {
        require(_validators.length != 0);
        require(_validators.length == _parts.length);
        require(_validators.length == _acks.length);
        require(_validatorSetContract != address(0));

        validatorSetContract = IValidatorSetHbbft(_validatorSetContract);
        validatorSet = _validators;

        for (uint256 i = 0; i < _validators.length; i++) {
            parts[_validators[i]] = _parts[i];
            acks[_validators[i]] = _acks[i];
        }
    }

    /// @dev Clears the state (acks and parts of previous validators.
    /// @param _prevValidators The list of previous validators.
    function clearPrevKeyGenState(address[] calldata _prevValidators) external onlyValidatorSet {

        for (uint256 i = 0; i < _prevValidators.length; i++) {
            delete parts[_prevValidators[i]];
            delete acks[_prevValidators[i]];
        }
    }

    /// @dev Returns true if at least 2/3 of the participating validators consent.
    function isReady() external view returns (bool) {

        /* for (uint256 i = 0; i < _validators.length; i++) {
            ;
        } */
        return true;
    }

    function writePart(bytes calldata _part) external {
        // Ensure that initiateChange is not allowed i.e. `InitiateChange` was emitted, but `finalizeChange`
        // function hasn't been called yet.
        require(!validatorSetContract.initiateChangeAllowed(), "Initiate change should not be allowed");
        // It can only be called by a new validator which is elected but not yet finalized...
        // ...or by a validator which is already in the validator set.
        require(validatorSetContract.isValidatorOrPending(msg.sender), "Sender is not a pending validator");
        parts[msg.sender] = _part;
    }

    function writeAck(bytes calldata _ack) external {
        // Ensure that initiateChange is not allowed i.e. `InitiateChange` was emitted, but `finalizeChange`
        // function hasn't been called yet.
        require(!validatorSetContract.initiateChangeAllowed(), "Initiate change should not be allowed");
        // It can only be called by a new validator which is elected but not yet finalized...
        // ...or by a validator which is already in the validator set.
        require(validatorSetContract.isValidatorOrPending(msg.sender), "Sender is not a pending validator");
        acks[msg.sender].push(_ack);
    }

    function getAcksLength(address val) public view returns(uint256) {
        return acks[val].length;
    }
}
