pragma solidity 0.5.10;

import '../../contracts/base/BlockRewardAuRaBase.sol';


contract BlockRewardAuRaBaseMock is BlockRewardAuRaBase {

    uint256 internal _currentBlockNumber;
    address internal _systemAddress;

    // ============================================== Modifiers =======================================================

    modifier onlySystem() {
        require(msg.sender == _getSystemAddress());
        _;
    }

    // =============================================== Setters ========================================================

    function sendCoins() public payable {
    }

    function setBlocksCreated(uint256 _stakingEpoch, address _miningAddress, uint256 _value) public {
        uint256 poolId = validatorSetContract.idByMiningAddress(_miningAddress);
        blocksCreated[_stakingEpoch][poolId] = _value;
    }

    function setCurrentBlockNumber(uint256 _blockNumber) public {
        _currentBlockNumber = _blockNumber;
    }

    function setSystemAddress(address _address) public {
        _systemAddress = _address;
    }

    function setValidatorMinRewardPercent(uint256 _stakingEpoch, uint256 _percent) public {
        validatorMinRewardPercent[_stakingEpoch] = _percent;
    }

    function snapshotPoolStakeAmounts(
        IStakingAuRa _stakingContract,
        uint256 _stakingEpoch,
        uint256 _poolId
    ) public {
        _snapshotPoolStakeAmounts(_stakingContract, _stakingEpoch, _poolId);
    }

    function setSnapshotPoolValidatorStakeAmount(uint256 _stakingEpoch, address _poolMiningAddress, uint256 _amount) public {
        uint256 poolId = validatorSetContract.idByMiningAddress(_poolMiningAddress);
        snapshotPoolValidatorStakeAmount[_stakingEpoch][poolId] = _amount;
    }

    // =============================================== Getters ========================================================

    function inflationAmount(
        uint256 _stakingEpoch,
        uint256[] memory _validators,
        uint256 _inflationRate
    ) public view returns(uint256) {
        return _inflationAmount(_stakingEpoch, _validators, _inflationRate);
    }

    // =============================================== Private ========================================================

    function _getCurrentBlockNumber() internal view returns(uint256) {
        return _currentBlockNumber;
    }

    function _getSystemAddress() internal view returns(address) {
        return _systemAddress;
    }

}
