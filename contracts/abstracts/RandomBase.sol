pragma solidity 0.4.25;

import "../interfaces/IRandom.sol";
import "../interfaces/IValidatorSet.sol";
import "../libs/SafeMath.sol";


contract RandomBase is IRandom {
    using SafeMath for uint256;

    // =============================================== Storage ========================================================

    IValidatorSet public validatorSetContract;

    uint256[] internal _randomArray;

    // ============================================== Modifiers =======================================================

    modifier onlySystem() {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    // =============================================== Setters ========================================================

    constructor(IValidatorSet _validatorSetContract) public {
        require(_validatorSetContract != address(0));
        validatorSetContract = _validatorSetContract;
    }

    // =============================================== Getters ========================================================

    // This function is called by ValidatorSet contract.
    function currentRandom() public view returns(uint256[]) {
        return _randomArray;
    }

}