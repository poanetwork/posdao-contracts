pragma solidity 0.5.10;

import "./interfaces/IBlockRewardAuRa.sol";
import "./interfaces/IRandomAuRa.sol";
import "./interfaces/IStakingAuRa.sol";
import "./interfaces/IValidatorSetAuRa.sol";
import "./upgradeability/UpgradeabilityAdmin.sol";
import "./libs/SafeMath.sol";


/// @dev Stores the current validator set and contains the logic for choosing new validators
/// before each staking epoch. The logic uses a random seed generated and stored by the `RandomAuRa` contract.
contract ValidatorSetAuRa is UpgradeabilityAdmin, IValidatorSetAuRa {
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

    /// @dev The pool id of the non-removable validator.
    /// Returns zero if a non-removable validator is not defined.
    uint256 public unremovableValidator;

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
    mapping(address => bool) public hasEverBeenMiningAddress;

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

    // ============================================== Constants =======================================================

    /// @dev The max number of validators.
    uint256 public constant MAX_VALIDATORS = 19;

    // ================================================ Events ========================================================

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
        uint256 blockNumber,
        uint256 reportingPoolId,
        uint256 maliciousPoolId
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

    /// @dev Ensures the caller is the SYSTEM_ADDRESS. See https://openethereum.github.io/wiki/Validator-Set.html
    modifier onlySystem() {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    // =============================================== Setters ========================================================

    /// @dev Makes the non-removable validator removable. Can only be called by the staking address of the
    /// non-removable validator or by the `owner`.
    function clearUnremovableValidator() external onlyInitialized {
        require(unremovableValidator != 0);
        address unremovableStakingAddress = stakingAddressById[unremovableValidator];
        require(msg.sender == unremovableStakingAddress || msg.sender == _admin());
        unremovableValidator = 0;
        stakingContract.clearUnremovableValidator(unremovableValidator);
        lastChangeBlock = _getCurrentBlockNumber();
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
    function finalizeChange() external onlySystem {
        if (_finalizeValidators.forNewEpoch) {
            // Apply a new validator set formed by the `newValidatorSet` function
            _savePreviousValidators();
            _finalizeNewValidators(true);
            IBlockRewardAuRa(blockRewardContract).clearBlocksCreated();
            validatorSetApplyBlock = _getCurrentBlockNumber();
        } else if (_finalizeValidators.list.length != 0) {
            // Apply the changed validator set after malicious validator is removed
            _finalizeNewValidators(false);
        } else {
            // This is the very first call of the `finalizeChange` (block #1 when starting from genesis)
            validatorSetApplyBlock = _getCurrentBlockNumber();
        }
        delete _finalizeValidators; // since this moment the `emitInitiateChange` is allowed
        lastChangeBlock = _getCurrentBlockNumber();
    }

    /// @dev Initializes the network parameters. Used by the
    /// constructor of the `InitializerAuRa` contract.
    /// @param _blockRewardContract The address of the `BlockRewardAuRa` contract.
    /// @param _randomContract The address of the `RandomAuRa` contract.
    /// @param _stakingContract The address of the `StakingAuRa` contract.
    /// @param _initialMiningAddresses The array of initial validators' mining addresses.
    /// @param _initialStakingAddresses The array of initial validators' staking addresses.
    /// @param _firstValidatorIsUnremovable The boolean flag defining whether the first validator in the
    /// `_initialMiningAddresses/_initialStakingAddresses` array is non-removable.
    /// Should be `false` for a production network.
    function initialize(
        address _blockRewardContract,
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

        blockRewardContract = _blockRewardContract;
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
                unremovableValidator = poolId;
            }
        }
    }

    /// @dev Implements the logic which forms a new validator set. If the number of active pools
    /// is greater than MAX_VALIDATORS, the logic chooses the validators randomly using a random seed generated and
    /// stored by the `RandomAuRa` contract.
    /// Automatically called by the `BlockRewardAuRa.reward` function at the latest block of the staking epoch.
    function newValidatorSet() external onlyBlockRewardContract {
        uint256[] memory poolsToBeElected = stakingContract.getPoolsToBeElected();

        // Choose new validators
        if (
            poolsToBeElected.length >= MAX_VALIDATORS &&
            (poolsToBeElected.length != MAX_VALIDATORS || unremovableValidator != 0)
        ) {
            uint256 randomNumber = IRandomAuRa(randomContract).currentSeed();

            (uint256[] memory likelihood, uint256 likelihoodSum) = stakingContract.getPoolsLikelihood();

            if (likelihood.length > 0 && likelihoodSum > 0) {
                uint256[] memory newValidators = new uint256[](
                    unremovableValidator == 0 ? MAX_VALIDATORS : MAX_VALIDATORS - 1
                );

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
        _removeMaliciousValidators(_miningAddresses, "unrevealed");
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
        revert("Temporarily disabled");

        /*
        address reportingMiningAddress = msg.sender;
        uint256 reportingId = idByMiningAddress[reportingMiningAddress];
        uint256 maliciousId = idByMiningAddress[_maliciousMiningAddress];

        if (isReportValidatorValid(reportingMiningAddress)) {
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
                _removeMaliciousValidators(miningAddresses, "spam");
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
            _removeMaliciousValidators(miningAddresses, "malicious");
        }
        */
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
    function addPool(address _miningAddress, address _stakingAddress) external onlyStakingContract returns(uint256) {
        return _addPool(_miningAddress, _stakingAddress);
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
    function isReportValidatorValid(address _miningAddress) public view returns(bool) {
        uint256 poolId = idByMiningAddress[_miningAddress];
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
        if (!isReportValidatorValid(_reportingMiningAddress)) return (false, false);
        if (!isReportValidatorValid(_maliciousMiningAddress)) return (false, false);

        uint256 reportingId = idByMiningAddress[_reportingMiningAddress];
        uint256 maliciousId = idByMiningAddress[_maliciousMiningAddress];
        uint256 validatorsNumber = _currentValidators.length;

        if (validatorsNumber > 1) {
            uint256 currentStakingEpoch = stakingContract.stakingEpoch();
            uint256 reportsNumber = _reportingCounter[reportingId][currentStakingEpoch];
            uint256 reportsTotalNumber = _reportingCounterTotal[currentStakingEpoch];
            uint256 averageReportsNumber = 0;

            if (reportsTotalNumber >= reportsNumber) {
                averageReportsNumber = (reportsTotalNumber - reportsNumber) / (validatorsNumber - 1);
            }

            if (reportsNumber > validatorsNumber * 50 && reportsNumber > averageReportsNumber * 10) {
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
        uint256 maliciousId = idByMiningAddress[_maliciousMiningAddress];
        if (isValidatorIdBanned(maliciousId)) {
            // We shouldn't report of the malicious validator
            // as it has already been reported
            return false;
        }
        uint256 reportingId = idByMiningAddress[_reportingMiningAddress];
        return !_maliceReportedForBlockMapped[maliciousId][_blockNumber][reportingId];
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

    /// @dev Updates the total reporting counter (see the `_reportingCounterTotal` mapping) for the current
    /// staking epoch after the specified validator is removed as malicious. The `reportMaliciousCallable` getter
    /// uses this counter for reporting checks so it must be up-to-date. Called by the `_removeMaliciousValidators`
    /// internal function.
    /// @param _miningAddress The mining address of the removed malicious validator.
    function _clearReportingCounter(address _miningAddress) internal {
        uint256 poolId = idByMiningAddress[_miningAddress];
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
        uint256 poolId = idByMiningAddress[_miningAddress];

        if (poolId == unremovableValidator) {
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

        // Remove malicious validator from the `pools`
        stakingContract.removePool(poolId);

        uint256 length = _pendingValidators.length;

        if (length == 1) {
            // If the removed validator is one and only in the validator set, don't let remove them
            return false;
        }

        for (uint256 i = 0; i < length; i++) {
            if (_pendingValidators[i] == poolId) {
                // Remove the malicious validator from `_pendingValidators`
                _pendingValidators[i] = _pendingValidators[length - 1];
                _pendingValidators.length--;
                return true;
            }
        }

        return false;
    }

    /// @dev Removes the specified validators as malicious from the pending validator set and marks the updated
    /// pending validator set as `changed` to be used by the `emitInitiateChange` function. Does nothing if
    /// the specified validators are already banned, non-removable, or don't exist in the pending validator set.
    /// @param _miningAddresses The mining addresses of the malicious validators.
    /// @param _reason A short string of the reason why the mining addresses are treated as malicious,
    /// see the `_removeMaliciousValidator` internal function description for possible values.
    function _removeMaliciousValidators(address[] memory _miningAddresses, bytes32 _reason) internal {
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
                if (pendingValidatorId == unremovableValidator) {
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
            delete _pendingValidators;

            if (unremovableValidator != 0) {
                // Keep unremovable validator
                _pendingValidators.push(unremovableValidator);
            }

            for (uint256 i = 0; i < _poolIds.length; i++) {
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
        require(_getCurrentBlockNumber() == 0, "Temporarily disabled");

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
        require(!hasEverBeenMiningAddress[_miningAddress]);
        require(!hasEverBeenMiningAddress[_stakingAddress]);

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

        hasEverBeenMiningAddress[_miningAddress] = true;
        hasEverBeenStakingAddress[_stakingAddress] = true;

        return poolId;
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
