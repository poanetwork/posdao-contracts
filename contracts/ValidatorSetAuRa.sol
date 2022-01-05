pragma solidity 0.5.10;

import "./base/BanReasons.sol";
import "./interfaces/IBlockRewardAuRa.sol";
import "./interfaces/IGovernance.sol";
import "./interfaces/IRandomAuRa.sol";
import "./interfaces/IStakingAuRa.sol";
import "./interfaces/IValidatorSetAuRa.sol";
import "./upgradeability/UpgradeabilityAdmin.sol";
import "./libs/SafeMath.sol";


/// @dev Stores the current validator set and contains the logic for choosing new validators
/// before each staking epoch. The logic uses a random seed generated and stored by the `RandomAuRa` contract.
contract ValidatorSetAuRa is UpgradeabilityAdmin, BanReasons, IValidatorSetAuRa {
    using SafeMath for uint256;

    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables, do not change their order,
    // and do not change their types!

    uint256[] internal _currentValidators;
    uint256[] internal _pendingValidators;
    uint256[] internal _previousValidators;
    struct ValidatorsList {
        bool forNewEpoch;
        uint256[] list;
    }
    ValidatorsList internal _finalizeValidators;

    bool internal _pendingValidatorsChanged;
    bool internal _pendingValidatorsChangedForNewEpoch;

    mapping(uint256 => mapping(uint256 => uint256[])) internal _maliceReportedForBlock;
    mapping(uint256 => mapping(uint256 => mapping(uint256 => bool))) internal _maliceReportedForBlockMapped;

    /// @dev How many times a given validator (pool id) was banned.
    mapping(uint256 => uint256) internal _banCounter;

    /// @dev The block number when the ban will be lifted for the specified pool id.
    mapping(uint256 => uint256) internal _bannedUntil;

    /// @dev The block number when the ban will be lifted for delegators
    /// of the specified pool (id).
    mapping(uint256 => uint256) internal _bannedDelegatorsUntil;

    /// @dev The reason for the latest ban of the specified pool id. See the `_removeMaliciousValidator`
    /// internal function description for the list of possible reasons.
    mapping(uint256 => bytes32) internal _banReason;

    /// @dev The address of the `BlockRewardAuRa` contract.
    address public blockRewardContract;

    /// @dev The serial number of a validator set change request. The counter is incremented
    /// every time a validator set needs to be changed.
    uint256 public changeRequestCount;

    /// @dev A boolean flag indicating whether the specified pool id is in the current validator set.
    /// See also the `getValidators` getter.
    mapping(uint256 => bool) public isValidatorById;

    /// @dev A boolean flag indicating whether the specified pool id was a validator in the previous set.
    mapping(uint256 => bool) internal _isValidatorPrevious;

    /// @dev A mining address bound to a specified staking address.
    /// See the `_addPool` internal function.
    mapping(address => address) public miningByStakingAddress;

    /// @dev The `RandomAuRa` contract address.
    address public randomContract;

    /// @dev The number of times the specified validator (pool id) reported misbehaviors during the specified
    /// staking epoch. Used by the `reportMaliciousCallable` getter and `reportMalicious` function to determine
    /// whether a validator reported too often.
    mapping(uint256 => mapping(uint256 => uint256)) internal _reportingCounter;

    /// @dev How many times all validators reported misbehaviors during the specified staking epoch.
    /// Used by the `reportMaliciousCallable` getter and `reportMalicious` function to determine
    /// whether a validator reported too often.
    mapping(uint256 => uint256) internal _reportingCounterTotal;

    /// @dev A staking address bound to a specified mining address.
    /// See the `_addPool` internal function.
    mapping(address => address) public stakingByMiningAddress;

    /// @dev The `StakingAuRa` contract address.
    IStakingAuRa public stakingContract;

    /// @dev Deprecated in favor of the `isUnremovableValidator` mapping.
    uint256 private _unremovableValidator;

    /// @dev How many times the given pool id has become a validator.
    mapping(uint256 => uint256) internal _validatorCounter;

    /// @dev The block number when the `finalizeChange` function was called to apply
    /// the current validator set formed by the `newValidatorSet` function. If it is zero,
    /// it means the `newValidatorSet` function has already been called (a new staking epoch has been started),
    /// but the new staking epoch's validator set hasn't yet been finalized by the `finalizeChange` function.
    uint256 public validatorSetApplyBlock;

    /// @dev The block number of the last change in this contract.
    /// Can be used by Staking DApp.
    uint256 public lastChangeBlock;

    /// @dev Designates whether the specified address has ever been a mining address.
    /// Returns pool id which has ever be bound to the specified mining address.
    mapping(address => uint256) public hasEverBeenMiningAddress;

    /// @dev Designates whether the specified address has ever been a staking address.
    mapping(address => bool) public hasEverBeenStakingAddress;

    /// @dev A pool id bound to a specified mining address.
    /// See the `_addPool` internal function.
    mapping(address => uint256) public idByMiningAddress;

    /// @dev A pool id bound to a specified staking address.
    /// See the `_addPool` internal function.
    mapping(address => uint256) public idByStakingAddress;

    /// @dev A pool mining address bound to a specified id.
    /// See the `_addPool` internal function.
    mapping(uint256 => address) public miningAddressById;

    /// @dev A pool staking address bound to a specified id.
    /// See the `_addPool` internal function.
    mapping(uint256 => address) public stakingAddressById;

    /// @dev Stores the last pool id used for a new pool creation.
    /// Increments each time a new pool is created by the `addPool` function.
    uint256 public lastPoolId;

    struct MiningAddressChangeRequest {
        uint256 poolId;
        address newMiningAddress;
    }
    MiningAddressChangeRequest public miningAddressChangeRequest;

    /// @dev Stores pool's name as UTF-8 string.
    mapping(uint256 => string) public poolName;

    /// @dev Stores pool's short description as UTF-8 string.
    mapping(uint256 => string) public poolDescription;

    /// @dev The `Governance` contract address.
    IGovernance public governanceContract;

    /// @dev Contains a list of poolIds of non-removable validators.
    uint256[] internal _unremovableValidators;

    /// @dev Designates whether the specified poolId is an unremovable validator.
    mapping(uint256 => bool) public isUnremovableValidator;

    // ============================================== Constants =======================================================

    /// @dev The max number of validators.
    uint256 public constant MAX_VALIDATORS = 19;

    // ================================================ Events ========================================================

    /// @dev Emitted by the `changeMiningAddress` function.
    /// @param poolId The ID of a pool for which the mining address is changed.
    /// @param oldMiningAddress An old mining address of the pool.
    /// @param newMiningAddress A new mining address of the pool.
    event ChangedMiningAddress(
        uint256 indexed poolId,
        address indexed oldMiningAddress,
        address indexed newMiningAddress
    );

    /// @dev Emitted by the `changeStakingAddress` function.
    /// @param poolId The ID of a pool for which the staking address is changed.
    /// @param oldStakingAddress An old staking address of the pool.
    /// @param newStakingAddress A new staking address of the pool.
    event ChangedStakingAddress(
        uint256 indexed poolId,
        address indexed oldStakingAddress,
        address indexed newStakingAddress
    );

    /// @dev Emitted by the `emitInitiateChange` function when a new validator set
    /// needs to be applied by validator nodes. See https://openethereum.github.io/Validator-Set.html
    /// @param parentHash Should be the parent block hash, otherwise the signal won't be recognized.
    /// @param newSet An array of new validators (their mining addresses).
    event InitiateChange(bytes32 indexed parentHash, address[] newSet);

    /// @dev Emitted by the `reportMalicious` function to signal that a specified validator reported
    /// misbehavior by a specified malicious validator at a specified block number.
    /// @param reportingValidator The mining address of the reporting validator.
    /// @param maliciousValidator The mining address of the malicious validator.
    /// @param blockNumber The block number at which the `maliciousValidator` misbehaved.
    /// @param reportingPoolId The pool id of the reporting validator.
    /// @param maliciousPoolId The pool id of the malicious validator.
    event ReportedMalicious(
        address reportingValidator,
        address maliciousValidator,
        uint256 indexed blockNumber,
        uint256 indexed reportingPoolId,
        uint256 indexed maliciousPoolId
    );

    /// @dev Emitted by the `_setPoolMetadata` function when the pool's metadata is changed.
    /// @param poolId The unique ID of the pool.
    /// @param name A new name of the pool.
    /// @param description A new short description of the pool.
    event SetPoolMetadata(
        uint256 indexed poolId,
        string name,
        string description
    );

    // ============================================== Modifiers =======================================================

    /// @dev Ensures the `initialize` function was called before.
    modifier onlyInitialized {
        require(isInitialized());
        _;
    }

    /// @dev Ensures the caller is the BlockRewardAuRa contract address.
    modifier onlyBlockRewardContract() {
        require(msg.sender == blockRewardContract);
        _;
    }

    /// @dev Ensures the caller is the Governance contract address.
    modifier onlyGovernanceContract() {
        require(msg.sender == address(governanceContract));
        _;
    }

    /// @dev Ensures the caller is the RandomAuRa contract address.
    modifier onlyRandomContract() {
        require(msg.sender == randomContract);
        _;
    }

    /// @dev Ensures the caller is the StakingAuRa contract address.
    modifier onlyStakingContract() {
        require(msg.sender == address(stakingContract));
        _;
    }

    /// @dev Ensures the caller is the SYSTEM_ADDRESS. See https://openethereum.github.io/Validator-Set.html
    modifier onlySystem() {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    // =============================================== Setters ========================================================

    /// @dev Adds a validator to the list of unremovable validators.
    /// @param _poolId Pool ID of the validator.
    function addUnremovableValidator(uint256 _poolId) external {
        require(msg.sender == _admin());
        _addUnremovableValidator(_poolId);
    }

    /// @dev Adds specified validators to the list of unremovable validators.
    /// @param _poolIds Pool IDs of the validators.
    function addUnremovableValidators(uint256[] calldata _poolIds) external {
        require(msg.sender == _admin());
        for (uint256 i = 0; i < _poolIds.length; i++) {
            _addUnremovableValidator(_poolIds[i]);
        }
    }

    /// @dev Makes the non-removable validator removable. Can only be called by the staking address of the
    /// non-removable validator or by the `owner`.
    function clearUnremovableValidator(uint256 _unremovablePoolId) external onlyInitialized {
        require(isUnremovableValidator[_unremovablePoolId]);
        address unremovableStakingAddress = stakingAddressById[_unremovablePoolId];
        require(msg.sender == unremovableStakingAddress || msg.sender == _admin());
        stakingContract.clearUnremovableValidator(_unremovablePoolId);
        for (uint256 i = 0; i < _unremovableValidators.length; i++) {
            if (_unremovableValidators[i] == _unremovablePoolId) {
                _unremovableValidators[i] = _unremovableValidators[_unremovableValidators.length - 1];
                _unremovableValidators.length--;
                break;
            }
        }
        isUnremovableValidator[_unremovablePoolId] = false;
        lastChangeBlock = _getCurrentBlockNumber();
    }

    /// @dev Changes pool's metadata (such as name and short description).
    /// Can only be called by a pool owner (staking address).
    /// @param _name A new name of the pool as UTF-8 string.
    /// @param _description A new short description of the pool as UTF-8 string.
    function changeMetadata(string calldata _name, string calldata _description) external onlyInitialized {
        uint256 poolId = idByStakingAddress[msg.sender];
        require(poolId != 0);
        _setPoolMetadata(poolId, _name, _description);
        lastChangeBlock = _getCurrentBlockNumber();
    }

    /// @dev Makes a request to change validator's mining address or changes the mining address of a candidate pool
    /// immediately. Will fail if there is already another request. Can be called by pool's staking address.
    /// If this is called by a validator pool, the function emits `InitiateChange` event,
    /// so the mining address change is actually applied once the `finalizeChange` function is invoked.
    /// A validator cannot call this function at the end of a staking epoch during the last
    /// two randomness collection rounds (see the `RandomAuRa` contract).
    /// A candidate can call this function at any time.
    /// @param _newMiningAddress The new mining address to set for the pool
    /// whose staking address called this function. The new mining address shouldn't be a former
    /// delegator or a pool (staking address or mining address).
    function changeMiningAddress(address _newMiningAddress) external onlyInitialized {
        address stakingAddress = msg.sender;
        address oldMiningAddress = miningByStakingAddress[stakingAddress];
        uint256 poolId = idByStakingAddress[stakingAddress];
        require(_newMiningAddress != address(0));
        require(oldMiningAddress != address(0));
        require(oldMiningAddress != _newMiningAddress);
        require(poolId != 0);
        require(miningAddressChangeRequest.poolId == 0);

        // Make sure that `_newMiningAddress` has never been a delegator before
        require(stakingContract.getDelegatorPoolsLength(_newMiningAddress) == 0);

        // Make sure that `_newMiningAddress` has never been a mining address before
        require(hasEverBeenMiningAddress[_newMiningAddress] == 0);

        // Make sure that `_newMiningAddress` has never been a staking address before
        require(!hasEverBeenStakingAddress[_newMiningAddress]);

        if (isValidatorById[poolId]) {
            // Since the pool is a validator at the moment, we cannot change their
            // mining address immediately. We create a request to change the address instead.
            // The request will be applied by the `finalizeChange` function once the new
            // validator set is applied.
            require(initiateChangeAllowed());
            require(!_pendingValidatorsChanged);

            // Deny requesting on the latest two randomness collection rounds
            // to prevend unrevealing due to validator's mining key change.
            require(_getCurrentBlockNumber() < stakingContract.stakingEpochEndBlock().sub(
                IRandomAuRa(randomContract).collectRoundLength().mul(2)
            ));

            address[] memory newSet = getPendingValidators();
            for (uint256 i = 0; i < newSet.length; i++) {
                if (newSet[i] == oldMiningAddress) {
                    newSet[i] = _newMiningAddress;
                    break;
                }
            }

            _finalizeValidators.list = _pendingValidators;
            miningAddressChangeRequest.poolId = poolId;
            miningAddressChangeRequest.newMiningAddress = _newMiningAddress;

            IRandomAuRa(randomContract).clearCommit(poolId);

            emit InitiateChange(blockhash(_getCurrentBlockNumber() - 1), newSet);
        } else {
            // The pool is not a validator. It is a candidate,
            // so we can change its mining address right now.
            _changeMiningAddress(oldMiningAddress, _newMiningAddress, poolId, stakingAddress);
            lastChangeBlock = _getCurrentBlockNumber();
        }

        emit ChangedMiningAddress(poolId, oldMiningAddress, _newMiningAddress);
    }

    /// @dev Changes the staking address of a pool. Will fail if there is already another request
    /// to change mining address (see `changeMiningAddress` code). Can be called by pool's staking address.
    /// Can be called at any time during a staking epoch.
    /// @param _newStakingAddress The new staking address to set for the pool
    /// whose old staking address called this function. The new staking address shouldn't be a former
    /// delegator or a pool (staking address or mining address).
    function changeStakingAddress(address _newStakingAddress) external onlyInitialized {
        address oldStakingAddress = msg.sender;

        uint256 poolId = idByStakingAddress[oldStakingAddress];
        require(_newStakingAddress != address(0));
        require(oldStakingAddress != _newStakingAddress);
        require(poolId != 0);
        require(miningAddressChangeRequest.poolId == 0);

        // Make sure that `_newStakingAddress` has never been a delegator before
        require(stakingContract.getDelegatorPoolsLength(_newStakingAddress) == 0);

        // Make sure that `_newStakingAddress` has never been a mining address before
        require(hasEverBeenMiningAddress[_newStakingAddress] == 0);

        // Make sure that `_newStakingAddress` has never been a staking address before
        require(!hasEverBeenStakingAddress[_newStakingAddress]);

        address miningAddress = miningAddressById[poolId];

        idByStakingAddress[oldStakingAddress] = 0;
        idByStakingAddress[_newStakingAddress] = poolId;

        miningByStakingAddress[oldStakingAddress] = address(0);
        miningByStakingAddress[_newStakingAddress] = miningAddress;

        stakingAddressById[poolId] = _newStakingAddress;
        stakingByMiningAddress[miningAddress] = _newStakingAddress;
        hasEverBeenStakingAddress[_newStakingAddress] = true;

        lastChangeBlock = _getCurrentBlockNumber();

        emit ChangedStakingAddress(poolId, oldStakingAddress, _newStakingAddress);
    }

    /// @dev Emits the `InitiateChange` event to pass a new validator set to the validator nodes.
    /// Called automatically by one of the current validator's nodes when the `emitInitiateChangeCallable` getter
    /// returns `true` (when some validator needs to be removed as malicious or the validator set needs to be
    /// updated at the beginning of a new staking epoch). The new validator set is passed to the validator nodes
    /// through the `InitiateChange` event and saved for later use by the `finalizeChange` function.
    /// See https://openethereum.github.io/Validator-Set.html for more info about the `InitiateChange` event.
    function emitInitiateChange() external onlyInitialized {
        require(emitInitiateChangeCallable());
        bool forNewEpoch = _unsetPendingValidatorsChanged();
        if (_pendingValidators.length > 0) {
            emit InitiateChange(blockhash(_getCurrentBlockNumber() - 1), getPendingValidators());
            _finalizeValidators.list = _pendingValidators;
            _finalizeValidators.forNewEpoch = forNewEpoch;
            lastChangeBlock = _getCurrentBlockNumber();
        }
    }

    /// @dev Called by the system when an initiated validator set change reaches finality and is activated.
    /// This function is called at the beginning of a block (before all the block transactions).
    /// Only valid when msg.sender == SUPER_USER (EIP96, 2**160 - 2). Stores a new validator set saved
    /// before by the `emitInitiateChange` function and passed through the `InitiateChange` event.
    /// After this function is called, the `getValidators` getter returns the new validator set.
    /// If this function finalizes a new validator set formed by the `newValidatorSet` function,
    /// an old validator set is also stored into the `_previousValidators` array.
    /// The `finalizeChange` is only called once for each `InitiateChange` event emitted. The next `InitiateChange`
    /// event is not emitted until the previous one is not yet finalized by the `finalizeChange`
    /// (see the code of `emitInitiateChangeCallable` getter).
    /// The function has unlimited gas (according to OpenEthereum and/or Nethermind client code).
    function finalizeChange() external onlySystem {
        if (_finalizeValidators.forNewEpoch) {
            // Apply a new validator set formed by the `newValidatorSet` function
            _savePreviousValidators();
            _finalizeNewValidators(true);
            IBlockRewardAuRa(blockRewardContract).clearBlocksCreated();
            validatorSetApplyBlock = _getCurrentBlockNumber();
        } else if (_finalizeValidators.list.length != 0) {
            // Apply the changed validator set after malicious validator is removed.
            // It is also called after the `changeMiningAddress` function is called for a validator.
            _finalizeNewValidators(false);
        } else {
            // This is the very first call of the `finalizeChange` (block #1 when starting from genesis)
            validatorSetApplyBlock = _getCurrentBlockNumber();
        }

        _applyMiningAddressChangeRequest();

        delete _finalizeValidators; // since this moment the `emitInitiateChange` is allowed
        lastChangeBlock = _getCurrentBlockNumber();
    }

    /// @dev Initializes the network parameters. Used by the
    /// constructor of the `InitializerAuRa` contract.
    /// @param _blockRewardContract The address of the `BlockRewardAuRa` contract.
    /// @param _governanceContract The address of the `Governance` contract.
    /// @param _randomContract The address of the `RandomAuRa` contract.
    /// @param _stakingContract The address of the `StakingAuRa` contract.
    /// @param _initialMiningAddresses The array of initial validators' mining addresses.
    /// @param _initialStakingAddresses The array of initial validators' staking addresses.
    /// @param _firstValidatorIsUnremovable The boolean flag defining whether the first validator in the
    /// `_initialMiningAddresses/_initialStakingAddresses` array is non-removable.
    /// Should be `false` for a production network.
    function initialize(
        address _blockRewardContract,
        address _governanceContract,
        address _randomContract,
        address _stakingContract,
        address[] calldata _initialMiningAddresses,
        address[] calldata _initialStakingAddresses,
        bool _firstValidatorIsUnremovable
    ) external {
        require(_getCurrentBlockNumber() == 0 || msg.sender == _admin());
        require(!isInitialized()); // initialization can only be done once
        require(_blockRewardContract != address(0));
        require(_randomContract != address(0));
        require(_stakingContract != address(0));
        require(_initialMiningAddresses.length > 0);
        require(_initialMiningAddresses.length == _initialStakingAddresses.length);
        require(_initialMiningAddresses.length <= MAX_VALIDATORS);

        blockRewardContract = _blockRewardContract;
        governanceContract = IGovernance(_governanceContract);
        randomContract = _randomContract;
        stakingContract = IStakingAuRa(_stakingContract);
        lastChangeBlock = _getCurrentBlockNumber();

        // Add initial validators to the `_currentValidators` array
        for (uint256 i = 0; i < _initialMiningAddresses.length; i++) {
            address miningAddress = _initialMiningAddresses[i];
            address stakingAddress = _initialStakingAddresses[i];
            uint256 poolId = _addPool(miningAddress, stakingAddress);
            _currentValidators.push(poolId);
            _pendingValidators.push(poolId);
            isValidatorById[poolId] = true;
            _validatorCounter[poolId]++;

            if (i == 0 && _firstValidatorIsUnremovable) {
                _unremovableValidators.push(poolId);
                isUnremovableValidator[poolId] = true;
            }
        }
    }

    // Temporary function to initialize a new set of unremovable validators.
    function initUnremovableValidators() external {
        require(msg.sender == _admin());
        require(_unremovableValidators.length == 0);
        require(_unremovableValidator == 606253130765665412215227113255708804686646306692);
        _unremovableValidators.push(_unremovableValidator);
        _unremovableValidators.push(512347112651376259641477594089983356080222555861);
        isUnremovableValidator[_unremovableValidator] = true;
        isUnremovableValidator[512347112651376259641477594089983356080222555861] = true;
        stakingContract.addUnremovableValidator(_unremovableValidator);
        stakingContract.addUnremovableValidator(512347112651376259641477594089983356080222555861);
        _unremovableValidator = 0;
    }

    /// @dev Implements the logic which forms a new validator set. If the number of active pools
    /// is greater than MAX_VALIDATORS, the logic chooses the validators randomly using a random seed generated and
    /// stored by the `RandomAuRa` contract.
    /// Automatically called by the `BlockRewardAuRa.reward` function
    /// at the end of the latest block of the staking epoch.
    function newValidatorSet() external onlyBlockRewardContract {
        uint256[] memory poolsToBeElected = stakingContract.getPoolsToBeElected();

        uint256 freeSlots =
            MAX_VALIDATORS >= _unremovableValidators.length ? MAX_VALIDATORS - _unremovableValidators.length : 0;

        // Choose new validators
        if (poolsToBeElected.length > freeSlots && freeSlots != 0) {
            uint256 randomNumber = IRandomAuRa(randomContract).currentSeed();

            (uint256[] memory likelihood, uint256 likelihoodSum) = stakingContract.getPoolsLikelihood();

            if (likelihood.length > 0 && likelihoodSum > 0) {
                uint256[] memory newValidators = new uint256[](freeSlots);

                uint256 poolsToBeElectedLength = poolsToBeElected.length;
                for (uint256 i = 0; i < newValidators.length; i++) {
                    randomNumber = uint256(keccak256(abi.encode(randomNumber)));
                    uint256 randomPoolIndex = _getRandomIndex(likelihood, likelihoodSum, randomNumber);
                    newValidators[i] = poolsToBeElected[randomPoolIndex];
                    likelihoodSum -= likelihood[randomPoolIndex];
                    poolsToBeElectedLength--;
                    poolsToBeElected[randomPoolIndex] = poolsToBeElected[poolsToBeElectedLength];
                    likelihood[randomPoolIndex] = likelihood[poolsToBeElectedLength];
                }

                _setPendingValidators(newValidators);
            }
        } else {
            _setPendingValidators(poolsToBeElected);
        }

        // From this moment the `getPendingValidators()` returns the new validator set.
        // Let the `emitInitiateChange` function know that the validator set is changed and needs
        // to be passed to the `InitiateChange` event.
        _setPendingValidatorsChanged(true);

        if (poolsToBeElected.length != 0) {
            // Remove pools marked as `to be removed`
            stakingContract.removePools();
        }
        stakingContract.incrementStakingEpoch();
        stakingContract.setStakingEpochStartBlock(_getCurrentBlockNumber() + 1);
        validatorSetApplyBlock = 0;
        lastChangeBlock = _getCurrentBlockNumber();
    }

    /// @dev Removes malicious validators. Called by the `RandomAuRa.onFinishCollectRound` function.
    /// @param _miningAddresses The mining addresses of the malicious validators.
    function removeMaliciousValidators(address[] calldata _miningAddresses) external onlyRandomContract {
        _removeMaliciousValidators(_miningAddresses, BAN_REASON_UNREVEALED);
    }

    /// @dev Removes a validator from the validator set and bans its pool.
    /// Can only be called by the Governance contract.
    /// @param _poolId A pool id of the removed validator.
    /// @param _banUntilBlock The number of the latest block of a ban period.
    /// @param _reason Can be one of the following:
    /// - "often block delays"
    /// - "often block skips"
    /// - "often reveal skips"
    /// - "unrevealed"
    function removeValidator(uint256 _poolId, uint256 _banUntilBlock, bytes32 _reason) external onlyGovernanceContract {
        if (isUnremovableValidator[_poolId]) {
            return;
        }

        require(miningAddressById[_poolId] != address(0));
        require(_banUntilBlock != 0);

        if (_banUntilBlock > _bannedUntil[_poolId]) {
            _bannedUntil[_poolId] = _banUntilBlock;
        }
        _banCounter[_poolId]++;
        _banReason[_poolId] = _reason;

        if (_removePool(_poolId)) {
            _setPendingValidatorsChanged(false);
        }

        lastChangeBlock = _getCurrentBlockNumber();
    }

    /// @dev Reports that the malicious validator misbehaved at the specified block.
    /// Called by the node of each honest validator after the specified validator misbehaved.
    /// See https://openethereum.github.io/Validator-Set.html#reporting-contract
    /// Can only be called when the `reportMaliciousCallable` getter returns `true`.
    /// @param _maliciousMiningAddress The mining address of the malicious validator.
    /// @param _blockNumber The block number where the misbehavior was observed.
    function reportMalicious(
        address _maliciousMiningAddress,
        uint256 _blockNumber,
        bytes calldata
    ) external onlyInitialized {
        address reportingMiningAddress = msg.sender;
        uint256 reportingId = idByMiningAddress[reportingMiningAddress];
        uint256 maliciousId = hasEverBeenMiningAddress[_maliciousMiningAddress];

        if (isReportValidatorValid(reportingMiningAddress, true)) {
            _incrementReportingCounter(reportingId);
        }

        (
            bool callable,
            bool removeReportingValidator
        ) = reportMaliciousCallable(
            reportingMiningAddress,
            _maliciousMiningAddress,
            _blockNumber
        );

        if (!callable) {
            if (removeReportingValidator) {
                // Reporting validator reported too often, so
                // treat them as a malicious as well
                address[] memory miningAddresses = new address[](1);
                miningAddresses[0] = reportingMiningAddress;
                _removeMaliciousValidators(miningAddresses, BAN_REASON_SPAM);
            }
            return;
        }

        uint256[] storage reportedValidators = _maliceReportedForBlock[maliciousId][_blockNumber];

        reportedValidators.push(reportingId);
        _maliceReportedForBlockMapped[maliciousId][_blockNumber][reportingId] = true;

        emit ReportedMalicious(
            reportingMiningAddress,
            _maliciousMiningAddress,
            _blockNumber,
            reportingId,
            maliciousId
        );

        // If more than 1/2 of validators reported about malicious validator
        // for the same `blockNumber`
        if (reportedValidators.length.mul(2) > _currentValidators.length) {
            address[] memory miningAddresses = new address[](1);
            miningAddresses[0] = _maliciousMiningAddress;
            _removeMaliciousValidators(miningAddresses, BAN_REASON_MALICIOUS);
        }
    }

    /// @dev Binds a mining address to the specified staking address and vice versa,
    /// generates a unique ID for the newly created pool, binds it to the mining/staking addresses,
    /// and returns it as a result.
    /// Called by the `StakingAuRa.addPool` function when a user wants to become a candidate and creates a pool.
    /// See also the `miningByStakingAddress`, `stakingByMiningAddress`, `idByMiningAddress`, `idByStakingAddress`,
    /// `miningAddressById`, `stakingAddressById` public mappings.
    /// @param _miningAddress The mining address of the newly created pool. Cannot be equal to the `_stakingAddress`
    /// and should never be used as a pool or delegator before.
    /// @param _stakingAddress The staking address of the newly created pool. Cannot be equal to the `_miningAddress`
    /// and should never be used as a pool or delegator before.
    /// @param _name A name of the pool as UTF-8 string (max length is 256 bytes).
    /// @param _description A short description of the pool as UTF-8 string (max length is 1024 bytes).
    function addPool(
        address _miningAddress,
        address _stakingAddress,
        string calldata _name,
        string calldata _description
    ) external onlyStakingContract returns(uint256) {
        uint256 poolId = _addPool(_miningAddress, _stakingAddress);
        _setPoolMetadata(poolId, _name, _description);
        return poolId;
    }

    // =============================================== Getters ========================================================

    /// @dev Returns a boolean flag indicating whether delegators of the specified pool are currently banned.
    /// A validator pool can be banned when they misbehave (see the `_removeMaliciousValidator` function).
    /// @param _miningAddress The mining address of the pool.
    function areDelegatorsBanned(address _miningAddress) public view returns(bool) {
        return _getCurrentBlockNumber() <= bannedDelegatorsUntil(_miningAddress);
    }

    /// @dev Returns a boolean flag indicating whether delegators of the specified pool are currently banned.
    /// A validator pool can be banned when they misbehave (see the `_removeMaliciousValidator` function).
    /// @param _poolId An id of the pool.
    function areIdDelegatorsBanned(uint256 _poolId) public view returns(bool) {
        return _getCurrentBlockNumber() <= _bannedDelegatorsUntil[_poolId];
    }

    /// @dev Returns how many times a given validator was banned.
    /// @param _miningAddress The mining address of the validator.
    function banCounter(address _miningAddress) public view returns(uint256) {
        return _banCounter[idByMiningAddress[_miningAddress]];
    }

    /// @dev Returns the block number when the ban will be lifted for the specified mining address.
    /// @param _miningAddress The mining address of the pool.
    function bannedUntil(address _miningAddress) public view returns(uint256) {
        return _bannedUntil[idByMiningAddress[_miningAddress]];
    }

    /// @dev Returns the block number when the ban will be lifted for delegators
    /// of the specified pool (mining address).
    /// @param _miningAddress The mining address of the pool.
    function bannedDelegatorsUntil(address _miningAddress) public view returns(uint256) {
        return _bannedDelegatorsUntil[idByMiningAddress[_miningAddress]];
    }

    /// @dev Returns the reason for the latest ban of the specified mining address. See the `_removeMaliciousValidator`
    /// internal function description for the list of possible reasons.
    /// @param _miningAddress The mining address of the pool.
    function banReason(address _miningAddress) public view returns(bytes32) {
        return _banReason[idByMiningAddress[_miningAddress]];
    }

    /// @dev Returns a boolean flag indicating whether the `emitInitiateChange` function can be called
    /// at the moment. Used by a validator's node and `TxPermission` contract (to deny dummy calling).
    function emitInitiateChangeCallable() public view returns(bool) {
        return initiateChangeAllowed() && _pendingValidatorsChanged;
    }

    /// @dev Returns the current array of validators which should be passed to the `InitiateChange` event.
    /// The pending array is changed when a validator is removed as malicious
    /// or the validator set is updated by the `newValidatorSet` function.
    /// Every time the pending array is changed, it is marked by the `_setPendingValidatorsChanged` and then
    /// used by the `emitInitiateChange` function which emits the `InitiateChange` event to all
    /// validator nodes.
    function getPendingValidators() public view returns(address[] memory) {
        address[] memory miningAddresses = new address[](_pendingValidators.length);
        for (uint256 i = 0; i < miningAddresses.length; i++) {
            miningAddresses[i] = miningAddressById[_pendingValidators[i]];
        }
        return miningAddresses;
    }

    /// @dev Returns the current array of validators (their pool ids).
    /// The pending array is changed when a validator is removed as malicious
    /// or the validator set is updated by the `newValidatorSet` function.
    /// Every time the pending array is changed, it is marked by the `_setPendingValidatorsChanged` and then
    /// used by the `emitInitiateChange` function which emits the `InitiateChange` event to all
    /// validator nodes.
    function getPendingValidatorsIds() public view returns(uint256[] memory) {
        return _pendingValidators;
    }

    /// @dev Returns the current validator set (an array of mining addresses)
    /// which always matches the validator set kept in validator's node.
    function getValidators() public view returns(address[] memory) {
        address[] memory miningAddresses = new address[](_currentValidators.length);
        for (uint256 i = 0; i < miningAddresses.length; i++) {
            miningAddresses[i] = miningAddressById[_currentValidators[i]];
        }
        return miningAddresses;
    }

    /// @dev Returns the current validator set (an array of pool ids).
    function getValidatorsIds() public view returns(uint256[] memory) {
        return _currentValidators;
    }

    /// @dev A boolean flag indicating whether the `emitInitiateChange` can be called at the moment.
    /// Used by the `emitInitiateChangeCallable` getter. This flag is set to `false` by the `emitInitiateChange`
    /// and set to `true` by the `finalizeChange` function. When the `InitiateChange` event is emitted by
    /// `emitInitiateChange`, the next `emitInitiateChange` call is not possible until the validator set from
    /// the previous call is finalized by the `finalizeChange` function.
    function initiateChangeAllowed() public view returns(bool) {
        return _finalizeValidators.list.length == 0;
    }

    /// @dev Returns a boolean flag indicating if the `initialize` function has been called.
    function isInitialized() public view returns(bool) {
        return blockRewardContract != address(0);
    }

    /// @dev Returns a boolean flag indicating whether the specified mining address is in the current validator set.
    /// See also the `getValidators` getter.
    function isValidator(address _miningAddress) public view returns(bool) {
        return isValidatorById[idByMiningAddress[_miningAddress]];
    }

    /// @dev Returns a boolean flag indicating whether the specified validator (mining address)
    /// is able to call the `reportMalicious` function or whether the specified validator (mining address)
    /// can be reported as malicious. This function also allows a validator to call the `reportMalicious`
    /// function several blocks after ceasing to be a validator. This is possible if a
    /// validator did not have the opportunity to call the `reportMalicious` function prior to the
    /// engine calling the `finalizeChange` function.
    /// @param _miningAddress The validator's mining address.
    /// @param _reportingValidator Set to true if _miningAddress belongs to reporting validator.
    /// Set to false, if _miningAddress belongs to malicious validator.
    function isReportValidatorValid(address _miningAddress, bool _reportingValidator) public view returns(bool) {
        uint256 poolId;
        if (_reportingValidator) {
            poolId = idByMiningAddress[_miningAddress];
        } else {
            poolId = hasEverBeenMiningAddress[_miningAddress];
        }
        bool isValid = isValidatorById[poolId] && !isValidatorIdBanned(poolId);
        if (stakingContract.stakingEpoch() == 0 || validatorSetApplyBlock == 0) {
            return isValid;
        }
        if (_getCurrentBlockNumber() - validatorSetApplyBlock <= MAX_VALIDATORS) {
            // The current validator set was finalized by the engine,
            // but we should let the previous validators finish
            // reporting malicious validator within a few blocks
            bool previousValidator = _isValidatorPrevious[poolId] && !isValidatorIdBanned(poolId);
            return isValid || previousValidator;
        }
        return isValid;
    }

    /// @dev Returns a boolean flag indicating whether the specified mining address is currently banned.
    /// A validator can be banned when they misbehave (see the `_removeMaliciousValidator` internal function).
    /// @param _miningAddress The mining address.
    function isValidatorBanned(address _miningAddress) public view returns(bool) {
        uint256 bn = bannedUntil(_miningAddress);
        if (bn == 0) {
            // Avoid returning `true` for the genesis block
            return false;
        }
        return _getCurrentBlockNumber() <= bn;
    }

    /// @dev Returns a boolean flag indicating whether the specified pool id is currently banned.
    /// A validator can be banned when they misbehave (see the `_removeMaliciousValidator` internal function).
    /// @param _poolId The pool id.
    function isValidatorIdBanned(uint256 _poolId) public view returns(bool) {
        uint256 bn = _bannedUntil[_poolId];
        if (bn == 0) {
            // Avoid returning `true` for the genesis block
            return false;
        }
        return _getCurrentBlockNumber() <= bn;
    }

    /// @dev Returns a boolean flag indicating whether the specified pool id is a validator
    /// or is in the `_pendingValidators` or `_finalizeValidators` array.
    /// Used by the `StakingAuRa.maxWithdrawAllowed` and `StakingAuRa.maxWithdrawOrderAllowed` getters.
    /// @param _poolId The pool id.
    function isValidatorOrPending(uint256 _poolId) public view returns(bool) {
        if (isValidatorById[_poolId]) {
            return true;
        }

        uint256 i;
        uint256 length;

        length = _finalizeValidators.list.length;
        for (i = 0; i < length; i++) {
            if (_poolId == _finalizeValidators.list[i]) {
                // This validator waits to be finalized,
                // so we treat them as `pending`
                return true;
            }
        }

        length = _pendingValidators.length;
        for (i = 0; i < length; i++) {
            if (_poolId == _pendingValidators[i]) {
                return true;
            }
        }

        return false;
    }

    /// @dev Returns whether the `reportMalicious` function can be called by the specified validator with the
    /// given parameters. Used by the `reportMalicious` function and `TxPermission` contract. Also, returns
    /// a boolean flag indicating whether the reporting validator should be removed as malicious due to
    /// excessive reporting during the current staking epoch.
    /// @param _reportingMiningAddress The mining address of the reporting validator which is calling
    /// the `reportMalicious` function.
    /// @param _maliciousMiningAddress The mining address of the malicious validator which is passed to
    /// the `reportMalicious` function.
    /// @param _blockNumber The block number which is passed to the `reportMalicious` function.
    /// @return `bool callable` - The boolean flag indicating whether the `reportMalicious` function can be called at
    /// the moment. `bool removeReportingValidator` - The boolean flag indicating whether the reporting validator
    /// should be removed as malicious due to excessive reporting. This flag is only used by the `reportMalicious`
    /// function.
    function reportMaliciousCallable(
        address _reportingMiningAddress,
        address _maliciousMiningAddress,
        uint256 _blockNumber
    ) public view returns(bool callable, bool removeReportingValidator) {
        if (!isReportValidatorValid(_reportingMiningAddress, true)) return (false, false);
        if (!isReportValidatorValid(_maliciousMiningAddress, false)) return (false, false);

        uint256 reportingId = idByMiningAddress[_reportingMiningAddress];
        uint256 maliciousId = hasEverBeenMiningAddress[_maliciousMiningAddress];
        uint256 validatorsNumber = _currentValidators.length;

        if (validatorsNumber > 1) {
            uint256 currentStakingEpoch = stakingContract.stakingEpoch();
            uint256 reportsNumber = _reportingCounter[reportingId][currentStakingEpoch];
            uint256 reportsTotalNumber = _reportingCounterTotal[currentStakingEpoch];
            uint256 averageReportsNumberX10 = 0;

            if (reportsTotalNumber >= reportsNumber) {
                averageReportsNumberX10 = (reportsTotalNumber - reportsNumber) * 10 / (validatorsNumber - 1);
            }

            if (reportsNumber > validatorsNumber * 50 && reportsNumber > averageReportsNumberX10) {
                return (false, true);
            }
        }

        uint256 currentBlock = _getCurrentBlockNumber();

        if (_blockNumber > currentBlock) return (false, false); // avoid reporting about future blocks

        uint256 ancientBlocksLimit = 100;
        if (currentBlock > ancientBlocksLimit && _blockNumber < currentBlock - ancientBlocksLimit) {
            return (false, false); // avoid reporting about ancient blocks
        }

        if (_maliceReportedForBlockMapped[maliciousId][_blockNumber][reportingId]) {
            // Don't allow reporting validator to report about the same misbehavior more than once
            return (false, false);
        }

        return (true, false);
    }

    /// @dev Only used by Ethereum client (see https://github.com/openethereum/parity-ethereum/pull/11245).
    /// Returns a boolean flag indicating whether the specified validator
    /// should report about some validator's misbehaviour at the specified block.
    /// @param _reportingMiningAddress The mining address of validator who reports.
    /// @param _maliciousMiningAddress The mining address of malicious validator.
    /// @param _blockNumber The block number at which the validator misbehaved.
    function shouldValidatorReport(
        address _reportingMiningAddress,
        address _maliciousMiningAddress,
        uint256 _blockNumber
    ) public view returns(bool) {
        uint256 currentBlock = _getCurrentBlockNumber();
        if (_blockNumber > currentBlock + 1) {
            // we added +1 in the condition to let validator next to the malicious one correctly report
            // because that validator will use the previous block state when calling this getter
            return false;
        }
        if (currentBlock > 100 && currentBlock - 100 > _blockNumber) {
            return false;
        }
        uint256 maliciousId = hasEverBeenMiningAddress[_maliciousMiningAddress];
        if (isValidatorIdBanned(maliciousId)) {
            // We shouldn't report of the malicious validator
            // as it has already been reported
            return false;
        }
        uint256 reportingId = idByMiningAddress[_reportingMiningAddress];
        return !_maliceReportedForBlockMapped[maliciousId][_blockNumber][reportingId];
    }

    /// @dev Returns poolId of the first unremovable validator in the list of unremovable validators.
    /// Deprecated and left for backward compatibility with Staking DApp.
    function unremovableValidator() public view returns(uint256) {
        if (_unremovableValidators.length == 0) {
            return 0;
        }
        return _unremovableValidators[0];
    }

    /// @dev Returns poolIds of unremovable validators.
    function unremovableValidators() public view returns(uint256[] memory) {
        return _unremovableValidators;
    }

    /// @dev Returns how many times the given mining address has become a validator.
    function validatorCounter(address _miningAddress) public view returns(uint256) {
        return _validatorCounter[idByMiningAddress[_miningAddress]];
    }

    /// @dev Returns a validator set about to be finalized by the `finalizeChange` function.
    /// @param miningAddresses An array set by the `emitInitiateChange` function.
    /// @param forNewEpoch A boolean flag indicating whether the `miningAddresses` array was formed by the
    /// `newValidatorSet` function. The `finalizeChange` function logic depends on this flag.
    function validatorsToBeFinalized() public view returns(address[] memory miningAddresses, bool forNewEpoch) {
        miningAddresses = new address[](_finalizeValidators.list.length);
        for (uint256 i = 0; i < miningAddresses.length; i++) {
            miningAddresses[i] = miningAddressById[_finalizeValidators.list[i]];
        }
        return (miningAddresses, _finalizeValidators.forNewEpoch);
    }

    /// @dev Returns a validator set about to be finalized by the `finalizeChange` function.
    function validatorsToBeFinalizedIds() public view returns(uint256[] memory) {
        return _finalizeValidators.list;
    }

    // ============================================== Internal ========================================================

    /// @dev Called by `addUnremovableValidator` and `addUnremovableValidators`.
    /// @param _poolId Pool ID of the validator.
    function _addUnremovableValidator(uint256 _poolId) internal {
        require(!isUnremovableValidator[_poolId]);
        require(_unremovableValidators.length < MAX_VALIDATORS);
        _unremovableValidators.push(_poolId);
        isUnremovableValidator[_poolId] = true;
        stakingContract.addUnremovableValidator(_poolId);
    }

    /// @dev Called by `finalizeChange` function to apply mining address change
    /// requested by a validator through `changeMiningAddress` function.
    function _applyMiningAddressChangeRequest() internal {
        // If there was a request from a validator to change their mining address
        uint256 poolId = miningAddressChangeRequest.poolId;
        if (poolId != 0) {
            address oldMiningAddress = miningAddressById[poolId];
            address newMiningAddress = miningAddressChangeRequest.newMiningAddress;
            address stakingAddress = stakingAddressById[poolId];
            _changeMiningAddress(oldMiningAddress, newMiningAddress, poolId, stakingAddress);
        }
        delete miningAddressChangeRequest;
    }

    /// @dev Updates mappings to change mining address of a pool.
    /// Used by the `changeMiningAddress` and `finalizeChange` functions.
    /// @param _oldMiningAddress An old mining address of the pool.
    /// @param _newMiningAddress A new mining address of the pool.
    /// @param _poolId The pool id for which the mining address is being changed.
    /// @param _stakingAddress The current staking address of the pool.
    function _changeMiningAddress(
        address _oldMiningAddress,
        address _newMiningAddress,
        uint256 _poolId,
        address _stakingAddress
    ) internal {
        idByMiningAddress[_oldMiningAddress] = 0;
        idByMiningAddress[_newMiningAddress] = _poolId;

        miningAddressById[_poolId] = _newMiningAddress;
        miningByStakingAddress[_stakingAddress] = _newMiningAddress;

        stakingByMiningAddress[_oldMiningAddress] = address(0);
        stakingByMiningAddress[_newMiningAddress] = _stakingAddress;

        hasEverBeenMiningAddress[_newMiningAddress] = _poolId;
    }

    /// @dev Updates the total reporting counter (see the `_reportingCounterTotal` mapping) for the current
    /// staking epoch after the specified validator is removed as malicious. The `reportMaliciousCallable` getter
    /// uses this counter for reporting checks so it must be up-to-date. Called by the `_removeMaliciousValidators`
    /// internal function.
    /// @param _miningAddress The mining address of the removed malicious validator.
    function _clearReportingCounter(address _miningAddress) internal {
        uint256 poolId = hasEverBeenMiningAddress[_miningAddress];
        uint256 currentStakingEpoch = stakingContract.stakingEpoch();
        uint256 total = _reportingCounterTotal[currentStakingEpoch];
        uint256 counter = _reportingCounter[poolId][currentStakingEpoch];

        _reportingCounter[poolId][currentStakingEpoch] = 0;

        if (total >= counter) {
            _reportingCounterTotal[currentStakingEpoch] -= counter;
        } else {
            _reportingCounterTotal[currentStakingEpoch] = 0;
        }
    }

    /// @dev Sets a new validator set stored in `_finalizeValidators.list` array.
    /// Called by the `finalizeChange` function.
    /// @param _newStakingEpoch A boolean flag defining whether the validator set was formed by the
    /// `newValidatorSet` function.
    function _finalizeNewValidators(bool _newStakingEpoch) internal {
        uint256[] memory validators;
        uint256 i;

        validators = _currentValidators;
        for (i = 0; i < validators.length; i++) {
            isValidatorById[validators[i]] = false;
        }

        _currentValidators = _finalizeValidators.list;

        validators = _currentValidators;
        for (i = 0; i < validators.length; i++) {
            uint256 poolId = validators[i];
            isValidatorById[poolId] = true;
            if (_newStakingEpoch) {
                _validatorCounter[poolId]++;
            }
        }
    }

    /// @dev Marks the pending validator set as changed to be used later by the `emitInitiateChange` function.
    /// Called when a validator is removed from the set as malicious or when a new validator set is formed by
    /// the `newValidatorSet` function.
    /// @param _newStakingEpoch A boolean flag defining whether the pending validator set was formed by the
    /// `newValidatorSet` function. The `finalizeChange` function logic depends on this flag.
    function _setPendingValidatorsChanged(bool _newStakingEpoch) internal {
        _pendingValidatorsChanged = true;
        if (_newStakingEpoch && _pendingValidators.length != 0) {
            _pendingValidatorsChangedForNewEpoch = true;
        }
        changeRequestCount++;
    }

    /// @dev Marks the pending validator set as unchanged before passing it to the `InitiateChange` event
    /// (and then to the `finalizeChange` function). Called by the `emitInitiateChange` function.
    function _unsetPendingValidatorsChanged() internal returns(bool) {
        bool forNewEpoch = _pendingValidatorsChangedForNewEpoch;
        _pendingValidatorsChanged = false;
        _pendingValidatorsChangedForNewEpoch = false;
        return forNewEpoch;
    }

    /// @dev Sets pool metadata (such as name and short description).
    /// @param _poolId The unique ID of the pool.
    /// @param _name A name of the pool as UTF-8 string (256 bytes max).
    /// @param _description A short description of the pool as UTF-8 string (1024 bytes max).
    function _setPoolMetadata(uint256 _poolId, string memory _name, string memory _description) internal {
        require(bytes(_name).length <= 256);
        require(bytes(_description).length <= 1024);
        poolName[_poolId] = _name;
        poolDescription[_poolId] = _description;
        emit SetPoolMetadata(_poolId, _name, _description);
    }

    /// @dev Increments the reporting counter for the specified validator and the current staking epoch.
    /// See the `_reportingCounter` and `_reportingCounterTotal` mappings. Called by the `reportMalicious`
    /// function when the validator reports a misbehavior.
    /// @param _reportingId The pool id of reporting validator.
    function _incrementReportingCounter(uint256 _reportingId) internal {
        uint256 currentStakingEpoch = stakingContract.stakingEpoch();
        _reportingCounter[_reportingId][currentStakingEpoch]++;
        _reportingCounterTotal[currentStakingEpoch]++;
    }

    /// @dev Removes the specified validator as malicious. Used by the `_removeMaliciousValidators` internal function.
    /// @param _miningAddress The removed validator mining address.
    /// @param _reason A short string of the reason why the mining address is treated as malicious:
    /// "unrevealed" - the validator didn't reveal their number at the end of staking epoch or skipped
    /// too many reveals during the staking epoch;
    /// "spam" - the validator made a lot of `reportMalicious` callings compared with other validators;
    /// "malicious" - the validator was reported as malicious by other validators with the `reportMalicious` function.
    /// @return Returns `true` if the specified validator has been removed from the pending validator set.
    /// Otherwise returns `false` (if the specified validator has already been removed or cannot be removed).
    function _removeMaliciousValidator(address _miningAddress, bytes32 _reason) internal returns(bool) {
        uint256 poolId = hasEverBeenMiningAddress[_miningAddress];

        if (isUnremovableValidator[poolId]) {
            return false;
        }

        bool isBanned = isValidatorIdBanned(poolId);

        // Ban the malicious validator for the next 3 months
        _banCounter[poolId]++;
        _bannedUntil[poolId] = _banUntil();
        _banReason[poolId] = _reason;

        if (isBanned) {
            // The validator is already banned
            return false;
        } else {
            _bannedDelegatorsUntil[poolId] = _banUntil();
        }

        // Remove the malicious validator
        return _removePool(poolId);
    }

    /// @dev Removes the specified validators as malicious from the pending validator set and marks the updated
    /// pending validator set as `changed` to be used by the `emitInitiateChange` function. Does nothing if
    /// the specified validators are already banned, non-removable, or don't exist in the pending validator set.
    /// @param _miningAddresses The mining addresses of the malicious validators.
    /// @param _reason A short string of the reason why the mining addresses are treated as malicious,
    /// see the `_removeMaliciousValidator` internal function description for possible values.
    function _removeMaliciousValidators(address[] memory _miningAddresses, bytes32 _reason) internal {
        // Temporarily turned off as all validators known
        /*
        bool removed = false;

        for (uint256 i = 0; i < _miningAddresses.length; i++) {
            if (_removeMaliciousValidator(_miningAddresses[i], _reason)) {
                // From this moment `getPendingValidators()` returns the new validator set
                _clearReportingCounter(_miningAddresses[i]);
                removed = true;
            }
        }

        if (removed) {
            _setPendingValidatorsChanged(false);
        }
        */

        lastChangeBlock = _getCurrentBlockNumber();
    }

    /// @dev Stores previous validators. Used by the `finalizeChange` function.
    function _savePreviousValidators() internal {
        uint256 length;
        uint256 i;

        // Save the previous validator set
        length = _previousValidators.length;
        for (i = 0; i < length; i++) {
            _isValidatorPrevious[_previousValidators[i]] = false;
        }
        length = _currentValidators.length;
        for (i = 0; i < length; i++) {
            _isValidatorPrevious[_currentValidators[i]] = true;
        }
        _previousValidators = _currentValidators;
    }

    /// @dev Sets a new validator set as a pending (which is not yet passed to the `InitiateChange` event).
    /// Called by the `newValidatorSet` function.
    /// @param _poolIds The array of the new validators' pool ids.
    function _setPendingValidators(
        uint256[] memory _poolIds
    ) internal {
        if (_poolIds.length == 0) {
            // If there are no `poolsToBeElected`, we remove the
            // validators which want to exit from the validator set
            for (uint256 i = 0; i < _pendingValidators.length; i++) {
                uint256 pendingValidatorId = _pendingValidators[i];
                if (isUnremovableValidator[pendingValidatorId]) {
                    continue; // don't touch unremovable validator
                }
                if (
                    stakingContract.isPoolActive(pendingValidatorId) &&
                    stakingContract.orderedWithdrawAmount(pendingValidatorId, address(0)) == 0
                ) {
                    // The validator has an active pool and is not going to withdraw their
                    // entire stake, so this validator doesn't want to exit from the validator set
                    continue;
                }
                if (_pendingValidators.length == 1) {
                    break; // don't remove one and only validator
                }
                // Remove the validator
                _pendingValidators[i] = _pendingValidators[_pendingValidators.length - 1];
                _pendingValidators.length--;
                i--;
            }
        } else {
            // If there are some `poolsToBeElected`, we remove all
            // validators which are not in the `poolsToBeElected` or
            // not selected by randomness
            _pendingValidators = _unremovableValidators;

            for (uint256 i = 0; i < _poolIds.length && _pendingValidators.length < MAX_VALIDATORS; i++) {
                _pendingValidators.push(_poolIds[i]);
            }
        }
    }

    /// @dev Binds a mining address to the specified staking address and vice versa,
    /// generates a unique ID for the newly created pool, binds it to the mining/staking addresses, and
    /// returns it as a result.
    /// Used by the `addPool` function. See also the `miningByStakingAddress`, `stakingByMiningAddress`,
    /// `idByMiningAddress`, `idByStakingAddress`, `miningAddressById`, `stakingAddressById` public mappings.
    /// @param _miningAddress The mining address of the newly created pool. Cannot be equal to the `_stakingAddress`
    /// and should never be used as a pool or delegator before.
    /// @param _stakingAddress The staking address of the newly created pool. Cannot be equal to the `_miningAddress`
    /// and should never be used as a pool or delegator before.
    function _addPool(address _miningAddress, address _stakingAddress) internal returns(uint256) {
        require(miningAddressChangeRequest.poolId == 0);
        require(_miningAddress != address(0));
        require(_stakingAddress != address(0));
        require(_miningAddress != _stakingAddress);
        require(miningByStakingAddress[_stakingAddress] == address(0));
        require(miningByStakingAddress[_miningAddress] == address(0));
        require(stakingByMiningAddress[_stakingAddress] == address(0));
        require(stakingByMiningAddress[_miningAddress] == address(0));

        // Make sure that `_miningAddress` and `_stakingAddress` have never been a delegator before
        require(stakingContract.getDelegatorPoolsLength(_miningAddress) == 0);
        require(stakingContract.getDelegatorPoolsLength(_stakingAddress) == 0);

        // Make sure that `_miningAddress` and `_stakingAddress` have never been a mining address before
        require(hasEverBeenMiningAddress[_miningAddress] == 0);
        require(hasEverBeenMiningAddress[_stakingAddress] == 0);

        // Make sure that `_miningAddress` and `_stakingAddress` have never been a staking address before
        require(!hasEverBeenStakingAddress[_miningAddress]);
        require(!hasEverBeenStakingAddress[_stakingAddress]);

        uint256 poolId = ++lastPoolId;

        idByMiningAddress[_miningAddress] = poolId;
        idByStakingAddress[_stakingAddress] = poolId;
        miningAddressById[poolId] = _miningAddress;
        miningByStakingAddress[_stakingAddress] = _miningAddress;
        stakingAddressById[poolId] = _stakingAddress;
        stakingByMiningAddress[_miningAddress] = _stakingAddress;

        hasEverBeenMiningAddress[_miningAddress] = poolId;
        hasEverBeenStakingAddress[_stakingAddress] = true;

        return poolId;
    }

    /// @dev Removes validator pool from the list of active pools
    /// and from the `_pendingValidators` array. Returns `true` if the removal
    /// was successful, `false` - otherwise.
    /// @param _poolId The pool id.
    function _removePool(uint256 _poolId) internal returns(bool) {
        stakingContract.removePool(_poolId);

        uint256 length = _pendingValidators.length;

        if (length == 1) {
            // If the removed validator is one and only in the validator set, don't let remove them
            return false;
        }

        for (uint256 i = 0; i < length; i++) {
            if (_pendingValidators[i] == _poolId) {
                // Remove the malicious validator from `_pendingValidators`
                _pendingValidators[i] = _pendingValidators[length - 1];
                _pendingValidators.length--;
                return true;
            }
        }

        return false;
    }

    /// @dev Returns the future block number until which a validator is banned.
    /// Used by the `_removeMaliciousValidator` internal function.
    function _banUntil() internal view returns(uint256) {
        uint256 blocksUntilEnd = stakingContract.stakingEpochEndBlock() - _getCurrentBlockNumber();
        // ~90 days, at least 12 full staking epochs (for 5 seconds block)
        return _getCurrentBlockNumber() + 12 * stakingContract.stakingEpochDuration() + blocksUntilEnd;
    }

    /// @dev Returns the current block number. Needed mostly for unit tests.
    function _getCurrentBlockNumber() internal view returns(uint256) {
        return block.number;
    }

    /// @dev Returns an index of a pool in the `poolsToBeElected` array
    /// (see the `StakingAuRa.getPoolsToBeElected` public getter)
    /// by a random number and the corresponding probability coefficients.
    /// Used by the `newValidatorSet` function.
    /// @param _likelihood An array of probability coefficients.
    /// @param _likelihoodSum A sum of probability coefficients.
    /// @param _randomNumber A random number.
    function _getRandomIndex(uint256[] memory _likelihood, uint256 _likelihoodSum, uint256 _randomNumber)
        internal
        pure
        returns(uint256)
    {
        uint256 random = _randomNumber % _likelihoodSum;
        uint256 sum = 0;
        uint256 index = 0;
        while (sum <= random) {
            sum += _likelihood[index];
            index++;
        }
        return index - 1;
    }
}
