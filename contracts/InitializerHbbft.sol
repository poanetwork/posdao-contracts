pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "./interfaces/IBlockRewardHbbft.sol";
import "./interfaces/ICertifier.sol";
import "./interfaces/IKeyGenHistory.sol";
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
    ///   5 is Certifier,
    ///   6 is KeyGenHistory.
    /// @param _owner The contracts' owner.
    /// @param _miningAddresses The array of initial validators' mining addresses.
    /// @param _stakingAddresses The array of initial validators' staking addresses.
    /// @param _firstValidatorIsUnremovable The boolean flag defining whether the first validator in the
    /// `_miningAddresses/_stakingAddresses` array is non-removable.
    /// Should be `false` for production network.
    /// @param _stakingParams list of staking related parameters, done to avoid "stack too deep" error
    /// _stakingParams[0]: _delegatorMinStake The minimum allowed amount of delegator stake in Wei
    /// (see the `StakingHbbft` contract).
    /// _stakingParams[1]: _candidateMinStake The minimum allowed amount of candidate stake in Wei
    /// (see the `StakingHbbft` contract).
    /// _stakingParams[2]: _stakingEpochDuration The duration of a staking epoch in blocks
    /// _stakingParams[3]: _stakingEpochStartBlock The number of the first block of initial staking epoch
    /// (must be zero if the network is starting from genesis block).
    /// _stakingParams[4]: _stakeWithdrawDisallowPeriod The duration period (in blocks) at the end of a staking epoch
    /// during which participants cannot stake or withdraw their staking tokens
    constructor(
        address[] memory _contracts,
        address _owner,
        address[] memory _miningAddresses,
        address[] memory _stakingAddresses,
        bool _firstValidatorIsUnremovable,
        uint256[5] memory _stakingParams,
        bytes32[] memory _publicKeys,
        bytes16[] memory _internetAddresses,
        bytes[] memory _parts,
        bytes[][] memory _acks
    ) public {
        IValidatorSetHbbft(_contracts[0]).initialize(
            _contracts[1], // _blockRewardContract
            _contracts[2], // _randomContract
            _contracts[3], // _stakingContract
            _contracts[6], // _keyGenHistoryContract
            _miningAddresses,
            _stakingAddresses,
            _firstValidatorIsUnremovable
        );
        IStakingHbbft(_contracts[3]).initialize(
            _contracts[0], // _validatorSetContract
            _stakingAddresses,
            _stakingParams[0],
            _stakingParams[1],
            _stakingParams[2],
            _stakingParams[3],
            _stakingParams[4],
            _publicKeys,
            _internetAddresses
        );
        IKeyGenHistory(_contracts[6]).initialize(
            _contracts[0], // _validatorSetContract
            _miningAddresses,
            _parts,
            _acks
        );
        IBlockRewardHbbft(_contracts[1]).initialize(_contracts[0]);
        IRandomHbbft(_contracts[2]).initialize(_contracts[0]);
        address[] memory permittedAddresses = new address[](1);
        permittedAddresses[0] = _owner;
        ITxPermission(_contracts[4]).initialize(permittedAddresses, _contracts[5], _contracts[0]);
        ICertifier(_contracts[5]).initialize(permittedAddresses, _contracts[0]);
        selfdestruct(msg.sender);
    }
}
