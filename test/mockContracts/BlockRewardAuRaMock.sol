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

    function sendCoins() public payable {
    }

    function setBlocksCreated(uint256 _stakingEpoch, address _miningAddress, uint256 _value) public {
        blocksCreated[_stakingEpoch][_miningAddress] = _value;
    }

    function setCurrentBlockNumber(uint256 _blockNumber) public {
        _currentBlockNumber = _blockNumber;
    }

    function setEpochPoolReward(
        uint256 _stakingEpoch,
        address _poolMiningAddress,
        uint256 _tokenReward
    ) public payable {
        require(_stakingEpoch != 0);
        require(_poolMiningAddress != address(0));
        require(_tokenReward != 0);
        require(msg.value != 0);
        require(epochPoolTokenReward[_stakingEpoch][_poolMiningAddress] == 0);
        require(epochPoolNativeReward[_stakingEpoch][_poolMiningAddress] == 0);
        IERC20Minting token = IERC20Minting(IStakingAuRa(validatorSetContract.stakingContract()).erc20TokenContract());
        token.mintReward(address(this), _tokenReward);
        epochPoolTokenReward[_stakingEpoch][_poolMiningAddress] = _tokenReward;
        epochPoolNativeReward[_stakingEpoch][_poolMiningAddress] = msg.value;
        _epochsPoolGotRewardFor[_poolMiningAddress].push(_stakingEpoch);
    }

    function setSystemAddress(address _address) public {
        _systemAddress = _address;
    }

    function snapshotPoolStakeAmounts(
        IStakingAuRa _stakingContract,
        uint256 _stakingEpoch,
        address _miningAddress
    ) public {
        _snapshotPoolStakeAmounts(_stakingContract, _stakingEpoch, _miningAddress);
    }

    // =============================================== Private ========================================================

    function _getCurrentBlockNumber() internal view returns(uint256) {
        return _currentBlockNumber;
    }

    function _getSystemAddress() internal view returns(address) {
        return _systemAddress;
    }

}
