pragma solidity 0.4.25;

import "./interfaces/IReportingValidatorSet.sol";
import "./libs/SafeMath.sol";


contract ReportingValidatorSet is IReportingValidatorSet {
    using SafeMath for uint256;

    struct ObserverState {
        uint256 index; // index in the `currentValidators`
        bool isValidator; // is this observer a validator?
        bytes publicKey; // serialized public key of observer
    }

    // ================================================ Store =========================================================

    uint256 public stakingEpoch; // the internal serial number of staking epoch
    uint256 public changeRequestCount; // the serial number of validator set changing request
    
    address[] public currentValidators; // the current set of validators
    address[] public previousValidators; // the set of validators at the end of previous staking epoch

    uint256[] public currentRandom;

    address[] public pools; // the list of current observers (pools)
    mapping(address => uint256) public poolIndex; // pool index in `pools` array

    mapping(address => address[]) public poolStakers; // the list of current stakers in the specified pool
    mapping(address => mapping(address => uint256)) public poolStakerIndex; // staker index in `poolStakers` array

    mapping(address => mapping(address => uint256)) public stakeAmount;
    mapping(address => mapping(address => mapping(uint256 => uint256))) public stakeAmountByEpoch;
    mapping(address => uint256) public stakeAmountTotal;

    mapping(address => ObserverState) public observersState;
    mapping(address => ObserverState) public observersStatePreviousEpoch;

    // ============================================== Constants =======================================================

    uint256 public constant MAX_OBSERVERS = 2000;
    uint256 public constant MAX_VALIDATORS = 20;
    uint256 public constant MIN_STAKE = 1 ether; // must be specified before network launching

    // ================================================ Events ========================================================
    
    event InitiateChange(bytes32 indexed parentHash, address[] newSet);
    event BenignReported(address indexed reporter, address indexed validator, uint256 indexed blockNumber);
    event MaliciousReported(address indexed reporter, address indexed validator, uint256 indexed blockNumber);
    event Staked(address indexed observer, address indexed staker, uint256 indexed stakingEpoch, uint256 amount);
    event Withdrawn(address indexed observer, address indexed staker, uint256 indexed stakingEpoch, uint256 amount);

    // ============================================== Modifiers =======================================================

    modifier onlySystem() {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    modifier onlyValidator() {
        require(isValidator(msg.sender));
        _;
    }

    // =============================================== Setters ========================================================

    constructor() public {
    }

    function finalizeChange() public onlySystem {
    }

    function newValidatorSet() public onlySystem returns(address[]) {
        /*
        uint256 i;
        for (i = 0; i < previousValidators.length; i++) {
            delete observersStatePreviousEpoch[previousValidators[i]];
        }
        previousValidators = currentValidators;
        for (i = 0; i < previousValidators.length; i++) {
            observersStatePreviousEpoch[previousValidators[i]] = ObserverState({
                index: i,
                isValidator: true,
                publicKey: observersState[previousValidators[i]].publicKey
            });
        }
        // ... changing `currentValidators` and `observersState`...
        */
        changeRequestCount++;
        stakingEpoch++;
    }

    function reportBenign(address _validator, uint256 _blockNumber)
        public
        onlyValidator
    {
        emit BenignReported(msg.sender, _validator, _blockNumber);
    }

    function reportMalicious(address _validator, uint256 _blockNumber, bytes /*_proof*/)
        public
        onlyValidator
    {
        // ... check `_proof` and remove `_validator` from `currentValidators` ...
        // if (majorityAchieved) {
        //     changeRequestCount++;
        //     emit InitiateChange(blockhash(block.number - 1), currentValidators);
        // }
        emit MaliciousReported(msg.sender, _validator, _blockNumber);
    }

    function savePublicKey(bytes _key) public {
        require(_key.length == 48); // https://github.com/poanetwork/threshold_crypto/issues/63
        observersState[msg.sender].publicKey = _key;
    }

    function storeRandom(uint256[] _random) public onlySystem {
        require(_random.length == MAX_VALIDATORS);
        currentRandom.length = 0;
        for (uint256 i = 0; i < _random.length; i++) {
            currentRandom.push(_random[i]);
        }
    }

    function moveStake(address _fromObserver, address _toObserver, uint256 _amount) public {
        /*
        require(_fromObserver != address(0));
        require(_toObserver != address(0));
        require(_amount != 0);

        address staker = msg.sender;

        if (staker != _toObserver) {
            // The observer must firstly make a stake for himself
            require(doesPoolExist(_toObserver));
        }
        */
    }

    function stake(address _observer) public payable {
        require(_observer != address(0));
        require(msg.value != 0);

        address staker = msg.sender;

        bool stakerIsObserver = staker == _observer; // `staker` makes a stake for himself and becomes an observer

        if (stakerIsObserver) {
            require(observersState[_observer].publicKey.length != 0);
        } else {
            // The observer must firstly make a stake for himself
            require(doesPoolExist(_observer));
        }

        uint256 newStakeAmount = stakeAmount[_observer][staker].add(msg.value);
        require(newStakeAmount >= MIN_STAKE); // the staked amount must be at least MIN_STAKE
        stakeAmount[_observer][staker] = newStakeAmount;
        stakeAmountByEpoch[_observer][staker][stakingEpoch] =
            stakeAmountByEpoch[_observer][staker][stakingEpoch].add(msg.value);
        stakeAmountTotal[_observer] = stakeAmountTotal[_observer].add(msg.value);

        if (newStakeAmount == msg.value) { // if the stake is first
            if (stakerIsObserver) { // if the observer makes a stake for himself
                // Add `_observer` to the array of pools
                poolIndex[_observer] = pools.length;
                pools.push(_observer);
                require(pools.length <= MAX_OBSERVERS);
            } else {
                // Add `staker` to the array of observer's stakers
                poolStakerIndex[_observer][staker] = poolStakers[_observer].length;
                poolStakers[_observer].push(staker);
            }
        }

        emit Staked(_observer, staker, stakingEpoch, msg.value);
    }

    function withdraw(address _observer, uint256 _amount) public {
        require(_observer != address(0));
        require(_amount != 0);

        address staker = msg.sender;

        // How much can `staker` withdraw from `_observer` pool on the current staking epoch?
        require(_amount <= maxWithdrawAllowed(_observer, staker));

        // The amount to be withdrawn must be the whole staked amount or
        // must not exceed the diff between the entire amount and MIN_STAKE
        uint256 newStakeAmount = stakeAmount[_observer][staker].sub(_amount);
        require(newStakeAmount == 0 || newStakeAmount >= MIN_STAKE);
        stakeAmount[_observer][staker] = newStakeAmount;
        if (_amount <= stakeAmountByEpoch[_observer][staker][stakingEpoch]) {
            stakeAmountByEpoch[_observer][staker][stakingEpoch] -= _amount;
        } else {
            stakeAmountByEpoch[_observer][staker][stakingEpoch] = 0;
        }
        stakeAmountTotal[_observer] = stakeAmountTotal[_observer].sub(_amount);

        if (newStakeAmount == 0) { // the whole amount has been withdrawn
            uint256 indexToRemove;
            if (staker == _observer) {
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

        emit Withdrawn(_observer, staker, stakingEpoch, _amount);
    }

    // =============================================== Getters ========================================================

    function doesPoolExist(address _observer) public view returns(bool) {
        return stakeAmount[_observer][_observer] != 0;
    }

    function getPools() public view returns(address[]) {
        return pools;
    }

    function getValidators() public view returns(address[]) {
        return currentValidators;
    }

    function isValidator(address _who) public view returns(bool) {
        return observersState[_who].isValidator;
    }

    function maxWithdrawAllowed(address _observer, address _staker) public view returns(uint256) {
        bool observerIsValidator = isValidator(_observer);

        if (_staker == _observer && observerIsValidator) {
            // An observer can't withdraw while he is a validator
            return 0;
        }

        if (!observerIsValidator) {
            // The whole amount can be withdrawn if observer is not a validator
            return stakeAmount[_observer][_staker];
        }

        if (observersStatePreviousEpoch[_observer].isValidator) {
            // The observer was also a validator on the previous staking epoch, so
            // the staker can't withdraw amount staked on the previous staking epoch
            return stakeAmount[_observer][_staker].sub(
                stakeAmountByEpoch[_observer][_staker][stakingEpoch.sub(1)] // stakingEpoch is always > 0 here
            );
        } else {
            // The observer wasn't a validator on the previous staking epoch, so
            // the staker can only withdraw amount staked on the current staking epoch
            return stakeAmountByEpoch[_observer][_staker][stakingEpoch];
        }
    }
}
