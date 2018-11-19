pragma solidity ^0.4.25;

import "./libs/SafeMath.sol";


contract KeyGenHistory {
    using SafeMath for uint256;

    modifier onlyNewValidator() {
        // ... check if msg.sender is a validator from a new validator set ...
        _;
    }

    mapping(uint256 => mapping(bytes32 => bytes32[])) public messages;
    mapping(uint256 => mapping(address => bytes32) public validatorPart;

    function writePart(bytes _part) public onlyNewValidator {
        bytes32 hashOfPart = keccak256(_part);
        uint256 stakingEpoch = _getStakingEpoch();

        require(validatorPart[stakingEpoch][msg.sender] == bytes32(0));

        validatorPart[stakingEpoch][msg.sender] = hashOfPart;
    }

    function bindAckToPart(bytes _ack) public onlyNewValidator {
        uint256 stakingEpoch = _getStakingEpoch();
        bytes32 hashOfPart = validatorPart[stakingEpoch][msg.sender];
        bytes32 hashOfAck = keccak256(_ack);

        require(hashOfPart != bytes32(0));

        uint256 boundAcks = messages[stakingEpoch][hashOfPart].length;

        for (uint256 i = 0; i < boundAcks; i++) {
            if (messages[stakingEpoch][hashOfPart][i] == hashOfAck) {
                return;
            }
        }

        messages[stakingEpoch][hashOfPart].push(hashOfAck);
    }

    function isKeyGenComplete() public returns(bool) {
        address[] newValidators = _getNewValidatorSet();
        uint256 newValidatorsLength = newValidators.length;
        
        uint256 stakingEpoch = _getStakingEpoch();
        uint256 partsReceivedEnoughAcks = 0;

        for (uint256 i = 0; i < newValidatorsLength; i++) {
            address newValidator = newValidators[i];
            bytes32 hashOfPart = validatorPart[stakingEpoch][newValidator];
            uint256 acksReceived = messages[stakingEpoch][hashOfPart].length;
            
            if (acksReceived > newValidatorsLength / 3) {
                partsReceivedEnoughAcks++;
            }
        }

        return partsReceivedEnoughAcks > newValidatorsLength * 2 / 3;
    }

    function _getStakingEpoch() internal view returns(uint256) {
        // ... read the current number of staking epoch from ValidatorSet contract ...
        return 0;
    }

    function _getNewValidatorSet() internal view returns(address[]) {
        // ... read new validator set from ValidatorSet contract ...
    }
}
