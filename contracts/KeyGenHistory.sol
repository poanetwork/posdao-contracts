pragma solidity 0.4.25;

import "./interfaces/IReportingValidatorSet.sol";
import "./libs/SafeMath.sol";


contract KeyGenHistory {
    using SafeMath for uint256;

    event PartWritten(
        address indexed validator,
        bytes part,
        uint256 indexed stakingEpoch
    );

    event AckWritten(
        address indexed validator,
        bytes32 indexed hashOfPart,
        bytes ack,
        uint256 indexed stakingEpoch
    );

    modifier onlyValidator() {
        require(validatorSet.isValidator(msg.sender));
        _;
    }

    mapping(uint256 => mapping(bytes32 => bytes32[])) public partAcks;
    mapping(uint256 => mapping(bytes32 => mapping(bytes32 => bool))) public partAckExists;
    mapping(uint256 => mapping(address => bytes32)) public validatorPart;
    IReportingValidatorSet public validatorSet;

    constructor(IReportingValidatorSet _validatorSet) public {
        validatorSet = _validatorSet;
    }

    function writePart(bytes _part) public onlyValidator {
        bytes32 hashOfPart = keccak256(_part);
        uint256 stakingEpoch = validatorSet.stakingEpoch();

        require(validatorPart[stakingEpoch][msg.sender] == bytes32(0));

        validatorPart[stakingEpoch][msg.sender] = hashOfPart;

        emit PartWritten(msg.sender, _part, stakingEpoch);
    }

    function writeAck(bytes _ack) public onlyValidator {
        uint256 stakingEpoch = validatorSet.stakingEpoch();
        bytes32 hashOfPart = validatorPart[stakingEpoch][msg.sender];
        bytes32 hashOfAck = keccak256(_ack);

        require(hashOfPart != bytes32(0));
        require(!partAckExists[stakingEpoch][hashOfPart][hashOfAck]);

        partAcks[stakingEpoch][hashOfPart].push(hashOfAck);
        partAckExists[stakingEpoch][hashOfPart][hashOfAck] = true;

        emit AckWritten(msg.sender, hashOfPart, _ack, stakingEpoch);
    }

    function isKeyGenComplete() public view returns(bool) {
        address[] memory validators = validatorSet.getValidators();
        uint256 validatorsLength = validators.length;
        
        uint256 stakingEpoch = validatorSet.stakingEpoch();
        uint256 partsReceivedEnoughAcks = 0;

        for (uint256 i = 0; i < validatorsLength; i++) {
            address validator = validators[i];
            bytes32 hashOfPart = validatorPart[stakingEpoch][validator];
            uint256 acksReceived = partAcks[stakingEpoch][hashOfPart].length;
            
            if (acksReceived.mul(3) >= validatorsLength) {
                partsReceivedEnoughAcks++;
            }
        }

        return partsReceivedEnoughAcks.mul(3) > validatorsLength.mul(2);
    }
}
