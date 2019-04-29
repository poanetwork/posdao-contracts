pragma solidity 0.5.7;

import "./OwnedEternalStorage.sol";
import "../interfaces/IEternalStorageProxy.sol";


/// @dev This proxy holds the storage of an upgradable contract and delegates every call to the current implementation.
/// It allows the contract's behavior to be updated and provides authorization control functionality.
contract EternalStorageProxy is OwnedEternalStorage, IEternalStorageProxy {

    // ================================================ Events ========================================================

    /// @dev Emitted by the `transferOwnership` function every time the ownership of this contract changes.
    /// @param previousOwner Represents the previous owner of the contract.
    /// @param newOwner Represents the new owner of the contract.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @dev Emitted by the `upgradeTo` function every time the implementation gets upgraded.
    /// @param version The new version number of the upgraded implementation.
    /// @param implementation The new address of the upgraded implementation.
    event Upgraded(uint256 version, address indexed implementation);

    // =============================================== Setters ========================================================

    /// @param _implementationAddress The address of the implementation. This must either be the address of
    /// an already-constructed contract, or `address(0)`. In the latter case, the implementation can be set later using
    /// the `upgradeTo` function.
    /// @param _ownerAddress The owner of the contract. If set to `address(0)`, then `msg.sender` will be used instead.
    constructor(address _implementationAddress, address _ownerAddress) public {
        if (_implementationAddress != address(0)) {
            require(_isContract(_implementationAddress));
            _setImplementation(_implementationAddress);
        }
        if (_ownerAddress != address(0)) {
            _owner = _ownerAddress;
        } else {
            _owner = msg.sender;
        }
    }

    // solhint-disable no-complex-fallback, no-inline-assembly
    /// @dev Fallback function allowing a `delegatecall` to the given implementation.
    /// This function will return whatever the implementation call returns.
    function() external payable {
        address _impl = implementation();
        require(_impl != address(0));

        assembly {
            // Copy `msg.data`. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0
            calldatacopy(0, 0, calldatasize)

            // Call the implementation. Out and outsize are 0 because we don't know the size yet
            let result := delegatecall(gas, _impl, 0, calldatasize, 0, 0)

            // Copy the returned data
            returndatacopy(0, 0, returndatasize)

            switch result
            // delegatecall returns 0 on error
            case 0 { revert(0, returndatasize) }
            default { return(0, returndatasize) }
        }
    }
    // solhint-enable no-complex-fallback, no-inline-assembly

    /// @dev Allows the current owner to irrevocably transfer control of the contract to a `_newOwner`.
    /// @param _newOwner The address ownership is transferred to.
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0));
        emit OwnershipTransferred(_owner, _newOwner);
        _owner = _newOwner;
    }

    /// @dev Allows the owner to upgrade the current implementation.
    /// @param _newImplementation Represents the address where the new implementation is set.
    function upgradeTo(address _newImplementation) external onlyOwner returns(bool) {
        if (_newImplementation == address(0)) return false;
        if (implementation() == _newImplementation) return false;
        if (!_isContract(_newImplementation)) return false;

        uint256 newVersion = version() + 1;
        if (newVersion <= version()) return false;

        _setVersion(newVersion);
        _setImplementation(_newImplementation);

        emit Upgraded(newVersion, _newImplementation);
        return true;
    }

    // =============================================== Getters ========================================================

    /// @dev Returns the address of the contract owner.
    function getOwner() external view returns(address) {
        return _owner;
    }

    /// @dev Returns the address of the current implementation.
    function implementation() public view returns(address) {
        return addressStorage[IMPLEMENTATION];
    }

    /// @dev Returns the version number of the current implementation.
    function version() public view returns(uint256) {
        return uintStorage[VERSION];
    }

    // =============================================== Private ========================================================

    bytes32 internal constant IMPLEMENTATION = keccak256("implementation");
    bytes32 internal constant VERSION = keccak256("version");

    /// @dev Checks whether the specified address is a contract address.
    /// Returns `false` if the address is an EOA (externally owned account).
    /// @param _addr The address which needs to be checked.
    function _isContract(address _addr) private view returns(bool) {
        uint256 size;
        assembly { size := extcodesize(_addr) } // solhint-disable-line no-inline-assembly
        return size != 0;
    }

    /// @dev Sets the implementation address.
    /// @param _implementationAddress The address of implementation.
    function _setImplementation(address _implementationAddress) private {
        addressStorage[IMPLEMENTATION] = _implementationAddress;
    }

    /// @dev Sets the version number.
    /// @param _newVersion The version number.
    function _setVersion(uint256 _newVersion) private {
        uintStorage[VERSION] = _newVersion;
    }

}
