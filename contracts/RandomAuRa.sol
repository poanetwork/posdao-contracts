pragma solidity 0.5.2;

import "./abstracts/RandomBase.sol";
import "./interfaces/IRandomAuRa.sol";
import "./interfaces/IValidatorSetAuRa.sol";


contract RandomAuRa is RandomBase, IRandomAuRa {

    // ============================================== Modifiers =======================================================

    modifier onlyBlockReward() {
        require(msg.sender == IValidatorSet(VALIDATOR_SET_CONTRACT).blockRewardContract());
        _;
    }

    // =============================================== Setters ========================================================

    function commitHash(bytes32 _secretHash, bytes calldata _cipher) external {
        require(isCommitPhase()); // must only be called in `commits phase`
        require(_secretHash != bytes32(0));

        address validator = msg.sender;
        require(IValidatorSet(VALIDATOR_SET_CONTRACT).isValidator(validator));

        uint256 collectRound = currentCollectRound();

        require(block.coinbase == validator); // make sure validator node is live
        require(!isCommitted(collectRound, validator)); // cannot commit more than once

        _setCommit(collectRound, validator, _secretHash);
        _setCipher(collectRound, validator, _cipher);
        _addCommittedValidator(collectRound, validator);
    }

    function revealSecret(uint256 _secret) external {
        require(isRevealPhase()); // must only be called in `reveals phase`

        bytes32 secretHash = keccak256(abi.encodePacked(_secret));
        require(secretHash != bytes32(0));

        address validator = msg.sender;
        require(IValidatorSet(VALIDATOR_SET_CONTRACT).isValidator(validator));

        uint256 collectRound = currentCollectRound();

        require(block.coinbase == validator); // make sure validator node is live
        require(!sentReveal(collectRound, validator)); // cannot reveal more than once during the same collectRound
        require(secretHash == getCommit(collectRound, validator)); // the hash must be commited

        _setCurrentSecret(_getCurrentSecret() ^ _secret);
        _setSentReveal(collectRound, validator, true);
    }

    /// Initializes the contract at the start of the network.
    /// Must be called by the constructor of `Initializer` contract on genesis block.
    /// This is used instead of `constructor()` because this contract is upgradable.
    function initialize(
        uint256 _collectRoundLength // in blocks
    ) external {
        require(block.number == 0);
        require(_collectRoundLength % 2 == 0);
        require(_collectRoundLength > 0);
        require(collectRoundLength() == 0);
        _setCollectRoundLength(_collectRoundLength);
    }

    function onBlockClose() external onlyBlockReward {
        if (block.number % collectRoundLength() != collectRoundLength() - 1) return;

        // This is the last block of the current collection round

        address[] memory validators;
        address validator;
        uint256 i;

        uint256 stakingEpoch = IValidatorSet(VALIDATOR_SET_CONTRACT).stakingEpoch();
        uint256 applyBlock = IValidatorSet(VALIDATOR_SET_CONTRACT).validatorSetApplyBlock();
        uint256 endBlock = IValidatorSetAuRa(VALIDATOR_SET_CONTRACT).stakingEpochEndBlock();
        uint256 currentRound = currentCollectRound();

        if (applyBlock != 0 && block.number > applyBlock + collectRoundLength() * 2) {
            // Check each validator whether he didn't reveal his secret
            // during collection round
            validators = IValidatorSet(VALIDATOR_SET_CONTRACT).getValidators();
            for (i = 0; i < validators.length; i++) {
                validator = validators[i];
                if (!sentReveal(currentRound, validator)) {
                    _incrementRevealSkips(stakingEpoch, validator);
                }
            }
        }

        // If this is the last collection round in the current staking epoch
        if (block.number == endBlock || block.number + collectRoundLength() > endBlock) {
            uint256 maxRevealSkipsAllowed =
                IValidatorSetAuRa(VALIDATOR_SET_CONTRACT).stakeWithdrawDisallowPeriod() / collectRoundLength();

            if (maxRevealSkipsAllowed > 0) {
                maxRevealSkipsAllowed--;
            }

            // Check each validator whether he didn't reveal
            // his secret during the last full `reveals phase`
            // or he missed required number of reveals per staking epoch
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

        // Clear info about previous collection round
        _clear(currentRound);
    }

    // =============================================== Getters ========================================================

    function collectRoundLength() public view returns(uint256) {
        return uintStorage[COLLECT_ROUND_LENGTH];
    }

    function commitPhaseLength() public view returns(uint256) {
        return collectRoundLength() / 2;
    }

    // Returns the number of collection round for the current block
    function currentCollectRound() public view returns(uint256) {
        return block.number / collectRoundLength();
    }

    function getCipher(uint256 _collectRound, address _validator) public view returns(bytes memory) {
        return bytesStorage[keccak256(abi.encode(CIPHERS, _collectRound, _validator))];
    }

    function getCommit(uint256 _collectRound, address _validator) public view returns(bytes32) {
        return bytes32Storage[keccak256(abi.encode(COMMITS, _collectRound, _validator))];
    }

    function isCommitted(uint256 _collectRound, address _validator) public view returns(bool) {
        return getCommit(_collectRound, _validator) != bytes32(0);
    }

    function isCommitPhase() public view returns(bool) {
        return (block.number % collectRoundLength()) < commitPhaseLength();
    }

    function isRevealPhase() public view returns(bool) {
        return !isCommitPhase();
    }

    function revealSkips(uint256 _stakingEpoch, address _validator) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(REVEAL_SKIPS, _stakingEpoch, _validator))];
    }

    function sentReveal(uint256 _collectRound, address _validator) public view returns(bool) {
        return boolStorage[keccak256(abi.encode(SENT_REVEAL, _collectRound, _validator))];
    }

    // =============================================== Private ========================================================

    bytes32 internal constant COLLECT_ROUND_LENGTH = keccak256("collectRoundLength");
    bytes32 internal constant CIPHERS = "ciphers";
    bytes32 internal constant COMMITS = "commits";
    bytes32 internal constant COMMITTED_VALIDATORS = "committedValidators";
    bytes32 internal constant REVEAL_SKIPS = "revealSkips";
    bytes32 internal constant SENT_REVEAL = "sentReveal";

    function _addCommittedValidator(uint256 _collectRound, address _validator) private {
        addressArrayStorage[keccak256(abi.encode(COMMITTED_VALIDATORS, _collectRound))].push(_validator);
    }

    // Removes garbage
    function _clear(uint256 _currentCollectRound) private {
        if (_currentCollectRound == 0) {
            return;
        }

        uint256 collectRound = _currentCollectRound - 1;
        address[] memory validators = _committedValidators(collectRound);

        for (uint256 i = 0; i < validators.length; i++) {
            _clearCipher(collectRound, validators[i]);
            _setCommit(collectRound, validators[i], bytes32(0));
            _setSentReveal(collectRound, validators[i], false);
        }
        _clearCommittedValidators(collectRound);
    }

    function _clearCommittedValidators(uint256 _collectRound) private {
        delete addressArrayStorage[keccak256(abi.encode(COMMITTED_VALIDATORS, _collectRound))];
    }

    function _clearCipher(uint256 _collectRound, address _validator) private {
        delete bytesStorage[keccak256(abi.encode(CIPHERS, _collectRound, _validator))];
    }

    function _incrementRevealSkips(uint256 _stakingEpoch, address _validator) private {
        uintStorage[keccak256(abi.encode(REVEAL_SKIPS, _stakingEpoch, _validator))]++;
    }

    function _setCipher(uint256 _collectRound, address _validator, bytes memory _cipher) private {
        bytesStorage[keccak256(abi.encode(CIPHERS, _collectRound, _validator))] = _cipher;
    }

    function _setCollectRoundLength(uint256 _length) private {
        uintStorage[COLLECT_ROUND_LENGTH] = _length;
    }

    function _setCommit(uint256 _collectRound, address _validator, bytes32 _secretHash) private {
        bytes32Storage[keccak256(abi.encode(COMMITS, _collectRound, _validator))] = _secretHash;
    }

    function _setSentReveal(uint256 _collectRound, address _validator, bool _sent) private {
        boolStorage[keccak256(abi.encode(SENT_REVEAL, _collectRound, _validator))] = _sent;
    }

    function _committedValidators(uint256 _collectRound) private view returns(address[] memory) {
        return addressArrayStorage[keccak256(abi.encode(COMMITTED_VALIDATORS, _collectRound))];
    }
}
