pragma solidity 0.5.2;

import "./interfaces/IValidatorSetAuRa.sol";
import "./interfaces/IRandomAuRa.sol";
import "./interfaces/ITxPermission.sol";
import "./interfaces/ICertifier.sol";


contract InitializerAuRa {
    constructor(
        IValidatorSetAuRa _validatorSetContract,
        address _blockRewardContract,
        IRandomAuRa _randomContract,
        ITxPermission _permissionContract,
        ICertifier _certifierContract,
        address _erc20TokenContract,
        address _owner,
        address[] memory _miningAddresses,
        address[] memory _stakingAddresses,
        bool _firstValidatorIsUnremovable, // must be `false` for production network
        uint256 _delegatorMinStake,
        uint256 _candidateMinStake,
        uint256 _stakingEpochDuration,
        uint256 _stakeWithdrawDisallowPeriod,
        uint256 _collectRoundLength
    ) public {
        require(address(_validatorSetContract) != address(0));
        _validatorSetContract.initialize(
            _blockRewardContract,
            address(_randomContract),
            _erc20TokenContract,
            _miningAddresses,
            _stakingAddresses,
            _firstValidatorIsUnremovable,
            _delegatorMinStake,
            _candidateMinStake,
            _stakingEpochDuration,
            _stakeWithdrawDisallowPeriod
        );
        _randomContract.initialize(_collectRoundLength);
        _permissionContract.initialize(_owner);
        _certifierContract.initialize(_owner);
        selfdestruct(msg.sender);
    }
}
