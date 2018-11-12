pragma solidity ^0.4.25;

import "./libs/SafeMath.sol";


contract ReportingValidatorSet {
    using SafeMath for uint256;

    struct ValidatorState {
        uint256 index; // index in the currentValidators
        bool isValidator; // is this a validator
    }

    address[] public currentValidators;
    address[] public previousValidators;
    uint256 public epoch;
    address[] public pools;
    mapping(address => mapping(address => uint256)) public stakeAmount;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public stakeAmountByEpoch;
    mapping(address => ValidatorState) public validatorsState;
    mapping(address => ValidatorState) public validatorsStatePreviousEpoch;

    uint256 public constant MIN_STAKE = 1 ether;
    
    event InitiateChange(bytes32 indexed parentHash, address[] newSet);
    event Staked(address indexed observer, address indexed staker, uint256 indexed epoch, uint256 amount);
    event Unstaked(address indexed observer, address indexed staker, uint256 indexed epoch, uint256 amount);

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
        uint256 i;
        for (i = 0; i < previousValidators.length; i++) {
            delete validatorsStatePreviousEpoch[previousValidators[i]];
        }
        previousValidators = currentValidators;
        for (i = 0; i < previousValidators.length; i++) {
            validatorsStatePreviousEpoch[previousValidators[i]] = ValidatorState({
                index: i,
                isValidator: true
            });
        }
        // ... changing `currentValidators` and `validatorsState`...
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
            // The observer must firstly make a stake for himself
            require(stakeAmount[_observer][_observer] != 0);
        }

        // The staked amount must be at least MIN_STAKE
        uint256 newStakeAmount = stakeAmount[_observer][staker].add(msg.value);
        require(newStakeAmount >= MIN_STAKE);
        stakeAmount[_observer][staker] = newStakeAmount;
        stakeAmountByEpoch[_observer][staker][epoch] = stakeAmountByEpoch[_observer][staker][epoch].add(msg.value);

        emit Staked(_observer, staker, epoch, msg.value);
    }

    function withdraw(address _observer, uint256 _amount) public {
        require(_observer != address(0));
        require(_amount != 0);

        address staker = msg.sender;
        bool observerIsValidator = validatorsState[_observer].isValidator;

        if (_observer == staker) {
            // An observer can't withdraw while he is a validator
            require(!observerIsValidator);
        }

        if (observerIsValidator) {
            uint256 withdrawAllowed;
            if (validatorsStatePreviousEpoch[_observer].isValidator) {
                // The observer was also a validator on the previous epoch, so
                // the staker can't withdraw amount staked on the previous epoch
                withdrawAllowed = stakeAmount[_observer][staker].sub(
                    stakeAmountByEpoch[_observer][staker][epoch.sub(1)]
                );
            } else {
                // The observer wasn't a validator on the previous epoch, so
                // the staker can only withdraw amount staked on the current epoch
                withdrawAllowed = stakeAmountByEpoch[_observer][staker][epoch];
            }
            require(_amount <= withdrawAllowed);
        }

        // The amount to be withdrawn must be the whole staked amount or
        // must not exceed the diff between the entire amount and MIN_STAKE
        uint256 newStakeAmount = stakeAmount[_observer][staker].sub(_amount);
        require(newStakeAmount == 0 || newStakeAmount >= MIN_STAKE);
        stakeAmount[_observer][staker] = newStakeAmount;

        staker.transfer(_amount);

        emit Unstaked(_observer, staker, epoch, _amount);
    }

    function getPools() public view returns(address[]) {
        return pools;
    }

    function getValidators() public view returns(address[]) {
        return currentValidators;
    }
}
