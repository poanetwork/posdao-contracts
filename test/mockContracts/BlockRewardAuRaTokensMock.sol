pragma solidity 0.5.10;

import './BlockRewardAuRaBaseMock.sol';
import '../../contracts/base/BlockRewardAuRaTokens.sol';


contract BlockRewardAuRaTokensMock is BlockRewardAuRaTokens, BlockRewardAuRaBaseMock {
    function setEpochPoolReward(
        uint256 _stakingEpoch,
        address _poolMiningAddress,
        uint256 _tokenReward
    ) public payable {
        address stakingAddress = validatorSetContract.stakingByMiningAddress(_poolMiningAddress);
        require(_stakingEpoch != 0);
        require(_poolMiningAddress != address(0));
        require(_tokenReward != 0);
        require(msg.value != 0);
        require(epochPoolTokenReward[_stakingEpoch][stakingAddress] == 0);
        require(epochPoolNativeReward[_stakingEpoch][stakingAddress] == 0);
        ITokenMinter tokenMinter = ITokenMinter(
            IStakingAuRaTokens(validatorSetContract.stakingContract()).erc677TokenContract()
        );
        tokenMinter.mintReward(_tokenReward);
        epochPoolTokenReward[_stakingEpoch][stakingAddress] = _tokenReward;
        epochPoolNativeReward[_stakingEpoch][stakingAddress] = msg.value;
        _epochsPoolGotRewardFor[stakingAddress].push(_stakingEpoch);
    }
}
