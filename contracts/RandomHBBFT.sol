pragma solidity 0.5.2;

import "./abstracts/RandomBase.sol";


contract RandomHBBFT is RandomBase {

    modifier onlySystem() {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    function storeRandom(uint256[] memory _random) public onlySystem {
        for (uint256 i = 0; i < _random.length; i++) {
            _setCurrentSeed(_getCurrentSeed() ^ _random[i]);
        }
    }

}
