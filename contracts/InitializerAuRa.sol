pragma solidity 0.5.2;

import "./abstracts/ContractsAddresses.sol";
import "./interfaces/IValidatorSet.sol";
import "./interfaces/IStakingAuRa.sol";
import "./interfaces/IRandomAuRa.sol";
import "./interfaces/ITxPermission.sol";
import "./interfaces/ICertifier.sol";


contract InitializerAuRa is ContractsAddresses {
    constructor(
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
        IValidatorSet(VALIDATOR_SET_CONTRACT).initialize(
            BLOCK_REWARD_CONTRACT,
            RANDOM_CONTRACT,
            STAKING_CONTRACT,
            _miningAddresses,
            _stakingAddresses,
            _firstValidatorIsUnremovable
        );
        IStakingAuRa(STAKING_CONTRACT).initialize(
            _erc20TokenContract,
            _stakingAddresses,
            _delegatorMinStake,
            _candidateMinStake,
            _stakingEpochDuration,
            _stakeWithdrawDisallowPeriod
        );
        IRandomAuRa(RANDOM_CONTRACT).initialize(_collectRoundLength);
        ITxPermission(PERMISSION_CONTRACT).initialize(_owner);
        ICertifier(CERTIFIER_CONTRACT).initialize(_owner);
        selfdestruct(msg.sender);
    }
}
