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

    /// @dev Returns the ballot result. Can be either: 1 - keep the pool, 2 - remove, 3 - remove and ban.
    mapping(uint256 => uint256) public ballotResult;

    /// @dev Returns the ballot status. Can be either: 1 - open, 2 - finalized, 3 - canceled.
    mapping(uint256 => uint256) public ballotStatus;

    /// @dev Returns the number of staking epoch during which the ballot was created.
    mapping(uint256 => uint256) public ballotStakingEpoch;

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

    /// @dev Long ban duration in full staking epochs.
    uint256 internal constant BAN_DURATION = 12; // ~90 days

    /// @dev Ballot statuses
    uint256 internal constant BALLOT_STATUS_OPEN = 1; // unfinalized and not cancelled
    uint256 internal constant BALLOT_STATUS_FINALIZED = 2;
    uint256 internal constant BALLOT_STATUS_CANCELED = 3;

    /// @dev Ballot results
    uint256 internal constant BALLOT_RESULT_KEEP = 1; // don't remove a validator from the validator set
    uint256 internal constant BALLOT_RESULT_REMOVE = 2; // remove a validator but don't ban them
    uint256 internal constant BALLOT_RESULT_BAN = 3; // remove a validator from the validator set and ban them

    // ================================================ Events ========================================================

    /// @dev Emitted by the `create` function to signal that a new ballot is created.
    /// @param ballotId A unique id of the newly added ballot.
    event Created(uint256 ballotId);

    /// @dev Emitted by the `cancel` function to signal that a ballot is canceled.
    /// @param ballotId The id of the canceled ballot.
    event Canceled(uint256 ballotId);

    /// @dev Emitted by the `vote` function to signal that there is a new vote
    /// related to the specified ballot from the specified pool.
    /// @param ballotId The id of the ballot for which the vote was given.
    /// @param choice Can be either: 1 - keep the pool, 2 - remove, 3 - remove and ban.
    /// @param senderPoolId The id of the pool which called the `vote` function.
    event Voted(uint256 indexed ballotId, uint256 choice, uint256 indexed senderPoolId);

    /// @dev Emitted by the `finalize` or `vote` function to signal that a ballot is finalized.
    /// @param ballotId The id of the finalized ballot.
    event Finalized(uint256 ballotId);

    // =============================================== Setters ========================================================

    /// @dev Initializes the contract. Used by the constructor of the `InitializerAuRa` contract, or separately when
    /// initializing not from genesis.
    /// @param _validatorSetContract The address of the `ValidatorSetAuRa` contract.
    function initialize(address _validatorSetContract) external {
        require(_getCurrentBlockNumber() == 0 || msg.sender == _admin());
        require(validatorSetContract == IValidatorSetAuRa(0));
        require(_validatorSetContract != address(0));
        validatorSetContract = IValidatorSetAuRa(_validatorSetContract);
    }

    /// @dev Creates a new ballot.
    /// @param _poolId The pool id for which the ballot is created.
    /// @param _duration Ballot duration in blocks. Cannot be less than MIN_DURATION or greater than MAX_DURATION.
    /// @param _reason A reason of the ballot. Can be one of the following (enumerated in BanReasons):
    /// "often block delays"
    /// "often block skips"
    /// "often reveal skips"
    /// "unrevealed"
    /// @param _choice An optional parameter which allows ballot creator to vote immediately when creating a ballot.
    /// Can be one of the following:
    /// 0 - don't vote immediately
    /// 1 - vote for keeping the pool
    /// 2 - vote for removing the pool without long ban
    /// 3 - vote for removing and banning the pool
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
            IStakingAuRa stakingContract = IStakingAuRa(validatorSetContract.stakingContract());
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
            ballotStakingEpoch[ballotId] = stakingContract.stakingEpoch();
        }
        ballotReason[ballotId] = _reason;
        ballotStatus[ballotId] = BALLOT_STATUS_OPEN;
        ballotThreshold[ballotId] = validatorsLength / 2 + 1;

        if (_choice != 0) {
            vote(ballotId, _choice);
        }

        emit Created(ballotId);
    }

    /// @dev Cancels the specified ballot before its expiration.
    /// Can only be called by ballot's creator.
    /// @param _ballotId The ballot id that should be canceled.
    function cancel(uint256 _ballotId) external {
        uint256 senderPoolId = validatorSetContract.idByStakingAddress(msg.sender);
        require(ballotCreator[_ballotId] == senderPoolId);
        require(ballotStatus[_ballotId] == BALLOT_STATUS_OPEN);
        require(_getCurrentBlockNumber() < ballotExpirationBlock[_ballotId]);
        require(validatorSetContract.isValidatorById(senderPoolId));
        ballotStatus[_ballotId] = BALLOT_STATUS_CANCELED;
        openCountPerPoolId[senderPoolId] = openCountPerPoolId[senderPoolId].sub(1);
        emit Canceled(_ballotId);
    }

    /// @dev Gives a vote for the specified ballot.
    /// Can be called by any validator except the validator for which the ballot was created.
    /// @param _ballotId The ballot id.
    /// @param _choice Can be one of the following:
    /// 1 - vote for keeping the pool
    /// 2 - vote for removing the pool without long ban
    /// 3 - vote for removing and banning the pool
    function vote(uint256 _ballotId, uint256 _choice) public {
        require(ballotCreator[_ballotId] != 0);
        uint256 senderPoolId = validatorSetContract.idByStakingAddress(msg.sender);
        require(validatorSetContract.isValidatorById(senderPoolId));
        require(senderPoolId != ballotPoolId[_ballotId]);
        require(ballotStatus[_ballotId] == BALLOT_STATUS_OPEN);
        require(_getCurrentBlockNumber() < ballotExpirationBlock[_ballotId]);
        require(ballotPoolVoted[_ballotId][senderPoolId] == 0);

        ballotPoolVoted[_ballotId][senderPoolId] = _choice;
        if (_choice == BALLOT_RESULT_KEEP) {
            ballotVotesKeep[_ballotId]++;
        } else if (_choice == BALLOT_RESULT_REMOVE) {
            ballotVotesRemove[_ballotId]++;
        } else if (_choice == BALLOT_RESULT_BAN) {
            ballotVotesBan[_ballotId]++;
        } else {
            revert();
        }

        emit Voted(_ballotId, _choice, senderPoolId);

        // Automatically finalize the ballot if all validators voted during the same staking epoch
        if (canBeFinalized(_ballotId)) {
            _finalize(_ballotId);
        }
    }

    /// @dev Finalizes the specified ballot. Can be called by anyone.
    /// @param _ballotId The ballot id.
    function finalize(uint256 _ballotId) public {
        require(canBeFinalized(_ballotId));
        _finalize(_ballotId);
    }

    // =============================================== Getters ========================================================

    /// @dev Returns a boolean flag indicating whether the specified ballot can be finalized
    /// at the current moment. Used by the `vote` and `finalize` functions.
    /// @param _ballotId The ballot id.
    function canBeFinalized(uint256 _ballotId) public view returns(bool) {
        if (ballotStatus[_ballotId] != BALLOT_STATUS_OPEN) {
            return false;
        } else if (_getCurrentBlockNumber() >= ballotExpirationBlock[_ballotId]) {
            return true;
        } else if (
            IStakingAuRa(validatorSetContract.stakingContract()).stakingEpoch() == ballotStakingEpoch[_ballotId]
        ) {
            uint256 keepVotesCount = ballotVotesKeep[_ballotId];
            uint256 removeVotesCount = ballotVotesRemove[_ballotId];
            uint256 banVotesCount = ballotVotesBan[_ballotId];
            uint256 validatorsLength = validatorSetContract.getValidatorsIds().length;

            if (keepVotesCount.add(removeVotesCount).add(banVotesCount) >= validatorsLength) {
                return true;
            }
        }
        return false;
    }

    /// @dev Returns parameters of the specified ballot:
    /// _poolId - id of the pool for which the ballot was created.
    /// _creatorPoolId - id of the pool which created the ballot.
    /// _expirationBlock - the number of expiration block of the ballot.
    /// _longBanUntilBlock - the number of the block at which a pool of the ballot will be unbanned
    /// if validators decide to ban it for a long time.
    /// _shortBanUntilBlock - the number of the block at which a pool of the ballot will be unbanned
    /// if validators decide to remove the pool without its banning.
    /// _reason - the ballot reason (see the description of the `ballotReason` mapping).
    /// _status - the ballot status (see the description of the `ballotStatus` mapping).
    /// _result - the ballot result (see the description of the `ballotResult` mapping).
    /// _threshold - the ballot threshold. If the number of votes achieves the threshold,
    /// the ballot result is accepted when finalizing; if not, the ballot result is declined, so a validator
    /// won't be removed from the consensus.
    /// _keepVotesCount - the number of votes for keeping a pool without removal.
    /// _removeVotesCount - the number of votes for a pool removal.
    /// _banVotesCount - the number of votes for a pool banning.
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
        _result = ballotResult[_ballotId] == 0 ? _calcBallotResult(_ballotId) : ballotResult[_ballotId];
        _threshold = ballotThreshold[_ballotId];
        _keepVotesCount = ballotVotesKeep[_ballotId];
        _removeVotesCount = ballotVotesRemove[_ballotId];
        _banVotesCount = ballotVotesBan[_ballotId];
    }

    /// @dev Returns a boolean flag indicating whether the specified pool is in an active ballot.
    /// Used by the `StakingAuRa._isWithdrawAllowed` internal function to check if tokens can be
    /// withdrawn from the specified pool at the moment. If it returns `true`, it means that the ballot
    /// is still open and not expired. If the open ballot is expired,
    /// the function returns `true` if the current block is in a ban period.
    /// @param _poolId The pool id to check.
    function isValidatorUnderBallot(uint256 _poolId) external view returns(bool) {
        uint256 ballotId = ballotIdByPoolId[_poolId];
        if (ballotId == 0 || ballotStatus[ballotId] != BALLOT_STATUS_OPEN) {
            return false;
        }
        if (_getCurrentBlockNumber() < ballotExpirationBlock[ballotId]) {
            return true;
        }
        uint256 result = _calcBallotResult(ballotId);
        if (result == BALLOT_RESULT_REMOVE) {
            return _getCurrentBlockNumber() <= ballotShortBanUntilBlock[ballotId];
        }
        if (result == BALLOT_RESULT_BAN) {
            return _getCurrentBlockNumber() <= ballotLongBanUntilBlock[ballotId];
        }
        return false;
    }

    // ============================================== Internal ========================================================

    /// @dev Finalizes the specified ballot. Used by the `vote` and `finalize` functions.
    /// @param _ballotId The ballot id.
    function _finalize(uint256 _ballotId) internal {
        require(validatorSetContract != IValidatorSetAuRa(0));
        uint256 result = _calcBallotResult(_ballotId);
        uint256 creatorPoolId = ballotCreator[_ballotId];
        ballotResult[_ballotId] = result;
        ballotStatus[_ballotId] == BALLOT_STATUS_FINALIZED;
        openCountPerPoolId[creatorPoolId] = openCountPerPoolId[creatorPoolId].sub(1);
        if (result == BALLOT_RESULT_REMOVE) {
            validatorSetContract.removeValidator(
                ballotPoolId[_ballotId],
                ballotShortBanUntilBlock[_ballotId],
                ballotReason[_ballotId]
            );
        } else if (result == BALLOT_RESULT_BAN) {
            validatorSetContract.removeValidator(
                ballotPoolId[_ballotId],
                ballotLongBanUntilBlock[_ballotId],
                ballotReason[_ballotId]
            );
        }
        emit Finalized(_ballotId);
    }

    /// @dev Determines a ballot result for the specified ballot.
    /// Used by `isValidatorUnderBallot` and `finalize` functions.
    /// See the description of the `ballotResult` mapping.
    /// @param _ballotId The ballot id.
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
