pragma solidity 0.5.10;

import '../../contracts/ValidatorSetHbbft.sol';

/// @dev mock contract
contract ValidatorSetHbbftMock is ValidatorSetHbbft {


    function finalizeChange() external onlySystem {
        _currentValidators = _pendingValidators;
        delete _pendingValidators;
    }

    constructor(address[] memory _validators) public {
        _currentValidators = _validators;
    }

    // =============================================== Setters ========================================================


    // =============================================== Getters ========================================================

    function getValidators() public view returns(address[] memory) {
        return _currentValidators;
    }

    function getPendingValidators() public view returns(address[] memory) {
        return _pendingValidators;
    }

    // =============================================== Internal ========================================================

    function _setPendingValidators(address[] memory _stakingAddresses) internal {
        _pendingValidators = _stakingAddresses;
    }

}
