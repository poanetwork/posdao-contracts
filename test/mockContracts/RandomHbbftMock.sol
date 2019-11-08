pragma solidity 0.5.10;

import '../../contracts/RandomHbbft.sol';


contract RandomHbbftMock is RandomHbbft {

    address internal _coinbase;
    uint256 internal _currentBlockNumber;

    // =============================================== Setters ========================================================

    function setCoinbase(address _base) public {
        _coinbase = _base;
    }

    function setCurrentBlockNumber(uint256 _blockNumber) public {
        _currentBlockNumber = _blockNumber;
    }

    // =============================================== Private ========================================================

    function _getCoinbase() internal view returns(address) {
        return _coinbase != address(0) ? _coinbase : block.coinbase;
    }

    function _getCurrentBlockNumber() internal view returns(uint256) {
        return _currentBlockNumber;
    }

}
