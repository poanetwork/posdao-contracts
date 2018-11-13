pragma solidity ^0.4.25;

import "./libs/SafeMath.sol";


contract ReportingValidatorSet {
    using SafeMath for uint256;

    struct ObserverState {
        uint256 index; // index in the currentValidators
        bool isValidator; // is this a validator
    }

    uint256 public epoch;
    
    address[] public currentValidators;
    address[] public previousValidators;

    address[] public pools;
    mapping(address => uint256) public poolIndex;

    mapping(address => address[]) public poolStakers;
    mapping(address => mapping(address => uint256)) public poolStakerIndex;

    mapping(address => mapping(address => uint256)) public stakeAmount;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public stakeAmountByEpoch;
    mapping(address => uint256) public stakeAmountTotal;

    mapping(address => ObserverState) public observersState;
    mapping(address => ObserverState) public observersStatePreviousEpoch;

    uint256 public constant MIN_STAKE = 1 ether;
    
    event InitiateChange(
        bytes32 indexed parentHash,
        address[] newSet
    );

    event MaliciousReported(
        address indexed reporter,
        address indexed validator,
        uint256 indexed blockNumber
    );
    
    event Staked(
        address indexed observer,
        address indexed staker,
        uint256 indexed epoch,
        uint256 amount
    );
    
    event Withdrawn(
        address indexed observer,
        address indexed staker,
        uint256 indexed epoch,
        uint256 amount
    );

    modifier onlySystem() {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    modifier onlyValidator() {
        require(observersState[msg.sender].isValidator);
        _;
    }

    constructor() public {
    }

    function finalizeChange() public onlySystem {
        uint256 i;
        for (i = 0; i < previousValidators.length; i++) {
            delete observersStatePreviousEpoch[previousValidators[i]];
        }
        previousValidators = currentValidators;
        for (i = 0; i < previousValidators.length; i++) {
            observersStatePreviousEpoch[previousValidators[i]] = ObserverState({
                index: i,
                isValidator: true
            });
        }
        // ... changing `currentValidators` and `observersState`...
        epoch++;
    }

    // function reportBenign(address _validator, uint256 _blockNumber)
    //     public
    //     onlyValidator
    // {
    // }

    function reportMalicious(address _validator, uint256 _blockNumber, bytes /*_proof*/)
        public
        onlyValidator
    {
        emit MaliciousReported(msg.sender, _validator, _blockNumber);
    }

    function stake(address _observer) public payable {
        require(_observer != address(0));
        require(msg.value != 0);

        address staker = msg.sender;

        if (_observer != staker) {
            // The observer must firstly make a stake for himself
            require(doesPoolExist(_observer));
        }

        uint256 newStakeAmount = stakeAmount[_observer][staker].add(msg.value);
        require(newStakeAmount >= MIN_STAKE); // the staked amount must be at least MIN_STAKE
        stakeAmount[_observer][staker] = newStakeAmount;
        stakeAmountByEpoch[_observer][staker][epoch] =
            stakeAmountByEpoch[_observer][staker][epoch].add(msg.value);
        stakeAmountTotal[_observer] = stakeAmountTotal[_observer].add(msg.value);

        if (newStakeAmount == msg.value) {
            if (_observer == staker) {
                // Add `_observer` to the array of pools
                poolIndex[_observer] = pools.length;
                pools.push(_observer);
            } else {
                // Add `staker` to the array of observer's stakers
                poolStakerIndex[_observer][staker] = poolStakers[_observer].length;
                poolStakers[_observer].push(staker);
            }
        }

        emit Staked(_observer, staker, epoch, msg.value);
    }

    function withdraw(address _observer, uint256 _amount) public {
        require(_observer != address(0));
        require(_amount != 0);

        address staker = msg.sender;

        bool observerIsStaker = _observer == staker;
        bool observerIsValidator = observersState[_observer].isValidator;

        if (observerIsStaker) {
            // An observer can't withdraw while he is a validator
            require(!observerIsValidator);
        }

        if (observerIsValidator) {
            uint256 withdrawAllowed;
            if (observersStatePreviousEpoch[_observer].isValidator) {
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
        stakeAmountTotal[_observer] = stakeAmountTotal[_observer].sub(_amount);

        if (newStakeAmount == 0) {
            uint256 indexToRemove;
            if (observerIsStaker) {
                // Remove `_observer` from the array of pools
                indexToRemove = poolIndex[_observer];
                pools[indexToRemove] = pools[pools.length - 1];
                poolIndex[pools[indexToRemove]] = indexToRemove;
                pools.length--;
                delete poolIndex[_observer];
            } else {
                // Remove `staker` from the array of observer's stakers
                indexToRemove = poolStakerIndex[_observer][staker];
                poolStakers[_observer][indexToRemove] =
                    poolStakers[_observer][poolStakers[_observer].length];
                poolStakerIndex[_observer][poolStakers[_observer][indexToRemove]] =
                    indexToRemove;
                poolStakers[_observer].length--;
                delete poolStakerIndex[_observer][staker];
            }
        }

        staker.transfer(_amount);

        emit Withdrawn(_observer, staker, epoch, _amount);
    }

    function doesPoolExist(address _observer) public view returns(bool) {
        return stakeAmount[_observer][_observer] != 0;
    }

    function getPools() public view returns(address[]) {
        return pools;
    }

    function getValidators() public view returns(address[]) {
        return currentValidators;
    }
}
