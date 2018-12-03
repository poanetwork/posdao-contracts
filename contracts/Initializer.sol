pragma solidity 0.4.25;

import "./interfaces/IReportingValidatorSet.sol";


contract Initializer {
    constructor(IReportingValidatorSet _validatorSetContract, address[] _validators) public {
        require(block.number == 0);
        _validatorSetContract.initialize(_validators);
        selfdestruct(0x0000000000000000000000000000000000000000);
    }
}