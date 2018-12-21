pragma solidity 0.4.25;

import "../interfaces/IRandom.sol";
import "../interfaces/IValidatorSet.sol";
import "../eternal-storage/EternalStorage.sol";
import "../libs/SafeMath.sol";


contract RandomBase is EternalStorage, IRandom {
    using SafeMath for uint256;

    // ============================================== Constants =======================================================

    // This address must be set before deploy
    address public constant VALIDATOR_SET_CONTRACT = address(0);

    // ============================================== Modifiers =======================================================

    modifier onlySystem() {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    // =============================================== Getters ========================================================

    // This function is called by ValidatorSet contract.
    function currentRandom() public view returns(uint256[]) {
        return uintArrayStorage[RANDOM_ARRAY];
    }

    // =============================================== Private ========================================================

    bytes32 internal constant RANDOM_ARRAY = keccak256("randomArray");

}