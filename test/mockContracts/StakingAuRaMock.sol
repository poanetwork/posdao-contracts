pragma solidity 0.5.9;

import '../../contracts/StakingAuRa.sol';


contract StakingAuRaMock is StakingAuRa {

    // =============================================== Setters ========================================================

    function addPoolActiveMock(address _stakingAddress) public {
        _addPoolActive(_stakingAddress, true);
    }

    function addPoolInactiveMock(address _stakingAddress) public {
        _addPoolInactive(_stakingAddress);
    }

    function resetErc20TokenContract() public {
        addressStorage[ERC20_TOKEN_CONTRACT] = address(0);
    }

    function setCurrentBlockNumber(uint256 _blockNumber) public {
        uintStorage[keccak256("currentBlockNumber")] = _blockNumber;
    }

    function setStakeAmountTotal(address _poolStakingAddress, uint256 _amount) public {
        _setStakeAmountTotal(_poolStakingAddress, _amount);
    }

    function setValidatorSetAddress(address _validatorSetAddress) public {
        addressStorage[VALIDATOR_SET_CONTRACT] = _validatorSetAddress;
    }

    // =============================================== Private ========================================================

    function _getCurrentBlockNumber() internal view returns(uint256) {
        return uintStorage[keccak256("currentBlockNumber")];
    }

    function _getMaxCandidates() internal pure returns(uint256) {
        return 100;
    }

}
