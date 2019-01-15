pragma solidity 0.5.2;

import "./interfaces/IRandomAuRa.sol";
import "./interfaces/IValidatorSetAuRa.sol";


contract InitializerAuRa {
    constructor(
        IValidatorSetAuRa _validatorSetContract,
        address _blockRewardContract,
        IRandomAuRa _randomContract,
        address _erc20TokenContract,
        address[] memory _validators,
        uint256 _stakerMinStake,
        uint256 _validatorMinStake,
        uint256 _stakingEpochDuration,
        uint256 _collectRoundLength
    ) public {
        require(address(_validatorSetContract) != address(0));
        _validatorSetContract.initialize(
            _blockRewardContract,
            address(_randomContract),
            _erc20TokenContract,
            _validators,
            _stakerMinStake,
            _validatorMinStake,
            _stakingEpochDuration
        );
        _randomContract.initialize(
            _collectRoundLength
        );
        selfdestruct(msg.sender);
    }
}
