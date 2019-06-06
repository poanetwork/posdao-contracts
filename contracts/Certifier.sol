pragma solidity 0.5.7;

import "./interfaces/ICertifier.sol";
import "./interfaces/IValidatorSet.sol";
import "./eternal-storage/OwnedEternalStorage.sol";


/// @dev Allows validators to use a zero gas price for their service transactions
/// (see https://wiki.parity.io/Permissioning.html#gas-price for more info).
contract Certifier is OwnedEternalStorage, ICertifier {

    // ================================================ Events ========================================================

    /// @dev Emitted by the `certify` function when the specified address is allowed to use a zero gas price
    /// for its transactions.
    /// @param who Specified address allowed to make zero gas price transactions.
    event Confirmed(address indexed who);

    /// @dev Emitted by the `revoke` function when the specified address is denied using a zero gas price
    /// for its transactions.
    /// @param who Specified address for which zero gas price transactions are denied.
    event Revoked(address indexed who);

    // =============================================== Setters ========================================================

    /// @dev Initializes the contract at network startup.
    /// Must be called by the constructor of the `Initializer` contract.
    /// @param _certifiedAddress The address for which a zero gas price must be allowed.
    /// @param _validatorSet The address of the `ValidatorSet` contract.
    function initialize(
        address _certifiedAddress,
        address _validatorSet
    ) external {
        require(_validatorSet != address(0));
        require(addressStorage[VALIDATOR_SET_CONTRACT] == address(0));
        _certify(_certifiedAddress);
        addressStorage[VALIDATOR_SET_CONTRACT] = _validatorSet;
    }

    /// @dev Allows the specified address to use a zero gas price for its transactions.
    /// Can only be called by the `owner`.
    /// @param _who The address for which zero gas price transactions must be allowed.
    function certify(address _who) external onlyOwner {
        _certify(_who);
        emit Confirmed(_who);
    }

    /// @dev Denies the specified address usage of a zero gas price for its transactions.
    /// Can only be called by the `owner`.
    /// @param _who The address for which transactions with a zero gas price must be denied.
    function revoke(address _who) external onlyOwner {
        boolStorage[keccak256(abi.encode(CERTIFIED, _who))] = false;
        emit Revoked(_who);
    }

    // =============================================== Getters ========================================================

    /// @dev Returns a boolean flag indicating whether the specified address is allowed to use zero gas price
    /// transactions. Returns `true` if either the address is certified using the `_certify` function or if 
    /// `ValidatorSet.isReportValidatorValid` returns `true` for the specified address.
    /// @param _who The address for which the boolean flag must be determined.
    function certified(address _who) external view returns(bool) {
        if (boolStorage[keccak256(abi.encode(CERTIFIED, _who))]) {
            return true;
        }
        return validatorSetContract().isReportValidatorValid(_who);
    }

    /// @dev Returns the address of the `ValidatorSet` contract.
    function validatorSetContract() public view returns(IValidatorSet) {
        return IValidatorSet(addressStorage[VALIDATOR_SET_CONTRACT]);
    }

    // =============================================== Private ========================================================

    bytes32 internal constant CERTIFIED = "certified";
    bytes32 internal constant VALIDATOR_SET_CONTRACT = keccak256("validatorSetContract");

    /// @dev An internal function for the `certify` and `initialize` functions.
    /// @param _who The address for which transactions with a zero gas price must be allowed.
    function _certify(address _who) internal {
        require(_who != address(0));
        boolStorage[keccak256(abi.encode(CERTIFIED, _who))] = true;
    }
}
