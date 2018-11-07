pragma solidity ^0.4.25;

import "./libs/SafeMath.sol";


contract ReportingValidatorSet {
    using SafeMath for uint256;

    struct ValidatorState {
        uint256 index; // index in the currentValidators
        bool isValidator; // is this a validator
    }

    address[] internal currentValidators;
    mapping(address => ValidatorState) public validatorsState;
    
    event InitiateChange(bytes32 indexed parentHash, address[] newSet);

    modifier onlySystem() {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    modifier onlyValidator() {
        require(validatorsState[msg.sender].isValidator);
        _;
    }

    constructor() public {
        currentValidators.push(address(0x6546ed725e88fa728a908f9ee9d61f50edc40ad6));
        currentValidators.push(address(0x1a22d96792666863f429a85623e6d4ca173d26ab));
        currentValidators.push(address(0x4579c2a15651609ec44a5fadeaabfc30943b5949));
    }

    function finalizeChange() public onlySystem {
    }

    function reportBenign(address _validator, uint256 _blockNumber)
        public
        onlyValidator
    {
    }

    function reportMalicious(address _validator, uint256 _blockNumber, bytes _proof)
        public
        onlyValidator
    {
    }

    function getValidators() public view returns(address[]) {
        return currentValidators;
    }
}
