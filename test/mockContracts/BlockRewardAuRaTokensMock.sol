pragma solidity 0.5.9;

import './BlockRewardAuRaBaseMock.sol';
import '../../contracts/base/BlockRewardAuRaTokens.sol';


contract BlockRewardAuRaTokensMock is BlockRewardAuRaTokens, BlockRewardAuRaBaseMock {
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
            IStakingAuRaTokens(validatorSetContract.stakingContract()).erc677TokenContract()
        );
        token.mintReward(_tokenReward);
        epochPoolTokenReward[_stakingEpoch][_poolMiningAddress] = _tokenReward;
        epochPoolNativeReward[_stakingEpoch][_poolMiningAddress] = msg.value;
        _epochsPoolGotRewardFor[_poolMiningAddress].push(_stakingEpoch);
    }
}
