pragma solidity 0.5.10;

import '../../contracts/base/StakingAuRaBase.sol';


contract StakingAuRaBaseMock is StakingAuRaBase {

    uint256 internal _currentBlockNumber;

    // =============================================== Setters ========================================================

    function addPoolActiveMock(uint256 _poolId) public {
        _addPoolActive(_poolId, true);
    }

    function addPoolInactiveMock(uint256 _poolId) public {
        _addPoolInactive(_poolId);
    }

    function clearDelegatorStakeSnapshot(uint256 _poolId, address _delegator, uint256 _stakingEpoch) public {
        delegatorStakeSnapshot[_poolId][_delegator][_stakingEpoch] = 0;
    }

    function clearRewardWasTaken(uint256 _poolId, address _staker, uint256 _epoch) public {
        rewardWasTaken[_poolId][_staker][_epoch] = false;
    }

    function setCurrentBlockNumber(uint256 _blockNumber) public {
        _currentBlockNumber = _blockNumber;
    }

    function setInitialStake(uint256 _poolId, uint256 _amount) public {
        _stakeInitial[_poolId] = _amount;
    }

    function setStakeAmountTotal(uint256 _poolId, uint256 _amount) public {
        stakeAmountTotal[_poolId] = _amount;
    }

    function setStakeFirstEpoch(uint256 _poolId, address _delegator, uint256 _value) public {
        stakeFirstEpoch[_poolId][_delegator] = _value;
    }

    function setStakeLastEpoch(uint256 _poolId, address _delegator, uint256 _value) public {
        stakeLastEpoch[_poolId][_delegator] = _value;
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
