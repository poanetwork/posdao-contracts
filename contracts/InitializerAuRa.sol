pragma solidity 0.5.2;

import "./abstracts/ContractsAddresses.sol";
import "./interfaces/IValidatorSet.sol";
import "./interfaces/IStakingAuRa.sol";
import "./interfaces/IRandomAuRa.sol";
import "./interfaces/ITxPermission.sol";
import "./interfaces/ICertifier.sol";


/// @dev Used once on network startup and then destroyed on the genesis block.
/// Needed for initializing upgradeable contracts on the genesis block since
/// upgradeable contracts can't have constructors.
contract InitializerAuRa is ContractsAddresses {
    /// @param _erc20TokenContract The address of the ERC20/677 staking token contract.
    /// Can be initialized as zero and defined later using the `StakingAuRa.setErc20TokenContract` function.
    /// @param _owner The contracts' owner.
    /// @param _miningAddresses The array of initial validators' mining addresses.
    /// @param _stakingAddresses The array of initial validators' staking addresses.
    /// @param _firstValidatorIsUnremovable The boolean flag defining whether the first validator in the
    /// `_miningAddresses/_stakingAddresses` array is non-removable.
    /// Must be `false` for production network.
    /// @param _delegatorMinStake The minimum allowed amount of delegator stake in STAKE_UNITs
    /// (see the `StakingAuRa` contract).
    /// @param _candidateMinStake The minimum allowed amount of candidate stake in STAKE_UNITs
    /// (see the `StakingAuRa` contract).
    /// @param _stakingEpochDuration The duration of a staking epoch in blocks
    /// (e.g., 120960 = 1 week for 5-seconds blocks in AuRa).
    /// @param _stakeWithdrawDisallowPeriod The duration period (in blocks) at the end of a staking epoch
    /// during which participants cannot stake or withdraw their staking tokens
    /// (e.g., 4320 = 6 hours for 5-seconds blocks in AuRa).
    /// @param _collectRoundLength The length of a collection round in blocks (see the `RandomAuRa` contract).
    constructor(
        address _erc20TokenContract,
        address _owner,
        address[] memory _miningAddresses,
        address[] memory _stakingAddresses,
        bool _firstValidatorIsUnremovable,
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
            VALIDATOR_SET_CONTRACT,
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
