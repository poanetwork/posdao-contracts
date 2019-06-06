pragma solidity 0.5.7;

import '../../contracts/RandomAuRa.sol';


contract RandomAuRaMock is RandomAuRa {

    // =============================================== Setters ========================================================

    function setCoinbase(address _coinbase) public {
        addressStorage[keccak256("coinbase")] = _coinbase;
    }

    function setCurrentBlockNumber(uint256 _blockNumber) public {
        uintStorage[keccak256("currentBlockNumber")] = _blockNumber;
    }

    function showCurrentSeed() public view returns(uint256) {
        return _getCurrentSeed();
    }

    // =============================================== Private ========================================================

    function _getCoinbase() internal view returns(address) {
        address coinbase = addressStorage[keccak256("coinbase")];
        return coinbase != address(0) ? coinbase : block.coinbase;
    }

    function _getCurrentBlockNumber() internal view returns(uint256) {
        return uintStorage[keccak256("currentBlockNumber")];
    }

}
