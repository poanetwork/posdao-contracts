pragma solidity 0.5.10;

import './BlockRewardAuRaBaseMock.sol';
import '../../contracts/base/BlockRewardAuRaCoins.sol';


contract BlockRewardAuRaCoinsMock is BlockRewardAuRaCoins, BlockRewardAuRaBaseMock {
    function setEpochPoolReward(
        uint256 _stakingEpoch,
        address _poolMiningAddress
    ) public payable {
        require(_stakingEpoch != 0);
        require(_poolMiningAddress != address(0));
        require(msg.value != 0);
        require(epochPoolNativeReward[_stakingEpoch][_poolMiningAddress] == 0);
        address stakingAddress = validatorSetContract.stakingByMiningAddress(_poolMiningAddress);
        epochPoolNativeReward[_stakingEpoch][_poolMiningAddress] = msg.value;
        _epochsPoolGotRewardFor[stakingAddress].push(_stakingEpoch);
    }
}
