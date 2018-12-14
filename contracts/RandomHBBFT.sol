pragma solidity 0.4.25;

import "./abstracts/RandomBase.sol";


contract RandomHBBFT is RandomBase {

    function storeRandom(uint256[] _random) public onlySystem {
        require(_random.length == validatorSetContract.MAX_VALIDATORS());
        _randomArray = _random;
    }

}