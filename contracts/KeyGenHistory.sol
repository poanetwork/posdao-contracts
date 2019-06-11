pragma solidity 0.5.9;
pragma experimental ABIEncoderV2;


contract KeyGenHistory {

    mapping(address => bytes) public parts;
    mapping(address => bytes) public acks;

    constructor(address[] memory _validators, bytes[] memory _parts, bytes[] memory _acks) public {
        require(_validators.length == _parts.length);
        require(_validators.length == _acks.length);

        for (uint256 i = 0; i < _validators.length; i++) {
            parts[_validators[i]] = _parts[i];
            acks[_validators[i]] = _acks[i];
        }
    }

    function writePart(bytes memory _part) public {
        // TODO: can only be called by a new validator which is elected but not yet finalized
        // or by a validator which is already in the validator set (ValidatorSet.isPendingValidator(msg.sender)
        // must return `true`).

        // TODO: ensure that the ValidatorSet.initiateChangeAllowed() returns `false`
        // (it means that the `InitiateChange` event was emitted, but the `finalizeChange`
        // function wasn't yet called).

        parts[msg.sender] = _part;
    }

    function writeAck(bytes memory _ack) public {
        // TODO: can only be called by a new validator which is elected but not yet finalized
        // or by a validator which is already in the validator set (ValidatorSet.isPendingValidator(msg.sender)
        // must return `true`).

        // TODO: ensure that the ValidatorSet.initiateChangeAllowed() returns `false`
        // (it means that the `InitiateChange` event was emitted, but the `finalizeChange`
        // function wasn't yet called).

        acks[msg.sender] = _ack;
    }

}
