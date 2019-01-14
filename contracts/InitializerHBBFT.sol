pragma solidity 0.5.2;

import "./ValidatorSetHBBFT.sol";


contract InitializerHBBFT {
    constructor(
        ValidatorSetHBBFT _validatorSetContract,
        address _blockRewardContract,
        address _randomContract,
        address _erc20TokenContract,
        address[] memory _validators,
        uint256 _stakerMinStake,
        uint256 _validatorMinStake
    ) public {
        require(address(_validatorSetContract) != address(0), "_validatorSetContract cannot be the zero address");
        _validatorSetContract.initialize(
            _blockRewardContract,
            _randomContract,
            _erc20TokenContract,
            _validators,
            _stakerMinStake,
            _validatorMinStake
        );
        selfdestruct(msg.sender);
    }
}
