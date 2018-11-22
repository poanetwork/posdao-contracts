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

    uint64[] public currentRandom;

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
    uint256 public constant MIN_STAKE = 1 * STAKE_UNIT; // must be specified before network launching
    uint256 public constant STAKE_UNIT = 1 ether;

    // ================================================ Events ========================================================
    
    event InitiateChange(
        bytes32 indexed parentHash,
        address[] newSet
    );

    event BenignReported(
        address indexed reporter,
        address indexed validator,
        uint256 indexed blockNumber
    );

    event MaliciousReported(
        address indexed reporter,
        address indexed validator,
        uint256 indexed blockNumber
    );

    event Staked(
        address indexed toObserver,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount
    );

    event StakeMoved(
        address indexed fromObserver,
        address indexed toObserver,
        address indexed staker,
        uint256 stakingEpoch,
        uint256 amount
    );

    event Withdrawn(
        address indexed fromObserver,
        address indexed staker,
        uint256 indexed stakingEpoch,
        uint256 amount
    );

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
        // Save previous validator set
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

        // Choose new validators
        if (pools.length <= MAX_VALIDATORS) {
            currentValidators = pools;
        } else {
            uint256[] memory likelihood = new uint256[](pools.length);
            address[] memory poolsLocal = pools;
            address[] memory newValidators = new address[](MAX_VALIDATORS);

            uint256 likelihoodSum = 0;
            uint256 poolsLocalLength = poolsLocal.length;

            for (i = 0; i < pools.length; i++) {
               likelihood[i] = stakeAmountTotal[pools[i]].mul(100).div(STAKE_UNIT);
               likelihoodSum = likelihoodSum.add(likelihood[i]);
            }

            for (i = 0; i < MAX_VALIDATORS; i++) {
                uint256 index = _getRandomIndex(likelihood, likelihoodSum, currentRandom[i]);
                newValidators[i] = poolsLocal[index];
                likelihoodSum -= likelihood[index];
                poolsLocalLength--;
                poolsLocal[index] = poolsLocal[poolsLocalLength];
                likelihood[index] = likelihood[poolsLocalLength];
            }

            currentValidators = newValidators;
        }

        // ...
        // changing `observersState`
        // ...

        changeRequestCount++;
        stakingEpoch++;

        return currentValidators;
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

    function storeRandom(uint64[] _random) public onlySystem {
        require(_random.length == MAX_VALIDATORS);
        currentRandom.length = 0;
        for (uint256 i = 0; i < _random.length; i++) {
            currentRandom.push(_random[i]);
        }
    }

    function moveStake(address _fromObserver, address _toObserver, uint256 _amount) public {
        address staker = msg.sender;
        _withdraw(_fromObserver, staker, _amount);
        _stake(_toObserver, staker, _amount);
        emit StakeMoved(_fromObserver, _toObserver, staker, stakingEpoch, _amount);
    }

    function stake(address _toObserver) public payable {
        address staker = msg.sender;
        _stake(_toObserver, staker, msg.value);
        emit Staked(_toObserver, staker, stakingEpoch, msg.value);
    }

    function withdraw(address _fromObserver, uint256 _amount) public {
        address staker = msg.sender;
        _withdraw(_fromObserver, staker, _amount);
        staker.transfer(_amount);
        emit Withdrawn(_fromObserver, staker, stakingEpoch, _amount);
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

    // =============================================== Private ========================================================

    function _stake(address _observer, address _staker, uint256 _amount) internal {
        require(_observer != address(0));
        require(_amount != 0);

        bool stakerIsObserver = _staker == _observer; // `staker` makes a stake for himself and becomes an observer

        if (stakerIsObserver) {
            require(observersState[_observer].publicKey.length != 0);
        } else {
            // The observer must firstly make a stake for himself
            require(doesPoolExist(_observer));
        }

        uint256 newStakeAmount = stakeAmount[_observer][_staker].add(_amount);
        require(newStakeAmount >= MIN_STAKE); // the staked amount must be at least MIN_STAKE
        stakeAmount[_observer][_staker] = newStakeAmount;
        stakeAmountByEpoch[_observer][_staker][stakingEpoch] =
            stakeAmountByEpoch[_observer][_staker][stakingEpoch].add(_amount);
        stakeAmountTotal[_observer] = stakeAmountTotal[_observer].add(_amount);

        if (newStakeAmount == _amount) { // if the stake is first
            if (stakerIsObserver) { // if the observer makes a stake for himself
                // Add `_observer` to the array of pools
                poolIndex[_observer] = pools.length;
                pools.push(_observer);
                require(pools.length <= MAX_OBSERVERS);
            } else {
                // Add `_staker` to the array of observer's stakers
                poolStakerIndex[_observer][_staker] = poolStakers[_observer].length;
                poolStakers[_observer].push(_staker);
            }
        }
    }

    function _withdraw(address _observer, address _staker, uint256 _amount) internal {
        require(_observer != address(0));
        require(_amount != 0);

        // How much can `staker` withdraw from `_observer` pool on the current staking epoch?
        require(_amount <= maxWithdrawAllowed(_observer, _staker));

        // The amount to be withdrawn must be the whole staked amount or
        // must not exceed the diff between the entire amount and MIN_STAKE
        uint256 newStakeAmount = stakeAmount[_observer][_staker].sub(_amount);
        require(newStakeAmount == 0 || newStakeAmount >= MIN_STAKE);
        stakeAmount[_observer][_staker] = newStakeAmount;
        if (_amount <= stakeAmountByEpoch[_observer][_staker][stakingEpoch]) {
            stakeAmountByEpoch[_observer][_staker][stakingEpoch] -= _amount;
        } else {
            stakeAmountByEpoch[_observer][_staker][stakingEpoch] = 0;
        }
        stakeAmountTotal[_observer] = stakeAmountTotal[_observer].sub(_amount);

        if (newStakeAmount == 0) { // the whole amount has been withdrawn
            uint256 indexToRemove;
            if (_staker == _observer) {
                // Remove `_observer` from the array of pools
                indexToRemove = poolIndex[_observer];
                pools[indexToRemove] = pools[pools.length - 1];
                poolIndex[pools[indexToRemove]] = indexToRemove;
                pools.length--;
                delete poolIndex[_observer];
            } else {
                // Remove `_staker` from the array of observer's stakers
                indexToRemove = poolStakerIndex[_observer][_staker];
                poolStakers[_observer][indexToRemove] =
                    poolStakers[_observer][poolStakers[_observer].length];
                poolStakerIndex[_observer][poolStakers[_observer][indexToRemove]] =
                    indexToRemove;
                poolStakers[_observer].length--;
                delete poolStakerIndex[_observer][_staker];
            }
        }
    }

    function _getRandomIndex(uint256[] _likelihood, uint256 _likelihoodSum, uint256 _randomNumber)
        internal
        pure
        returns(uint256)
    {
        int256 r = int256(_randomNumber % _likelihoodSum) + 1;
        int256 index = -1;
        do {
            r -= int256(_likelihood[uint256(++index)]);
        } while (r > 0);
        return uint256(index);
    }
}
