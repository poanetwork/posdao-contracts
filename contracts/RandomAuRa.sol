pragma solidity 0.5.9;

import "./interfaces/IRandomAuRa.sol";
import "./interfaces/IStakingAuRa.sol";
import "./interfaces/IValidatorSetAuRa.sol";


/// @dev Generates and stores random numbers in a RANDAO manner (and controls when they are revealed by AuRa
/// validators) and accumulates a random seed. The random seed is used to form a new validator set by the
/// `ValidatorSet._newValidatorSet` function.
contract RandomAuRa is IRandomAuRa {

    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables and do not change their types!

    mapping(uint256 => mapping(address => bytes)) internal _ciphers;
    mapping(uint256 => mapping(address => bytes32)) internal _commits;
    mapping(uint256 => address[]) internal _committedValidators;

    /// @dev The length of the collection round (in blocks).
    uint256 public collectRoundLength;

    /// @dev The current random seed accumulated during RANDAO or another process
    /// (depending on implementation).
    uint256 public currentSeed;

    /// @dev The number of reveal skips made by the specified validator during the specified staking epoch.
    mapping(uint256 => mapping(address => uint256)) public revealSkips;

    /// @dev A boolean flag of whether the specified validator has revealed their secret for the
    /// specified collection round.
    mapping(uint256 => mapping(address => bool)) public sentReveal;

    /// @dev The address of the `ValidatorSet` contract.
    IValidatorSetAuRa public validatorSetContract;

    // ============================================== Modifiers =======================================================

    /// @dev Ensures the caller is the BlockRewardAuRa contract address
    /// (EternalStorageProxy proxy contract for BlockRewardAuRa).
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

    /// @dev Called by the validator's node to store a hash and a cipher of the validator's secret on each collection
    /// round. The validator's node must use its mining address to call this function.
    /// This function can only be called once per collection round (during the `commits phase`).
    /// @param _secretHash The Keccak-256 hash of the validator's secret.
    /// @param _cipher The cipher of the validator's secret. Can be used by the node to restore the lost secret after
    /// the node is restarted (see the `getCipher` getter).
    function commitHash(bytes32 _secretHash, bytes calldata _cipher) external onlyInitialized {
        address miningAddress = msg.sender;

        require(commitHashCallable(miningAddress, _secretHash));
        require(_getCoinbase() == miningAddress); // make sure validator node is live

        uint256 collectRound = currentCollectRound();

        _commits[collectRound][miningAddress] = _secretHash;
        _ciphers[collectRound][miningAddress] = _cipher;
        _committedValidators[collectRound].push(miningAddress);
    }

    /// @dev Called by the validator's node to XOR its secret with the current random seed.
    /// The validator's node must use its mining address to call this function.
    /// This function can only be called once per collection round (during the `reveals phase`).
    /// @param _secret The validator's secret.
    function revealSecret(uint256 _secret) external onlyInitialized {
        address miningAddress = msg.sender;

        require(revealSecretCallable(miningAddress, _secret));
        require(_getCoinbase() == miningAddress); // make sure validator node is live

        currentSeed = currentSeed ^ _secret;
        sentReveal[currentCollectRound()][miningAddress] = true;
    }

    /// @dev Initializes the contract at network startup.
    /// Must be called by the constructor of the `InitializerAuRa` contract.
    /// @param _collectRoundLength The length of a collection round in blocks.
    /// @param _validatorSet The address of the `ValidatorSet` contract.
    function initialize(
        uint256 _collectRoundLength, // in blocks
        address _validatorSet
    ) external {
        IValidatorSetAuRa validatorSet = IValidatorSetAuRa(_validatorSet);
        require(_collectRoundLength % 2 == 0);
        require(_collectRoundLength % validatorSet.MAX_VALIDATORS() == 0);
        require(IStakingAuRa(validatorSet.stakingContract()).stakingEpochDuration() % _collectRoundLength == 0);
        require(_collectRoundLength > 0);
        require(collectRoundLength == 0);
        collectRoundLength = _collectRoundLength;
        _initialize(_validatorSet);
    }

    /// @dev Checks whether the current validators at the end of each collection round revealed their secrets,
    /// and removes malicious validators if needed.
    /// This function does nothing if the current block is not the last block of the current collection round.
    /// Can only be called by the `BlockRewardAuRa` contract (its `reward` function).
    function onFinishCollectRound() external onlyBlockReward {
        if (_getCurrentBlockNumber() % collectRoundLength != 0) return;

        // This is the last block of the current collection round

        address[] memory validators;
        address validator;
        uint256 i;

        address stakingContract = validatorSetContract.stakingContract();

        uint256 stakingEpoch = IStakingAuRa(stakingContract).stakingEpoch();
        uint256 applyBlock = validatorSetContract.validatorSetApplyBlock();
        uint256 endBlock = IStakingAuRa(stakingContract).stakingEpochEndBlock();
        uint256 currentRound = currentCollectRound();

        if (applyBlock != 0 && _getCurrentBlockNumber() > applyBlock + collectRoundLength * 2) {
            // Check whether each validator didn't reveal their secret
            // during the current collection round
            validators = validatorSetContract.getValidators();
            for (i = 0; i < validators.length; i++) {
                validator = validators[i];
                if (!sentReveal[currentRound][validator]) {
                    revealSkips[stakingEpoch][validator]++;
                }
            }
        }

        // If this is the last collection round in the current staking epoch.
        if (_getCurrentBlockNumber() == endBlock || _getCurrentBlockNumber() + collectRoundLength > endBlock) {
            uint256 maxRevealSkipsAllowed =
                IStakingAuRa(stakingContract).stakeWithdrawDisallowPeriod() / collectRoundLength;

            if (maxRevealSkipsAllowed > 0) {
                maxRevealSkipsAllowed--;
            }

            // Check each validator to see if they didn't reveal
            // their secret during the last full `reveals phase`
            // or if they missed the required number of reveals per staking epoch.
            validators = validatorSetContract.getValidators();

            address[] memory maliciousValidators = new address[](validators.length);
            uint256 maliciousValidatorsLength = 0;

            for (i = 0; i < validators.length; i++) {
                validator = validators[i];
                if (
                    !sentReveal[currentRound][validator] ||
                    revealSkips[stakingEpoch][validator] > maxRevealSkipsAllowed
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

    /// @dev Returns the cipher of the validator's secret for the specified collection round and the specified validator
    /// stored by the validator through the `commitHash` function.
    /// @param _collectRound The serial number of the collection round for which the cipher should be retrieved.
    /// @param _miningAddress The mining address of validator.
    function getCipher(uint256 _collectRound, address _miningAddress) public view returns(bytes memory) {
        return _ciphers[_collectRound][_miningAddress];
    }

    /// @dev Returns the Keccak-256 hash of the validator's secret for the specified collection round and the specified
    /// validator stored by the validator through the `commitHash` function.
    /// @param _collectRound The serial number of the collection round for which the hash should be retrieved.
    /// @param _miningAddress The mining address of validator.
    function getCommit(uint256 _collectRound, address _miningAddress) public view returns(bytes32) {
        return _commits[_collectRound][_miningAddress];
    }

    /// @dev Returns a boolean flag indicating whether the specified validator has committed their secret's hash for the
    /// specified collection round.
    /// @param _collectRound The serial number of the collection round for which the checkup should be done.
    /// @param _miningAddress The mining address of the validator.
    function isCommitted(uint256 _collectRound, address _miningAddress) public view returns(bool) {
        return getCommit(_collectRound, _miningAddress) != bytes32(0);
    }

    /// @dev Returns a boolean flag indicating whether the current phase of the current collection round
    /// is a `commits phase`. Used by the validator's node to determine if it should commit the hash of
    /// the secret during the current collection round.
    function isCommitPhase() public view returns(bool) {
        return ((_getCurrentBlockNumber() - 1) % collectRoundLength) < commitPhaseLength();
    }

    /// @dev Returns a boolean flag indicating if the `initialize` function has been called.
    function isInitialized() public view returns(bool) {
        return validatorSetContract != IValidatorSetAuRa(0);
    }

    /// @dev Returns a boolean flag indicating whether the current phase of the current collection round
    /// is a `reveals phase`. Used by the validator's node to determine if it should reveal the secret during
    /// the current collection round.
    function isRevealPhase() public view returns(bool) {
        return !isCommitPhase();
    }

    /// @dev Returns a boolean flag of whether the `commitHash` function can be called at the current block
    /// by the specified validator. Used by the `commitHash` function and the `TxPermission` contract.
    /// @param _miningAddress The mining address of the validator which tries to call the `commitHash` function.
    /// @param _secretHash The Keccak-256 hash of validator's secret passed to the `commitHash` function.
    function commitHashCallable(address _miningAddress, bytes32 _secretHash) public view returns(bool) {
        if (!isCommitPhase()) return false; // must only be called in `commits phase`

        if (_secretHash == bytes32(0)) return false;

        if (!validatorSetContract.isValidator(_miningAddress)) return false;

        if (isCommitted(currentCollectRound(), _miningAddress)) return false; // cannot commit more than once

        return true;
    }

    /// @dev Returns a boolean flag of whether the `revealSecret` function can be called at the current block
    /// by the specified validator. Used by the `revealSecret` function and the `TxPermission` contract.
    /// @param _miningAddress The mining address of validator which tries to call the `revealSecret` function.
    /// @param _secret The validator's secret passed to the `revealSecret` function.
    function revealSecretCallable(address _miningAddress, uint256 _secret) public view returns(bool) {
        if (!isRevealPhase()) return false; // must only be called in `reveals phase`

        bytes32 secretHash = keccak256(abi.encodePacked(_secret));

        if (secretHash == bytes32(0)) return false;

        if (!validatorSetContract.isValidator(_miningAddress)) return false;

        uint256 collectRound = currentCollectRound();

        if (sentReveal[collectRound][_miningAddress]) {
            return false; // cannot reveal more than once during the same collectRound
        }

        if (secretHash != getCommit(collectRound, _miningAddress)) {
            return false; // the hash must be commited
        }

        return true;
    }

    // =============================================== Private ========================================================

    /// @dev Removes the ciphers of all committed validators for the specified collection round.
    /// @param _collectRound The serial number of the collection round.
    function _clearOldCiphers(uint256 _collectRound) private {
        if (_collectRound == 0) {
            return;
        }

        uint256 collectRound = _collectRound - 1;
        address[] storage miningAddresses = _committedValidators[collectRound];
        uint256 miningAddressesLength = miningAddresses.length;

        for (uint256 i = 0; i < miningAddressesLength; i++) {
            delete _ciphers[collectRound][miningAddresses[i]];
        }
    }

    /// @dev Initializes the network parameters. Used by the `initialize` function.
    /// @param _validatorSet The address of the `ValidatorSet` contract.
    function _initialize(address _validatorSet) internal {
        require(!isInitialized());
        require(_validatorSet != address(0));
        validatorSetContract = IValidatorSetAuRa(_validatorSet);
    }

    /// @dev Returns the current `coinbase` address. Needed mostly for unit tests.
    function _getCoinbase() internal view returns(address) {
        return block.coinbase;
    }

    /// @dev Returns the current block number. Needed mostly for unit tests.
    function _getCurrentBlockNumber() internal view returns(uint256) {
        return block.number;
    }
}
