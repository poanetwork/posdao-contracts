pragma solidity 0.5.2;

import "./interfaces/IValidatorSet.sol";


contract Initializer {
    constructor(
        IValidatorSet _validatorSetContract,
        address _blockRewardContract,
        address _randomContract,
        address _erc20TokenContract,
        address[] memory _validators,
        uint256 _stakerMinStake,
        uint256 _validatorMinStake
    ) public {
        require(address(_validatorSetContract) != address(0));
        _validatorSetContract.initialize(
            _blockRewardContract,
            _randomContract,
            _erc20TokenContract,
            _validators,
            _stakerMinStake,
            _validatorMinStake
        );
        selfdestruct(address(0));
    }
}
