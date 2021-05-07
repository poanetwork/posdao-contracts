pragma solidity 0.5.10;

import "./base/BanReasons.sol";
import "./interfaces/IGovernance.sol";
import "./interfaces/IStakingAuRa.sol";
import "./interfaces/IValidatorSetAuRa.sol";
import "./upgradeability/UpgradeableOwned.sol";
import "./libs/SafeMath.sol";


/// @dev Lets any validator to create a ballot for some validator removal.
/// This can be helpful when some validator doesn't work for a long time or delays blocks.
/// Validators can vote to remove a bad validator from the validator set.
contract Governance is UpgradeableOwned, BanReasons, IGovernance {
    using SafeMath for uint256;

    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables, do not change their order,
    // and do not change their types!

    /// @dev Returns ID of the latest open ballot related to the specified pool.
    /// There can only be one open ballot for the same pool at the same time.
    /// Returns zero if there is no open ballot for the specified pool.
    mapping(uint256 => uint256) public ballotIdByPoolId;

    /// @dev Returns the number of the current open ballots created by the specified pool.
    mapping(uint256 => uint256) public openCountPerPoolId;

    /// @dev Returns pool id of the specified ballot id.
    mapping(uint256 => uint256) public ballotPoolId;

    /// @dev Returns id of the pool that created the specified ballot.
    mapping(uint256 => uint256) public ballotCreator;

    /// @dev Returns the number of the expiration block of the specified ballot id.
    mapping(uint256 => uint256) public ballotExpirationBlock;

    /// @dev Returns the number of the block at which a pool of the ballot will be unbanned
    /// if validators decide to ban it for a long time.
    mapping(uint256 => uint256) public ballotLongBanUntilBlock;

    /// @dev Returns the number of the block at which a pool of the ballot will be unbanned
    /// if validators decide to remove the pool without its banning.
    mapping(uint256 => uint256) public ballotShortBanUntilBlock;

    /// @dev Returns the ballot reason. Can be either:
    /// "often block delays", "often block skips", "often reveal skips", "unrevealed".
    mapping(uint256 => bytes32) public ballotReason;

    /// @dev Returns the ballot status. Can be either: 1 - open, 2 - finalized, 3 - canceled.
    mapping(uint256 => uint256) public ballotStatus;

    /// @dev Returns the ballot threshold. If the number of votes achieves the threshold,
    /// the ballot result is accepted; if not, the ballot result is declined, so a validator
    /// won't be removed from the consensus.
    mapping(uint256 => uint256) public ballotThreshold;

    /// @dev Returns the number of votes for keeping a pool without removal.
    /// Accepts ballot id as a parameter.
    mapping(uint256 => uint256) public ballotVotesKeep;

    /// @dev Returns the number of votes for a pool removal.
    /// Accepts ballot id as a parameter.
    mapping(uint256 => uint256) public ballotVotesRemove;

    /// @dev Returns the number of votes for a pool banning.
    /// Accepts ballot id as a parameter.
    mapping(uint256 => uint256) public ballotVotesBan;

    /// @dev Returns an integer indicating whether the specified pool
    /// voted for the specified ballot and what choice was made by the pool.
    /// The first parameter is ballot id, the second one is pool id.
    mapping(uint256 => mapping(uint256 => uint256)) public ballotPoolVoted;

    /// @dev Contains the latest ballot ID.
    uint256 public latestBallotId;

    /// @dev The address of the `ValidatorSetAuRa` contract.
    IValidatorSetAuRa public validatorSetContract;

    // ============================================== Constants =======================================================

    /// @dev Min possible ballot duration in blocks.
    uint256 public constant MIN_DURATION = 17280; // 1 day if 5-second blocks

    /// @dev Max possible ballot duration in blocks.
    uint256 public constant MAX_DURATION = 86400; // 5 days if 5-second blocks

    /// @dev Ban duration in full staking epochs.
    uint256 internal constant BAN_DURATION = 12; // ~90 days

    /// @dev Ballot statuses
    uint256 internal constant BALLOT_STATUS_OPEN = 1; // unfinalized and not cancelled ballot
    uint256 internal constant BALLOT_STATUS_FINALIZED = 2;
    uint256 internal constant BALLOT_STATUS_CANCELED = 3;

    /// @dev Ballot results
    uint256 internal constant BALLOT_RESULT_KEEP = 1; // don't remove a validator from the validator set
    uint256 internal constant BALLOT_RESULT_REMOVE = 2; // remove a validator but don't ban them
    uint256 internal constant BALLOT_RESULT_BAN = 3; // remove a validator from the validator set and ban them

    // =============================================== Setters ========================================================

    function initialize(IValidatorSetAuRa _validatorSetContract) external {
        require(_getCurrentBlockNumber() == 0 || msg.sender == _admin());
        require(validatorSetContract == IValidatorSetAuRa(0));
        require(_validatorSetContract != IValidatorSetAuRa(0));
        validatorSetContract = _validatorSetContract;
    }

    function create(uint256 _poolId, uint256 _duration, bytes32 _reason, uint256 _choice) external {
        uint256 senderPoolId = validatorSetContract.idByStakingAddress(msg.sender);
        require(validatorSetContract.isValidatorById(_poolId));
        require(validatorSetContract.isValidatorById(senderPoolId));
        require(_poolId != senderPoolId);

        // Make sure the previous ballot for _poolId is finalized
        require(ballotIdByPoolId[_poolId] == 0);

        uint256 validatorsLength = validatorSetContract.getValidatorsIds().length;

        // Each validator cannot create too many parallel ballots
        uint256 maxParallelBallotsAllowed = validatorsLength / 3;
        require(openCountPerPoolId[senderPoolId]++ < maxParallelBallotsAllowed);

        require(_duration >= MIN_DURATION);
        require(_duration <= MAX_DURATION);

        require(
            _reason == BAN_REASON_OFTEN_BLOCK_DELAYS ||
            _reason == BAN_REASON_OFTEN_BLOCK_SKIPS ||
            _reason == BAN_REASON_OFTEN_REVEAL_SKIPS ||
            _reason == BAN_REASON_UNREVEALED
        );

        uint256 ballotId = ++latestBallotId;
        uint256 expirationBlock = _getCurrentBlockNumber().add(_duration);

        ballotPoolId[ballotId] = _poolId;
        ballotCreator[ballotId] = senderPoolId;
        ballotExpirationBlock[ballotId] = expirationBlock;
        {
            uint256 fullStakingEpochs = BAN_DURATION;
            IStakingAuRa stakingContract = validatorSetContract.stakingContract();
            uint256 stakingEpochDuration = stakingContract.stakingEpochDuration();
            uint256 stakingEpochEndBlock = stakingContract.stakingEpochEndBlock();
            if (expirationBlock > stakingEpochEndBlock) {
                fullStakingEpochs =
                    expirationBlock
                    .sub(stakingEpochEndBlock)
                    .div(stakingEpochDuration)
                    .add(fullStakingEpochs)
                    .add(1);
            }
            ballotLongBanUntilBlock[ballotId] = fullStakingEpochs.mul(stakingEpochDuration).add(stakingEpochEndBlock);
            ballotShortBanUntilBlock[ballotId] = fullStakingEpochs.sub(BAN_DURATION).mul(stakingEpochDuration).add(stakingEpochEndBlock);
        }
        ballotReason[ballotId] = _reason;
        ballotStatus[ballotId] = BALLOT_STATUS_OPEN;
        ballotThreshold[ballotId] = validatorsLength / 2 + 1;

        if (_choice != 0) {
            vote(ballotId, _choice);
        }
    }

    function cancel(uint256 _ballotId) external {
        // TODO: creator of the ballot can cancel it before expiration
    }

    // Can be called by any validator except the validator `ballotPoolId`.
    function vote(uint256 _ballotId, uint256 _choice) public {
        require(ballotCreator[_ballotId] != 0);
        uint256 poolId = validatorSetContract.idByStakingAddress(msg.sender);
        require(validatorSetContract.isValidatorById(poolId));
        require(poolId != ballotPoolId[_ballotId]);
        require(ballotStatus[_ballotId] == BALLOT_STATUS_OPEN);
        require(_getCurrentBlockNumber() < ballotExpirationBlock[_ballotId]);
        require(ballotPoolVoted[_ballotId][poolId] == 0);

        ballotPoolVoted[_ballotId][poolId] = _choice;
        if (_choice == BALLOT_RESULT_KEEP) {
            ballotVotesKeep[_ballotId]++;
        } else if (_choice == BALLOT_RESULT_REMOVE) {
            ballotVotesRemove[_ballotId]++;
        } else if (_choice == BALLOT_RESULT_BAN) {
            ballotVotesBan[_ballotId]++;
        } else {
            revert();
        }

        // TODO: automatically finalize the ballot if all validators voted during the same staking epoch
    }

    function finalize(uint256 _ballotId) external {
    }

    // =============================================== Getters ========================================================

    function getBallot(uint256 _ballotId) external view returns(
        uint256 _poolId,
        uint256 _creatorPoolId,
        uint256 _expirationBlock,
        uint256 _longBanUntilBlock,
        uint256 _shortBanUntilBlock,
        bytes32 _reason,
        uint256 _status,
        uint256 _result,
        uint256 _threshold,
        uint256 _keepVotesCount,
        uint256 _removeVotesCount,
        uint256 _banVotesCount
    ) {
        _poolId = ballotPoolId[_ballotId];
        _creatorPoolId = ballotCreator[_ballotId];
        _expirationBlock = ballotExpirationBlock[_ballotId];
        _longBanUntilBlock = ballotLongBanUntilBlock[_ballotId];
        _shortBanUntilBlock = ballotShortBanUntilBlock[_ballotId];
        _reason = ballotReason[_ballotId];
        _status = ballotStatus[_ballotId];
        _result = _calcBallotResult(_ballotId);
        _threshold = ballotThreshold[_ballotId];
        _keepVotesCount = ballotVotesKeep[_ballotId];
        _removeVotesCount = ballotVotesRemove[_ballotId];
        _banVotesCount = ballotVotesBan[_ballotId];
    }

    function isValidatorUnderBallot(uint256 _poolId) external view returns(bool) {
        uint256 ballotId = ballotIdByPoolId[_poolId];
        if (ballotId == 0 || ballotStatus[ballotId] != BALLOT_STATUS_OPEN) {
            return false;
        }
        if (_getCurrentBlockNumber() < ballotExpirationBlock[ballotId]) {
            return true;
        }
        uint256 ballotResult = _calcBallotResult(ballotId);
        if (ballotResult == BALLOT_RESULT_REMOVE) {
            return _getCurrentBlockNumber() <= ballotShortBanUntilBlock[ballotId];
        }
        if (ballotResult == BALLOT_RESULT_BAN) {
            return _getCurrentBlockNumber() <= ballotLongBanUntilBlock[ballotId];
        }
        return false;
    }

    // ============================================== Internal ========================================================

    function _calcBallotResult(uint256 _ballotId) internal view returns(uint256) {
        uint256 keepVotesCount = ballotVotesKeep[_ballotId];
        uint256 removeVotesCount = ballotVotesRemove[_ballotId];
        uint256 banVotesCount = ballotVotesBan[_ballotId];

        if (keepVotesCount.add(removeVotesCount).add(banVotesCount) < ballotThreshold[_ballotId]) {
            return BALLOT_RESULT_KEEP;
        }

        uint256 result = BALLOT_RESULT_KEEP;

        if (removeVotesCount > banVotesCount) {
            if (removeVotesCount > keepVotesCount) {
                result = BALLOT_RESULT_REMOVE;
            }
        } else {
            if (banVotesCount > removeVotesCount && banVotesCount > keepVotesCount) {
                result = BALLOT_RESULT_BAN;
            }
        }

        return result;
    }

    /// @dev Returns the current block number. Needed mostly for unit tests.
    function _getCurrentBlockNumber() internal view returns(uint256) {
        return block.number;
    }

}
