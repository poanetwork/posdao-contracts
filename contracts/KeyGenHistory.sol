pragma solidity 0.5.10;
pragma experimental ABIEncoderV2;


contract KeyGenHistory {

    mapping(address => bytes) public parts;
    mapping(address => bytes[]) public acks;

    /// @dev Ensures the caller is the SYSTEM_ADDRESS. See https://wiki.parity.io/Validator-Set.html
    modifier onlySystem() {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    constructor(address[] memory _validators, bytes[] memory _parts, bytes[][] memory _acks) public {
        require(_validators.length == _parts.length);
        require(_validators.length == _acks.length);

        for (uint256 i = 0; i < _validators.length; i++) {
            parts[_validators[i]] = _parts[i];
            acks[_validators[i]] = _acks[i];
        }
    }

    function getAcksLength(address val) public view returns(uint256) {
        return acks[val].length;
    }

    function writePart(bytes memory _part) public onlySystem {
        // TODO: can only be called by a new validator which is elected but not yet finalized
        // or by a validator which is already in the validator set (ValidatorSet.isPendingValidator(msg.sender)
        // must return `true`).

        // TODO: ensure that the ValidatorSet.initiateChangeAllowed() returns `false`
        // (it means that the `InitiateChange` event was emitted, but the `finalizeChange`
        // function wasn't yet called).

        parts[msg.sender] = _part;
    }

    function writeAck(bytes memory _ack) public onlySystem {
        // TODO: can only be called by a new validator which is elected but not yet finalized
        // or by a validator which is already in the validator set (ValidatorSet.isPendingValidator(msg.sender)
        // must return `true`).

        // TODO: ensure that the ValidatorSet.initiateChangeAllowed() returns `false`
        // (it means that the `InitiateChange` event was emitted, but the `finalizeChange`
        // function wasn't yet called).

        acks[msg.sender].push(_ack);
    }

}
