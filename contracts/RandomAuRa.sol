pragma solidity 0.4.25;

import "./abstracts/RandomBase.sol";
import "./interfaces/IRandomAuRa.sol";


contract RandomAuRa is RandomBase, IRandomAuRa {

    // ============================================== Constants =======================================================

    uint256 public constant COLLECT_ROUND_LENGTH = 200; // blocks
    uint256 public constant COMMIT_PHASE_LENGTH = COLLECT_ROUND_LENGTH / 2; // blocks

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

    function commitHash(bytes32 _secretHash, bytes _signature) public onlySystem {
        require(isCommitPhase()); // must only be called in commits phase
        require(_secretHash != bytes32(0));

        address validator = _recoverAddressFromSignedMessage(_secretHash, _signature);
        require(IValidatorSet(VALIDATOR_SET_CONTRACT).isValidator(validator));

        uint256 collectRound = currentCollectRound();

        require(getCommit(collectRound, validator) == bytes32(0)); // cannot commit more than once

        if (committedValidators(collectRound).length == 0) {
            // Clear info about previous collection round
            _clear();
        }

        _setCommit(collectRound, validator, _secretHash);
        _addCommittedValidator(collectRound, validator);
    }

    function revealSecret(uint256 _secret, bytes _signature) public onlySystem {
        require(isRevealPhase()); // must only be called in reveals phase

        bytes32 secretHash = keccak256(abi.encodePacked(_secret));
        require(secretHash != bytes32(0));

        address validator = _recoverAddressFromSignedMessage(bytes32(_secret), _signature);
        require(IValidatorSet(VALIDATOR_SET_CONTRACT).isValidator(validator));

        uint256 collectRound = currentCollectRound();

        require(!sentReveal(collectRound, validator)); // cannot reveal more than once during the same collection round
        require(secretHash == getCommit(collectRound, validator)); // the hash must be commited

        _setCurrentSecret(_getCurrentSecret() ^ _secret);
        _setSentReveal(collectRound, validator, true);
        _setRevealsCount(collectRound, revealsCount(collectRound).add(1));

        if (revealsCount(collectRound) == committedValidators(collectRound).length) {
            _allowPublishSecret();
        }
    }

    function onBlockClose(address _currentValidator) external onlyBlockReward {
        // if (isCommitPhase()) {
        //     createdBlockOnCommitsPhase[currentCollectRound()][_currentValidator] = true;
        // } else {
        //     createdBlockOnRevealsPhase[currentCollectRound()][_currentValidator] = true;
        // }

        if (block.number % COLLECT_ROUND_LENGTH == COLLECT_ROUND_LENGTH - 1) {
            // This is the last block of the current collection round

            if (boolStorage[ALLOW_PUBLISH_SECRET]) {
                _publishSecret(); // publish new secret if reveals phase fully completed
            }

            uint256 applyBlock = IValidatorSet(VALIDATOR_SET_CONTRACT).validatorSetApplyBlock();

            if (applyBlock != 0 && block.number > applyBlock + COLLECT_ROUND_LENGTH * 2 || applyBlock == 0) {
                // Check each validator whether he created at least one block
                // during commits phase and at least one block during reveals phase
                // but didn't reveal his secret during reveals phase

                // mapping(collectRound => mapping(validator => bool)) public createdBlockOnCommitsPhase;
                // mapping(collectRound => mapping(validator => bool)) public createdBlockOnRevealsPhase;

                // address[] memory validators = IValidatorSet(VALIDATOR_SET_CONTRACT).getValidators();
                // for (uint256 i = 0; i < validators.length; i++) {
                //     address validator = validators[i];
                //     if (
                //         createdBlockOnCommitsPhase[currentCollectRound()][validator] &&
                //         createdBlockOnRevealsPhase[currentCollectRound()][validator] &&
                //         !sentReveal(currentCollectRound(), validator)
                //     ) {
                //         // Remove validator from validator set as malicious
                //         // ...
                //     }
                // }
            }
        }
    }

    // =============================================== Getters ========================================================

    function committedValidators(uint256 _collectRound) public view returns(address[]) {
        return addressArrayStorage[keccak256(abi.encode(COMMITTED_VALIDATORS, _collectRound))];
    }

    // Returns the number of collection round for the current block
    function currentCollectRound() public view returns(uint256) {
        return block.number / COLLECT_ROUND_LENGTH;
    }

    function getCommit(uint256 _collectRound, address _validator) public view returns(bytes32) {
        return bytes32Storage[keccak256(abi.encode(COMMITS, _collectRound, _validator))];
    }

    function getCurrentSecret() public onlyOwner view returns(uint256) {
        return _getCurrentSecret();
    }

    function isCommitPhase() public view returns(bool) {
        return (block.number % COLLECT_ROUND_LENGTH) < COMMIT_PHASE_LENGTH;
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
    bytes32 internal constant CURRENT_SECRET = keccak256("currentSecret");
    bytes32 internal constant OWNER = keccak256("owner");

    bytes32 internal constant COMMITS = "commits";
    bytes32 internal constant COMMITTED_VALIDATORS = "committedValidators";
    bytes32 internal constant REVEALS_COUNT = "revealsCount";
    bytes32 internal constant SENT_REVEAL = "sentReveal";

    function _addCommittedValidator(uint256 _collectRound, address _validator) private {
        addressArrayStorage[keccak256(abi.encode(COMMITTED_VALIDATORS, _collectRound))].push(_validator);
    }

    function _allowPublishSecret() private {
        boolStorage[ALLOW_PUBLISH_SECRET] = true;
    }

    function _denyPublishSecret() private {
        boolStorage[ALLOW_PUBLISH_SECRET] = false;
    }

    // Removes garbage
    function _clear() private {
        uint256 collectRound = currentCollectRound();

        if (collectRound == 0) {
            return;
        }

        collectRound--;

        address[] memory validators = committedValidators(collectRound);

        for (uint256 i = 0; i < validators.length; i++) {
            _setCommit(collectRound, validators[i], bytes32(0));
            _setSentReveal(collectRound, validators[i], false);
        }

        _setRevealsCount(collectRound, 0);
        _clearCommittedValidators(collectRound);
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

    function _setCommit(uint256 _collectRound, address _validator, bytes32 _secretHash) private {
        bytes32Storage[keccak256(abi.encode(COMMITS, _collectRound, _validator))] = _secretHash;
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

    function _recoverAddressFromSignedMessage(bytes32 _message, bytes _signature)
        private
        pure
        returns(address)
    {
        require(_signature.length == 65);
        bytes32 r;
        bytes32 s;
        bytes1 v;
        assembly {
            r := mload(add(_signature, 0x20))
            s := mload(add(_signature, 0x40))
            v := mload(add(_signature, 0x60))
        }
        bytes memory prefix = "\x19Ethereum Signed Message:\n";
        string memory msgLength = "32";
        bytes32 messageHash = keccak256(abi.encodePacked(prefix, msgLength, _message));
        return ecrecover(messageHash, uint8(v), r, s);
    }
}