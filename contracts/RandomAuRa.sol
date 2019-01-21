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

    modifier onlyOwner() {
        require(msg.sender == addressStorage[OWNER]);
        _;
    }

    // =============================================== Setters ========================================================

    function commitHash(bytes32 _secretHash) external {
        require(isCommitPhase()); // must only be called in `commits phase`
        require(_secretHash != bytes32(0));

        address validator = msg.sender;
        require(IValidatorSet(VALIDATOR_SET_CONTRACT).isValidator(validator));

        uint256 collectRound = currentCollectRound();

        if (isCommitted(collectRound, validator)) return; // cannot commit more than once

        _setCommit(collectRound, validator, _secretHash);
        _addCommittedValidator(collectRound, validator);
    }

    function revealSecret(uint256 _secret) external {
        require(isRevealPhase()); // must only be called in `reveals phase`

        bytes32 secretHash = keccak256(abi.encodePacked(_secret));
        require(secretHash != bytes32(0));

        address validator = msg.sender;
        require(IValidatorSet(VALIDATOR_SET_CONTRACT).isValidator(validator));

        uint256 collectRound = currentCollectRound();

        if (sentReveal(collectRound, validator)) return; // cannot reveal more than once during the same collectRound

        if (secretHash != getCommit(collectRound, validator)) return; // the hash must be commited

        _setCurrentSecret(_getCurrentSecret() ^ _secret);
        _setSentReveal(collectRound, validator, true);
        _setRevealsCount(collectRound, revealsCount(collectRound).add(1));

        if (revealsCount(collectRound) == committedValidators(collectRound).length) {
            _allowPublishSecret();
        }
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

    function onBlockClose(address _currentValidator) external onlyBlockReward {
        uint256 currentRound = currentCollectRound();

        if (isCommitPhase()) {
            // Remember that the current validator produced the current block
            // during the `commits phase` of the current collection round
            if (!createdBlockOnCommitsPhase(currentRound, _currentValidator)) {
                _setCreatedBlockOnCommitsPhase(currentRound, _currentValidator, true);
                _addBlockProducer(currentRound, _currentValidator);
            }
        } else {
            // Remember that the current validator produced the current block
            // during the `reveals phase` of the current collection round
            if (!createdBlockOnRevealsPhase(currentRound, _currentValidator)) {
                _setCreatedBlockOnRevealsPhase(currentRound, _currentValidator, true);
                if (!createdBlockOnCommitsPhase(currentRound, _currentValidator)) {
                    _addBlockProducer(currentRound, _currentValidator);
                }
            }
        }

        if (block.number % collectRoundLength() == collectRoundLength() - 1) {
            // This is the last block of the current collection round

            if (boolStorage[ALLOW_PUBLISH_SECRET]) {
                _publishSecret(); // publish new secret if `reveals phase` fully completed
            }

            address[] memory validators;
            address validator;
            uint256 blockNumber;
            uint256 i;

            blockNumber = IValidatorSet(VALIDATOR_SET_CONTRACT).validatorSetApplyBlock();

            if (blockNumber != 0 && block.number > blockNumber + collectRoundLength() * 2 || blockNumber == 0) {
                // Check each validator whether he created at least one block
                // during commits phase and at least one block during reveals phase
                // but didn't reveal his secret during reveals phase

                validators = IValidatorSet(VALIDATOR_SET_CONTRACT).getValidators();
                for (i = 0; i < validators.length; i++) {
                    validator = validators[i];
                    if (
                        createdBlockOnCommitsPhase(currentRound, validator) &&
                        createdBlockOnRevealsPhase(currentRound, validator) &&
                        !sentReveal(currentRound, validator)
                    ) {
                        // The validator produced the blocks but didn't reveal his secret during
                        // the current collection round, so remove him from validator set as malicious
                        IValidatorSetAuRa(VALIDATOR_SET_CONTRACT).removeMaliciousValidator(validator);
                    }
                }
            }

            blockNumber = IValidatorSetAuRa(VALIDATOR_SET_CONTRACT).stakingEpochStartBlock();

            // If this is the last collection round in the current staking epoch
            if (
                blockNumber == block.number ||
                block.number + collectRoundLength() >
                blockNumber + IValidatorSetAuRa(VALIDATOR_SET_CONTRACT).stakingEpochDuration() - 1
            ) {
                // Check each validator whether he didn't reveal
                // his secret during the last full `reveals phase`
                validators = IValidatorSet(VALIDATOR_SET_CONTRACT).getValidators();
                for (i = 0; i < validators.length; i++) {
                    validator = validators[i];
                    if (!sentReveal(currentRound, validator)) {
                        // Remove the validator as malicious
                        IValidatorSetAuRa(VALIDATOR_SET_CONTRACT).removeMaliciousValidator(validator);
                    }
                }
            }

            // Clear info about previous collection round
            _clear(currentRound);
        }
    }

    // =============================================== Getters ========================================================

    function blocksProducers(uint256 _collectRound) public view returns(address[] memory) {
        return addressArrayStorage[keccak256(abi.encode(BLOCKS_PRODUCERS, _collectRound))];
    }

    function collectRoundLength() public view returns(uint256) {
        return uintStorage[COLLECT_ROUND_LENGTH];
    }
    function commitPhaseLength() public view returns(uint256) {
        return collectRoundLength() / 2;
    }

    function committedValidators(uint256 _collectRound) public view returns(address[] memory) {
        return addressArrayStorage[keccak256(abi.encode(COMMITTED_VALIDATORS, _collectRound))];
    }

    function createdBlockOnCommitsPhase(uint256 _collectRound, address _validator) public view returns(bool) {
        return boolStorage[keccak256(abi.encode(CREATED_BLOCK_ON_COMMITS_PHASE, _collectRound, _validator))];
    }

    function createdBlockOnRevealsPhase(uint256 _collectRound, address _validator) public view returns(bool) {
        return boolStorage[keccak256(abi.encode(CREATED_BLOCK_ON_REVEALS_PHASE, _collectRound, _validator))];
    }

    // Returns the number of collection round for the current block
    function currentCollectRound() public view returns(uint256) {
        return block.number / collectRoundLength();
    }

    function getCommit(uint256 _collectRound, address _validator) public view returns(bytes32) {
        return bytes32Storage[keccak256(abi.encode(COMMITS, _collectRound, _validator))];
    }

    function getCurrentSecret() public onlyOwner view returns(uint256) {
        return _getCurrentSecret();
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

    function revealsCount(uint256 _collectRound) public view returns(uint256) {
        return uintStorage[keccak256(abi.encode(REVEALS_COUNT, _collectRound))];
    }

    function sentReveal(uint256 _collectRound, address _validator) public view returns(bool) {
        return boolStorage[keccak256(abi.encode(SENT_REVEAL, _collectRound, _validator))];
    }

    // =============================================== Private ========================================================

    bytes32 internal constant ALLOW_PUBLISH_SECRET = keccak256("allowPublishSecret");
    bytes32 internal constant COLLECT_ROUND_LENGTH = keccak256("collectRoundLength");
    bytes32 internal constant CURRENT_SECRET = keccak256("currentSecret");
    bytes32 internal constant OWNER = keccak256("owner");

    bytes32 internal constant BLOCKS_PRODUCERS = "blocksProducers";
    bytes32 internal constant COMMITS = "commits";
    bytes32 internal constant COMMITTED_VALIDATORS = "committedValidators";
    bytes32 internal constant CREATED_BLOCK_ON_COMMITS_PHASE = "createdBlockOnCommitsPhase";
    bytes32 internal constant CREATED_BLOCK_ON_REVEALS_PHASE = "createdBlockOnRevealsPhase";
    bytes32 internal constant REVEALS_COUNT = "revealsCount";
    bytes32 internal constant SENT_REVEAL = "sentReveal";

    function _addBlockProducer(uint256 _collectRound, address _validator) private {
        addressArrayStorage[
            keccak256(abi.encode(BLOCKS_PRODUCERS, _collectRound))
        ].push(_validator);
    }

    function _addCommittedValidator(uint256 _collectRound, address _validator) private {
        addressArrayStorage[keccak256(abi.encode(COMMITTED_VALIDATORS, _collectRound))].push(_validator);
    }

    function _allowPublishSecret() private {
        boolStorage[ALLOW_PUBLISH_SECRET] = true;
    }

    function _clearBlocksProducers(uint256 _collectRound) private {
        delete addressArrayStorage[keccak256(abi.encode(BLOCKS_PRODUCERS, _collectRound))];
    }

    function _denyPublishSecret() private {
        boolStorage[ALLOW_PUBLISH_SECRET] = false;
    }

    // Removes garbage
    function _clear(uint256 _currentCollectRound) private {
        if (_currentCollectRound == 0) {
            return;
        }

        uint256 collectRound = _currentCollectRound - 1;
        address[] memory validators;
        uint256 i;

        validators = committedValidators(collectRound);
        for (i = 0; i < validators.length; i++) {
            _setCommit(collectRound, validators[i], bytes32(0));
            _setSentReveal(collectRound, validators[i], false);
        }
        _clearCommittedValidators(collectRound);

        validators = blocksProducers(collectRound);
        for (i = 0; i < validators.length; i++) {
            _setCreatedBlockOnCommitsPhase(collectRound, validators[i], false);
            _setCreatedBlockOnRevealsPhase(collectRound, validators[i], false);
        }
        _clearBlocksProducers(collectRound);

        _setRevealsCount(collectRound, 0);
        _denyPublishSecret();
    }

    function _clearCommittedValidators(uint256 _collectRound) private {
        delete addressArrayStorage[keccak256(abi.encode(COMMITTED_VALIDATORS, _collectRound))];
    }

    function _publishSecret() private {
        uint256[] storage randomArray = uintArrayStorage[RANDOM_ARRAY];

        randomArray.push(_getCurrentSecret());

        if (randomArray.length > IValidatorSet(VALIDATOR_SET_CONTRACT).MAX_VALIDATORS()) {
            // Shift random array to remove the first item
            uint256 length = randomArray.length.sub(1);
            for (uint256 i = 0; i < length; i++) {
                randomArray[i] = randomArray[i + 1];
            }
            randomArray.length = length;
        }

        _denyPublishSecret();
    }

    function _setCollectRoundLength(uint256 _length) private {
        uintStorage[COLLECT_ROUND_LENGTH] = _length;
    }

    function _setCommit(uint256 _collectRound, address _validator, bytes32 _secretHash) private {
        bytes32Storage[keccak256(abi.encode(COMMITS, _collectRound, _validator))] = _secretHash;
    }

    function _setCreatedBlockOnCommitsPhase(uint256 _collectRound, address _validator, bool _flag) private {
        boolStorage[
            keccak256(abi.encode(CREATED_BLOCK_ON_COMMITS_PHASE, _collectRound, _validator))
        ] = _flag;
    }

    function _setCreatedBlockOnRevealsPhase(uint256 _collectRound, address _validator, bool _flag) private {
        boolStorage[
            keccak256(abi.encode(CREATED_BLOCK_ON_REVEALS_PHASE, _collectRound, _validator))
        ] = _flag;
    }

    function _setCurrentSecret(uint256 _secret) private {
        uintStorage[CURRENT_SECRET] = _secret;
    }

    function _setRevealsCount(uint256 _collectRound, uint256 _count) private {
        uintStorage[keccak256(abi.encode(REVEALS_COUNT, _collectRound))] = _count;
    }

    function _setSentReveal(uint256 _collectRound, address _validator, bool _sent) private {
        boolStorage[keccak256(abi.encode(SENT_REVEAL, _collectRound, _validator))] = _sent;
    }

    function _getCurrentSecret() private view returns(uint256) {
        return uintStorage[CURRENT_SECRET];
    }
}
