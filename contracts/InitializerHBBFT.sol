pragma solidity 0.5.2;
pragma experimental ABIEncoderV2;

import "./abstracts/ContractsAddresses.sol";
import "./interfaces/IValidatorSet.sol";
import "./interfaces/IValidatorSetHBBFT.sol";
import "./interfaces/IStakingHBBFT.sol";
import "./interfaces/ITxPermission.sol";
import "./interfaces/ICertifier.sol";


contract InitializerHBBFT is ContractsAddresses {
    constructor(
        address _erc20TokenContract,
        address _owner,
        address[] memory _miningAddresses,
        address[] memory _stakingAddresses,
        bytes[] memory _publicKeys,
        bool _firstValidatorIsUnremovable, // must be `false` for production network
        uint256 _delegatorMinStake,
        uint256 _candidateMinStake
    ) public {
        IValidatorSet(VALIDATOR_SET_CONTRACT).initialize(
            BLOCK_REWARD_CONTRACT,
            RANDOM_CONTRACT,
            STAKING_CONTRACT,
            _miningAddresses,
            _stakingAddresses,
            _firstValidatorIsUnremovable
        );
        IValidatorSetHBBFT(VALIDATOR_SET_CONTRACT).initializePublicKeys(
            _publicKeys
        );
        IStakingHBBFT(STAKING_CONTRACT).initialize(
            VALIDATOR_SET_CONTRACT,
            _erc20TokenContract,
            _stakingAddresses,
            _delegatorMinStake,
            _candidateMinStake
        );
        ITxPermission(PERMISSION_CONTRACT).initialize(_owner);
        ICertifier(CERTIFIER_CONTRACT).initialize(_owner);
        selfdestruct(msg.sender);
    }
}
