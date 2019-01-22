pragma solidity 0.5.2;

import "./abstracts/RandomBase.sol";


contract RandomHBBFT is RandomBase {

    function storeRandom(uint256[] memory _random) public onlySystem {
        require(_random.length == IValidatorSet(VALIDATOR_SET_CONTRACT).MAX_VALIDATORS());
        uintArrayStorage[RANDOM_ARRAY] = _random;
    }

}
