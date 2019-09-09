pragma solidity 0.5.9;

import '../../contracts/BlockRewardAuRa.sol';


contract BlockRewardAuRaMock is BlockRewardAuRa {

    uint256 internal _currentBlockNumber;
    address internal _systemAddress;

    // ============================================== Modifiers =======================================================

    modifier onlySystem() {
        require(msg.sender == _getSystemAddress());
        _;
    }

    // =============================================== Setters ========================================================

    function setBlocksCreated(uint256 _stakingEpoch, address _miningAddress, uint256 _value) public {
        blocksCreated[_stakingEpoch][_miningAddress] = _value;
    }

    function setCurrentBlockNumber(uint256 _blockNumber) public {
        _currentBlockNumber = _blockNumber;
    }

    function setSystemAddress(address _address) public {
        _systemAddress = _address;
    }

    // =============================================== Private ========================================================

    function _getCurrentBlockNumber() internal view returns(uint256) {
        return _currentBlockNumber;
    }

    function _getSystemAddress() internal view returns(address) {
        return _systemAddress;
    }

}
