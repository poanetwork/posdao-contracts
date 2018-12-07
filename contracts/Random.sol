pragma solidity 0.4.25;

import "./interfaces/IRandom.sol";
import "./interfaces/IReportingValidatorSet.sol";
import "./libs/SafeMath.sol";


contract Random is IRandom {
    using SafeMath for uint256;

    // ============================================== Constants =======================================================

    uint256 public constant COLLECT_ROUND_LENGTH = 200; // blocks
    uint256 public constant COMMIT_PHASE_LENGTH = COLLECT_ROUND_LENGTH / 2; // blocks

    enum ConsensusMode { Invalid, AuRa, HBBFT }

    // =============================================== Storage ========================================================

    IReportingValidatorSet public validatorSetContract;
    ConsensusMode public consensusMode;

    mapping(uint256 => mapping(address => bytes32)) public commits;
    mapping(uint256 => address[]) public comittedValidators;
    mapping(uint256 => mapping(address => bool)) public reveals;
    mapping(uint256 => uint256) public revealsCount;
    
    uint256 private _currentSecret;
    uint256[] private _randomArray;

    // ============================================== Modifiers =======================================================

    modifier onlySystem() {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    modifier onlyAuRa() {
        require(consensusMode == ConsensusMode.AuRa);
        _;
    }

    modifier onlyHBBFT() {
        require(consensusMode == ConsensusMode.HBBFT);
        _;
    }

    // =============================================== Setters ========================================================

    constructor(IReportingValidatorSet _validatorSetContract, ConsensusMode _consensusMode) public {
        require(_validatorSetContract != address(0));
        require(_consensusMode != ConsensusMode.Invalid);
        validatorSetContract = _validatorSetContract;
        consensusMode = _consensusMode;
    }

    // This function is for AuRa
    function commitHash(bytes32 _secretHash, address _validator) public onlySystem onlyAuRa {
        require(_secretHash != bytes32(0));
        require(validatorSetContract.isValidator(_validator));
        require(isCommitPhase()); // must only be called in commit phase
        
        uint256 collectRound = currentCollectRound();

        require(commits[collectRound][_validator] == bytes32(0)); // cannot commit more than once

        if (comittedValidators[collectRound].length == 0) {
            // Clear info about previous collection round
            _clear();
        }

        commits[collectRound][_validator] = _secretHash;
        comittedValidators[collectRound].push(_validator);
    }

    // This function is for AuRa
    function revealSecret(uint256 _secret, address _validator) public onlySystem onlyAuRa {
        bytes32 secretHash = keccak256(abi.encodePacked(_secret));

        require(secretHash != bytes32(0));
        require(validatorSetContract.isValidator(_validator));
        require(isRevealPhase()); // must only be called in reveal phase

        uint256 collectRound = currentCollectRound();

        require(!reveals[collectRound][_validator]); // cannot reveal more than once

        if (secretHash == commits[collectRound][_validator]) {
            _currentSecret ^= _secret;
            reveals[collectRound][_validator] = true;
            revealsCount[collectRound] = revealsCount[collectRound].add(1);

            if (revealsCount[collectRound] == validatorSetContract.getValidators().length) {
                _publishSecret();
            }
        }
    }

    // This function is for hbbft
    function storeRandom(uint256[] _random) public onlySystem onlyHBBFT {
        require(_random.length == validatorSetContract.MAX_VALIDATORS());
        _randomArray = _random;
    }

    // =============================================== Getters ========================================================

    // This function is for AuRa
    function currentCollectRound() public view returns(uint256) {
        return block.number / COLLECT_ROUND_LENGTH;
    }

    // This function is called by ReportingValidatorSet.
    // May be used both by AuRa and hbbft.
    function currentRandom() public view returns(uint256[]) {
        return _randomArray;
    }

    // This function is for AuRa
    function isCommitPhase() public view returns(bool) {
        return (block.number % COLLECT_ROUND_LENGTH) < COMMIT_PHASE_LENGTH;
    }

    // This function is for AuRa
    function isRevealPhase() public view returns(bool) {
        return (block.number % COLLECT_ROUND_LENGTH) >= COMMIT_PHASE_LENGTH;
    }

    // =============================================== Private ========================================================

    // Removes garbage
    function _clear() private {
        uint256 collectRound = currentCollectRound();

        if (collectRound == 0) {
            return;
        }

        collectRound--;

        address[] storage validators = comittedValidators[collectRound];

        for (uint256 i = 0; i < validators.length; i++) {
            commits[collectRound][validators[i]] = bytes32(0);
            reveals[collectRound][validators[i]] = false;
        }

        revealsCount[collectRound] = 0;
        validators.length = 0;
    }

    function _publishSecret() private {
        _randomArray.push(_currentSecret);

        if (_randomArray.length > validatorSetContract.MAX_VALIDATORS()) {
            // Shift random array to remove the first item
            uint256 length = _randomArray.length.sub(1);
            for (uint256 i = 0; i < length; i++) {
                _randomArray[i] = _randomArray[i + 1];
            }
            _randomArray.length = length;
        }
    }
}