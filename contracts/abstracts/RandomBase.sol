pragma solidity 0.5.2;

import "../interfaces/IRandom.sol";
import "../interfaces/IValidatorSet.sol";
import "../eternal-storage/OwnedEternalStorage.sol";
import "../libs/SafeMath.sol";


contract RandomBase is OwnedEternalStorage, IRandom {
    using SafeMath for uint256;

    // ============================================== Constants =======================================================

    // This address must be set before deploy
    address public constant VALIDATOR_SET_CONTRACT = address(0x1000000000000000000000000000000000000001);

    // ============================================== Modifiers =======================================================

    modifier onlyValidatorSetContract() {
        require(msg.sender == VALIDATOR_SET_CONTRACT);
        _;
    }

    // =============================================== Getters ========================================================

    // This function is called by ValidatorSet contract.
    function getCurrentSecret() external onlyValidatorSetContract view returns(uint256) {
        return _getCurrentSecret();
    }

    // =============================================== Private ========================================================

    bytes32 internal constant CURRENT_SECRET = keccak256("currentSecret");

    function _setCurrentSecret(uint256 _secret) internal {
        uintStorage[CURRENT_SECRET] = _secret;
    }

    function _getCurrentSecret() internal view returns(uint256) {
        return uintStorage[CURRENT_SECRET];
    }

}
