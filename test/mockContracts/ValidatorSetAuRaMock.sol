pragma solidity 0.5.2;

import '../../contracts/ValidatorSetAuRa.sol';


contract ValidatorSetAuRaMock is ValidatorSetAuRa {

    // ============================================== Modifiers =======================================================

    modifier onlySystem() {
        require(msg.sender == _getSystemAddress());
        _;
    }

    // =============================================== Setters ========================================================

    function setBlockRewardContract(address _address) public {
        addressStorage[BLOCK_REWARD_CONTRACT] = _address;
    }

    function setCurrentBlockNumber(uint256 _blockNumber) public {
        uintStorage[keccak256("currentBlockNumber")] = _blockNumber;
    }

    function setSystemAddress(address _systemAddress) public {
        addressStorage[keccak256("systemAddress")] = _systemAddress;
    }

    // =============================================== Getters ========================================================

    function getRandomIndex(
        int256[] memory _likelihood,
        int256 _likelihoodSum,
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

    function _getSystemAddress() internal view returns(address) {
        return addressStorage[keccak256("systemAddress")];
    }

}
