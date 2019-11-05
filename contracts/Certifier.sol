pragma solidity 0.5.10;

import "./interfaces/ICertifier.sol";
import "./interfaces/IValidatorSetAuRa.sol";
import "./upgradeability/UpgradeableOwned.sol";


/// @dev Allows validators to use a zero gas price for their service transactions
/// (see https://wiki.parity.io/Permissioning.html#gas-price for more info).
contract Certifier is UpgradeableOwned, ICertifier {

    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables and do not change their types!

    mapping(address => bool) internal _certified;

    /// @dev The address of the `ValidatorSetAuRa` contract.
    IValidatorSetAuRa public validatorSetContract;

    // ================================================ Events ========================================================

    /// @dev Emitted by the `certify` function when the specified address is allowed to use a zero gas price
    /// for its transactions.
    /// @param who Specified address allowed to make zero gas price transactions.
    event Confirmed(address indexed who);

    /// @dev Emitted by the `revoke` function when the specified address is denied using a zero gas price
    /// for its transactions.
    /// @param who Specified address for which zero gas price transactions are denied.
    event Revoked(address indexed who);

    // ============================================== Modifiers =======================================================

    /// @dev Ensures the `initialize` function was called before.
    modifier onlyInitialized {
        require(isInitialized());
        _;
    }

    // =============================================== Setters ========================================================

    /// @dev Initializes the contract at network startup.
    /// Can only be called by the constructor of the `InitializerAuRa` contract or owner.
    /// @param _certifiedAddresses The addresses for which a zero gas price must be allowed.
    /// @param _validatorSet The address of the `ValidatorSetAuRa` contract.
    function initialize(
        address[] calldata _certifiedAddresses,
        address _validatorSet
    ) external {
        require(block.number == 0 || msg.sender == _admin());
        require(!isInitialized());
        require(_validatorSet != address(0));
        for (uint256 i = 0; i < _certifiedAddresses.length; i++) {
            _certify(_certifiedAddresses[i]);
        }
        validatorSetContract = IValidatorSetAuRa(_validatorSet);
    }

    /// @dev Allows the specified address to use a zero gas price for its transactions.
    /// Can only be called by the `owner`.
    /// @param _who The address for which zero gas price transactions must be allowed.
    function certify(address _who) external onlyOwner onlyInitialized {
        _certify(_who);
        emit Confirmed(_who);
    }

    /// @dev Denies the specified address usage of a zero gas price for its transactions.
    /// Can only be called by the `owner`.
    /// @param _who The address for which transactions with a zero gas price must be denied.
    function revoke(address _who) external onlyOwner onlyInitialized {
        _certified[_who] = false;
        emit Revoked(_who);
    }

    // =============================================== Getters ========================================================

    /// @dev Returns a boolean flag indicating whether the specified address is allowed to use zero gas price
    /// transactions. Returns `true` if either the address is certified using the `_certify` function or if 
    /// `ValidatorSetAuRa.isReportValidatorValid` returns `true` for the specified address.
    /// @param _who The address for which the boolean flag must be determined.
    function certified(address _who) external view returns(bool) {
        if (_certified[_who]) {
            return true;
        }
        return validatorSetContract.isReportValidatorValid(_who);
    }

    /// @dev Returns a boolean flag indicating if the `initialize` function has been called.
    function isInitialized() public view returns(bool) {
        return validatorSetContract != IValidatorSetAuRa(0);
    }

    // ============================================== Internal ========================================================

    /// @dev An internal function for the `certify` and `initialize` functions.
    /// @param _who The address for which transactions with a zero gas price must be allowed.
    function _certify(address _who) internal {
        require(_who != address(0));
        _certified[_who] = true;
    }
}
