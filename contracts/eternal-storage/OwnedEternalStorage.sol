pragma solidity 0.5.2;

import "./EternalStorage.sol";
import "../interfaces/IValidatorSet.sol";


/// @title Owned Eternal Storage
/// @notice This contract provides ownership and access control functionality.
/// Using the `onlyOwner` modifier, a function can be restricted to being
/// called by the owner of the contract.  The owner of a contract can
/// irrevocably transfer ownership using the `transferOwnership` function.
contract OwnedEternalStorage is EternalStorage {

    // ============================================== Constants =======================================================

    /// @notice The address of the validator set contract.  The block reward contract calls the validator set contract
    /// to retrieve the current staking epoch and to get and set staking amounts.  It also needs to know this value for
    /// access control, as some of its methods can only be called by the validator set contract.
    ///
    /// This address must be set before deploy, and is also hard-coded into `scripts/make_spec.js`, which creates the
    /// chain spec.  The values in both places must be kept in sync, or the network will not work properly.
    ///
    /// @dev This _must_ be `internal`, not `public`, to avoid a (false) report of clashing from
    /// `/scripts/check_for_clashing.js`.  Since both the method that would be proxied to and the method that is
    /// called instead have no side effects, and return the same value, such clashing would be harmless, but it is
    /// better to mark this as `internal` than to change `/scripts/check_for_clashing.js` to ignore this special case.
    IValidatorSet internal constant VALIDATOR_SET_CONTRACT = IValidatorSet(0x1000000000000000000000000000000000000001);

    /// @notice Access check: revert unless `msg.sender` is the owner of the contract.
    modifier onlyOwner() {
        require(msg.sender == _owner);
        _;
    }

}
