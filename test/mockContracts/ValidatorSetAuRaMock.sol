pragma solidity 0.5.2;

import '../../contracts/ValidatorSetAuRa.sol';


contract ValidatorSetAuRaMock is ValidatorSetAuRa {

    // =============================================== Setters ========================================================

    function addToPoolsMock(address _who) public {
        _addToPools(_who);
    }

    function addToPoolsInactiveMock(address _who) public {
        _addToPoolsInactive(_who);
    }

    function resetErc20TokenContract() public {
        addressStorage[ERC20_TOKEN_CONTRACT] = address(0);
    }

    function setCurrentBlockNumber(uint256 _blockNumber) public {
        uintStorage[keccak256("currentBlockNumber")] = _blockNumber;
    }

    // =============================================== Getters ========================================================

    function getRandomIndex(
        uint256[] memory _likelihood,
        uint256 _likelihoodSum,
        uint256 _randomNumber
    ) public pure returns(uint256) {
        return _getRandomIndex(
            _likelihood,
            _likelihoodSum,
            uint256(keccak256(abi.encode(_randomNumber)))
        );
    }

    // =============================================== Private ========================================================

    function _getCurrentBlockNumber() internal view returns(uint256) {
        return uintStorage[keccak256("currentBlockNumber")];
    }

    function _getMaxCandidates() internal pure returns(uint256) {
        return 100;
    }

}
