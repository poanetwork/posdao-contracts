pragma solidity 0.4.25;

import "./abstracts/RandomBase.sol";


contract RandomHBBFT is RandomBase {

    function storeRandom(uint256[] _random) public onlySystem {
        require(_random.length == IValidatorSet(VALIDATOR_SET_CONTRACT).MAX_VALIDATORS());
        uintArrayStorage[RANDOM_ARRAY] = _random;
    }

}