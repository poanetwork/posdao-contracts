pragma solidity 0.4.25;

import "./interfaces/IReportingValidatorSet.sol";
import "./eternal-storage/EternalStorage.sol";
import "./libs/SafeMath.sol";


contract KeyGenHistory is EternalStorage {
    using SafeMath for uint256;

    bytes32 internal constant OWNER = keccak256("owner");
    bytes32 internal constant VALIDATOR_SET = keccak256("validatorSet");

    bytes32 internal constant PART_ACKS = "partAcks";
    bytes32 internal constant PART_ACK_EXISTS = "partAckExists";
    bytes32 internal constant VALIDATOR_PART = "validatorPart";

    // ================================================ Events ========================================================

    event PartWritten(
        address indexed validator,
        bytes part,
        uint256 indexed stakingEpoch,
        uint256 indexed changeRequestCount
    );

    event AckWritten(
        address indexed validator,
        bytes32 indexed hashOfPart,
        bytes ack,
        uint256 stakingEpoch,
        uint256 indexed changeRequestCount
    );

    // ============================================== Modifiers =======================================================

    modifier onlyOwner() {
        require(msg.sender == addressStorage[OWNER]);
        _;
    }

    modifier onlyValidator() {
        require(validatorSet().isValidator(msg.sender));
        _;
    }

    // =============================================== Setters ========================================================

    function setValidatorSetContract(IReportingValidatorSet _validatorSet) public onlyOwner {
        require(validatorSet() == address(0));
        require(_validatorSet != address(0));
        addressStorage[VALIDATOR_SET] = _validatorSet;
    }

    function writePart(bytes _part) public onlyValidator {
        IReportingValidatorSet validatorSetContract = validatorSet();

        bytes32 hashOfPart = keccak256(_part);
        uint256 stakingEpoch = validatorSetContract.stakingEpoch();
        uint256 changeRequestCount = validatorSetContract.changeRequestCount();

        require(validatorPart(changeRequestCount, msg.sender) == bytes32(0));

        _setValidatorPart(changeRequestCount, msg.sender, hashOfPart);

        emit PartWritten(msg.sender, _part, stakingEpoch, changeRequestCount);
    }

    function writeAck(bytes _ack) public onlyValidator {
        IReportingValidatorSet validatorSetContract = validatorSet();

        uint256 stakingEpoch = validatorSetContract.stakingEpoch();
        uint256 changeRequestCount = validatorSetContract.changeRequestCount();
        
        bytes32 hashOfPart = validatorPart(changeRequestCount, msg.sender);
        bytes32 hashOfAck = keccak256(_ack);

        require(hashOfPart != bytes32(0));
        require(!partAckExists(changeRequestCount, hashOfPart, hashOfAck));

        _pushPartAck(changeRequestCount, hashOfPart, hashOfAck);
        _setPartAckExists(changeRequestCount, hashOfPart, hashOfAck);

        emit AckWritten(msg.sender, hashOfPart, _ack, stakingEpoch, changeRequestCount);
    }

    // =============================================== Getters ========================================================

    function isKeyGenComplete() public view returns(bool) {
        IReportingValidatorSet validatorSetContract = validatorSet();

        address[] memory validators = validatorSetContract.getValidators();
        uint256 validatorsLength = validators.length;
        
        uint256 changeRequestCount = validatorSetContract.changeRequestCount();
        uint256 partsReceivedEnoughAcks = 0;

        for (uint256 i = 0; i < validatorsLength; i++) {
            address validator = validators[i];
            bytes32 hashOfPart = validatorPart(changeRequestCount, validator);
            uint256 acksReceived = partAcks(changeRequestCount, hashOfPart).length;
            
            if (acksReceived.mul(3) >= validatorsLength) {
                partsReceivedEnoughAcks++;
            }
        }

        return partsReceivedEnoughAcks.mul(3) > validatorsLength.mul(2);
    }

    function partAcks(uint256 _changeRequestCount, bytes32 _hashOfPart) public view returns(bytes32[]) {
        return bytes32ArrayStorage[
            keccak256(abi.encode(PART_ACKS, _changeRequestCount, _hashOfPart))
        ];
    }

    function partAckExists(uint256 _changeRequestCount, bytes32 _hashOfPart, bytes32 _hashOfAck)
        public
        view
        returns(bool)
    {
        return boolStorage[
            keccak256(abi.encode(PART_ACK_EXISTS, _changeRequestCount, _hashOfPart, _hashOfAck))
        ];
    }

    function validatorPart(uint256 _changeRequestCount, address _validator) public view returns(bytes32) {
        return bytes32Storage[
            keccak256(abi.encode(VALIDATOR_PART, _changeRequestCount, _validator))
        ];
    }

    function validatorSet() public view returns(IReportingValidatorSet) {
        return IReportingValidatorSet(addressStorage[VALIDATOR_SET]);
    }

    // =============================================== Private ========================================================

    function _pushPartAck(uint256 _changeRequestCount, bytes32 _hashOfPart, bytes32 _hashOfAck) internal {
        bytes32ArrayStorage[
            keccak256(abi.encode(PART_ACKS, _changeRequestCount, _hashOfPart))
        ].push(_hashOfAck);
    }

    function _setPartAckExists(uint256 _changeRequestCount, bytes32 _hashOfPart, bytes32 _hashOfAck) internal {
        boolStorage[
            keccak256(abi.encode(PART_ACK_EXISTS, _changeRequestCount, _hashOfPart, _hashOfAck))
        ] = true;
    }

    function _setValidatorPart(uint256 _changeRequestCount, address _validator, bytes32 _hashOfPart) internal {
        bytes32Storage[
            keccak256(abi.encode(VALIDATOR_PART, _changeRequestCount, _validator))
        ] = _hashOfPart;
    }
}
