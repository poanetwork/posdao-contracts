pragma solidity ^0.5.16;

import './BlockRewardHbbftBaseMock.sol';
import '../../contracts/base/BlockRewardHbbftTokens.sol';


contract BlockRewardHbbftTokensMock is BlockRewardHbbftTokens, BlockRewardHbbftBaseMock {
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
        IERC677Minting token = IERC677Minting(
            IStakingHbbftTokens(validatorSetContract.stakingContract()).erc677TokenContract()
        );
        token.mintReward(_tokenReward);
        epochPoolTokenReward[_stakingEpoch][_poolMiningAddress] = _tokenReward;
        epochPoolNativeReward[_stakingEpoch][_poolMiningAddress] = msg.value;
        _epochsPoolGotRewardFor[_poolMiningAddress].push(_stakingEpoch);
    }
}
