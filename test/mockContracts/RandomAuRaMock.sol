pragma solidity 0.5.10;

import '../../contracts/RandomAuRa.sol';


contract RandomAuRaMock is RandomAuRa {

    uint256 internal _currentBlockNumber;

    // =============================================== Setters ========================================================

    function setCurrentBlockNumber(uint256 _blockNumber) public {
        _currentBlockNumber = _blockNumber;
    }

    function setSentReveal(address _validator) public {
        sentReveal[currentCollectRound()][_validator] = true;
    }

    // =============================================== Private ========================================================

    function _getCurrentBlockNumber() internal view returns(uint256) {
        return _currentBlockNumber;
    }

}
