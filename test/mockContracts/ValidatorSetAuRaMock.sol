pragma solidity 0.5.2;

import '../../contracts/ValidatorSetAuRa.sol';


contract ValidatorSetAuRaMock is ValidatorSetAuRa {

    function _getCurrentBlockNumber() internal view returns(uint256) {
        return uintStorage[keccak256("currentBlockNumber")];
    }

    function setCurrentBlockNumber(uint256 _blockNumber) public {
        uintStorage[keccak256("currentBlockNumber")] = _blockNumber;
    }

}