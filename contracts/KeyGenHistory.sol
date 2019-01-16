pragma solidity 0.5.2;

import "./interfaces/IValidatorSet.sol";
import "./eternal-storage/OwnedEternalStorage.sol";
import "./libs/SafeMath.sol";


contract KeyGenHistory is OwnedEternalStorage {
    using SafeMath for uint256;

    // ================================================ Events ========================================================

    event PartWritten(
        address indexed validator,
        bytes part,
        uint256 indexed stakingEpoch,
        uint256 indexed changeRequestCount
    );

    event AckWritten(
        address indexed validator,
        bytes ack,
        uint256 indexed stakingEpoch,
        uint256 indexed changeRequestCount
    );

    // ============================================== Modifiers =======================================================

    modifier onlyValidator() {
        require(validatorSet().isValidator(msg.sender));
        _;
    }

    // =============================================== Setters ========================================================

    function setValidatorSetContract(IValidatorSet _validatorSet) public onlyOwner {
        require(address(validatorSet()) == address(0));
        require(address(_validatorSet) != address(0));
        addressStorage[VALIDATOR_SET] = address(_validatorSet);
    }

    // Note: since this is non-system transaction, the calling validator
    // should have enough balance to call this function.
    function writePart(bytes memory _part) public onlyValidator {
        IValidatorSet validatorSetContract = validatorSet();

        uint256 stakingEpoch = validatorSetContract.stakingEpoch();
        uint256 changeRequestCount = validatorSetContract.changeRequestCount();

        require(!validatorWrotePart(changeRequestCount, msg.sender));

        _setValidatorWrotePart(changeRequestCount, msg.sender);

        emit PartWritten(msg.sender, _part, stakingEpoch, changeRequestCount);
    }

    // Note: since this is non-system transaction, the calling validator
    // should have enough balance to call this function.
    function writeAck(bytes memory _ack) public onlyValidator {
        IValidatorSet validatorSetContract = validatorSet();

        uint256 stakingEpoch = validatorSetContract.stakingEpoch();
        uint256 changeRequestCount = validatorSetContract.changeRequestCount();

        emit AckWritten(msg.sender, _ack, stakingEpoch, changeRequestCount);
    }

    // =============================================== Getters ========================================================

    function validatorSet() public view returns(IValidatorSet) {
        return IValidatorSet(addressStorage[VALIDATOR_SET]);
    }

    function validatorWrotePart(uint256 _changeRequestCount, address _validator) public view returns(bool) {
        return boolStorage[
            keccak256(abi.encode(VALIDATOR_WROTE_PART, _changeRequestCount, _validator))
        ];
    }

    // =============================================== Private ========================================================

    bytes32 internal constant VALIDATOR_SET = keccak256("validatorSet");
    bytes32 internal constant VALIDATOR_WROTE_PART = "validatorWrotePart";

    function _setValidatorWrotePart(uint256 _changeRequestCount, address _validator) internal {
        boolStorage[
            keccak256(abi.encode(VALIDATOR_WROTE_PART, _changeRequestCount, _validator))
        ] = true;
    }
}
