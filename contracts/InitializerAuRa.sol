pragma solidity 0.5.2;

import "./ValidatorSetAuRa.sol";
import "./RandomAuRa.sol";

contract InitializerAuRa {
    constructor(
        ValidatorSetAuRa _validatorSetContract,
        address _blockRewardContract,
        RandomAuRa _randomContract,
        address _erc20TokenContract,
        address[] memory _validators,
        uint256 _stakerMinStake,
        uint256 _validatorMinStake,
        uint256 _stakingEpochDuration,
        uint256 _stakeWithdrawlDisallowPeriod,
        uint256 _collectRoundLength
    ) public {
        require(address(_validatorSetContract) != address(0), "_validatorSetContract cannot be the zero address");
        _validatorSetContract.initialize(
            _blockRewardContract,
            _randomContract,
            _erc20TokenContract,
            _validators,
            _stakerMinStake,
            _validatorMinStake,
            _stakingEpochDuration,
            _stakeWithdrawlDisallowPeriod,
            _collectRoundLength
        );
        
        selfdestruct(msg.sender);
    }
}
