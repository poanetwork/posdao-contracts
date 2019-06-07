pragma solidity 0.5.7;
pragma experimental ABIEncoderV2;

import "./interfaces/IBlockReward.sol";
import "./interfaces/IValidatorSet.sol";
import "./interfaces/IValidatorSetHBBFT.sol";
import "./interfaces/IStakingHBBFT.sol";
import "./interfaces/IRandomHBBFT.sol";
import "./interfaces/ITxPermission.sol";
import "./interfaces/ICertifier.sol";


contract InitializerHBBFT {
    constructor(
        address[] memory _contracts,
        address _owner,
        address[] memory _miningAddresses,
        address[] memory _stakingAddresses,
        bytes[] memory _publicKeys,
        bool _firstValidatorIsUnremovable, // must be `false` for production network
        uint256 _delegatorMinStake,
        uint256 _candidateMinStake,
        bool _erc20Restricted
    ) public {
        IValidatorSet(_contracts[0]).initialize(
            _contracts[1], // _blockRewardContract
            _contracts[2], // _randomContract
            _contracts[3], // _stakingContract
            _miningAddresses,
            _stakingAddresses,
            _firstValidatorIsUnremovable
        );
        IValidatorSetHBBFT(_contracts[0]).initializePublicKeys(
            _publicKeys
        );
        IStakingHBBFT(_contracts[3]).initialize(
            _contracts[0], // _validatorSetContract
            _stakingAddresses,
            _delegatorMinStake,
            _candidateMinStake,
            _erc20Restricted
        );
        IBlockReward(_contracts[1]).initialize(_contracts[0]);
        IRandomHBBFT(_contracts[2]).initialize(_contracts[0]);
        address[] memory permittedAddresses = new address[](1);
        permittedAddresses[0] = _owner;
        ITxPermission(_contracts[4]).initialize(permittedAddresses, _contracts[0]);
        ICertifier(_contracts[5]).initialize(permittedAddresses, _contracts[0]);
        selfdestruct(msg.sender);
    }
}
