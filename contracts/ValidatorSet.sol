pragma solidity ^0.4.25;

import "./libs/SafeMath.sol";


contract ReportingValidatorSet {
    using SafeMath for uint256;

    struct ValidatorState {
        uint256 index; // index in the currentValidators
        bool isValidator; // is this a validator
    }

    address[] public currentValidators;
    uint256 public epoch;
    address[] public pools;
    mapping(address => mapping(address => uint256)) public stakes;
    mapping(address => ValidatorState) public validatorsState;

    uint256 public constant MIN_STAKE = 1 ether;
    
    event InitiateChange(bytes32 indexed parentHash, address[] newSet);
    event Staked(address indexed observer, address indexed staker, uint256 amount);

    modifier onlySystem() {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    modifier onlyValidator() {
        require(validatorsState[msg.sender].isValidator);
        _;
    }

    constructor() public {
    }

    function finalizeChange() public onlySystem {
        epoch++;
    }

    // function reportBenign(address _validator, uint256 _blockNumber)
    //     public
    //     onlyValidator
    // {
    // }

    function reportMalicious(address _validator, uint256 _blockNumber, bytes _proof)
        public
        onlyValidator
    {
    }

    function stake(address _observer) public payable {
        require(_observer != address(0));
        require(msg.value != 0);

        address staker = msg.sender;

        if (_observer == staker) {
            pools.push(_observer);
        } else {
            // observer must firstly make a stake for himself
            require(stakes[_observer][_observer] != 0);
        }

        uint256 newStakeValue = stakes[_observer][staker].add(msg.value);
        require(newStakeValue >= MIN_STAKE);
        stakes[_observer][staker] = newStakeValue;

        emit Staked(_observer, staker, msg.value);
    }

    function unstake(address _observer) public {
        /*
        require(_observer != address(0));

        address staker = msg.sender;

        if (_observer == staker) {

        }
        */
    }

    function getPools() public view returns(address[]) {
        return pools;
    }

    function getValidators() public view returns(address[]) {
        return currentValidators;
    }
}
