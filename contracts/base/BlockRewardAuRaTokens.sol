pragma solidity 0.5.12;

import "./BlockRewardAuRaBase.sol";
import "../interfaces/IBlockRewardAuRaTokens.sol";
import "../interfaces/IStakingAuRaTokens.sol";


contract BlockRewardAuRaTokens is BlockRewardAuRaBase, IBlockRewardAuRaTokens {

    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables and do not change their types!

    mapping(address => bool) internal _ercToErcBridgeAllowed;
    mapping(address => bool) internal _nativeToErcBridgeAllowed;
    address[] internal _ercToErcBridgesAllowed;
    address[] internal _nativeToErcBridgesAllowed;

    /// @dev The current bridge's total fee amount of staking tokens accumulated by
    /// the `addBridgeTokenFeeReceivers` function.
    uint256 public bridgeTokenFee;

    /// @dev The reward amount to be distributed in staking tokens among participants (the validator and their
    /// delegators) of the specified pool (mining address) for the specified staking epoch.
    mapping(uint256 => mapping(address => uint256)) public epochPoolTokenReward;

    /// @dev The total reward amount in staking tokens which is not yet distributed among pools.
    uint256 public tokenRewardUndistributed;

    // ================================================ Events ========================================================

    /// @dev Emitted by the `addBridgeTokenFeeReceivers` function.
    /// @param amount The fee amount in tokens passed to the
    /// `addBridgeTokenFeeReceivers` function as a parameter.
    /// @param cumulativeAmount The value of `bridgeTokenFee` state variable
    /// after adding the `amount` to it.
    /// @param bridge The bridge address which called the `addBridgeTokenFeeReceivers` function.
    event BridgeTokenFeeAdded(uint256 amount, uint256 cumulativeAmount, address indexed bridge);

    // ============================================== Modifiers =======================================================

    /// @dev Ensures the caller is the `erc-to-erc` or `native-to-erc` bridge contract address.
    modifier onlyXToErcBridge {
        require(_ercToErcBridgeAllowed[msg.sender] || _nativeToErcBridgeAllowed[msg.sender]);
        _;
    }

    // =============================================== Setters ========================================================

    /// @dev Called by the `erc-to-erc` or `native-to-erc` bridge contract when a portion of the bridge fee should be
    /// minted and distributed to participants in staking tokens. The specified amount is used by the
    /// `_distributeRewards` function.
    /// @param _amount The fee amount distributed to participants.
    function addBridgeTokenFeeReceivers(uint256 _amount) external onlyXToErcBridge {
        require(_amount != 0);
        bridgeTokenFee = bridgeTokenFee.add(_amount);
        emit BridgeTokenFeeAdded(_amount, bridgeTokenFee, msg.sender);
    }

    /// @dev Sets the array of `erc-to-erc` bridge addresses which are allowed to call some of the functions with
    /// the `onlyXToErcBridge` modifier. This setter can only be called by the `owner`.
    /// @param _bridgesAllowed The array of bridge addresses.
    function setErcToErcBridgesAllowed(address[] calldata _bridgesAllowed) external onlyOwner onlyInitialized {
        uint256 i;

        for (i = 0; i < _ercToErcBridgesAllowed.length; i++) {
            _ercToErcBridgeAllowed[_ercToErcBridgesAllowed[i]] = false;
        }

        _ercToErcBridgesAllowed = _bridgesAllowed;

        for (i = 0; i < _bridgesAllowed.length; i++) {
            _ercToErcBridgeAllowed[_bridgesAllowed[i]] = true;
        }
    }

    /// @dev Sets the array of `native-to-erc` bridge addresses which are allowed to call some of the functions with
    /// the `onlyXToErcBridge` modifier. This setter can only be called by the `owner`.
    /// @param _bridgesAllowed The array of bridge addresses.
    function setNativeToErcBridgesAllowed(address[] calldata _bridgesAllowed) external onlyOwner onlyInitialized {
        uint256 i;

        for (i = 0; i < _nativeToErcBridgesAllowed.length; i++) {
            _nativeToErcBridgeAllowed[_nativeToErcBridgesAllowed[i]] = false;
        }

        _nativeToErcBridgesAllowed = _bridgesAllowed;

        for (i = 0; i < _bridgesAllowed.length; i++) {
            _nativeToErcBridgeAllowed[_bridgesAllowed[i]] = true;
        }
    }

    /// @dev Called by the `StakingAuRa.claimReward` function to transfer tokens and native coins
    /// from the balance of the `BlockRewardAuRa` contract to the specified address as a reward.
    /// @param _tokens The amount of tokens to transfer as a reward.
    /// @param _nativeCoins The amount of native coins to transfer as a reward.
    /// @param _to The target address to transfer the amounts to.
    function transferReward(uint256 _tokens, uint256 _nativeCoins, address payable _to) external onlyStakingContract {
        if (_tokens != 0) {
            IStakingAuRaTokens stakingContract = IStakingAuRaTokens(msg.sender);
            IERC677Minting erc677TokenContract = IERC677Minting(stakingContract.erc677TokenContract());
            erc677TokenContract.transfer(_to, _tokens);
        }

        _transferNativeReward(_nativeCoins, _to);
    }

    // =============================================== Getters ========================================================

    /// @dev Returns the array of `erc-to-erc` bridge addresses set by the `setErcToErcBridgesAllowed` setter.
    function ercToErcBridgesAllowed() public view returns(address[] memory) {
        return _ercToErcBridgesAllowed;
    }

    /// @dev Returns the reward amounts in tokens and native coins for
    /// some delegator with the specified stake amount placed into the specified
    /// pool before the specified staking epoch. Used by the `StakingAuRa.claimReward` function.
    /// @param _delegatorStake The stake amount placed by some delegator into the `_poolMiningAddress` pool.
    /// @param _stakingEpoch The serial number of staking epoch.
    /// @param _poolMiningAddress The pool mining address.
    /// @return `uint256 tokenReward` - the reward amount in tokens.
    /// `uint256 nativeReward` - the reward amount in native coins.
    function getDelegatorReward(
        uint256 _delegatorStake,
        uint256 _stakingEpoch,
        address _poolMiningAddress
    ) external view returns(uint256 tokenReward, uint256 nativeReward) {
        uint256 validatorStake = snapshotPoolValidatorStakeAmount[_stakingEpoch][_poolMiningAddress];
        uint256 totalStake = snapshotPoolTotalStakeAmount[_stakingEpoch][_poolMiningAddress];

        tokenReward = delegatorShare(
            _stakingEpoch,
            _delegatorStake,
            validatorStake,
            totalStake,
            epochPoolTokenReward[_stakingEpoch][_poolMiningAddress]
        );

        nativeReward = delegatorShare(
            _stakingEpoch,
            _delegatorStake,
            validatorStake,
            totalStake,
            epochPoolNativeReward[_stakingEpoch][_poolMiningAddress]
        );
    }

    /// @dev Returns the reward amounts in tokens and native coins for
    /// the specified validator and for the specified staking epoch.
    /// Used by the `StakingAuRa.claimReward` function.
    /// @param _stakingEpoch The serial number of staking epoch.
    /// @param _poolMiningAddress The pool mining address.
    /// @return `uint256 tokenReward` - the reward amount in tokens.
    /// `uint256 nativeReward` - the reward amount in native coins.
    function getValidatorReward(
        uint256 _stakingEpoch,
        address _poolMiningAddress
    ) external view returns(uint256 tokenReward, uint256 nativeReward) {
        uint256 validatorStake = snapshotPoolValidatorStakeAmount[_stakingEpoch][_poolMiningAddress];
        uint256 totalStake = snapshotPoolTotalStakeAmount[_stakingEpoch][_poolMiningAddress];

        tokenReward = validatorShare(
            _stakingEpoch,
            validatorStake,
            totalStake,
            epochPoolTokenReward[_stakingEpoch][_poolMiningAddress]
        );

        nativeReward = validatorShare(
            _stakingEpoch,
            validatorStake,
            totalStake,
            epochPoolNativeReward[_stakingEpoch][_poolMiningAddress]
        );
    }

    /// @dev Returns the array of `native-to-erc` bridge addresses which were set by
    /// the `setNativeToErcBridgesAllowed` setter.
    function nativeToErcBridgesAllowed() public view returns(address[] memory) {
        return _nativeToErcBridgesAllowed;
    }

    // ============================================== Internal ========================================================

    /// @dev Distributes rewards in tokens among pools at the latest block of a staking epoch.
    /// This function is called by the `_distributeRewards` function.
    /// @param _stakingContract The address of the StakingAuRa contract.
    /// @param _stakingEpoch The number of the current staking epoch.
    /// @param _totalRewardShareNum Numerator of the total reward share.
    /// @param _totalRewardShareDenom Denominator of the total reward share.
    /// @param _validators The array of the current validators (their mining addresses).
    /// @param _blocksCreatedShareNum Numerators of blockCreated share for each of the validators.
    /// @param _blocksCreatedShareDenom Denominator of blockCreated share.
    function _distributeTokenRewards(
        address _stakingContract,
        uint256 _stakingEpoch,
        uint256 _totalRewardShareNum,
        uint256 _totalRewardShareDenom,
        address[] memory _validators,
        uint256[] memory _blocksCreatedShareNum,
        uint256 _blocksCreatedShareDenom
    ) internal {
        uint256 totalReward = bridgeTokenFee + tokenRewardUndistributed;

        if (totalReward == 0) {
            return;
        }

        bridgeTokenFee = 0;

        IERC677Minting erc677TokenContract = IERC677Minting(
            IStakingAuRaTokens(_stakingContract).erc677TokenContract()
        );

        uint256 distributedAmount = 0;

        if (erc677TokenContract != IERC677Minting(0) && _blocksCreatedShareDenom != 0 && _totalRewardShareDenom != 0) {
            uint256 rewardToDistribute = totalReward * _totalRewardShareNum / _totalRewardShareDenom;

            if (rewardToDistribute != 0) {
                for (uint256 i = 0; i < _validators.length; i++) {
                    uint256 poolReward =
                        rewardToDistribute * _blocksCreatedShareNum[i] / _blocksCreatedShareDenom;
                    epochPoolTokenReward[_stakingEpoch][_validators[i]] = poolReward;
                    distributedAmount += poolReward;
                    if (poolReward != 0 && epochPoolNativeReward[_stakingEpoch][_validators[i]] == 0) {
                        _epochsPoolGotRewardFor[_validators[i]].push(_stakingEpoch);
                    }
                }

                erc677TokenContract.mintReward(distributedAmount);
            }
        }

        tokenRewardUndistributed = totalReward - distributedAmount;
    }
}
