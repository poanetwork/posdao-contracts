pragma solidity 0.5.12;

import '../../contracts/base/StakingAuRaBase.sol';


contract StakingAuRaBaseMock is StakingAuRaBase {

    uint256 internal _currentBlockNumber;

    // =============================================== Setters ========================================================

    function addPoolActiveMock(address _stakingAddress) public {
        _addPoolActive(_stakingAddress, true);
    }

    function addPoolInactiveMock(address _stakingAddress) public {
        _addPoolInactive(_stakingAddress);
    }

    function clearDelegatorStakeSnapshot(address _poolStakingAddress, address _delegator, uint256 _stakingEpoch) public {
        delegatorStakeSnapshot[_poolStakingAddress][_delegator][_stakingEpoch] = 0;
    }

    function clearRewardWasTaken(address _poolStakingAddress, address _staker, uint256 _epoch) public {
        rewardWasTaken[_poolStakingAddress][_staker][_epoch] = false;
    }

    function setCurrentBlockNumber(uint256 _blockNumber) public {
        _currentBlockNumber = _blockNumber;
    }

    function setStakeAmountTotal(address _poolStakingAddress, uint256 _amount) public {
        stakeAmountTotal[_poolStakingAddress] = _amount;
    }

    function setStakeFirstEpoch(address _poolStakingAddress, address _delegator, uint256 _value) public {
        stakeFirstEpoch[_poolStakingAddress][_delegator] = _value;
    }

    function setStakeLastEpoch(address _poolStakingAddress, address _delegator, uint256 _value) public {
        stakeLastEpoch[_poolStakingAddress][_delegator] = _value;
    }

    function setStakingEpoch(uint256 _stakingEpoch) public {
        stakingEpoch = _stakingEpoch;
    }

    function setValidatorSetAddress(IValidatorSetAuRa _validatorSetAddress) public {
        validatorSetContract = _validatorSetAddress;
    }

    // =============================================== Private ========================================================

    function _getCurrentBlockNumber() internal view returns(uint256) {
        return _currentBlockNumber;
    }

    function _getMaxCandidates() internal pure returns(uint256) {
        return 100;
    }

}
