pragma solidity 0.5.2;

import "./interfaces/IValidatorSetHBBFT.sol";
import "./interfaces/ITxPermission.sol";
import "./interfaces/ICertifier.sol";


contract InitializerHBBFT {
    constructor(
        IValidatorSetHBBFT _validatorSetContract,
        address _blockRewardContract,
        address _randomContract,
        ITxPermission _permissionContract,
        ICertifier _certifierContract,
        address _erc20TokenContract,
        address _owner,
        address[] memory _validators,
        uint256 _delegatorMinStake,
        uint256 _candidateMinStake
    ) public {
        require(address(_validatorSetContract) != address(0));
        _validatorSetContract.initialize(
            _blockRewardContract,
            _randomContract,
            _erc20TokenContract,
            _validators,
            _delegatorMinStake,
            _candidateMinStake
        );
        _permissionContract.initialize(_owner);
        _certifierContract.initialize(_owner);
        selfdestruct(msg.sender);
    }
}
