pragma solidity 0.5.10;

import "./interfaces/IRandomAuRa.sol";
import "./interfaces/IStakingAuRa.sol";
import "./interfaces/IValidatorSetAuRa.sol";
import "./upgradeability/UpgradeableOwned.sol";


/// @dev Generates and stores random numbers in a RANDAO manner (and controls when they are revealed by AuRa
/// validators) and accumulates a random seed. The random seed is used to form a new validator set by the
/// `ValidatorSetAuRa.newValidatorSet` function.
contract RandomAuRa is UpgradeableOwned, IRandomAuRa {

    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables, do not change their order,
    // and do not change their types!

    mapping(uint256 => mapping(address => bytes)) internal _ciphers;
    mapping(uint256 => mapping(address => bytes32)) internal _commits;
    mapping(uint256 => address[]) internal _committedValidators;

    /// @dev The length of the collection round (in blocks).
    uint256 public collectRoundLength;

    /// @dev The current random seed accumulated during RANDAO or another process
    /// (depending on implementation).
    uint256 public currentSeed;

    /// @dev A boolean flag defining whether to punish validators for unrevealing.
    bool public punishForUnreveal;

    /// @dev The number of reveal skips made by the specified validator during the specified staking epoch.
    mapping(uint256 => mapping(address => uint256)) internal _revealSkips;

    /// @dev A boolean flag of whether the specified validator has revealed their number for the
    /// specified collection round.
    mapping(uint256 => mapping(address => bool)) internal _sentReveal;

    /// @dev The address of the `ValidatorSetAuRa` contract.
    IValidatorSetAuRa public validatorSetContract;

    // ============================================== Modifiers =======================================================

    /// @dev Ensures the caller is the BlockRewardAuRa contract address.
    modifier onlyBlockReward() {
        require(msg.sender == validatorSetContract.blockRewardContract());
        _;
    }

    /// @dev Ensures the `initialize` function was called before.
    modifier onlyInitialized {
        require(isInitialized());
        _;
    }

    // =============================================== Setters ========================================================

    // Temporary function (must be removed after `upgradeToAndCall` call)
    function miningAddressToStakingAddress() public onlyOwner {
        require(isCommitPhase());
        uint256 currentRound = currentCollectRound();
        address[] memory miningAddresses = _committedValidators[currentRound];
        for (uint256 i = 0; i < miningAddresses.length; i++) {
            address miningAddress = miningAddresses[i];
            address stakingAddress = validatorSetContract.stakingByMiningAddress(miningAddress);

            bytes32 commits = _commits[currentRound][miningAddress];
            if (commits != bytes32(0)) {
                _commits[currentRound][stakingAddress] = commits;
                delete _commits[currentRound][miningAddress];
            }

            bytes storage ciphers = _ciphers[currentRound][miningAddress];
            if (ciphers.length > 0) {
                _ciphers[currentRound][stakingAddress] = ciphers;
                ciphers.length = 0;
            }
            
            _committedValidators[currentRound][i] = stakingAddress;
            
            delete _ciphers[currentRound - 1][miningAddress];
        }
        _committedValidators[currentRound - 1].length = 0;

        address stakingContract = validatorSetContract.stakingContract();
        uint256 currentStakingEpoch = IStakingAuRa(stakingContract).stakingEpoch();
        miningAddresses = validatorSetContract.getValidators();
        for (uint256 v = 0; v < miningAddresses.length; v++) {
            address miningAddress = miningAddresses[v];
            address stakingAddress = validatorSetContract.stakingByMiningAddress(miningAddress);
            for (uint256 epoch = 0; epoch <= currentStakingEpoch; epoch++) {
                uint256 skips = _revealSkips[epoch][miningAddress];
                if (skips > 0) {
                    _revealSkips[epoch][stakingAddress] = skips;
                }
            }
        }
    }

    // Temporary function
    function clearRevealSkips() external {
        require(msg.sender == address(0xF96E3bb5e06DaA129B9981E1467e2DeDd6451DbE));
        address stakingContract = validatorSetContract.stakingContract();
        uint256 currentStakingEpoch = IStakingAuRa(stakingContract).stakingEpoch();
        address[] memory miningAddresses = validatorSetContract.getValidators();
        for (uint256 v = 0; v < miningAddresses.length; v++) {
            address miningAddress = miningAddresses[v];
            for (uint256 epoch = 0; epoch <= currentStakingEpoch; epoch++) {
                _revealSkips[epoch][miningAddress] = 0;
            }
        }
    }

    // Temporary function
    function migrateCommitsReveals(address _miningAddress, uint256 _startRound, uint256 _endRound) public {
        require(msg.sender == address(0xF96E3bb5e06DaA129B9981E1467e2DeDd6451DbE));
        address stakingAddress = validatorSetContract.stakingByMiningAddress(_miningAddress);
        if (_startRound == 0) {
            _startRound = 120874;
        }
        if (_endRound == 0) {
            _endRound = currentCollectRound();
        }
        for (uint256 round = _startRound; round <= _endRound; round++) {
            bytes32 commits = _commits[round][_miningAddress];
            if (commits != bytes32(0)) {
                _commits[round][stakingAddress] = commits;
            }
            if (_sentReveal[round][_miningAddress]) {
                _sentReveal[round][stakingAddress] = true;
            }
        }
    }

    // Temporary function
    function clearCommitsReveals(address _miningAddress, uint256 _startRound, uint256 _endRound) public {
        require(msg.sender == address(0xF96E3bb5e06DaA129B9981E1467e2DeDd6451DbE));
        if (_startRound == 0) {
            _startRound = 120874;
        }
        if (_endRound == 0) {
            _endRound = currentCollectRound();
        }
        for (uint256 round = _startRound; round <= _endRound; round++) {
            delete _commits[round][_miningAddress];
            delete _sentReveal[round][_miningAddress];
        }
    }

    /// @dev Called by the validator's node to store a hash and a cipher of the validator's number on each collection
    /// round. The validator's node must use its mining address to call this function.
    /// This function can only be called once per collection round (during the `commits phase`).
    /// @param _numberHash The Keccak-256 hash of the validator's number.
    /// @param _cipher The cipher of the validator's number. Can be used by the node to restore the lost number after
    /// the node is restarted (see the `getCipher` getter).
    function commitHash(bytes32 _numberHash, bytes calldata _cipher) external onlyInitialized {
        address miningAddress = msg.sender;

        require(commitHashCallable(miningAddress, _numberHash));
        require(_getCoinbase() == miningAddress); // make sure validator node is live

        uint256 collectRound = currentCollectRound();
        address stakingAddress = validatorSetContract.stakingByMiningAddress(miningAddress);

        _commits[collectRound][stakingAddress] = _numberHash;
        _ciphers[collectRound][stakingAddress] = _cipher;
        _committedValidators[collectRound].push(stakingAddress);
    }

    /// @dev Called by the validator's node to XOR its number with the current random seed.
    /// The validator's node must use its mining address to call this function.
    /// This function can only be called once per collection round (during the `reveals phase`).
    /// @param _number The validator's number.
    function revealNumber(uint256 _number) external onlyInitialized {
        _revealNumber(_number);
    }

    /// @dev The same as the `revealNumber` function (see its description).
    /// The `revealSecret` was renamed to `revealNumber`, so this function
    /// is left for backward compatibility with the previous client
    /// implementation and should be deleted in the future.
    /// @param _number The validator's number.
    function revealSecret(uint256 _number) external onlyInitialized {
        _revealNumber(_number);
    }

    /// @dev Changes the `punishForUnreveal` boolean flag. Can only be called by an owner.
    function setPunishForUnreveal(bool _punishForUnreveal) external onlyOwner {
        punishForUnreveal = _punishForUnreveal;
    }

    /// @dev Initializes the contract at network startup.
    /// Can only be called by the constructor of the `InitializerAuRa` contract or owner.
    /// @param _collectRoundLength The length of a collection round in blocks.
    /// @param _validatorSet The address of the `ValidatorSet` contract.
    /// @param _punishForUnreveal A boolean flag defining whether to punish validators for unrevealing.
    function initialize(
        uint256 _collectRoundLength, // in blocks
        address _validatorSet,
        bool _punishForUnreveal
    ) external {
        require(_getCurrentBlockNumber() == 0 || msg.sender == _admin());
        require(!isInitialized());
        IValidatorSetAuRa validatorSet = IValidatorSetAuRa(_validatorSet);
        require(_collectRoundLength % 2 == 0);
        require(_collectRoundLength % validatorSet.MAX_VALIDATORS() == 0);
        require(IStakingAuRa(validatorSet.stakingContract()).stakingEpochDuration() % _collectRoundLength == 0);
        require(_collectRoundLength > 0);
        require(collectRoundLength == 0);
        require(_validatorSet != address(0));
        collectRoundLength = _collectRoundLength;
        validatorSetContract = IValidatorSetAuRa(_validatorSet);
        punishForUnreveal = _punishForUnreveal;
    }

    /// @dev Checks whether the current validators at the end of each collection round revealed their numbers,
    /// and removes malicious validators if needed.
    /// This function does nothing if the current block is not the last block of the current collection round.
    /// Can only be called by the `BlockRewardAuRa` contract (by its `reward` function).
    function onFinishCollectRound() external onlyBlockReward {
        if (_getCurrentBlockNumber() % collectRoundLength != 0) return;

        // This is the last block of the current collection round

        address[] memory validators;
        address validator;
        uint256 i;

        address stakingContract = validatorSetContract.stakingContract();

        uint256 stakingEpoch = IStakingAuRa(stakingContract).stakingEpoch();
        uint256 startBlock = IStakingAuRa(stakingContract).stakingEpochStartBlock();
        uint256 endBlock = IStakingAuRa(stakingContract).stakingEpochEndBlock();
        uint256 currentRound = currentCollectRound();

        if (_getCurrentBlockNumber() > startBlock + collectRoundLength * 3) {
            // Check whether each validator didn't reveal their number
            // during the current collection round
            validators = validatorSetContract.getValidators();
            for (i = 0; i < validators.length; i++) {
                validator = validators[i];
                if (!sentReveal(currentRound, validator)) {
                    address stakingAddress = validatorSetContract.stakingByMiningAddress(validator);
                    _revealSkips[stakingEpoch][stakingAddress]++;
                }
            }
        }

        // If this is the last collection round in the current staking epoch
        // and punishing for unreveal is enabled.
        if (
            punishForUnreveal &&
            (_getCurrentBlockNumber() == endBlock || _getCurrentBlockNumber() + collectRoundLength > endBlock)
        ) {
            uint256 maxRevealSkipsAllowed =
                IStakingAuRa(stakingContract).stakeWithdrawDisallowPeriod() / collectRoundLength;

            if (maxRevealSkipsAllowed > 1) {
                maxRevealSkipsAllowed -= 2;
            } else if (maxRevealSkipsAllowed > 0) {
                maxRevealSkipsAllowed--;
            }

            // Check each validator to see if they didn't reveal
            // their number during the last full `reveals phase`
            // or if they missed the required number of reveals per staking epoch.
            validators = validatorSetContract.getValidators();

            address[] memory maliciousValidators = new address[](validators.length);
            uint256 maliciousValidatorsLength = 0;

            for (i = 0; i < validators.length; i++) {
                validator = validators[i];
                if (
                    !sentReveal(currentRound, validator) ||
                    revealSkips(stakingEpoch, validator) > maxRevealSkipsAllowed
                ) {
                    // Mark the validator as malicious
                    maliciousValidators[maliciousValidatorsLength++] = validator;
                }
            }

            if (maliciousValidatorsLength > 0) {
                address[] memory miningAddresses = new address[](maliciousValidatorsLength);
                for (i = 0; i < maliciousValidatorsLength; i++) {
                    miningAddresses[i] = maliciousValidators[i];
                }
                validatorSetContract.removeMaliciousValidators(miningAddresses);
            }
        }

        // Clear unnecessary info about previous collection round.
        _clearOldCiphers(currentRound);
    }

    // =============================================== Getters ========================================================

    /// @dev Returns the length of the commits/reveals phase which is always half of the collection round length.
    function commitPhaseLength() public view returns(uint256) {
        return collectRoundLength / 2;
    }

    /// @dev Returns the serial number of the current collection round.
    function currentCollectRound() public view returns(uint256) {
        return (_getCurrentBlockNumber() - 1) / collectRoundLength;
    }

    /// @dev Returns the number of the first block of the current collection round.
    function currentCollectRoundStartBlock() public view returns(uint256) {
        return currentCollectRound() * collectRoundLength + 1;
    }

    /// @dev Returns the cipher of the validator's number for the specified collection round and the specified validator
    /// stored by the validator through the `commitHash` function.
    /// For the past collection rounds the cipher is empty as it's erased by the internal `_clearOldCiphers` function.
    /// @param _collectRound The serial number of the collection round for which the cipher should be retrieved.
    /// @param _miningAddress The mining address of validator.
    function getCipher(uint256 _collectRound, address _miningAddress) public view returns(bytes memory) {
        address stakingAddress = validatorSetContract.stakingByMiningAddress(_miningAddress);
        return _ciphers[_collectRound][stakingAddress];
    }

    /// @dev Returns the Keccak-256 hash of the validator's number for the specified collection round and the specified
    /// validator stored by the validator through the `commitHash` function. Note that for the past collection rounds
    /// it can return empty results because there was a migration from mining addresses to staking addresses.
    /// @param _collectRound The serial number of the collection round for which the hash should be retrieved.
    /// @param _miningAddress The mining address of validator.
    function getCommit(uint256 _collectRound, address _miningAddress) public view returns(bytes32) {
        address stakingAddress = validatorSetContract.stakingByMiningAddress(_miningAddress);
        return _commits[_collectRound][stakingAddress];
    }

    /// @dev Returns the Keccak-256 hash and cipher of the validator's number for the specified collection round
    /// and the specified validator stored by the validator through the `commitHash` function.
    /// For the past collection rounds the cipher is empty. Note that for the past collection rounds
    /// it can return empty results because there was a migration from mining addresses to staking addresses.
    /// @param _collectRound The serial number of the collection round for which hash and cipher should be retrieved.
    /// @param _miningAddress The mining address of validator.
    function getCommitAndCipher(
        uint256 _collectRound,
        address _miningAddress
    ) public view returns(bytes32, bytes memory) {
        return (getCommit(_collectRound, _miningAddress), getCipher(_collectRound, _miningAddress));
    }

    /// @dev Returns a boolean flag indicating whether the specified validator has committed their number's hash for the
    /// specified collection round. Note that for the past collection rounds it can return false-negative results
    /// because there was a migration from mining addresses to staking addresses.
    /// @param _collectRound The serial number of the collection round for which the checkup should be done.
    /// @param _miningAddress The mining address of the validator.
    function isCommitted(uint256 _collectRound, address _miningAddress) public view returns(bool) {
        return getCommit(_collectRound, _miningAddress) != bytes32(0);
    }

    /// @dev Returns a boolean flag indicating whether the current phase of the current collection round
    /// is a `commits phase`. Used by the validator's node to determine if it should commit the hash of
    /// the number during the current collection round.
    function isCommitPhase() public view returns(bool) {
        return ((_getCurrentBlockNumber() - 1) % collectRoundLength) < commitPhaseLength();
    }

    /// @dev Returns a boolean flag indicating if the `initialize` function has been called.
    function isInitialized() public view returns(bool) {
        return validatorSetContract != IValidatorSetAuRa(0);
    }

    /// @dev Returns a boolean flag indicating whether the current phase of the current collection round
    /// is a `reveals phase`. Used by the validator's node to determine if it should reveal the number during
    /// the current collection round.
    function isRevealPhase() public view returns(bool) {
        return !isCommitPhase();
    }

    /// @dev Returns a boolean flag of whether the `commitHash` function can be called at the current block
    /// by the specified validator. Used by the `commitHash` function and the `TxPermission` contract.
    /// @param _miningAddress The mining address of the validator which tries to call the `commitHash` function.
    /// @param _numberHash The Keccak-256 hash of validator's number passed to the `commitHash` function.
    function commitHashCallable(address _miningAddress, bytes32 _numberHash) public view returns(bool) {
        if (!isCommitPhase()) return false; // must only be called in `commits phase`

        if (_numberHash == bytes32(0)) return false;

        if (!validatorSetContract.isValidator(_miningAddress)) return false;

        if (isCommitted(currentCollectRound(), _miningAddress)) return false; // cannot commit more than once

        return true;
    }

    /// @dev Returns the number of the first block of the next (future) collection round.
    function nextCollectRoundStartBlock() public view returns(uint256) {
        uint256 currentBlock = _getCurrentBlockNumber();
        uint256 remainingBlocksToNextRound = collectRoundLength - (currentBlock - 1) % collectRoundLength;
        return currentBlock + remainingBlocksToNextRound;
    }

    /// @dev Returns the number of the first block of the next (future) commit phase.
    function nextCommitPhaseStartBlock() public view returns(uint256) {
        return nextCollectRoundStartBlock();
    }

    /// @dev Returns the number of the first block of the next (future) reveal phase.
    function nextRevealPhaseStartBlock() public view returns(uint256) {
        if (isCommitPhase()) {
            return currentCollectRoundStartBlock() + commitPhaseLength();
        } else {
            return nextCollectRoundStartBlock() + commitPhaseLength();
        }
    }

    /// @dev Returns a boolean flag of whether the `revealNumber` function can be called at the current block
    /// by the specified validator. Used by the `revealNumber` function and the `TxPermission` contract.
    /// @param _miningAddress The mining address of validator which tries to call the `revealNumber` function.
    /// @param _number The validator's number passed to the `revealNumber` function.
    function revealNumberCallable(address _miningAddress, uint256 _number) public view returns(bool) {
        return _revealNumberCallable(_miningAddress, _number);
    }

    /// @dev The same as the `revealNumberCallable` getter (see its description).
    /// The `revealSecretCallable` was renamed to `revealNumberCallable`, so this function
    /// is left for backward compatibility with the previous client
    /// implementation and should be deleted in the future.
    /// @param _miningAddress The mining address of validator which tries to call the `revealSecret` function.
    /// @param _number The validator's number passed to the `revealSecret` function.
    function revealSecretCallable(address _miningAddress, uint256 _number) public view returns(bool) {
        return _revealNumberCallable(_miningAddress, _number);
    }

    /// @dev Returns the number of reveal skips made by the specified validator during the specified staking epoch.
    /// @param _stakingEpoch The number of staking epoch.
    /// @param _miningAddress The mining address of the validator.
    function revealSkips(uint256 _stakingEpoch, address _miningAddress) public view returns(uint256) {
        address stakingAddress = validatorSetContract.stakingByMiningAddress(_miningAddress);
        return _revealSkips[_stakingEpoch][stakingAddress];
    }

    /// @dev Returns a boolean flag indicating whether the specified validator has revealed their number for the
    /// specified collection round. Note that for the past collection rounds it can return false-negative results
    /// because there was a migration from mining addresses to staking addresses.
    /// @param _collectRound The serial number of the collection round for which the checkup should be done.
    /// @param _miningAddress The mining address of the validator.
    function sentReveal(uint256 _collectRound, address _miningAddress) public view returns(bool) {
        address stakingAddress = validatorSetContract.stakingByMiningAddress(_miningAddress);
        return _sentReveal[_collectRound][stakingAddress];
    }

    // ============================================== Internal ========================================================

    /// @dev Removes the ciphers of all committed validators for the collection round
    /// preceding to the specified collection round.
    /// @param _collectRound The serial number of the collection round.
    function _clearOldCiphers(uint256 _collectRound) internal {
        if (_collectRound == 0) {
            return;
        }

        uint256 collectRound = _collectRound - 1;
        address[] storage stakingAddresses = _committedValidators[collectRound];
        uint256 stakingAddressesLength = stakingAddresses.length;

        for (uint256 i = 0; i < stakingAddressesLength; i++) {
            delete _ciphers[collectRound][stakingAddresses[i]];
        }

        stakingAddresses.length = 0;
    }

    /// @dev Used by the `revealNumber` function.
    /// @param _number The validator's number.
    function _revealNumber(uint256 _number) internal {
        address miningAddress = msg.sender;

        require(revealNumberCallable(miningAddress, _number));
        require(_getCoinbase() == miningAddress); // make sure validator node is live

        address stakingAddress = validatorSetContract.stakingByMiningAddress(miningAddress);

        currentSeed = currentSeed ^ _number;
        _sentReveal[currentCollectRound()][stakingAddress] = true;
    }

    /// @dev Returns the current `coinbase` address. Needed mostly for unit tests.
    function _getCoinbase() internal view returns(address) {
        return block.coinbase;
    }

    /// @dev Returns the current block number. Needed mostly for unit tests.
    function _getCurrentBlockNumber() internal view returns(uint256) {
        return block.number;
    }

    /// @dev Used by the `revealNumberCallable` public getter.
    /// @param _miningAddress The mining address of validator which tries to call the `revealNumber` function.
    /// @param _number The validator's number passed to the `revealNumber` function.
    function _revealNumberCallable(address _miningAddress, uint256 _number) internal view returns(bool) {
        if (!isRevealPhase()) return false; // must only be called in `reveals phase`

        bytes32 numberHash = keccak256(abi.encodePacked(_number));

        if (numberHash == bytes32(0)) return false;

        if (!validatorSetContract.isValidator(_miningAddress)) return false;

        uint256 collectRound = currentCollectRound();

        if (sentReveal(collectRound, _miningAddress)) {
            return false; // cannot reveal more than once during the same collectRound
        }

        if (numberHash != getCommit(collectRound, _miningAddress)) {
            return false; // the hash must be commited
        }

        return true;
    }
}
