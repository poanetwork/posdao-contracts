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

    function getAcksLength(address val) public view returns(uint256) {
        return acks[val].length;
    }

    function setNewValidators(address[] calldata _newValidators) external onlyValidatorSet {
        // TODO: delete acks and parts
        validatorSet = _newValidators;
    }

    function writePart(address _validator, bytes calldata _part) external onlySystem {
        // TODO: can only be called by a new validator which is elected but not yet finalized
        // or by a validator which is already in the validator set (ValidatorSet.isPendingValidator(msg.sender)
        // must return `true`).

        // TODO: ensure that the ValidatorSet.initiateChangeAllowed() returns `false`
        // (it means that the `InitiateChange` event was emitted, but the `finalizeChange`
        // function wasn't yet called).

        parts[_validator] = _part;
    }

    function writeAck(address _validator, bytes calldata _ack) external onlySystem {
        // TODO: can only be called by a new validator which is elected but not yet finalized
        // or by a validator which is already in the validator set (ValidatorSet.isPendingValidator(msg.sender)
        // must return `true`).

        // TODO: ensure that the ValidatorSet.initiateChangeAllowed() returns `false`
        // (it means that the `InitiateChange` event was emitted, but the `finalizeChange`
        // function wasn't yet called).

        acks[_validator].push(_ack);
    }

    /// @dev Returns true if at least 2/3 of the participating validators consent.
    function isReady() external view returns (bool) {

        /* for (uint256 i = 0; i < _validators.length; i++) {
            ;
        } */
        return true;

    }
}
