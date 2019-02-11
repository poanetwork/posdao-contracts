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
    function getCurrentSeed() external onlyValidatorSetContract view returns(uint256) {
        return _getCurrentSeed();
    }

    // =============================================== Private ========================================================

    bytes32 internal constant CURRENT_SEED = keccak256("currentSeed");

    function _setCurrentSeed(uint256 _seed) internal {
        uintStorage[CURRENT_SEED] = _seed;
    }

    function _getCurrentSeed() internal view returns(uint256) {
        return uintStorage[CURRENT_SEED];
    }

}
