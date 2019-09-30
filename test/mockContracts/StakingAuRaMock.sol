pragma solidity 0.5.9;

import '../../contracts/StakingAuRa.sol';


contract StakingAuRaMock is StakingAuRa {

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

    function setErc20TokenContractMock(IERC20Minting _erc20TokenContract) public {
        erc20TokenContract = _erc20TokenContract;
    }

    function setErc20Restricted(bool _erc20Restricted) public {
        erc20Restricted = _erc20Restricted;
    }

    function setStakeAmountTotal(address _poolStakingAddress, uint256 _amount) public {
        stakeAmountTotal[_poolStakingAddress] = _amount;
    }

    function setStakeFirstEpoch(address _poolStakingAddress, address _delegator, uint256 _value) public {
        _stakeFirstEpoch[_poolStakingAddress][_delegator] = _value;
    }

    function setStakeLastEpoch(address _poolStakingAddress, address _delegator, uint256 _value) public {
        _stakeLastEpoch[_poolStakingAddress][_delegator] = _value;
    }

    function setStakingEpoch(uint256 _stakingEpoch) public {
        stakingEpoch = _stakingEpoch;
    }

    function setValidatorSetAddress(IValidatorSetAuRa _validatorSetAddress) public {
        validatorSetContract = _validatorSetAddress;
    }

    // =============================================== Getters ========================================================

    function stakeFirstEpoch(address _poolStakingAddress, address _delegator) public view returns(uint256) {
        return _stakeFirstEpoch[_poolStakingAddress][_delegator];
    }

    function stakeLastEpoch(address _poolStakingAddress, address _delegator) public view returns(uint256) {
        return _stakeLastEpoch[_poolStakingAddress][_delegator];
    }

    // =============================================== Private ========================================================

    function _getCurrentBlockNumber() internal view returns(uint256) {
        return _currentBlockNumber;
    }

    function _getMaxCandidates() internal pure returns(uint256) {
        return 100;
    }

}
