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
        blocksCreated[_stakingEpoch][_miningAddress] = _value;
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
        address _miningAddress
    ) public {
        _snapshotPoolStakeAmounts(_stakingContract, _stakingEpoch, _miningAddress);
    }

    function setSnapshotPoolValidatorStakeAmount(uint256 _stakingEpoch, address _poolMiningAddress, uint256 _amount) public {
        snapshotPoolValidatorStakeAmount[_stakingEpoch][_poolMiningAddress] = _amount;
    }

    // =============================================== Private ========================================================

    function _getCurrentBlockNumber() internal view returns(uint256) {
        return _currentBlockNumber;
    }

    function _getSystemAddress() internal view returns(address) {
        return _systemAddress;
    }

}
