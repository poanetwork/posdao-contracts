pragma solidity 0.5.12;
pragma experimental ABIEncoderV2;


contract KeyGenHistory {

    mapping(address => bytes) public parts;
    mapping(address => bytes[]) public acks;
    address public owner;
    
    constructor() public {
        owner = msg.sender;
    }
    
    // This is used instead of constructor
    function initParts(address[] memory _validators, bytes[] memory _parts) public {
        require(msg.sender == owner);
        require(_validators.length == _parts.length);
        
        for (uint256 i = 0; i < _validators.length; i++) {
            parts[_validators[i]] = _parts[i];
        }
    }
    
    // This is used instead of constructor
    function initAcks(address _validator, bytes[] memory _acks) public {
        require(msg.sender == owner);
        acks[_validator] = _acks;
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

    function writeAcks(bytes[] memory _acks) public {
        // TODO: can only be called by a new validator which is elected but not yet finalized
        // or by a validator which is already in the validator set (ValidatorSet.isPendingValidator(msg.sender)
        // must return `true`).

        // TODO: ensure that the ValidatorSet.initiateChangeAllowed() returns `false`
        // (it means that the `InitiateChange` event was emitted, but the `finalizeChange`
        // function wasn't yet called).

        acks[msg.sender] = _acks;
    }

}
