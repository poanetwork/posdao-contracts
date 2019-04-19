pragma solidity 0.5.2;

import "./abstracts/RandomBase.sol";
import "./interfaces/IRandomAuRa.sol";
import "./interfaces/IValidatorSetAuRa.sol";
import "./interfaces/IStaking.sol";
import "./interfaces/IStakingAuRa.sol";


/// @dev Generates and stores random numbers in a RANDAO manner (and controls when they are revealed by AuRa
/// validators) and accumulates a random seed. The random seed is used to form a new validator set by the
/// `ValidatorSet._newValidatorSet` function.
contract RandomAuRa is RandomBase, IRandomAuRa {

    // ============================================== Modifiers =======================================================

    /// @dev Ensures the caller is the BlockRewardAuRa contract address
    /// (EternalStorageProxy proxy contract for BlockRewardAuRa).
    modifier onlyBlockReward() {
        require(msg.sender == IValidatorSet(VALIDATOR_SET_CONTRACT).blockRewardContract());
        _;
    }

    // =============================================== Setters ========================================================

    /// @dev Called by the validator's node to store a hash and a cipher of the validator's secret on each collection
    /// round. The validator's node must use its mining address to call this function.
    /// This function can only be called once per collection round (during the `commits phase`).
    /// @param _secretHash The Keccak-256 hash of the validator's secret.
    /// @param _cipher The cipher of the validator's secret. Can be used by the node to restore the lost secret after
    /// the node is restarted (see the `getCipher` getter).
    function commitHash(bytes32 _secretHash, bytes calldata _cipher) external {
        address miningAddress = msg.sender;

        require(commitHashCallable(miningAddress, _secretHash));
        require(block.coinbase == miningAddress); // make sure validator node is live

        uint256 collectRound = currentCollectRound();

        _setCommit(collectRound, miningAddress, _secretHash);
        _setCipher(collectRound, miningAddress, _cipher);
        _addCommittedValidator(collectRound, miningAddress);
    }

    /// @dev Called by the validator's node to XOR its secret with the current random seed.
    /// The validator's node must use its mining address to call this function.
    /// This function can only be called once per collection round (during the `reveals phase`).
    /// @param _secret The validator's secret.
    function revealSecret(uint256 _secret) external {
        address miningAddress = msg.sender;

        require(revealSecretCallable(miningAddress, _secret));
        require(block.coinbase == miningAddress); // make sure validator node is live

        _setCurrentSeed(_getCurrentSeed() ^ _secret);
        _setSentReveal(currentCollectRound(), miningAddress);
    }

    /// @dev Initializes the contract at network startup.
    /// Must be called by the constructor of the `InitializerAuRa` contract on the genesis block.
    /// @param _collectRoundLength The length of a collection round in blocks.
    function initialize(
        uint256 _collectRoundLength // in blocks
    ) external {
        require(block.number == 0);
        require(_collectRoundLength % 2 == 0);
        require(_collectRoundLength > 0);
        require(collectRoundLength() == 0);
        uintStorage[COLLECT_ROUND_LENGTH] = _collectRoundLength;
    }

    /// @dev Checks whether the current validators at the end of each collection round revealed their secrets,
    /// and removes malicious validators if needed.
    /// This function does nothing if the current block is not the last block of the current collection round.
    /// Can only be called by the `BlockRewardAuRa` contract (its `reward` function).
    function onFinishCollectRound() external onlyBlockReward {
        if (block.number % collectRoundLength() != collectRoundLength() - 1) return;

        // This is the last block of the current collection round

        address[] memory validators;
        address validator;
        uint256 i;

        address stakingContract = IValidatorSet(VALIDATOR_SET_CONTRACT).stakingContract();

        uint256 stakingEpoch = IStaking(stakingContract).stakingEpoch();
        uint256 applyBlock = IValidatorSet(VALIDATOR_SET_CONTRACT).validatorSetApplyBlock();
        uint256 endBlock = IStakingAuRa(stakingContract).stakingEpochEndBlock();
        uint256 currentRound = currentCollectRound();

        if (applyBlock != 0 && block.number > applyBlock + collectRoundLength() * 2) {
            // Check whether each validator didn't reveal their secret
            // during the current collection round
            validators = IValidatorSet(VALIDATOR_SET_CONTRACT).getValidators();
            for (i = 0; i < validators.length; i++) {
                validator = validators[i];
                if (!sentReveal(currentRound, validator)) {
                    _incrementRevealSkips(stakingEpoch, validator);
                }
            }
        }

        // If this is the last collection round in the current staking epoch.
        if (block.number == endBlock || block.number + collectRoundLength() > endBlock) {
            uint256 maxRevealSkipsAllowed =
                IStakingAuRa(stakingContract).stakeWithdrawDisallowPeriod() / collectRoundLength();

            if (maxRevealSkipsAllowed > 0) {
                maxRevealSkipsAllowed--;
            }

            // Check each validator to see if they didn't reveal
            // their secret during the last full `reveals phase`
            // or if they missed the required number of reveals per staking epoch.
            validators = IValidatorSet(VALIDATOR_SET_CONTRACT).getValidators();
            for (i = 0; i < validators.length; i++) {
                validator = validators[i];
                if (
                    !sentReveal(currentRound, validator) ||
                    revealSkips(stakingEpoch, validator) > maxRevealSkipsAllowed
                ) {
                    // Remove the validator as malicious
                    IValidatorSetAuRa(VALIDATOR_SET_CONTRACT).removeMaliciousValidator(validator);
                }
            }
        }

        // Clear unnecessary info about previous collection round.
        _clearOldCiphers(currentRound);
    }

    // =============================================== Getters ========================================================

    /// @dev Returns the length of the collection round (in blocks).
    function collectRoundLength() public view returns(uint256) {
        return uintStorage[COLLECT_ROUND_LENGTH];
    }

    /// @dev Returns the length of the commits/reveals phase which is always half of the collection round length.
    function commitPhaseLength() public view returns(uint256) {
        return collectRoundLength() / 2;
    }

    /// @dev Returns the serial number of the current collection round.
    function currentCollectRound() public view returns(uint256) {
        return block.number / collectRoundLength();
    }

    /// @dev Returns the cipher of the validator's secret for the specified collection round and the specified validator
    /// stored by the validator through the `commitHash` function.
    /// @param _collectRound The serial number of the collection round for which the cipher should be retrieved.
    /// @param _miningAddress The mining address of validator.
    function getCipher(uint256 _collectRound, address _miningAddress) public view returns(bytes memory) {
        return bytesStorage[keccak256(abi.encode(CIPHERS, _collectRound, _miningAddress))];
    }

    /// @dev Returns the Keccak-256 hash of the validator's secret for the specified collection round and the specified
    /// validator stored by the validator through the `commitHash` function.
    /// @param _collectRound The serial number of the collection round for which the hash should be retrieved.
    /// @param _miningAddress The mining address of validator.
    function getCommit(uint256 _collectRound, address _miningAddress) public view returns(bytes32) {
        return bytes32Storage[keccak256(abi.encode(COMMITS, _collectRound, _miningAddress))];
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
        return (block.number % collectRoundLength()) < commitPhaseLength();
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

        if (!IValidatorSet(VALIDATOR_SET_CONTRACT).isValidator(_miningAddress)) return false;

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

        if (!IValidatorSet(VALIDATOR_SET_CONTRACT).isValidator(_miningAddress)) return false;

        uint256 collectRound = currentCollectRound();

        if (sentReveal(collectRound, _miningAddress)) {
            return false; // cannot reveal more than once during the same collectRound
        }

        if (secretHash != getCommit(collectRound, _miningAddress)) {
            return false; // the hash must be commited
        }

        return true;
    }

    /// @dev Returns the number of reveal skips made by the specified validator during the specified staking epoch.
    /// @param _stakingEpoch The serial number of the staking epoch for which the number of skips should be returned.
    /// @param _miningAddress The mining address of the validator for which the number of skips should be returned.
    function revealSkips(uint256 _stakingEpoch, address _miningAddress) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(REVEAL_SKIPS, _stakingEpoch, _miningAddress))];
    }

    /// @dev Returns a boolean flag of whether the specified validator has revealed their secret for the
    /// specified collection round.
    /// @param _collectRound The serial number of the collection round for which the checkup should be done.
    /// @param _miningAddress The mining address of the validator.
    function sentReveal(uint256 _collectRound, address _miningAddress) public view returns(bool) {
        return boolStorage[keccak256(abi.encode(SENT_REVEAL, _collectRound, _miningAddress))];
    }

    // =============================================== Private ========================================================

    bytes32 internal constant COLLECT_ROUND_LENGTH = keccak256("collectRoundLength");
    bytes32 internal constant CIPHERS = "ciphers";
    bytes32 internal constant COMMITS = "commits";
    bytes32 internal constant COMMITTED_VALIDATORS = "committedValidators";
    bytes32 internal constant REVEAL_SKIPS = "revealSkips";
    bytes32 internal constant SENT_REVEAL = "sentReveal";

    /// @dev Adds the specified validator to the array of validators that committed their
    /// hashes during the specified collection round. Used by the `commitHash` function.
    /// @param _collectRound The serial number of the collection round.
    /// @param _miningAddress The validator's mining address to be added.
    function _addCommittedValidator(uint256 _collectRound, address _miningAddress) private {
        addressArrayStorage[keccak256(abi.encode(COMMITTED_VALIDATORS, _collectRound))].push(_miningAddress);
    }

    /// @dev Removes the ciphers of all committed validators for the specified collection round.
    /// @param _collectRound The serial number of the collection round.
    function _clearOldCiphers(uint256 _collectRound) private {
        if (_collectRound == 0) {
            return;
        }

        uint256 collectRound = _collectRound - 1;
        address[] storage miningAddresses =
            addressArrayStorage[keccak256(abi.encode(COMMITTED_VALIDATORS, collectRound))];

        for (uint256 i = 0; i < miningAddresses.length; i++) {
            delete bytesStorage[keccak256(abi.encode(CIPHERS, collectRound, miningAddresses[i]))];
        }
    }

    /// @dev Increments the reveal skips counter for the specified validator and staking epoch.
    /// Used by the `onFinishCollectRound` function.
    /// @param _stakingEpoch The serial number of the staking epoch.
    /// @param _miningAddress The validator's mining address.
    function _incrementRevealSkips(uint256 _stakingEpoch, address _miningAddress) private {
        uintStorage[keccak256(abi.encode(REVEAL_SKIPS, _stakingEpoch, _miningAddress))]++;
    }

    /// @dev Stores the cipher of the secret for the specified validator and collection round.
    /// Used by the `commitHash` function.
    /// @param _collectRound The serial number of the collection round.
    /// @param _miningAddress The validator's mining address.
    /// @param _cipher The cipher's bytes sequence to be stored.
    function _setCipher(uint256 _collectRound, address _miningAddress, bytes memory _cipher) private {
        bytesStorage[keccak256(abi.encode(CIPHERS, _collectRound, _miningAddress))] = _cipher;
    }

    /// @dev Stores the Keccak-256 hash of the secret for the specified validator and collection round.
    /// Used by the `commitHash` function.
    /// @param _collectRound The serial number of the collection round.
    /// @param _miningAddress The validator's mining address.
    /// @param _secretHash The hash to be stored.
    function _setCommit(uint256 _collectRound, address _miningAddress, bytes32 _secretHash) private {
        bytes32Storage[keccak256(abi.encode(COMMITS, _collectRound, _miningAddress))] = _secretHash;
    }

    /// @dev Stores the boolean flag of whether the specified validator revealed their secret
    /// during the specified collection round.
    /// @param _collectRound The serial number of the collection round.
    /// @param _miningAddress The validator's mining address.
    function _setSentReveal(uint256 _collectRound, address _miningAddress) private {
        boolStorage[keccak256(abi.encode(SENT_REVEAL, _collectRound, _miningAddress))] = true;
    }
}
