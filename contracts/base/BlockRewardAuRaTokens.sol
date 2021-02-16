pragma solidity 0.5.10;

import "./BlockRewardAuRaBase.sol";
import "../interfaces/IBlockRewardAuRaTokens.sol";
import "../interfaces/IStakingAuRaTokens.sol";
import "../interfaces/ITokenMinter.sol";


contract BlockRewardAuRaTokens is BlockRewardAuRaBase, IBlockRewardAuRaTokens {

    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables, do not change their order,
    // and do not change their types!

    mapping(address => bool) internal _ercToErcBridgeAllowed;
    mapping(address => bool) internal _nativeToErcBridgeAllowed;
    address[] internal _ercToErcBridgesAllowed;
    address[] internal _nativeToErcBridgesAllowed;

    /// @dev The current bridge's total fee/reward amount of staking tokens accumulated by
    /// the `addBridgeTokenRewardReceivers` function.
    uint256 public bridgeTokenReward;

    /// @dev The reward amount to be distributed in staking tokens among participants (the validator and their
    /// delegators) of the specified pool (staking address) for the specified staking epoch.
    mapping(uint256 => mapping(address => uint256)) public epochPoolTokenReward;

    /// @dev The total reward amount in staking tokens which is not yet distributed among pools.
    uint256 public tokenRewardUndistributed;

    /// @dev The address of the minting contract. If it's zero, the address returned by
    /// IStakingAuRaTokens(_stakingContract).erc677TokenContract() is used.
    ITokenMinter public tokenMinterContract;

    // ============================================== Constants =======================================================

    /// @dev Inflation rate per staking epoch. Calculated as follows:
    /// 15% annual rate * 48 staking weeks per staking year / 100 * 10**18
    /// This assumes that 1 staking epoch = 1 week
    /// i.e. Inflation Rate = 15/48/100 * 1 ether
    /// Recalculate it for different annual rate and/or different staking epoch duration.
    uint256 public constant STAKE_TOKEN_INFLATION_RATE = 3125000000000000;

    // ================================================ Events ========================================================

    /// @dev Emitted by the `addBridgeTokenRewardReceivers` function.
    /// @param amount The fee/reward amount in tokens passed to the
    /// `addBridgeTokenRewardReceivers` function as a parameter.
    /// @param cumulativeAmount The value of `bridgeTokenReward` state variable
    /// after adding the `amount` to it.
    /// @param bridge The bridge address which called the `addBridgeTokenRewardReceivers` function.
    event BridgeTokenRewardAdded(uint256 amount, uint256 cumulativeAmount, address indexed bridge);

    // ============================================== Modifiers =======================================================

    /// @dev Ensures the caller is the `erc-to-erc` or `native-to-erc` bridge contract address.
    modifier onlyXToErcBridge {
        require(_ercToErcBridgeAllowed[msg.sender] || _nativeToErcBridgeAllowed[msg.sender]);
        _;
    }

    // =============================================== Setters ========================================================

    // Temporary function
    function migrateSnapshotsAndRewards(address _miningAddress) external {
        require(msg.sender == address(0xF96E3bb5e06DaA129B9981E1467e2DeDd6451DbE));
        address stakingAddress = validatorSetContract.stakingByMiningAddress(_miningAddress);
        for (uint256 epoch = 0; epoch <= 44; epoch++) {
            uint256 amount = snapshotPoolTotalStakeAmount[epoch][_miningAddress];
            if (amount > 0) {
                snapshotPoolTotalStakeAmount[epoch][stakingAddress] = amount;
                delete snapshotPoolTotalStakeAmount[epoch][_miningAddress];
            }
            amount = snapshotPoolValidatorStakeAmount[epoch][_miningAddress];
            if (amount > 0) {
                snapshotPoolValidatorStakeAmount[epoch][stakingAddress] = amount;
                delete snapshotPoolValidatorStakeAmount[epoch][_miningAddress];
            }
            amount = epochPoolNativeReward[epoch][_miningAddress];
            if (amount > 0) {
                epochPoolNativeReward[epoch][stakingAddress] = amount;
                delete epochPoolNativeReward[epoch][_miningAddress];
            }
            amount = epochPoolTokenReward[epoch][_miningAddress];
            if (amount > 0) {
                epochPoolTokenReward[epoch][stakingAddress] = amount;
                delete epochPoolTokenReward[epoch][_miningAddress];
            }
        }
    }

    /// @dev An alias for `addBridgeTokenRewardReceivers`
    /// (for backward compatibility with the previous bridge contract).
    function addBridgeTokenFeeReceivers(uint256 _amount) external {
        addBridgeTokenRewardReceivers(_amount);
    }

    /// @dev Called by the `erc-to-erc` or `native-to-erc` bridge contract when a portion of the bridge fee/reward
    /// should be minted and distributed to participants in staking tokens. The specified amount is used by the
    /// `_distributeRewards` function.
    /// @param _amount The fee/reward amount distributed to participants.
    function addBridgeTokenRewardReceivers(uint256 _amount) public onlyXToErcBridge {
        require(_amount != 0);
        bridgeTokenReward = bridgeTokenReward.add(_amount);
        emit BridgeTokenRewardAdded(_amount, bridgeTokenReward, msg.sender);
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

    /// @dev Sets the address of the contract which will mint staking tokens.
    /// Such a contract is used when there is no `mintReward` function in the staking token contract
    /// and thus we use an intermediate minting contract.
    /// @param _tokenMinterContract The minter contract address. If it is zero,
    /// the address returned by IStakingAuRaTokens(_stakingContract).erc677TokenContract() is used
    /// as a minting contract.
    function setTokenMinterContract(ITokenMinter _tokenMinterContract) external onlyOwner onlyInitialized {
        tokenMinterContract = _tokenMinterContract;
    }

    /*
    /// @dev Called by the `StakingAuRa.claimReward` function to transfer tokens and native coins
    /// from the balance of the `BlockRewardAuRa` contract to the specified address as a reward.
    /// @param _tokens The amount of tokens to transfer as a reward.
    /// @param _nativeCoins The amount of native coins to transfer as a reward.
    /// @param _to The target address to transfer the amounts to.
    function transferReward(uint256 _tokens, uint256 _nativeCoins, address payable _to) external onlyStakingContract {
        if (_tokens != 0) {
            IStakingAuRaTokens stakingContract = IStakingAuRaTokens(msg.sender);
            IERC677 erc677TokenContract = IERC677(stakingContract.erc677TokenContract());
            erc677TokenContract.transfer(_to, _tokens);
        }

        _transferNativeReward(_nativeCoins, _to);
    }
    */
    // Temporarily lock reward withdrawals
    function transferReward(uint256, uint256, address payable) external onlyStakingContract {
        revert("Temporarily locked");
    }

    // =============================================== Getters ========================================================

    /// @dev Returns the array of `erc-to-erc` bridge addresses set by the `setErcToErcBridgesAllowed` setter.
    function ercToErcBridgesAllowed() public view returns(address[] memory) {
        return _ercToErcBridgesAllowed;
    }

    /// @dev Returns the reward amounts in tokens and native coins for
    /// some delegator with the specified stake amount placed into the specified
    /// pool before the specified staking epoch. Used by the `StakingAuRa.claimReward` function.
    /// @param _delegatorStake The stake amount placed by some delegator into the `_poolStakingAddress` pool.
    /// @param _stakingEpoch The serial number of staking epoch.
    /// @param _poolStakingAddress The pool staking address.
    /// @return `uint256 tokenReward` - the reward amount in tokens.
    /// `uint256 nativeReward` - the reward amount in native coins.
    function getDelegatorReward(
        uint256 _delegatorStake,
        uint256 _stakingEpoch,
        address _poolStakingAddress
    ) external view returns(uint256 tokenReward, uint256 nativeReward) {
        uint256 validatorStake = snapshotPoolValidatorStakeAmount[_stakingEpoch][_poolStakingAddress];
        uint256 totalStake = snapshotPoolTotalStakeAmount[_stakingEpoch][_poolStakingAddress];

        tokenReward = delegatorShare(
            _stakingEpoch,
            _delegatorStake,
            validatorStake,
            totalStake,
            epochPoolTokenReward[_stakingEpoch][_poolStakingAddress]
        );

        nativeReward = delegatorShare(
            _stakingEpoch,
            _delegatorStake,
            validatorStake,
            totalStake,
            epochPoolNativeReward[_stakingEpoch][_poolStakingAddress]
        );
    }

    /// @dev Returns the reward amounts in tokens and native coins for
    /// the specified validator and for the specified staking epoch.
    /// Used by the `StakingAuRa.claimReward` function.
    /// @param _stakingEpoch The serial number of staking epoch.
    /// @param _poolStakingAddress The pool staking address.
    /// @return `uint256 tokenReward` - the reward amount in tokens.
    /// `uint256 nativeReward` - the reward amount in native coins.
    function getValidatorReward(
        uint256 _stakingEpoch,
        address _poolStakingAddress
    ) external view returns(uint256 tokenReward, uint256 nativeReward) {
        uint256 validatorStake = snapshotPoolValidatorStakeAmount[_stakingEpoch][_poolStakingAddress];
        uint256 totalStake = snapshotPoolTotalStakeAmount[_stakingEpoch][_poolStakingAddress];

        tokenReward = validatorShare(
            _stakingEpoch,
            validatorStake,
            totalStake,
            epochPoolTokenReward[_stakingEpoch][_poolStakingAddress]
        );

        nativeReward = validatorShare(
            _stakingEpoch,
            validatorStake,
            totalStake,
            epochPoolNativeReward[_stakingEpoch][_poolStakingAddress]
        );
    }

    /// @dev Returns the array of `native-to-erc` bridge addresses which were set by
    /// the `setNativeToErcBridgesAllowed` setter.
    function nativeToErcBridgesAllowed() public view returns(address[] memory) {
        return _nativeToErcBridgesAllowed;
    }

    /// @dev Calculates the current total reward in tokens which is going to be distributed
    /// among validator pools once the current staking epoch finishes. Its value can differ
    /// from block to block since the reward can increase in time due to bridge's fees.
    /// Used by the `_distributeTokenRewards` internal function but can also be used by
    /// any external user.
    /// @param _stakingContract The address of StakingAuRa contract.
    /// @param _stakingEpoch The number of the current staking epoch.
    /// @param _totalRewardShareNum The value returned by the `_rewardShareNumDenom` internal function.
    /// Ignored if the `_totalRewardShareDenom` param is zero.
    /// @param _totalRewardShareDenom The value returned by the `_rewardShareNumDenom` internal function.
    /// Set it to zero to calculate `_totalRewardShareNum` and `_totalRewardShareDenom` automatically.
    /// @param _validators The array of the current validators. Leave it empty to get the array automatically.
    /// @return `uint256 rewardToDistribute` - The current total reward in tokens to distribute.
    /// `uint256 totalReward` - The current total reward in tokens. Can be greater or equal to `rewardToDistribute`
    /// depending on chain's health (how soon validator set change was finalized after beginning of staking epoch).
    /// Usually equals to `rewardToDistribute`. Used internally by the `_distributeTokenRewards` function.
    function currentTokenRewardToDistribute(
        IStakingAuRa _stakingContract,
        uint256 _stakingEpoch,
        uint256 _totalRewardShareNum,
        uint256 _totalRewardShareDenom,
        address[] memory _validators
    ) public view returns(uint256, uint256) {
        return _currentRewardToDistribute(
            _getTotalTokenReward(_stakingEpoch, _validators),
            _stakingContract,
            _totalRewardShareNum,
            _totalRewardShareDenom
        );
    }

    // ============================================== Internal ========================================================

    /// @dev See the description of `BlockRewardAuRaCoins._coinInflationAmount` internal function.
    /// In this case (when ERC tokens are used for staking) the inflation for native coins is zero.
    function _coinInflationAmount(uint256, address[] memory) internal view returns(uint256) {
        return 0;
    }

    /// @dev Distributes rewards in tokens among pools at the latest block of a staking epoch.
    /// This function is called by the `_distributeRewards` function.
    /// @param _stakingContract The address of the StakingAuRa contract.
    /// @param _stakingEpoch The number of the current staking epoch.
    /// @param _totalRewardShareNum Numerator of the total reward share.
    /// @param _totalRewardShareDenom Denominator of the total reward share.
    /// @param _validators The array of the current validators (their staking addresses).
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
        (uint256 rewardToDistribute, uint256 totalReward) = currentTokenRewardToDistribute(
            IStakingAuRa(_stakingContract),
            _stakingEpoch,
            _totalRewardShareNum,
            _totalRewardShareDenom,
            _validators
        );

        if (totalReward == 0) {
            return;
        }

        bridgeTokenReward = 0;

        IERC677 tokenContract = IERC677(IStakingAuRaTokens(_stakingContract).erc677TokenContract());
        ITokenMinter minterContract;
        if (tokenMinterContract != ITokenMinter(0) && tokenContract != IERC677(0)) {
            if (tokenContract.owner() == address(tokenMinterContract)) {
                minterContract = tokenMinterContract;
            } else {
                minterContract = ITokenMinter(0);
            }
        } else {
            minterContract = ITokenMinter(address(tokenContract));
        }

        uint256 distributedAmount = 0;

        if (minterContract != ITokenMinter(0) && minterContract.blockRewardContract() == address(this)) {
            uint256[] memory poolReward = currentPoolRewards(
                rewardToDistribute,
                _blocksCreatedShareNum,
                _blocksCreatedShareDenom,
                _stakingEpoch
            );
            if (poolReward.length == _validators.length) {
                for (uint256 i = 0; i < _validators.length; i++) {
                    epochPoolTokenReward[_stakingEpoch][_validators[i]] = poolReward[i];
                    distributedAmount += poolReward[i];
                    if (poolReward[i] != 0 && epochPoolNativeReward[_stakingEpoch][_validators[i]] == 0) {
                        _epochsPoolGotRewardFor[_validators[i]].push(_stakingEpoch);
                    }
                }

                minterContract.mintReward(distributedAmount);
            }
        }

        tokenRewardUndistributed = totalReward - distributedAmount;
    }

    /// @dev Calculates the current total reward in tokens.
    /// Used by the `currentTokenRewardToDistribute` function.
    /// @param _stakingEpoch The number of the current staking epoch.
    /// @param _validators The array of the current validators.
    /// Can be empty to retrieve the array automatically inside
    /// the `_inflationAmount` internal function.
    function _getTotalTokenReward(
        uint256 _stakingEpoch,
        address[] memory _validators
    ) internal view returns(uint256 totalReward) {
        totalReward =
            bridgeTokenReward +
            tokenRewardUndistributed +
            _inflationAmount(_stakingEpoch, _validators, STAKE_TOKEN_INFLATION_RATE);
    }
}
