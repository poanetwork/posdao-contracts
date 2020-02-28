pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "./interfaces/IKeyGenHistory.sol";
import "./interfaces/IValidatorSetHbbft.sol";
import "./upgradeability/UpgradeabilityAdmin.sol";

contract KeyGenHistory is UpgradeabilityAdmin, IKeyGenHistory {

    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables and do not change their types!

    // the current validator addresses
    address[] public validatorSet;
    mapping(address => bytes) public parts;
    mapping(address => bytes[]) public acks;

    /// @dev The address of the `ValidatorSetHbbft` contract.
    IValidatorSetHbbft public validatorSetContract;

    event NewValidatorsSet(address[] newValidatorSet);

    /// @dev Ensures the `initialize` function was called before.
    modifier onlyInitialized {
        require(isInitialized());
        _;
    }

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

    /// @dev Clears the state (acks and parts of previous validators.
    /// @param _prevValidators The list of previous validators.
    function clearPrevKeyGenState(address[] calldata _prevValidators) external onlyValidatorSet {

        for (uint256 i = 0; i < _prevValidators.length; i++) {
            delete parts[_prevValidators[i]];
            delete acks[_prevValidators[i]];
        }
    }

    function initialize(
        address _validatorSetContract,
        address[] memory _validators,
        bytes[] memory _parts,
        bytes[][] memory _acks
    ) public {
        require(_getCurrentBlockNumber() == 0 || msg.sender == _admin());
        require(!isInitialized()); // initialization can only be done once
        require(_validators.length != 0, "Validators must be more than 0.");
        require(_validators.length == _parts.length, "Wrong number of Parts!");
        require(_validators.length == _acks.length, "Wrong number of Acks!");
        require(_validatorSetContract != address(0), "Validator contract address cannot be 0.");

        validatorSetContract = IValidatorSetHbbft(_validatorSetContract);
        validatorSet = _validators;

        for (uint256 i = 0; i < _validators.length; i++) {
            parts[_validators[i]] = _parts[i];
            acks[_validators[i]] = _acks[i];
        }
    }

    function writePart(bytes calldata _part) external {
        // It can only be called by a new validator which is elected but not yet finalized...
        // ...or by a validator which is already in the validator set.
        require(validatorSetContract.isPendingValidator(msg.sender), "Sender is not a pending validator");
        require(parts[msg.sender].length == 0, "Parts already submitted!");
        parts[msg.sender] = _part;
    }

    function writeAck(bytes calldata _ack) external {
        // It can only be called by a new validator which is elected but not yet finalized...
        // ...or by a validator which is already in the validator set.
        require(validatorSetContract.isPendingValidator(msg.sender), "Sender is not a pending validator");
        require(acks[msg.sender].length == 0, "Acks already submitted");
        acks[msg.sender].push(_ack);
    }

    function getAcksLength(address val) public view returns(uint256) {
        return acks[val].length;
    }

    /// @dev Returns the current block number. Needed mostly for unit tests.
    function _getCurrentBlockNumber() internal view returns(uint256) {
        return block.number;
    }

    /// @dev Returns a boolean flag indicating if the `initialize` function has been called.
    function isInitialized() public view returns(bool) {
        return validatorSetContract != IValidatorSetHbbft(0);
    }
}
