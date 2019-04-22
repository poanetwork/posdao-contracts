pragma solidity 0.5.2;

import "./EternalStorage.sol";


/// @dev Provides access control functionality and extends the `EternalStorage` contract.
/// Using the `onlyOwner` modifier, a function can be restricted to being called by the
/// owner of the contract. The owner of a contract can irrevocably transfer ownership
/// using the `EternalStorageProxy.transferOwnership` function.
contract OwnedEternalStorage is EternalStorage {

    /// @dev Access check: revert unless `msg.sender` is the owner of the contract.
    modifier onlyOwner() {
        require(msg.sender == _owner);
        _;
    }

}
