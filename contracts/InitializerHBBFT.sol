pragma solidity 0.5.7;
pragma experimental ABIEncoderV2;

import "./abstracts/ContractsAddresses.sol";
import "./interfaces/IValidatorSet.sol";
import "./interfaces/IValidatorSetHBBFT.sol";
import "./interfaces/IStakingHBBFT.sol";
import "./interfaces/ITxPermission.sol";
import "./interfaces/ICertifier.sol";


contract InitializerHBBFT is ContractsAddresses {
    constructor(
        address _owner,
        address[] memory _miningAddresses,
        address[] memory _stakingAddresses,
        bytes[] memory _publicKeys,
        bool _firstValidatorIsUnremovable, // must be `false` for production network
        uint256 _delegatorMinStake,
        uint256 _candidateMinStake,
        bool _erc20Restricted
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
            _stakingAddresses,
            _delegatorMinStake,
            _candidateMinStake,
            _erc20Restricted
        );
        ITxPermission(PERMISSION_CONTRACT).initialize(_owner, VALIDATOR_SET_CONTRACT);
        ICertifier(CERTIFIER_CONTRACT).initialize(_owner);
        selfdestruct(msg.sender);
    }
}
