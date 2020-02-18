pragma solidity ^0.5.16;

import '../../contracts/RandomHbbft.sol';


contract RandomHbbftMock is RandomHbbft {

    address internal _coinbase;
    uint256 internal _currentBlockNumber;
    address internal _systemAddress;

    // ============================================== Modifiers =======================================================

    modifier onlySystem() {
        require(msg.sender == _getSystemAddress());
        _;
    }

    // =============================================== Setters ========================================================

    function setCoinbase(address _base) public {
        _coinbase = _base;
    }

    function setCurrentBlockNumber(uint256 _blockNumber) public {
        _currentBlockNumber = _blockNumber;
    }

    function setSystemAddress(address _address) public {
        _systemAddress = _address;
    }

    // =============================================== Private ========================================================

    function _getCoinbase() internal view returns(address) {
        return _coinbase != address(0) ? _coinbase : block.coinbase;
    }

    function _getCurrentBlockNumber() internal view returns(uint256) {
        return _currentBlockNumber;
    }

    function _getSystemAddress() internal view returns(address) {
        return _systemAddress;
    }

}
