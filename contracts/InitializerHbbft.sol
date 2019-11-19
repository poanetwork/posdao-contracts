pragma solidity 0.5.10;

import "./interfaces/IBlockRewardHbbft.sol";
import "./interfaces/ICertifier.sol";
import "./interfaces/IRandomHbbft.sol";
import "./interfaces/IStakingHbbft.sol";
import "./interfaces/ITxPermission.sol";
import "./interfaces/IValidatorSetHbbft.sol";



/// @dev Used once on network startup and then destroyed.
/// Needed for initializing upgradeable contracts since
/// upgradeable contracts can't have constructors.
contract InitializerHbbft {
    /// @param _contracts An array of the contracts:
    ///   0 is ValidatorSetHbbft,
    ///   1 is BlockRewardHbbft,
    ///   2 is RandomHbbft,
    ///   3 is StakingHbbft,
    ///   4 is TxPermission,
    ///   5 is Certifier.
    /// @param _owner The contracts' owner.
    /// @param _miningAddresses The array of initial validators' mining addresses.
    /// @param _stakingAddresses The array of initial validators' staking addresses.
    /// @param _firstValidatorIsUnremovable The boolean flag defining whether the first validator in the
    /// `_miningAddresses/_stakingAddresses` array is non-removable.
    /// Should be `false` for production network.
    /// @param _delegatorMinStake The minimum allowed amount of delegator stake in Wei
    /// (see the `StakingHbbft` contract).
    /// @param _candidateMinStake The minimum allowed amount of candidate stake in Wei
    /// (see the `StakingHbbft` contract).
    /// @param _stakingEpochDuration The duration of a staking epoch in blocks
    /// @param _stakingEpochStartBlock The number of the first block of initial staking epoch
    /// (must be zero if the network is starting from genesis block).
    /// @param _stakeWithdrawDisallowPeriod The duration period (in blocks) at the end of a staking epoch
    /// during which participants cannot stake or withdraw their staking tokens
    constructor(
        address[] memory _contracts,
        address _owner,
        address[] memory _miningAddresses,
        address[] memory _stakingAddresses,
        bool _firstValidatorIsUnremovable,
        uint256 _delegatorMinStake,
        uint256 _candidateMinStake,
        uint256 _stakingEpochDuration,
        uint256 _stakingEpochStartBlock,
        uint256 _stakeWithdrawDisallowPeriod
    ) public {
        IValidatorSetHbbft(_contracts[0]).initialize(
            _contracts[1], // _blockRewardContract
            _contracts[2], // _randomContract
            _contracts[3], // _stakingContract
            _miningAddresses,
            _stakingAddresses,
            _firstValidatorIsUnremovable
        );
        IStakingHbbft(_contracts[3]).initialize(
            _contracts[0], // _validatorSetContract
            _stakingAddresses,
            _delegatorMinStake,
            _candidateMinStake,
            _stakingEpochDuration,
            _stakingEpochStartBlock,
            _stakeWithdrawDisallowPeriod
        );
        IBlockRewardHbbft(_contracts[1]).initialize(_contracts[0]);
        IRandomHbbft(_contracts[2]).initialize(_contracts[0]);
        address[] memory permittedAddresses = new address[](1);
        permittedAddresses[0] = _owner;
        ITxPermission(_contracts[4]).initialize(permittedAddresses, _contracts[0]);
        ICertifier(_contracts[5]).initialize(permittedAddresses, _contracts[0]);
        selfdestruct(msg.sender);
    }
}
