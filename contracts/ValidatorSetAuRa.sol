pragma solidity 0.5.9;

import "./interfaces/IBlockRewardAuRa.sol";
import "./interfaces/IRandomAuRa.sol";
import "./interfaces/IStakingAuRa.sol";
import "./interfaces/IValidatorSetAuRa.sol";
import "./upgradeability/UpgradeabilityAdmin.sol";
import "./libs/SafeMath.sol";


/// @dev stores the current validator set and contains the logic for choosing new validators
/// at the beginning of each staking epoch. The logic uses a random seed generated
/// and stored by the `RandomAuRa` contract.
contract ValidatorSetAuRa is UpgradeabilityAdmin, IValidatorSetAuRa {
    using SafeMath for uint256;

    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables and do not change their types!

    address[] internal _currentValidators;
    address[] internal _pendingValidators;
    address[] internal _previousValidators;
    address[] internal _queueValidators;
    int256 internal _queuePVFirst;
    int256 internal _queuePVLast;
    bool internal _queueValidatorsNewStakingEpoch;
    struct PendingValidatorsQueue {
        uint256 block;
        bool newEpoch;
        address[] list;
    }
    mapping(int256 => PendingValidatorsQueue) internal _queuePV;

    /// @dev How many times a given mining address was banned.
    mapping(address => uint256) public banCounter;

    /// @dev Returns the block number when the ban will be lifted for the specified mining address.
    mapping(address => uint256) public bannedUntil;

    /// @dev Returns the block number when the ban will be lifted for delegators of the specified mining address.
    mapping(address => uint256) public bannedDelegatorsUntil;

    /// @dev The reason for the latest ban of the specified mining address. See the `_removeMaliciousValidator`
    /// function for the list of possible reasons.
    mapping(address => bytes32) public banReason;

    /// @dev The address of the `BlockReward` contract.
    address public blockRewardContract;

    /// @dev The serial number of a validator set change request. The counter is incremented
    /// every time a validator set needs to be changed.
    uint256 public changeRequestCount;

    /// @dev A boolean flag indicating whether the `emitInitiateChange` can be called at the moment.
    /// Used by the `emitInitiateChangeCallable` getter. This flag is set to `false` by the `emitInitiateChange`
    /// and set to `true` by the `finalizeChange` function. When the `InitiateChange` event is emitted by
    /// `emitInitiateChange`, the next `emitInitiateChange` call is not possible until the previous call is
    /// finalized by the `finalizeChange` function.
    bool public initiateChangeAllowed;

    /// @dev A boolean flag indicating whether the specified mining address is in the current validator set.
    /// See the `getValidators` getter.
    mapping(address => bool) public isValidator;

    /// @dev A boolean flag indicating whether the specified mining address was a validator at the end of
    /// the previous staking epoch. See the `getPreviousValidators` getter.
    mapping(address => bool) public isValidatorOnPreviousEpoch;

    /// @dev An array of the validators (their mining addresses) which reported that the specified malicious
    /// validator (mining address) misbehaved at the specified block.
    mapping(address => mapping(uint256 => address[])) public maliceReportedForBlock;

    /// @dev A mining address bound to a specified staking address.
    /// See the `_setStakingAddress` function.
    mapping(address => address) public miningByStakingAddress;

    /// @dev The `Random` contract address.
    address public randomContract;

    /// @dev The number of times the specified validator (mining address) reported misbehaviors during the specified
    /// staking epoch. Used by the `reportMaliciousCallable` getter to determine whether a validator reported too often.
    mapping(address => mapping(uint256 => uint256)) public reportingCounter;

    /// @dev How many times all validators reported misbehaviors during the specified staking epoch.
    /// Used by the `reportMaliciousCallable` getter to determine whether a validator reported too often.
    mapping(uint256 => uint256) public reportingCounterTotal;

    /// @dev A staking address bound to a specified mining address.
    /// See the `_setStakingAddress` function.
    mapping(address => address) public stakingByMiningAddress;

    /// @dev The `Staking` contract address.
    IStakingAuRa public stakingContract;

    /// @dev The staking address of the non-removable validator.
    /// Returns zero if a non-removable validator is not defined.
    address public unremovableValidator;

    /// @dev How many times the given mining address has become a validator.
    mapping(address => uint256) public validatorCounter;

    /// @dev The index of the specified validator in the current validator set
    /// returned by the `getValidators` getter.
    /// The mining address is accepted as a parameter;
    /// If the value is zero, it may mean the array doesn't contain the address.
    /// Check the address is in the current validator set using the `isValidator` getter.
    mapping(address => uint256) public validatorIndex;

    /// @dev The block number when the `finalizeChange` function was called to apply
    /// the current validator set formed by the `_newValidatorSet` function. If it is zero,
    /// it means the `_newValidatorSet` function has already been called (a new staking epoch has been started),
    /// but the new staking epoch's validator set hasn't yet been finalized by the `finalizeChange` function.
    uint256 public validatorSetApplyBlock;

    // ============================================== Constants =======================================================

    /// @dev The max number of validators.
    uint256 public constant MAX_VALIDATORS = 19;

    // ================================================ Events ========================================================

    /// @dev Emitted by the `emitInitiateChange` function when a new validator set
    /// needs to be applied in the Parity engine. See https://wiki.parity.io/Validator-Set.html
    /// @param parentHash Should be the parent block hash, otherwise the signal won't be recognized.
    /// @param newSet An array of new validators (their mining addresses).
    event InitiateChange(bytes32 indexed parentHash, address[] newSet);

    /// @dev Emitted by the `reportMalicious` function to signal that a specified validator reported
    /// misbehavior by a specified malicious validator at a specified block number.
    /// @param reportingValidator The mining address of the reporting validator.
    /// @param maliciousValidator The mining address of the malicious validator.
    /// @param blockNumber The block number at which the `maliciousValidator` misbehaved.
    event ReportedMalicious(address reportingValidator, address maliciousValidator, uint256 blockNumber);

    // ============================================== Modifiers =======================================================

    /// @dev Ensures the `initialize` function was called before.
    modifier onlyInitialized {
        require(isInitialized());
        _;
    }

    /// @dev Ensures the caller is the BlockRewardAuRa contract address
    /// (EternalStorageProxy proxy contract for the BlockRewardAuRa).
    modifier onlyBlockRewardContract() {
        require(msg.sender == blockRewardContract);
        _;
    }

    /// @dev Ensures the caller is the RandomAuRa contract address
    /// (EternalStorageProxy proxy contract for the RandomAuRa).
    modifier onlyRandomContract() {
        require(msg.sender == randomContract);
        _;
    }

    /// @dev Ensures the caller is the Staking contract address
    /// (EternalStorageProxy proxy contract for Staking).
    modifier onlyStakingContract() {
        require(msg.sender == address(stakingContract));
        _;
    }

    /// @dev Ensures the caller is the SYSTEM_ADDRESS. See https://wiki.parity.io/Validator-Set.html
    modifier onlySystem() {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    // =============================================== Setters ========================================================

    /// @dev Makes the non-removable validator removable. Can only be called by the staking address of the
    /// non-removable validator or by the `owner`.
    function clearUnremovableValidator() external onlyInitialized {
        address unremovableStakingAddress = unremovableValidator;
        bytes32 slot = ADMIN_SLOT;
        address owner;
        assembly {
            owner := sload(slot)
        }
        require(msg.sender == unremovableStakingAddress || msg.sender == owner);
        unremovableValidator = address(0);
        stakingContract.clearUnremovableValidator(unremovableStakingAddress);
    }

    /// @dev Emits the `InitiateChange` event to pass a new validator set to the validator nodes.
    /// Called automatically by one of the current validator's nodes when the `emitInitiateChangeCallable` getter
    /// returns `true` (when some validator needs to be removed as malicious or the validator set needs to be
    /// updated at the beginning of a new staking epoch). The new validator set is passed to the validator nodes
    /// through the `InitiateChange` event and saved for later use by the `finalizeChange` function.
    /// See https://wiki.parity.io/Validator-Set.html for more info about the `InitiateChange` event.
    function emitInitiateChange() external onlyInitialized {
        require(emitInitiateChangeCallable());
        (address[] memory newSet, bool newStakingEpoch) = _dequeuePendingValidators();
        if (newSet.length > 0) {
            emit InitiateChange(blockhash(_getCurrentBlockNumber() - 1), newSet);
            initiateChangeAllowed = false;
            _setQueueValidators(newSet, newStakingEpoch);
        }
    }

    /// @dev Called by the system when an initiated validator set change reaches finality and is activated.
    /// Only valid when msg.sender == SUPER_USER (EIP96, 2**160 - 2). Stores a new validator set saved
    /// before by the `emitInitiateChange` function and passed through the `InitiateChange` event.
    /// After this function is called, the `getValidators` getter returns the new validator set.
    /// If this function finalizes a new validator set formed by the `newValidatorSet` function,
    /// an old validator set is also stored and can be read by the `getPreviousValidators` getter.
    /// The `finalizeChange` is only called once for each `InitiateChange` event emitted. The next `InitiateChange`
    /// event is not emitted until the previous one is not yet finalized by the `finalizeChange`
    /// (this is achieved by the queue, `emitInitiateChange` function, and `initiateChangeAllowed` boolean flag -
    /// see the `_setInitiateChangeAllowed` function).
    function finalizeChange() external onlySystem {
        (address[] memory queueValidators, bool newStakingEpoch) = getQueueValidators();

        if (validatorSetApplyBlock == 0 && newStakingEpoch) {
            // Apply a new validator set formed by the `newValidatorSet` function

            address[] memory previousValidators = getPreviousValidators();
            address[] memory currentValidators = getValidators();
            uint256 i;

            // Save the previous validator set
            for (i = 0; i < previousValidators.length; i++) {
                isValidatorOnPreviousEpoch[previousValidators[i]] = false;
            }
            for (i = 0; i < currentValidators.length; i++) {
                isValidatorOnPreviousEpoch[currentValidators[i]] = true;
            }
            _previousValidators = currentValidators;

            _applyQueueValidators(queueValidators);

            validatorSetApplyBlock = _getCurrentBlockNumber();
        } else if (queueValidators.length > 0) {
            // Apply new validator set after malicious validator is discovered
            _applyQueueValidators(queueValidators);
        } else {
            // This is the very first call of the `finalizeChange`
            validatorSetApplyBlock = _getCurrentBlockNumber();
        }
        initiateChangeAllowed = true;
    }

    /// @dev Initializes the network parameters. Used by the
    /// constructor of the `InitializerAuRa` contract.
    /// @param _blockRewardContract The address of the `BlockReward` contract.
    /// @param _randomContract The address of the `Random` contract.
    /// @param _stakingContract The address of the `Staking` contract.
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

        // Add initial validators to the `_currentValidators` array
        for (uint256 i = 0; i < _initialMiningAddresses.length; i++) {
            _currentValidators.push(_initialMiningAddresses[i]);
            _pendingValidators.push(_initialMiningAddresses[i]);
            validatorIndex[_initialMiningAddresses[i]] = i;
            _setIsValidator(_initialMiningAddresses[i], true);
            _setStakingAddress(_initialMiningAddresses[i], _initialStakingAddresses[i]);
        }

        if (_firstValidatorIsUnremovable) {
            unremovableValidator = _initialStakingAddresses[0];
        }

        _queuePVFirst = 1;
        _queuePVLast = 0;
    }

    /// @dev Implements the logic which forms a new validator set. Calls the internal `_newValidatorSet` function of
    /// the base contract. Automatically called by the `BlockRewardAuRa.reward` function on every block.
    /// @return `bool called` - A boolean flag indicating whether the internal `_newValidatorSet` function was called.
    /// `uint256 poolsToBeElectedLength` - The number of pools ready to be elected
    /// (see the `Staking.getPoolsToBeElected` function). Equals `0` if the `called` flag is `false`.
    function newValidatorSet() external onlyBlockRewardContract returns(bool called, uint256 poolsToBeElectedLength) {
        uint256 currentBlock = _getCurrentBlockNumber();
        if (currentBlock != stakingContract.stakingEpochEndBlock()) return (false, 0);
        called = true;
        poolsToBeElectedLength = _newValidatorSet();
        stakingContract.setStakingEpochStartBlock(currentBlock + 1);
    }

    /// @dev Removes malicious validators. Called by the `RandomAuRa.onFinishCollectRound` function.
    /// @param _miningAddresses The mining addresses of the malicious validators.
    function removeMaliciousValidators(address[] calldata _miningAddresses) external onlyRandomContract {
        _removeMaliciousValidators(_miningAddresses, "unrevealed");
    }

    /// @dev Reports that the malicious validator misbehaved at the specified block.
    /// Called by the node of each honest validator after the specified validator misbehaved.
    /// See https://wiki.parity.io/Validator-Set.html#reporting-contract
    /// Can only be called when the `reportMaliciousCallable` getter returns `true`.
    /// @param _maliciousMiningAddress The mining address of the malicious validator.
    /// @param _blockNumber The block number where the misbehavior was observed.
    function reportMalicious(
        address _maliciousMiningAddress,
        uint256 _blockNumber,
        bytes calldata
    ) external onlyInitialized {
        address reportingMiningAddress = msg.sender;

        _incrementReportingCounter(reportingMiningAddress);

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

        address[] storage reportedValidators = maliceReportedForBlock[_maliciousMiningAddress][_blockNumber];

        reportedValidators.push(reportingMiningAddress);

        emit ReportedMalicious(reportingMiningAddress, _maliciousMiningAddress, _blockNumber);

        uint256 validatorsLength = _currentValidators.length;
        bool remove;

        if (validatorsLength > 3) {
            // If more than 2/3 of validators reported about malicious validator
            // for the same `blockNumber`
            remove = reportedValidators.length.mul(3) > validatorsLength.mul(2);
        } else {
            // If more than 1/2 of validators reported about malicious validator
            // for the same `blockNumber`
            remove = reportedValidators.length.mul(2) > validatorsLength;
        }

        if (remove) {
            address[] memory miningAddresses = new address[](1);
            miningAddresses[0] = _maliciousMiningAddress;
            _removeMaliciousValidators(miningAddresses, "malicious");
        }
    }

    /// @dev Binds a mining address to the specified staking address. Called by the `Staking.addPool` function
    /// when a user wants to become a candidate and create a pool.
    /// See also the `miningByStakingAddress` and `stakingByMiningAddress` getters.
    /// @param _miningAddress The mining address of the newly created pool. Cannot be equal to the `_stakingAddress`.
    /// @param _stakingAddress The staking address of the newly created pool. Cannot be equal to the `_miningAddress`.
    function setStakingAddress(address _miningAddress, address _stakingAddress) external onlyStakingContract {
        _setStakingAddress(_miningAddress, _stakingAddress);
    }

    // =============================================== Getters ========================================================

    /// @dev Returns a boolean flag indicating whether delegators of the specified mining address are currently banned.
    /// A validator pool can be banned when they misbehave (see the `_removeMaliciousValidator` function).
    /// @param _miningAddress The mining address.
    function areDelegatorsBanned(address _miningAddress) public view returns(bool) {
        return _getCurrentBlockNumber() <= bannedDelegatorsUntil[_miningAddress];
    }

    /// @dev Returns a boolean flag indicating whether the `emitInitiateChange` function can be called
    /// at the moment. Used by a validator's node and `TxPermission` contract (to deny dummy calling).
    function emitInitiateChangeCallable() public view returns(bool) {
        return initiateChangeAllowed && _queuePVLast >= _queuePVFirst;
    }

    /// @dev Returns the validator set (validators' mining addresses array) which was active
    /// at the end of the previous staking epoch. The array is stored by the `finalizeChange` function
    /// when a new staking epoch's validator set is finalized.
    function getPreviousValidators() public view returns(address[] memory) {
        return _previousValidators;
    }

    /// @dev Returns the current array of validators which is not yet finalized by the
    /// `finalizeChange` function. The pending array is changed when a validator is removed as malicious
    /// or the validator set is updated at the beginning of a new staking epoch (see the `_newValidatorSet` function).
    /// Every time the pending array is updated, it is enqueued by the `_enqueuePendingValidators` and then
    /// dequeued by the `emitInitiateChange` function which emits the `InitiateChange` event to all
    /// validator nodes.
    function getPendingValidators() public view returns(address[] memory) {
        return _pendingValidators;
    }

    /// @dev Returns a validator set to be finalized by the `finalizeChange` function.
    /// Used by the `finalizeChange` function.
    /// @param miningAddresses An array set by the `emitInitiateChange` function.
    /// @param newStakingEpoch A boolean flag indicating whether the `miningAddresses` array was formed by the
    /// `_newValidatorSet` function. The `finalizeChange` function logic depends on this flag.
    function getQueueValidators() public view returns(address[] memory miningAddresses, bool newStakingEpoch) {
        return (_queueValidators, _queueValidatorsNewStakingEpoch);
    }

    /// @dev Returns the current validator set (an array of mining addresses)
    /// which always matches the validator set in the Parity engine.
    function getValidators() public view returns(address[] memory) {
        return _currentValidators;
    }

    /// @dev Returns a boolean flag indicating if the `initialize` function has been called.
    function isInitialized() public view returns(bool) {
        return blockRewardContract != address(0);
    }

    /// @dev Returns a boolean flag indicating whether the specified validator (mining address)
    /// can call the `reportMalicious` function or whether the specified validator (mining address)
    /// can be reported as malicious. This function also allows a validator to call the `reportMalicious`
    /// function several blocks after ceasing to be a validator. This is possible if a
    /// validator did not have the opportunity to call the `reportMalicious` function prior to the
    /// engine calling the `finalizeChange` function.
    /// @param _miningAddress The validator's mining address.
    function isReportValidatorValid(address _miningAddress) public view returns(bool) {
        bool isValid = isValidator[_miningAddress] && !isValidatorBanned(_miningAddress);
        if (stakingContract.stakingEpoch() == 0 || validatorSetApplyBlock == 0) {
            return isValid;
        }
        if (_getCurrentBlockNumber() - validatorSetApplyBlock <= 20) {
            // The current validator set was finalized by the engine,
            // but we should let the previous validators finish
            // reporting malicious validator within a few blocks
            bool previousEpochValidator =
                isValidatorOnPreviousEpoch[_miningAddress] && !isValidatorBanned(_miningAddress);
            return isValid || previousEpochValidator;
        }
        return isValid;
    }

    /// @dev Returns a boolean flag indicating whether the specified mining address is currently banned.
    /// A validator can be banned when they misbehave (see the `_removeMaliciousValidator` function).
    /// @param _miningAddress The mining address.
    function isValidatorBanned(address _miningAddress) public view returns(bool) {
        return _getCurrentBlockNumber() <= bannedUntil[_miningAddress];
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

        uint256 validatorsNumber = _currentValidators.length;

        if (validatorsNumber > 1) {
            uint256 currentStakingEpoch = stakingContract.stakingEpoch();
            uint256 reportsNumber = reportingCounter[_reportingMiningAddress][currentStakingEpoch];
            uint256 reportsTotalNumber = reportingCounterTotal[currentStakingEpoch];
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

        address[] storage reportedValidators = maliceReportedForBlock[_maliciousMiningAddress][_blockNumber];

        // Don't allow reporting validator to report about the same misbehavior more than once
        for (uint256 m = 0; m < reportedValidators.length; m++) {
            if (reportedValidators[m] == _reportingMiningAddress) {
                return (false, false);
            }
        }

        return (true, false);
    }

    // =============================================== Private ========================================================

    /// @dev Sets a new validator set returned by the `getValidators` getter.
    /// Called by the `finalizeChange` function.
    /// @param _validators An array of new validators (their mining addresses).
    function _applyQueueValidators(address[] memory _validators) internal {
        address[] memory prevValidators = getValidators();
        uint256 i;

        // Clear indexes for old validator set
        for (i = 0; i < prevValidators.length; i++) {
            validatorIndex[prevValidators[i]] = 0;
            _setIsValidator(prevValidators[i], false);
        }

        _currentValidators = _validators;

        // Set indexes for new validator set
        for (i = 0; i < _validators.length; i++) {
            validatorIndex[_validators[i]] = i;
            _setIsValidator(_validators[i], true);
        }
    }

    /// @dev Updates the total reporting counter (see the `reportingCounterTotal` getter) for the current staking epoch
    /// after the specified validator is removed as malicious. The `reportMaliciousCallable` getter uses this counter
    /// for reporting checks so it must be up-to-date. Called by the `_removeMaliciousValidatorAuRa` internal function.
    /// @param _miningAddress The mining address of the removed malicious validator.
    function _clearReportingCounter(address _miningAddress) internal {
        uint256 currentStakingEpoch = stakingContract.stakingEpoch();
        uint256 total = reportingCounterTotal[currentStakingEpoch];
        uint256 counter = reportingCounter[_miningAddress][currentStakingEpoch];

        reportingCounter[_miningAddress][currentStakingEpoch] = 0;

        if (total >= counter) {
            reportingCounterTotal[currentStakingEpoch] -= counter;
        } else {
            reportingCounterTotal[currentStakingEpoch] = 0;
        }
    }

    /// @dev Enqueues the pending validator set which is returned by the `getPendingValidators` getter
    /// to be dequeued later by the `emitInitiateChange` function. Called when a validator is removed
    /// from the set as malicious or when a new validator set is formed by the `_newValidatorSet` function.
    /// @param _newStakingEpoch A boolean flag defining whether the pending validator set was formed by the
    /// `_newValidatorSet` function. The `finalizeChange` function logic depends on this flag.
    function _enqueuePendingValidators(bool _newStakingEpoch) internal {
        int256 queueFirst = _queuePVFirst;
        int256 queueLast = _queuePVLast;

        for (int256 i = queueLast; i >= queueFirst; i--) {
            if (_queuePV[i].block == _getCurrentBlockNumber()) {
                _queuePV[i].list = getPendingValidators();
                if (_newStakingEpoch) {
                    _queuePV[i].newEpoch = true;
                }
                return;
            }
        }

        queueLast++;
        _queuePV[queueLast] = PendingValidatorsQueue({
            block: _getCurrentBlockNumber(),
            newEpoch: _newStakingEpoch,
            list: getPendingValidators()
        });
        _queuePVLast = queueLast;
    }

    /// @dev Dequeues the pending validator set to pass it to the `InitiateChange` event
    /// (and then to the `finalizeChange` function). Called by the `emitInitiateChange` function.
    /// @param newSet An array of mining addresses.
    /// @param newStakingEpoch A boolean flag indicating whether the `newSet` array was formed by the
    /// `_newValidatorSet` function. The `finalizeChange` function logic depends on this flag.
    function _dequeuePendingValidators() internal returns(address[] memory newSet, bool newStakingEpoch) {
        int256 queueFirst = _queuePVFirst;
        int256 queueLast = _queuePVLast;

        if (queueLast < queueFirst) {
            newSet = new address[](0);
            newStakingEpoch = false;
        } else {
            newSet = _queuePV[queueFirst].list;
            newStakingEpoch = _queuePV[queueFirst].newEpoch;
            delete _queuePV[queueFirst];
            _queuePVFirst++;
        }
    }

    /// @dev Increments the reporting counter for the specified validator and the current staking epoch.
    /// See the `reportingCounter` and `reportingCounterTotal` getters. Called by the `reportMalicious`
    /// function when the validator reports a misbehavior.
    /// @param _reportingMiningAddress The mining address of reporting validator.
    function _incrementReportingCounter(address _reportingMiningAddress) internal {
        if (!isReportValidatorValid(_reportingMiningAddress)) return;
        uint256 currentStakingEpoch = stakingContract.stakingEpoch();
        reportingCounter[_reportingMiningAddress][currentStakingEpoch]++;
        reportingCounterTotal[currentStakingEpoch]++;
    }

    /// @dev An internal function implementing the logic which forms a new validator set. If the number of active pools
    /// is greater than MAX_VALIDATORS, the logic chooses the validators randomly using a random seed generated and
    /// stored by the `Random` contract.
    /// This function is called by the `newValidatorSet` function of a child contract.
    /// @return The number of pools ready to be elected (see the `Staking.getPoolsToBeElected` function).
    function _newValidatorSet() internal returns(uint256) {
        address[] memory poolsToBeElected = stakingContract.getPoolsToBeElected();
        address unremovableStakingAddress = unremovableValidator;

        // Choose new validators
        if (
            poolsToBeElected.length >= MAX_VALIDATORS &&
            (poolsToBeElected.length != MAX_VALIDATORS || unremovableStakingAddress != address(0))
        ) {
            uint256 randomNumber = IRandomAuRa(randomContract).currentSeed();

            (uint256[] memory likelihood, uint256 likelihoodSum) = stakingContract.getPoolsLikelihood();

            if (likelihood.length > 0 && likelihoodSum > 0) {
                address[] memory newValidators = new address[](
                    unremovableStakingAddress == address(0) ? MAX_VALIDATORS : MAX_VALIDATORS - 1
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

                _setPendingValidators(newValidators, unremovableStakingAddress);
            }
        } else {
            _setPendingValidators(poolsToBeElected, unremovableStakingAddress);
        }

        // From this moment the `getPendingValidators()` will return a new validator set

        stakingContract.incrementStakingEpoch();
        validatorSetApplyBlock = 0;

        changeRequestCount++;
        _enqueuePendingValidators(true);

        return poolsToBeElected.length;
    }

    /// @dev Removes the specified validator as malicious. Used by a child contract.
    /// @param _miningAddress The removed validator mining address.
    /// @param _reason A short string of the reason why the mining address is treated as malicious:
    /// "unrevealed" - the validator didn't reveal their secret at the end of staking epoch or skipped
    /// too many reveals during the staking epoch;
    /// "spam" - the validator made a lot of `reportMalicious` callings compared with other validators;
    /// "malicious" - the validator was reported as malicious by other validators with the `reportMalicious` function.
    /// @return Returns `true` if the specified validator has been removed from the pending validator set.
    /// Otherwise returns `false` (if the specified validator has already been removed or cannot be removed).
    function _removeMaliciousValidator(address _miningAddress, bytes32 _reason) internal returns(bool) {
        address stakingAddress = stakingByMiningAddress[_miningAddress];

        if (stakingAddress == unremovableValidator) {
            return false;
        }

        if (_pendingValidators.length < 2) {
            // If the removed validator is one and only in the validator set, don't let remove them
            return false;
        }

        bool isBanned = isValidatorBanned(_miningAddress);

        // Ban the malicious validator for the next 3 months
        banCounter[_miningAddress]++;
        bannedUntil[_miningAddress] = _banUntil();
        banReason[_miningAddress] = _reason;

        if (isBanned) {
            // The validator is already banned
            return false;
        } else {
            bannedDelegatorsUntil[_miningAddress] = _banUntil();
        }

        // Remove malicious validator from the `pools`
        stakingContract.removePool(stakingAddress);

        for (uint256 i = 0; i < _pendingValidators.length; i++) {
            if (_pendingValidators[i] == _miningAddress) {
                // Remove the malicious validator from `pendingValidators`
                _pendingValidators[i] = _pendingValidators[_pendingValidators.length - 1];
                _pendingValidators.length--;
                return true;
            }
        }

        return false;
    }

    /// @dev Removes the specified validators as malicious from the pending validator set and enqueues the updated
    /// pending validator set to be dequeued by the `emitInitiateChange` function. Does nothing if the specified
    /// validators are already banned, non-removable, or don't exist in the pending validator set.
    /// @param _miningAddresses The mining addresses of the malicious validators.
    /// @param _reason A short string of the reason why the mining addresses are treated as malicious,
    /// see the `_removeMaliciousValidator` function for possible values.
    function _removeMaliciousValidators(address[] memory _miningAddresses, bytes32 _reason) internal {
        uint256 removedCount = 0;

        for (uint256 i = 0; i < _miningAddresses.length; i++) {
            if (_removeMaliciousValidator(_miningAddresses[i], _reason)) {
                _clearReportingCounter(_miningAddresses[i]);
                removedCount++;
            }
        }

        if (removedCount > 0) {
            changeRequestCount++;
            // From this moment `getPendingValidators()` will return the new validator set
            _enqueuePendingValidators(false);
        }
    }

    /// @dev Sets a boolean flag defining whether the specified mining address is a validator
    /// (whether it is existed in the array returned by the `getValidators` getter).
    /// See the `_applyQueueValidators` function and `isValidator`/`getValidators` getters.
    /// @param _miningAddress The mining address.
    /// @param _isValidator The boolean flag.
    function _setIsValidator(address _miningAddress, bool _isValidator) internal {
        isValidator[_miningAddress] = _isValidator;
        if (_isValidator) validatorCounter[_miningAddress]++;
    }

    /// @dev Sets a new validator set as a pending (which is not yet finalized by the `finalizeChange` function).
    /// Removes the pools in the `poolsToBeRemoved` array (see the `Staking.getPoolsToBeRemoved` function).
    /// Called by the `_newValidatorSet` function.
    /// @param _stakingAddresses The array of the new validators' staking addresses.
    /// @param _unremovableStakingAddress The staking address of a non-removable validator.
    /// See the `unremovableValidator` getter.
    function _setPendingValidators(
        address[] memory _stakingAddresses,
        address _unremovableStakingAddress
    ) internal {
        if (_stakingAddresses.length == 0) return;

        uint256 i;

        delete _pendingValidators;

        if (_unremovableStakingAddress != address(0)) {
            _pendingValidators.push(miningByStakingAddress[_unremovableStakingAddress]);
        }

        for (i = 0; i < _stakingAddresses.length; i++) {
            _pendingValidators.push(miningByStakingAddress[_stakingAddresses[i]]);
        }

        address[] memory poolsToBeRemoved = stakingContract.getPoolsToBeRemoved();
        for (i = 0; i < poolsToBeRemoved.length; i++) {
            stakingContract.removePool(poolsToBeRemoved[i]);
        }
    }

    /// @dev Sets a validator set for the `finalizeChange` function.
    /// Called by the `emitInitiateChange` function.
    /// @param _miningAddresses An array of the new validator set mining addresses.
    /// @param _newStakingEpoch A boolean flag indicating whether the `_miningAddresses` array was formed by the
    /// `_newValidatorSet` function. The `finalizeChange` function logic depends on this flag.
    function _setQueueValidators(address[] memory _miningAddresses, bool _newStakingEpoch) internal {
        _queueValidators = _miningAddresses;
        _queueValidatorsNewStakingEpoch = _newStakingEpoch;
    }

    /// @dev Binds a mining address to the specified staking address. Used by the `setStakingAddress` function.
    /// See also the `miningByStakingAddress` and `stakingByMiningAddress` getters.
    /// @param _miningAddress The mining address of a newly created pool. Cannot be equal to the `_stakingAddress`.
    /// @param _stakingAddress The staking address of a newly created pool. Cannot be equal to the `_miningAddress`.
    function _setStakingAddress(address _miningAddress, address _stakingAddress) internal {
        require(_miningAddress != address(0));
        require(_stakingAddress != address(0));
        require(_miningAddress != _stakingAddress);
        require(miningByStakingAddress[_stakingAddress] == address(0));
        require(miningByStakingAddress[_miningAddress] == address(0));
        require(stakingByMiningAddress[_stakingAddress] == address(0));
        require(stakingByMiningAddress[_miningAddress] == address(0));
        miningByStakingAddress[_stakingAddress] = _miningAddress;
        stakingByMiningAddress[_miningAddress] = _stakingAddress;
    }

    /// @dev Returns the future block number until which a validator is banned.
    /// Used by the `_removeMaliciousValidator` function.
    function _banUntil() internal view returns(uint256) {
        return _getCurrentBlockNumber() + 1555200; // 90 days (for 5 seconds block)
    }

    /// @dev Returns the current block number. Needed mostly for unit tests.
    function _getCurrentBlockNumber() internal view returns(uint256) {
        return block.number;
    }

    /// @dev Returns an index of a pool in the `poolsToBeElected` array (see the `Staking.getPoolsToBeElected` getter)
    /// by a random number and the corresponding probability coefficients.
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
