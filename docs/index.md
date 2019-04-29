---
title: Contracts
---

<div class="contracts">

## Contracts

### `BlockRewardAuRa`

Generates and distributes rewards according to the logic and formulas described in the white paper.

<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#BlockRewardAuRa.reward(address[],uint16[])"><code class="function-signature">reward(address[] benefactors, uint16[] kind)</code></a></li><li><a href="#BlockRewardAuRa.getBlocksCreated(uint256,address)"><code class="function-signature">getBlocksCreated(uint256 _stakingEpoch, address _validatorMiningAddress)</code></a></li><li><a href="#BlockRewardAuRa.getEpochPoolNativeReward(uint256,address)"><code class="function-signature">getEpochPoolNativeReward(uint256 _stakingEpoch, address _poolStakingAddress)</code></a></li><li><a href="#BlockRewardAuRa.getEpochPoolTokenReward(uint256,address)"><code class="function-signature">getEpochPoolTokenReward(uint256 _stakingEpoch, address _poolStakingAddress)</code></a></li><li><a href="#BlockRewardAuRa.getNativeRewardUndistributed()"><code class="function-signature">getNativeRewardUndistributed()</code></a></li><li><a href="#BlockRewardAuRa.getTokenRewardUndistributed()"><code class="function-signature">getTokenRewardUndistributed()</code></a></li><li><a href="#BlockRewardAuRa._distributeRewards(contract IValidatorSet,address,contract IStakingAuRa,uint256,uint256)"><code class="function-signature">_distributeRewards(contract IValidatorSet _validatorSetContract, address _erc20TokenContract, contract IStakingAuRa _stakingContract, uint256 _stakingEpoch, uint256 _rewardPointBlock)</code></a></li><li><a href="#BlockRewardAuRa._dequeueValidator()"><code class="function-signature">_dequeueValidator()</code></a></li><li><a href="#BlockRewardAuRa._enqueueValidator(address)"><code class="function-signature">_enqueueValidator(address _validatorStakingAddress)</code></a></li><li><a href="#BlockRewardAuRa._subNativeRewardUndistributed(uint256)"><code class="function-signature">_subNativeRewardUndistributed(uint256 _minus)</code></a></li><li><a href="#BlockRewardAuRa._subTokenRewardUndistributed(uint256)"><code class="function-signature">_subTokenRewardUndistributed(uint256 _minus)</code></a></li><li><a href="#BlockRewardAuRa._rewardPointBlock(contract IStakingAuRa,contract IValidatorSet)"><code class="function-signature">_rewardPointBlock(contract IStakingAuRa _stakingContract, contract IValidatorSet _validatorSetContract)</code></a></li><li><a href="#BlockRewardAuRa._validatorsQueueSize()"><code class="function-signature">_validatorsQueueSize()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.addBridgeNativeFeeReceivers(uint256)"><code class="function-signature">addBridgeNativeFeeReceivers(uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.addBridgeTokenFeeReceivers(uint256)"><code class="function-signature">addBridgeTokenFeeReceivers(uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.addExtraReceiver(uint256,address)"><code class="function-signature">addExtraReceiver(uint256 _amount, address _receiver)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.setErcToNativeBridgesAllowed(address[])"><code class="function-signature">setErcToNativeBridgesAllowed(address[] _bridgesAllowed)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.setNativeToErcBridgesAllowed(address[])"><code class="function-signature">setNativeToErcBridgesAllowed(address[] _bridgesAllowed)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.setErcToErcBridgesAllowed(address[])"><code class="function-signature">setErcToErcBridgesAllowed(address[] _bridgesAllowed)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.ercToErcBridgesAllowed()"><code class="function-signature">ercToErcBridgesAllowed()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.ercToNativeBridgesAllowed()"><code class="function-signature">ercToNativeBridgesAllowed()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.extraReceiversQueueSize()"><code class="function-signature">extraReceiversQueueSize()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.getBridgeNativeFee()"><code class="function-signature">getBridgeNativeFee()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.getBridgeTokenFee()"><code class="function-signature">getBridgeTokenFee()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.isRewarding()"><code class="function-signature">isRewarding()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.isSnapshotting()"><code class="function-signature">isSnapshotting()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.mintedForAccount(address)"><code class="function-signature">mintedForAccount(address _account)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.mintedForAccountInBlock(address,uint256)"><code class="function-signature">mintedForAccountInBlock(address _account, uint256 _blockNumber)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.mintedInBlock(uint256)"><code class="function-signature">mintedInBlock(uint256 _blockNumber)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.mintedTotallyByBridge(address)"><code class="function-signature">mintedTotallyByBridge(address _bridge)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.mintedTotally()"><code class="function-signature">mintedTotally()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.nativeToErcBridgesAllowed()"><code class="function-signature">nativeToErcBridgesAllowed()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.snapshotRewardPercents(address)"><code class="function-signature">snapshotRewardPercents(address _validatorStakingAddress)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.snapshotStakers(address)"><code class="function-signature">snapshotStakers(address _validatorStakingAddress)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.snapshotStakingAddresses()"><code class="function-signature">snapshotStakingAddresses()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.snapshotTotalStakeAmount()"><code class="function-signature">snapshotTotalStakeAmount()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase._mintNativeCoinsByErcToNativeBridge(address[],uint256[],uint256)"><code class="function-signature">_mintNativeCoinsByErcToNativeBridge(address[] _bridgeFeeReceivers, uint256[] _bridgeFeeRewards, uint256 _queueLimit)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase._dequeueExtraReceiver()"><code class="function-signature">_dequeueExtraReceiver()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase._enqueueExtraReceiver(uint256,address,address)"><code class="function-signature">_enqueueExtraReceiver(uint256 _amount, address _receiver, address _bridge)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase._setMinted(uint256,address,address)"><code class="function-signature">_setMinted(uint256 _amount, address _account, address _bridge)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase._setSnapshot(address,contract IStaking,uint256)"><code class="function-signature">_setSnapshot(address _stakingAddress, contract IStaking _stakingContract, uint256 _offset)</code></a></li><li class="inherited"><a href="interfaces#IBlockReward.DELEGATORS_ALIQUOT()"><code class="function-signature">DELEGATORS_ALIQUOT()</code></a></li></ul><span class="contract-index-title">Events</span><ul><li class="inherited"><a href="#BlockRewardAuRa.AddedReceiver(uint256,address,address)"><code class="function-signature">AddedReceiver(uint256 amount, address receiver, address bridge)</code></a></li><li class="inherited"><a href="#BlockRewardAuRa.MintedNative(address[],uint256[])"><code class="function-signature">MintedNative(address[] receivers, uint256[] rewards)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="BlockRewardAuRa.reward(address[],uint16[])"></a><code class="function-signature">reward(address[] benefactors, uint16[] kind) <span class="return-arrow">→</span> <span class="return-type">address[],uint256[]</span></code></h4>

Called by the validator&#x27;s node when producing and closing a block,
 see https://wiki.parity.io/Block-Reward-Contract.html.
 This function performs all of the automatic operations needed for controlling secrets revealing by validators,
 accumulating block producing statistics, starting a new staking epoch, snapshotting reward coefficients 
 at the beginning of a new staking epoch, rewards distributing at the end of a staking epoch, and minting
 native coins needed for the `erc-to-native` bridge.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardAuRa.getBlocksCreated(uint256,address)"></a><code class="function-signature">getBlocksCreated(uint256 _stakingEpoch, address _validatorMiningAddress) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns a number of blocks produced by the specified validator during the specified staking epoch
 (beginning from the block when the `finalizeChange` function is called until the block specified by the
 `_rewardPointBlock` function). The results are used by the `_distributeRewards` function to track
 each validator&#x27;s downtime (when a validator&#x27;s node is not running and doesn&#x27;t produce blocks).
 @param _stakingEpoch The number of the staking epoch for which the statistics should be returned.
 @param _validatorMiningAddress The mining address of the validator for which the statistics should be returned.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardAuRa.getEpochPoolNativeReward(uint256,address)"></a><code class="function-signature">getEpochPoolNativeReward(uint256 _stakingEpoch, address _poolStakingAddress) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the reward amount to be distributed in native coins among participants (the validator and their
 delegators) of the specified pool at the end of the specified staking epoch.
 @param _stakingEpoch The number of the staking epoch for which the amount should be returned.
 @param _poolStakingAddress The staking address of the pool for which the amount should be returned.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardAuRa.getEpochPoolTokenReward(uint256,address)"></a><code class="function-signature">getEpochPoolTokenReward(uint256 _stakingEpoch, address _poolStakingAddress) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the reward amount to be distributed in staking tokens among participants (the validator and their
 delegators) of the specified pool at the end of the specified staking epoch.
 @param _stakingEpoch The number of the staking epoch for which the amount should be returned.
 @param _poolStakingAddress The staking address of the pool for which the amount should be returned.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardAuRa.getNativeRewardUndistributed()"></a><code class="function-signature">getNativeRewardUndistributed() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the total reward amount in native coins which is not yet distributed among participants.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardAuRa.getTokenRewardUndistributed()"></a><code class="function-signature">getTokenRewardUndistributed() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the total reward amount in staking tokens which is not yet distributed among participants.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardAuRa._distributeRewards(contract IValidatorSet,address,contract IStakingAuRa,uint256,uint256)"></a><code class="function-signature">_distributeRewards(contract IValidatorSet _validatorSetContract, address _erc20TokenContract, contract IStakingAuRa _stakingContract, uint256 _stakingEpoch, uint256 _rewardPointBlock) <span class="return-arrow">→</span> <span class="return-type">address[],uint256[],bool</span></code></h4>

Distributes rewards among participants during the last MAX_VALIDATORS

DELEGATORS_ALIQUOT
 blocks of a staking epoch. This function is called by the `reward` function.
 @param _validatorSetContract The address of the ValidatorSet contract.
 @param _erc20TokenContract The address of the ERC20 staking token contract.
 @param _stakingContract The address of the Staking contract.
 @param _stakingEpoch The number of the current staking epoch.
 @param _rewardPointBlock The number of the block within the current staking epoch when the rewarding process
 should start. This number is calculated by the `_rewardPointBlock` getter.
 @return receivers The array of fee receivers (the fee is in native coins) which should be rewarded at the
 current block by the `erc-to-native` bridge.
 @return rewards The array of amounts corresponding to the `receivers` array.
 @return noop The boolean flag which is set to `true` when there are no complex operations during the
 function launch. The flag is used by the `reward` function to control the load on the block inside the
 `_mintNativeCoinsByErcToNativeBridge` function.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardAuRa._dequeueValidator()"></a><code class="function-signature">_dequeueValidator() <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>

Dequeues a validator enqueued for the snapshotting or rewarding process.
 Used by the `reward` and `_distributeRewards` functions.
 If the queue is empty, the function returns a zero address.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardAuRa._enqueueValidator(address)"></a><code class="function-signature">_enqueueValidator(address _validatorStakingAddress)</code></h4>

Enqueues the specified validator for the snapshotting or rewarding process.
 Used by the `reward` and `_distributeRewards` functions. See also DELEGATORS_ALIQUOT.
 @param _validatorStakingAddress The staking address of a validator to be enqueued.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardAuRa._subNativeRewardUndistributed(uint256)"></a><code class="function-signature">_subNativeRewardUndistributed(uint256 _minus)</code></h4>

Reduces an undistributed amount of native coins.
 This function is used by the `_distributeRewards` function.
 @param _minus The subtraction value.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardAuRa._subTokenRewardUndistributed(uint256)"></a><code class="function-signature">_subTokenRewardUndistributed(uint256 _minus)</code></h4>

Reduces an undistributed amount of staking tokens.
 This function is used by the `_distributeRewards` function.
 @param _minus The subtraction value.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardAuRa._rewardPointBlock(contract IStakingAuRa,contract IValidatorSet)"></a><code class="function-signature">_rewardPointBlock(contract IStakingAuRa _stakingContract, contract IValidatorSet _validatorSetContract) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Calculates the starting block number for the rewarding process
 at the end of the current staking epoch.
 Used by the `reward` and `_distributeRewards` functions.
 @param _stakingContract The address of the StakingAuRa contract.
 @param _validatorSetContract The address of the ValidatorSet contract.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardAuRa._validatorsQueueSize()"></a><code class="function-signature">_validatorsQueueSize() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the size of the validator queue used for the snapshotting and rewarding processes.
 See `_enqueueValidator` and `_dequeueValidator` functions.
 This function is used by the `reward` and `_distributeRewards` functions.





### `BlockRewardHBBFT`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#BlockRewardHBBFT.reward(address[],uint16[])"><code class="function-signature">reward(address[], uint16[])</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.addBridgeNativeFeeReceivers(uint256)"><code class="function-signature">addBridgeNativeFeeReceivers(uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.addBridgeTokenFeeReceivers(uint256)"><code class="function-signature">addBridgeTokenFeeReceivers(uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.addExtraReceiver(uint256,address)"><code class="function-signature">addExtraReceiver(uint256 _amount, address _receiver)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.setErcToNativeBridgesAllowed(address[])"><code class="function-signature">setErcToNativeBridgesAllowed(address[] _bridgesAllowed)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.setNativeToErcBridgesAllowed(address[])"><code class="function-signature">setNativeToErcBridgesAllowed(address[] _bridgesAllowed)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.setErcToErcBridgesAllowed(address[])"><code class="function-signature">setErcToErcBridgesAllowed(address[] _bridgesAllowed)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.ercToErcBridgesAllowed()"><code class="function-signature">ercToErcBridgesAllowed()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.ercToNativeBridgesAllowed()"><code class="function-signature">ercToNativeBridgesAllowed()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.extraReceiversQueueSize()"><code class="function-signature">extraReceiversQueueSize()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.getBridgeNativeFee()"><code class="function-signature">getBridgeNativeFee()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.getBridgeTokenFee()"><code class="function-signature">getBridgeTokenFee()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.isRewarding()"><code class="function-signature">isRewarding()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.isSnapshotting()"><code class="function-signature">isSnapshotting()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.mintedForAccount(address)"><code class="function-signature">mintedForAccount(address _account)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.mintedForAccountInBlock(address,uint256)"><code class="function-signature">mintedForAccountInBlock(address _account, uint256 _blockNumber)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.mintedInBlock(uint256)"><code class="function-signature">mintedInBlock(uint256 _blockNumber)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.mintedTotallyByBridge(address)"><code class="function-signature">mintedTotallyByBridge(address _bridge)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.mintedTotally()"><code class="function-signature">mintedTotally()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.nativeToErcBridgesAllowed()"><code class="function-signature">nativeToErcBridgesAllowed()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.snapshotRewardPercents(address)"><code class="function-signature">snapshotRewardPercents(address _validatorStakingAddress)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.snapshotStakers(address)"><code class="function-signature">snapshotStakers(address _validatorStakingAddress)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.snapshotStakingAddresses()"><code class="function-signature">snapshotStakingAddresses()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase.snapshotTotalStakeAmount()"><code class="function-signature">snapshotTotalStakeAmount()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase._mintNativeCoinsByErcToNativeBridge(address[],uint256[],uint256)"><code class="function-signature">_mintNativeCoinsByErcToNativeBridge(address[] _bridgeFeeReceivers, uint256[] _bridgeFeeRewards, uint256 _queueLimit)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase._dequeueExtraReceiver()"><code class="function-signature">_dequeueExtraReceiver()</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase._enqueueExtraReceiver(uint256,address,address)"><code class="function-signature">_enqueueExtraReceiver(uint256 _amount, address _receiver, address _bridge)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase._setMinted(uint256,address,address)"><code class="function-signature">_setMinted(uint256 _amount, address _account, address _bridge)</code></a></li><li class="inherited"><a href="abstracts#BlockRewardBase._setSnapshot(address,contract IStaking,uint256)"><code class="function-signature">_setSnapshot(address _stakingAddress, contract IStaking _stakingContract, uint256 _offset)</code></a></li><li class="inherited"><a href="interfaces#IBlockReward.DELEGATORS_ALIQUOT()"><code class="function-signature">DELEGATORS_ALIQUOT()</code></a></li></ul><span class="contract-index-title">Events</span><ul><li class="inherited"><a href="#BlockRewardHBBFT.RewardedERC20ByBlock(address[],uint256[])"><code class="function-signature">RewardedERC20ByBlock(address[] receivers, uint256[] rewards)</code></a></li><li class="inherited"><a href="#BlockRewardHBBFT.AddedReceiver(uint256,address,address)"><code class="function-signature">AddedReceiver(uint256 amount, address receiver, address bridge)</code></a></li><li class="inherited"><a href="#BlockRewardHBBFT.MintedNative(address[],uint256[])"><code class="function-signature">MintedNative(address[] receivers, uint256[] rewards)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="BlockRewardHBBFT.reward(address[],uint16[])"></a><code class="function-signature">reward(address[], uint16[]) <span class="return-arrow">→</span> <span class="return-type">address[],uint256[]</span></code></h4>







<h4><a class="anchor" aria-hidden="true" id="BlockRewardHBBFT.RewardedERC20ByBlock(address[],uint256[])"></a><code class="function-signature">RewardedERC20ByBlock(address[] receivers, uint256[] rewards)</code></h4>





### `Certifier`

Allows validators to use a zero gas price for their service transactions
 (see https://wiki.parity.io/Permissioning.html#gas-price for more info).

<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#Certifier.initialize(address)"><code class="function-signature">initialize(address _certifiedAddress)</code></a></li><li><a href="#Certifier.certify(address)"><code class="function-signature">certify(address _who)</code></a></li><li><a href="#Certifier.revoke(address)"><code class="function-signature">revoke(address _who)</code></a></li><li><a href="#Certifier.certified(address)"><code class="function-signature">certified(address _who)</code></a></li><li><a href="#Certifier._certify(address)"><code class="function-signature">_certify(address _who)</code></a></li></ul><span class="contract-index-title">Events</span><ul><li class="inherited"><a href="#Certifier.Confirmed(address)"><code class="function-signature">Confirmed(address who)</code></a></li><li class="inherited"><a href="#Certifier.Revoked(address)"><code class="function-signature">Revoked(address who)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="Certifier.initialize(address)"></a><code class="function-signature">initialize(address _certifiedAddress)</code></h4>

Initializes the contract at network startup.
 Must be called by the constructor of the `Initializer` contract on the genesis block.
 @param _certifiedAddress The address for which a zero gas price must be allowed.



<h4><a class="anchor" aria-hidden="true" id="Certifier.certify(address)"></a><code class="function-signature">certify(address _who)</code></h4>

Allows the specified address to use a zero gas price for its transactions.
 Can only be called by the `owner`.
 @param _who The address for which zero gas price transactions must be allowed.



<h4><a class="anchor" aria-hidden="true" id="Certifier.revoke(address)"></a><code class="function-signature">revoke(address _who)</code></h4>

Denies the specified address usage of a zero gas price for its transactions.
 Can only be called by the `owner`.
 @param _who The address for which transactions with a zero gas price must be denied.



<h4><a class="anchor" aria-hidden="true" id="Certifier.certified(address)"></a><code class="function-signature">certified(address _who) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Returns a boolean flag indicating whether the specified address is allowed to use zero gas price
 transactions. Returns `true` if either the address is certified using the `_certify` function or if 
 `ValidatorSet.isReportValidatorValid` returns `true` for the specified address.
 @param _who The address for which the boolean flag must be determined.



<h4><a class="anchor" aria-hidden="true" id="Certifier._certify(address)"></a><code class="function-signature">_certify(address _who)</code></h4>

An internal function for the `certify` and `initialize` functions.
 @param _who The address for which transactions with a zero gas price must be allowed.





<h4><a class="anchor" aria-hidden="true" id="Certifier.Confirmed(address)"></a><code class="function-signature">Confirmed(address who)</code></h4>

Emitted by the `certify` function when the specified address is allowed to use a zero gas price
 for its transactions.
 @param who Specified address allowed to make zero gas price transactions.



<h4><a class="anchor" aria-hidden="true" id="Certifier.Revoked(address)"></a><code class="function-signature">Revoked(address who)</code></h4>

Emitted by the `revoke` function when the specified address is denied using a zero gas price
 for its transactions.
 @param who Specified address for which zero gas price transactions are denied.



### `InitializerAuRa`

Used once on network startup and then destroyed on the genesis block.
 Needed for initializing upgradeable contracts on the genesis block since
 upgradeable contracts can&#x27;t have constructors.

<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#InitializerAuRa.constructor(address,address,address[],address[],bool,uint256,uint256,uint256,uint256,uint256)"><code class="function-signature">constructor(address _erc20TokenContract, address _owner, address[] _miningAddresses, address[] _stakingAddresses, bool _firstValidatorIsUnremovable, uint256 _delegatorMinStake, uint256 _candidateMinStake, uint256 _stakingEpochDuration, uint256 _stakeWithdrawDisallowPeriod, uint256 _collectRoundLength)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="InitializerAuRa.constructor(address,address,address[],address[],bool,uint256,uint256,uint256,uint256,uint256)"></a><code class="function-signature">constructor(address _erc20TokenContract, address _owner, address[] _miningAddresses, address[] _stakingAddresses, bool _firstValidatorIsUnremovable, uint256 _delegatorMinStake, uint256 _candidateMinStake, uint256 _stakingEpochDuration, uint256 _stakeWithdrawDisallowPeriod, uint256 _collectRoundLength)</code></h4>







### `InitializerHBBFT`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#InitializerHBBFT.constructor(address,address,address[],address[],bytes[],bool,uint256,uint256)"><code class="function-signature">constructor(address _erc20TokenContract, address _owner, address[] _miningAddresses, address[] _stakingAddresses, bytes[] _publicKeys, bool _firstValidatorIsUnremovable, uint256 _delegatorMinStake, uint256 _candidateMinStake)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="InitializerHBBFT.constructor(address,address,address[],address[],bytes[],bool,uint256,uint256)"></a><code class="function-signature">constructor(address _erc20TokenContract, address _owner, address[] _miningAddresses, address[] _stakingAddresses, bytes[] _publicKeys, bool _firstValidatorIsUnremovable, uint256 _delegatorMinStake, uint256 _candidateMinStake)</code></h4>







### `KeyGenHistory`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#KeyGenHistory.setValidatorSetContract(contract IValidatorSet)"><code class="function-signature">setValidatorSetContract(contract IValidatorSet _validatorSet)</code></a></li><li><a href="#KeyGenHistory.writePart(bytes)"><code class="function-signature">writePart(bytes _part)</code></a></li><li><a href="#KeyGenHistory.writeAck(bytes)"><code class="function-signature">writeAck(bytes _ack)</code></a></li><li><a href="#KeyGenHistory.validatorSet()"><code class="function-signature">validatorSet()</code></a></li><li><a href="#KeyGenHistory.validatorWrotePart(uint256,address)"><code class="function-signature">validatorWrotePart(uint256 _changeRequestCount, address _validator)</code></a></li><li><a href="#KeyGenHistory._setValidatorWrotePart(uint256,address)"><code class="function-signature">_setValidatorWrotePart(uint256 _changeRequestCount, address _validator)</code></a></li></ul><span class="contract-index-title">Events</span><ul><li class="inherited"><a href="#KeyGenHistory.PartWritten(address,bytes,uint256,uint256)"><code class="function-signature">PartWritten(address validator, bytes part, uint256 stakingEpoch, uint256 changeRequestCount)</code></a></li><li class="inherited"><a href="#KeyGenHistory.AckWritten(address,bytes,uint256,uint256)"><code class="function-signature">AckWritten(address validator, bytes ack, uint256 stakingEpoch, uint256 changeRequestCount)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="KeyGenHistory.setValidatorSetContract(contract IValidatorSet)"></a><code class="function-signature">setValidatorSetContract(contract IValidatorSet _validatorSet)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="KeyGenHistory.writePart(bytes)"></a><code class="function-signature">writePart(bytes _part)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="KeyGenHistory.writeAck(bytes)"></a><code class="function-signature">writeAck(bytes _ack)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="KeyGenHistory.validatorSet()"></a><code class="function-signature">validatorSet() <span class="return-arrow">→</span> <span class="return-type">contract IValidatorSet</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="KeyGenHistory.validatorWrotePart(uint256,address)"></a><code class="function-signature">validatorWrotePart(uint256 _changeRequestCount, address _validator) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="KeyGenHistory._setValidatorWrotePart(uint256,address)"></a><code class="function-signature">_setValidatorWrotePart(uint256 _changeRequestCount, address _validator)</code></h4>







<h4><a class="anchor" aria-hidden="true" id="KeyGenHistory.PartWritten(address,bytes,uint256,uint256)"></a><code class="function-signature">PartWritten(address validator, bytes part, uint256 stakingEpoch, uint256 changeRequestCount)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="KeyGenHistory.AckWritten(address,bytes,uint256,uint256)"></a><code class="function-signature">AckWritten(address validator, bytes ack, uint256 stakingEpoch, uint256 changeRequestCount)</code></h4>





### `Migrations`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#Migrations.constructor()"><code class="function-signature">constructor()</code></a></li><li><a href="#Migrations.setCompleted(uint256)"><code class="function-signature">setCompleted(uint256 completed)</code></a></li><li><a href="#Migrations.upgrade(address)"><code class="function-signature">upgrade(address new_address)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="Migrations.constructor()"></a><code class="function-signature">constructor()</code></h4>





<h4><a class="anchor" aria-hidden="true" id="Migrations.setCompleted(uint256)"></a><code class="function-signature">setCompleted(uint256 completed)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="Migrations.upgrade(address)"></a><code class="function-signature">upgrade(address new_address)</code></h4>







### `RandomAuRa`

Generates and stores random numbers in a RANDAO manner (and controls when they are revealed by AuRa
 validators) and accumulates a random seed. The random seed is used to form a new validator set by the
 `ValidatorSet._newValidatorSet` function.

<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#RandomAuRa.commitHash(bytes32,bytes)"><code class="function-signature">commitHash(bytes32 _secretHash, bytes _cipher)</code></a></li><li><a href="#RandomAuRa.revealSecret(uint256)"><code class="function-signature">revealSecret(uint256 _secret)</code></a></li><li><a href="#RandomAuRa.initialize(uint256)"><code class="function-signature">initialize(uint256 _collectRoundLength)</code></a></li><li><a href="#RandomAuRa.onFinishCollectRound()"><code class="function-signature">onFinishCollectRound()</code></a></li><li><a href="#RandomAuRa.collectRoundLength()"><code class="function-signature">collectRoundLength()</code></a></li><li><a href="#RandomAuRa.commitPhaseLength()"><code class="function-signature">commitPhaseLength()</code></a></li><li><a href="#RandomAuRa.currentCollectRound()"><code class="function-signature">currentCollectRound()</code></a></li><li><a href="#RandomAuRa.getCipher(uint256,address)"><code class="function-signature">getCipher(uint256 _collectRound, address _miningAddress)</code></a></li><li><a href="#RandomAuRa.getCommit(uint256,address)"><code class="function-signature">getCommit(uint256 _collectRound, address _miningAddress)</code></a></li><li><a href="#RandomAuRa.isCommitted(uint256,address)"><code class="function-signature">isCommitted(uint256 _collectRound, address _miningAddress)</code></a></li><li><a href="#RandomAuRa.isCommitPhase()"><code class="function-signature">isCommitPhase()</code></a></li><li><a href="#RandomAuRa.isRevealPhase()"><code class="function-signature">isRevealPhase()</code></a></li><li><a href="#RandomAuRa.commitHashCallable(address,bytes32)"><code class="function-signature">commitHashCallable(address _miningAddress, bytes32 _secretHash)</code></a></li><li><a href="#RandomAuRa.revealSecretCallable(address,uint256)"><code class="function-signature">revealSecretCallable(address _miningAddress, uint256 _secret)</code></a></li><li><a href="#RandomAuRa.revealSkips(uint256,address)"><code class="function-signature">revealSkips(uint256 _stakingEpoch, address _miningAddress)</code></a></li><li><a href="#RandomAuRa.sentReveal(uint256,address)"><code class="function-signature">sentReveal(uint256 _collectRound, address _miningAddress)</code></a></li><li><a href="#RandomAuRa._addCommittedValidator(uint256,address)"><code class="function-signature">_addCommittedValidator(uint256 _collectRound, address _miningAddress)</code></a></li><li><a href="#RandomAuRa._clearOldCiphers(uint256)"><code class="function-signature">_clearOldCiphers(uint256 _collectRound)</code></a></li><li><a href="#RandomAuRa._incrementRevealSkips(uint256,address)"><code class="function-signature">_incrementRevealSkips(uint256 _stakingEpoch, address _miningAddress)</code></a></li><li><a href="#RandomAuRa._setCipher(uint256,address,bytes)"><code class="function-signature">_setCipher(uint256 _collectRound, address _miningAddress, bytes _cipher)</code></a></li><li><a href="#RandomAuRa._setCommit(uint256,address,bytes32)"><code class="function-signature">_setCommit(uint256 _collectRound, address _miningAddress, bytes32 _secretHash)</code></a></li><li><a href="#RandomAuRa._setSentReveal(uint256,address)"><code class="function-signature">_setSentReveal(uint256 _collectRound, address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#RandomBase.getCurrentSeed()"><code class="function-signature">getCurrentSeed()</code></a></li><li class="inherited"><a href="abstracts#RandomBase._setCurrentSeed(uint256)"><code class="function-signature">_setCurrentSeed(uint256 _seed)</code></a></li><li class="inherited"><a href="abstracts#RandomBase._getCurrentSeed()"><code class="function-signature">_getCurrentSeed()</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa.commitHash(bytes32,bytes)"></a><code class="function-signature">commitHash(bytes32 _secretHash, bytes _cipher)</code></h4>

Called by the validator&#x27;s node to store a hash and a cipher of the validator&#x27;s secret on each collection
 round. The validator&#x27;s node must use its mining address to call this function.
 This function can only be called once per collection round (during the `commits phase`).
 @param _secretHash The Keccak-256 hash of the validator&#x27;s secret.
 @param _cipher The cipher of the validator&#x27;s secret. Can be used by the node to restore the lost secret after
 the node is restarted (see the `getCipher` getter).



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa.revealSecret(uint256)"></a><code class="function-signature">revealSecret(uint256 _secret)</code></h4>

Called by the validator&#x27;s node to XOR its secret with the current random seed.
 The validator&#x27;s node must use its mining address to call this function.
 This function can only be called once per collection round (during the `reveals phase`).
 @param _secret The validator&#x27;s secret.



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa.initialize(uint256)"></a><code class="function-signature">initialize(uint256 _collectRoundLength)</code></h4>

Initializes the contract at network startup.
 Must be called by the constructor of the `InitializerAuRa` contract on the genesis block.
 @param _collectRoundLength The length of a collection round in blocks.



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa.onFinishCollectRound()"></a><code class="function-signature">onFinishCollectRound()</code></h4>

Checks whether the current validators at the end of each collection round revealed their secrets,
 and removes malicious validators if needed.
 This function does nothing if the current block is not the last block of the current collection round.
 Can only be called by the `BlockRewardAuRa` contract (its `reward` function).



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa.collectRoundLength()"></a><code class="function-signature">collectRoundLength() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the length of the collection round (in blocks).



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa.commitPhaseLength()"></a><code class="function-signature">commitPhaseLength() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the length of the commits/reveals phase which is always half of the collection round length.



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa.currentCollectRound()"></a><code class="function-signature">currentCollectRound() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the serial number of the current collection round.



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa.getCipher(uint256,address)"></a><code class="function-signature">getCipher(uint256 _collectRound, address _miningAddress) <span class="return-arrow">→</span> <span class="return-type">bytes</span></code></h4>

Returns the cipher of the validator&#x27;s secret for the specified collection round and the specified validator
 stored by the validator through the `commitHash` function.
 @param _collectRound The serial number of the collection round for which the cipher should be retrieved.
 @param _miningAddress The mining address of validator.



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa.getCommit(uint256,address)"></a><code class="function-signature">getCommit(uint256 _collectRound, address _miningAddress) <span class="return-arrow">→</span> <span class="return-type">bytes32</span></code></h4>

Returns the Keccak-256 hash of the validator&#x27;s secret for the specified collection round and the specified
 validator stored by the validator through the `commitHash` function.
 @param _collectRound The serial number of the collection round for which the hash should be retrieved.
 @param _miningAddress The mining address of validator.



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa.isCommitted(uint256,address)"></a><code class="function-signature">isCommitted(uint256 _collectRound, address _miningAddress) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Returns a boolean flag indicating whether the specified validator has committed their secret&#x27;s hash for the
 specified collection round.
 @param _collectRound The serial number of the collection round for which the checkup should be done.
 @param _miningAddress The mining address of the validator.



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa.isCommitPhase()"></a><code class="function-signature">isCommitPhase() <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Returns a boolean flag indicating whether the current phase of the current collection round
 is a `commits phase`. Used by the validator&#x27;s node to determine if it should commit the hash of
 the secret during the current collection round.



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa.isRevealPhase()"></a><code class="function-signature">isRevealPhase() <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Returns a boolean flag indicating whether the current phase of the current collection round
 is a `reveals phase`. Used by the validator&#x27;s node to determine if it should reveal the secret during
 the current collection round.



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa.commitHashCallable(address,bytes32)"></a><code class="function-signature">commitHashCallable(address _miningAddress, bytes32 _secretHash) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Returns a boolean flag of whether the `commitHash` function can be called at the current block
 by the specified validator. Used by the `commitHash` function and the `TxPermission` contract.
 @param _miningAddress The mining address of the validator which tries to call the `commitHash` function.
 @param _secretHash The Keccak-256 hash of validator&#x27;s secret passed to the `commitHash` function.



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa.revealSecretCallable(address,uint256)"></a><code class="function-signature">revealSecretCallable(address _miningAddress, uint256 _secret) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Returns a boolean flag of whether the `revealSecret` function can be called at the current block
 by the specified validator. Used by the `revealSecret` function and the `TxPermission` contract.
 @param _miningAddress The mining address of validator which tries to call the `revealSecret` function.
 @param _secret The validator&#x27;s secret passed to the `revealSecret` function.



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa.revealSkips(uint256,address)"></a><code class="function-signature">revealSkips(uint256 _stakingEpoch, address _miningAddress) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the number of reveal skips made by the specified validator during the specified staking epoch.
 @param _stakingEpoch The serial number of the staking epoch for which the number of skips should be returned.
 @param _miningAddress The mining address of the validator for which the number of skips should be returned.



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa.sentReveal(uint256,address)"></a><code class="function-signature">sentReveal(uint256 _collectRound, address _miningAddress) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Returns a boolean flag of whether the specified validator has revealed their secret for the
 specified collection round.
 @param _collectRound The serial number of the collection round for which the checkup should be done.
 @param _miningAddress The mining address of the validator.



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa._addCommittedValidator(uint256,address)"></a><code class="function-signature">_addCommittedValidator(uint256 _collectRound, address _miningAddress)</code></h4>

Adds the specified validator to the array of validators that committed their
 hashes during the specified collection round. Used by the `commitHash` function.
 @param _collectRound The serial number of the collection round.
 @param _miningAddress The validator&#x27;s mining address to be added.



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa._clearOldCiphers(uint256)"></a><code class="function-signature">_clearOldCiphers(uint256 _collectRound)</code></h4>

Removes the ciphers of all committed validators for the specified collection round.
 @param _collectRound The serial number of the collection round.



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa._incrementRevealSkips(uint256,address)"></a><code class="function-signature">_incrementRevealSkips(uint256 _stakingEpoch, address _miningAddress)</code></h4>

Increments the reveal skips counter for the specified validator and staking epoch.
 Used by the `onFinishCollectRound` function.
 @param _stakingEpoch The serial number of the staking epoch.
 @param _miningAddress The validator&#x27;s mining address.



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa._setCipher(uint256,address,bytes)"></a><code class="function-signature">_setCipher(uint256 _collectRound, address _miningAddress, bytes _cipher)</code></h4>

Stores the cipher of the secret for the specified validator and collection round.
 Used by the `commitHash` function.
 @param _collectRound The serial number of the collection round.
 @param _miningAddress The validator&#x27;s mining address.
 @param _cipher The cipher&#x27;s bytes sequence to be stored.



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa._setCommit(uint256,address,bytes32)"></a><code class="function-signature">_setCommit(uint256 _collectRound, address _miningAddress, bytes32 _secretHash)</code></h4>

Stores the Keccak-256 hash of the secret for the specified validator and collection round.
 Used by the `commitHash` function.
 @param _collectRound The serial number of the collection round.
 @param _miningAddress The validator&#x27;s mining address.
 @param _secretHash The hash to be stored.



<h4><a class="anchor" aria-hidden="true" id="RandomAuRa._setSentReveal(uint256,address)"></a><code class="function-signature">_setSentReveal(uint256 _collectRound, address _miningAddress)</code></h4>

Stores the boolean flag of whether the specified validator revealed their secret
 during the specified collection round.
 @param _collectRound The serial number of the collection round.
 @param _miningAddress The validator&#x27;s mining address.





### `RandomHBBFT`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#RandomHBBFT.storeRandom(uint256[])"><code class="function-signature">storeRandom(uint256[] _random)</code></a></li><li class="inherited"><a href="abstracts#RandomBase.getCurrentSeed()"><code class="function-signature">getCurrentSeed()</code></a></li><li class="inherited"><a href="abstracts#RandomBase._setCurrentSeed(uint256)"><code class="function-signature">_setCurrentSeed(uint256 _seed)</code></a></li><li class="inherited"><a href="abstracts#RandomBase._getCurrentSeed()"><code class="function-signature">_getCurrentSeed()</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="RandomHBBFT.storeRandom(uint256[])"></a><code class="function-signature">storeRandom(uint256[] _random)</code></h4>







### `Owned`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#Owned.setOwner(address)"><code class="function-signature">setOwner(address _new)</code></a></li></ul><span class="contract-index-title">Events</span><ul><li class="inherited"><a href="#Owned.NewOwner(address,address)"><code class="function-signature">NewOwner(address old, address current)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="Owned.setOwner(address)"></a><code class="function-signature">setOwner(address _new)</code></h4>







<h4><a class="anchor" aria-hidden="true" id="Owned.NewOwner(address,address)"></a><code class="function-signature">NewOwner(address old, address current)</code></h4>





### `Registry`

Stores human-readable keys associated with addresses, like DNS information
 (see https://wiki.parity.io/Parity-name-registry.html). Needed primarily to store the address
 of the `TxPermission` contract (see https://wiki.parity.io/Permissioning.html#transaction-type for details).

<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#Registry.constructor(address,address)"><code class="function-signature">constructor(address _certifierContract, address _owner)</code></a></li><li><a href="#Registry.reserve(bytes32)"><code class="function-signature">reserve(bytes32 _name)</code></a></li><li><a href="#Registry.transfer(bytes32,address)"><code class="function-signature">transfer(bytes32 _name, address _to)</code></a></li><li><a href="#Registry.drop(bytes32)"><code class="function-signature">drop(bytes32 _name)</code></a></li><li><a href="#Registry.setData(bytes32,string,bytes32)"><code class="function-signature">setData(bytes32 _name, string _key, bytes32 _value)</code></a></li><li><a href="#Registry.setAddress(bytes32,string,address)"><code class="function-signature">setAddress(bytes32 _name, string _key, address _value)</code></a></li><li><a href="#Registry.setUint(bytes32,string,uint256)"><code class="function-signature">setUint(bytes32 _name, string _key, uint256 _value)</code></a></li><li><a href="#Registry.proposeReverse(string,address)"><code class="function-signature">proposeReverse(string _name, address _who)</code></a></li><li><a href="#Registry.confirmReverse(string)"><code class="function-signature">confirmReverse(string _name)</code></a></li><li><a href="#Registry.confirmReverseAs(string,address)"><code class="function-signature">confirmReverseAs(string _name, address _who)</code></a></li><li><a href="#Registry.removeReverse()"><code class="function-signature">removeReverse()</code></a></li><li><a href="#Registry.setFee(uint256)"><code class="function-signature">setFee(uint256 _amount)</code></a></li><li><a href="#Registry.drain()"><code class="function-signature">drain()</code></a></li><li><a href="#Registry.getData(bytes32,string)"><code class="function-signature">getData(bytes32 _name, string _key)</code></a></li><li><a href="#Registry.getAddress(bytes32,string)"><code class="function-signature">getAddress(bytes32 _name, string _key)</code></a></li><li><a href="#Registry.getUint(bytes32,string)"><code class="function-signature">getUint(bytes32 _name, string _key)</code></a></li><li><a href="#Registry.getOwner(bytes32)"><code class="function-signature">getOwner(bytes32 _name)</code></a></li><li><a href="#Registry.hasReverse(bytes32)"><code class="function-signature">hasReverse(bytes32 _name)</code></a></li><li><a href="#Registry.getReverse(bytes32)"><code class="function-signature">getReverse(bytes32 _name)</code></a></li><li><a href="#Registry.canReverse(address)"><code class="function-signature">canReverse(address _data)</code></a></li><li><a href="#Registry.reverse(address)"><code class="function-signature">reverse(address _data)</code></a></li><li><a href="#Registry.reserved(bytes32)"><code class="function-signature">reserved(bytes32 _name)</code></a></li><li class="inherited"><a href=".#Owned.setOwner(address)"><code class="function-signature">setOwner(address _new)</code></a></li></ul><span class="contract-index-title">Events</span><ul><li class="inherited"><a href="#Registry.Drained(uint256)"><code class="function-signature">Drained(uint256 amount)</code></a></li><li class="inherited"><a href="#Registry.FeeChanged(uint256)"><code class="function-signature">FeeChanged(uint256 amount)</code></a></li><li class="inherited"><a href="#Registry.ReverseProposed(string,address)"><code class="function-signature">ReverseProposed(string name, address reverse)</code></a></li><li class="inherited"><a href="#Registry.ReverseConfirmed(string,address)"><code class="function-signature">ReverseConfirmed(string name, address reverse)</code></a></li><li class="inherited"><a href="#Registry.ReverseRemoved(string,address)"><code class="function-signature">ReverseRemoved(string name, address reverse)</code></a></li><li class="inherited"><a href="#Registry.Reserved(bytes32,address)"><code class="function-signature">Reserved(bytes32 name, address owner)</code></a></li><li class="inherited"><a href="#Registry.Transferred(bytes32,address,address)"><code class="function-signature">Transferred(bytes32 name, address oldOwner, address newOwner)</code></a></li><li class="inherited"><a href="#Registry.Dropped(bytes32,address)"><code class="function-signature">Dropped(bytes32 name, address owner)</code></a></li><li class="inherited"><a href="#Registry.DataChanged(bytes32,string,string)"><code class="function-signature">DataChanged(bytes32 name, string key, string plainKey)</code></a></li><li class="inherited"><a href="#Registry.NewOwner(address,address)"><code class="function-signature">NewOwner(address old, address current)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="Registry.constructor(address,address)"></a><code class="function-signature">constructor(address _certifierContract, address _owner)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.reserve(bytes32)"></a><code class="function-signature">reserve(bytes32 _name) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.transfer(bytes32,address)"></a><code class="function-signature">transfer(bytes32 _name, address _to) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.drop(bytes32)"></a><code class="function-signature">drop(bytes32 _name) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.setData(bytes32,string,bytes32)"></a><code class="function-signature">setData(bytes32 _name, string _key, bytes32 _value) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.setAddress(bytes32,string,address)"></a><code class="function-signature">setAddress(bytes32 _name, string _key, address _value) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.setUint(bytes32,string,uint256)"></a><code class="function-signature">setUint(bytes32 _name, string _key, uint256 _value) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.proposeReverse(string,address)"></a><code class="function-signature">proposeReverse(string _name, address _who) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.confirmReverse(string)"></a><code class="function-signature">confirmReverse(string _name) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.confirmReverseAs(string,address)"></a><code class="function-signature">confirmReverseAs(string _name, address _who) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.removeReverse()"></a><code class="function-signature">removeReverse()</code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.setFee(uint256)"></a><code class="function-signature">setFee(uint256 _amount) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.drain()"></a><code class="function-signature">drain() <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.getData(bytes32,string)"></a><code class="function-signature">getData(bytes32 _name, string _key) <span class="return-arrow">→</span> <span class="return-type">bytes32</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.getAddress(bytes32,string)"></a><code class="function-signature">getAddress(bytes32 _name, string _key) <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.getUint(bytes32,string)"></a><code class="function-signature">getUint(bytes32 _name, string _key) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.getOwner(bytes32)"></a><code class="function-signature">getOwner(bytes32 _name) <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.hasReverse(bytes32)"></a><code class="function-signature">hasReverse(bytes32 _name) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.getReverse(bytes32)"></a><code class="function-signature">getReverse(bytes32 _name) <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.canReverse(address)"></a><code class="function-signature">canReverse(address _data) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.reverse(address)"></a><code class="function-signature">reverse(address _data) <span class="return-arrow">→</span> <span class="return-type">string</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.reserved(bytes32)"></a><code class="function-signature">reserved(bytes32 _name) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>







<h4><a class="anchor" aria-hidden="true" id="Registry.Drained(uint256)"></a><code class="function-signature">Drained(uint256 amount)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.FeeChanged(uint256)"></a><code class="function-signature">FeeChanged(uint256 amount)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="Registry.ReverseProposed(string,address)"></a><code class="function-signature">ReverseProposed(string name, address reverse)</code></h4>





### `StakingAuRa`

Implements staking and withdrawal logic.

<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#StakingAuRa.addPool(uint256,address)"><code class="function-signature">addPool(uint256 _amount, address _miningAddress)</code></a></li><li><a href="#StakingAuRa.initialize(address,address,address[],uint256,uint256,uint256,uint256)"><code class="function-signature">initialize(address _validatorSetContract, address _erc20TokenContract, address[] _initialStakingAddresses, uint256 _delegatorMinStake, uint256 _candidateMinStake, uint256 _stakingEpochDuration, uint256 _stakeWithdrawDisallowPeriod)</code></a></li><li><a href="#StakingAuRa.setStakingEpochStartBlock(uint256)"><code class="function-signature">setStakingEpochStartBlock(uint256 _blockNumber)</code></a></li><li><a href="#StakingAuRa.areStakeAndWithdrawAllowed()"><code class="function-signature">areStakeAndWithdrawAllowed()</code></a></li><li><a href="#StakingAuRa.stakeWithdrawDisallowPeriod()"><code class="function-signature">stakeWithdrawDisallowPeriod()</code></a></li><li><a href="#StakingAuRa.stakingEpochDuration()"><code class="function-signature">stakingEpochDuration()</code></a></li><li><a href="#StakingAuRa.stakingEpochStartBlock()"><code class="function-signature">stakingEpochStartBlock()</code></a></li><li><a href="#StakingAuRa.stakingEpochEndBlock()"><code class="function-signature">stakingEpochEndBlock()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.clearUnremovableValidator(address)"><code class="function-signature">clearUnremovableValidator(address _unremovableStakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.incrementStakingEpoch()"><code class="function-signature">incrementStakingEpoch()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.removePool(address)"><code class="function-signature">removePool(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.removePool()"><code class="function-signature">removePool()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.moveStake(address,address,uint256)"><code class="function-signature">moveStake(address _fromPoolStakingAddress, address _toPoolStakingAddress, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.stake(address,uint256)"><code class="function-signature">stake(address _toPoolStakingAddress, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.withdraw(address,uint256)"><code class="function-signature">withdraw(address _fromPoolStakingAddress, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.orderWithdraw(address,int256)"><code class="function-signature">orderWithdraw(address _poolStakingAddress, int256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.claimOrderedWithdraw(address)"><code class="function-signature">claimOrderedWithdraw(address _poolStakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.setErc20TokenContract(address)"><code class="function-signature">setErc20TokenContract(address _erc20TokenContract)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.setCandidateMinStake(uint256)"><code class="function-signature">setCandidateMinStake(uint256 _minStake)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.setDelegatorMinStake(uint256)"><code class="function-signature">setDelegatorMinStake(uint256 _minStake)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.getPools()"><code class="function-signature">getPools()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.getPoolsInactive()"><code class="function-signature">getPoolsInactive()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.getPoolsLikelihood()"><code class="function-signature">getPoolsLikelihood()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.getPoolsToBeElected()"><code class="function-signature">getPoolsToBeElected()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.getPoolsToBeRemoved()"><code class="function-signature">getPoolsToBeRemoved()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.erc20TokenContract()"><code class="function-signature">erc20TokenContract()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.getCandidateMinStake()"><code class="function-signature">getCandidateMinStake()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.getDelegatorMinStake()"><code class="function-signature">getDelegatorMinStake()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.isPoolActive(address)"><code class="function-signature">isPoolActive(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.maxWithdrawAllowed(address,address)"><code class="function-signature">maxWithdrawAllowed(address _poolStakingAddress, address _staker)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.maxWithdrawOrderAllowed(address,address)"><code class="function-signature">maxWithdrawOrderAllowed(address _poolStakingAddress, address _staker)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.onTokenTransfer(address,uint256,bytes)"><code class="function-signature">onTokenTransfer(address, uint256, bytes)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.orderedWithdrawAmount(address,address)"><code class="function-signature">orderedWithdrawAmount(address _poolStakingAddress, address _staker)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.orderedWithdrawAmountTotal(address)"><code class="function-signature">orderedWithdrawAmountTotal(address _poolStakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.orderWithdrawEpoch(address,address)"><code class="function-signature">orderWithdrawEpoch(address _poolStakingAddress, address _staker)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.stakeAmountTotal(address)"><code class="function-signature">stakeAmountTotal(address _poolStakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.poolDelegators(address)"><code class="function-signature">poolDelegators(address _poolStakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.poolDelegatorIndex(address,address)"><code class="function-signature">poolDelegatorIndex(address _poolStakingAddress, address _delegator)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.poolDelegatorInactiveIndex(address,address)"><code class="function-signature">poolDelegatorInactiveIndex(address _poolStakingAddress, address _delegator)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.poolIndex(address)"><code class="function-signature">poolIndex(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.poolInactiveIndex(address)"><code class="function-signature">poolInactiveIndex(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.poolToBeElectedIndex(address)"><code class="function-signature">poolToBeElectedIndex(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.poolToBeRemovedIndex(address)"><code class="function-signature">poolToBeRemovedIndex(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.stakeAmount(address,address)"><code class="function-signature">stakeAmount(address _poolStakingAddress, address _staker)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.stakeAmountByCurrentEpoch(address,address)"><code class="function-signature">stakeAmountByCurrentEpoch(address _poolStakingAddress, address _staker)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.stakeAmountMinusOrderedWithdraw(address,address)"><code class="function-signature">stakeAmountMinusOrderedWithdraw(address _poolStakingAddress, address _staker)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.stakeAmountTotalMinusOrderedWithdraw(address)"><code class="function-signature">stakeAmountTotalMinusOrderedWithdraw(address _poolStakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.stakingEpoch()"><code class="function-signature">stakingEpoch()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.validatorSetContract()"><code class="function-signature">validatorSetContract()</code></a></li><li class="inherited"><a href="abstracts#StakingBase._addPoolActive(address,bool)"><code class="function-signature">_addPoolActive(address _stakingAddress, bool _toBeElected)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._addPoolInactive(address)"><code class="function-signature">_addPoolInactive(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._addPoolToBeElected(address)"><code class="function-signature">_addPoolToBeElected(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._addPoolToBeRemoved(address)"><code class="function-signature">_addPoolToBeRemoved(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._deletePoolToBeElected(address)"><code class="function-signature">_deletePoolToBeElected(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._deletePoolToBeRemoved(address)"><code class="function-signature">_deletePoolToBeRemoved(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._removePool(address)"><code class="function-signature">_removePool(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._removePoolInactive(address)"><code class="function-signature">_removePoolInactive(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._initialize(address,address,address[],uint256,uint256)"><code class="function-signature">_initialize(address _validatorSetContract, address _erc20TokenContract, address[] _initialStakingAddresses, uint256 _delegatorMinStake, uint256 _candidateMinStake)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setOrderWithdrawEpoch(address,address,uint256)"><code class="function-signature">_setOrderWithdrawEpoch(address _poolStakingAddress, address _staker, uint256 _stakingEpoch)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setPoolDelegatorIndex(address,address,uint256)"><code class="function-signature">_setPoolDelegatorIndex(address _poolStakingAddress, address _delegator, uint256 _index)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setPoolDelegatorInactiveIndex(address,address,uint256)"><code class="function-signature">_setPoolDelegatorInactiveIndex(address _poolStakingAddress, address _delegator, uint256 _index)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setPoolIndex(address,uint256)"><code class="function-signature">_setPoolIndex(address _stakingAddress, uint256 _index)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setPoolInactiveIndex(address,uint256)"><code class="function-signature">_setPoolInactiveIndex(address _stakingAddress, uint256 _index)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setPoolToBeElectedIndex(address,uint256)"><code class="function-signature">_setPoolToBeElectedIndex(address _stakingAddress, uint256 _index)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setPoolToBeRemovedIndex(address,uint256)"><code class="function-signature">_setPoolToBeRemovedIndex(address _stakingAddress, uint256 _index)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._addPoolDelegator(address,address)"><code class="function-signature">_addPoolDelegator(address _poolStakingAddress, address _delegator)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._addPoolDelegatorInactive(address,address)"><code class="function-signature">_addPoolDelegatorInactive(address _poolStakingAddress, address _delegator)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._removePoolDelegator(address,address)"><code class="function-signature">_removePoolDelegator(address _poolStakingAddress, address _delegator)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._removePoolDelegatorInactive(address,address)"><code class="function-signature">_removePoolDelegatorInactive(address _poolStakingAddress, address _delegator)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setLikelihood(address)"><code class="function-signature">_setLikelihood(address _poolStakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setOrderedWithdrawAmount(address,address,uint256)"><code class="function-signature">_setOrderedWithdrawAmount(address _poolStakingAddress, address _staker, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setOrderedWithdrawAmountTotal(address,uint256)"><code class="function-signature">_setOrderedWithdrawAmountTotal(address _poolStakingAddress, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setStakeAmount(address,address,uint256)"><code class="function-signature">_setStakeAmount(address _poolStakingAddress, address _staker, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setStakeAmountByCurrentEpoch(address,address,uint256)"><code class="function-signature">_setStakeAmountByCurrentEpoch(address _poolStakingAddress, address _staker, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setStakeAmountTotal(address,uint256)"><code class="function-signature">_setStakeAmountTotal(address _poolStakingAddress, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setDelegatorMinStake(uint256)"><code class="function-signature">_setDelegatorMinStake(uint256 _minStake)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setCandidateMinStake(uint256)"><code class="function-signature">_setCandidateMinStake(uint256 _minStake)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._stake(address,uint256)"><code class="function-signature">_stake(address _toPoolStakingAddress, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._stake(address,address,uint256)"><code class="function-signature">_stake(address _poolStakingAddress, address _staker, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._withdraw(address,address,uint256)"><code class="function-signature">_withdraw(address _poolStakingAddress, address _staker, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._withdrawCheckPool(address,address)"><code class="function-signature">_withdrawCheckPool(address _poolStakingAddress, address _staker)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._getCurrentBlockNumber()"><code class="function-signature">_getCurrentBlockNumber()</code></a></li><li class="inherited"><a href="abstracts#StakingBase._getMaxCandidates()"><code class="function-signature">_getMaxCandidates()</code></a></li><li class="inherited"><a href="abstracts#StakingBase._isPoolToBeElected(address)"><code class="function-signature">_isPoolToBeElected(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._isWithdrawAllowed(address)"><code class="function-signature">_isWithdrawAllowed(address _miningAddress)</code></a></li></ul><span class="contract-index-title">Events</span><ul><li class="inherited"><a href="#StakingAuRa.Claimed(address,address,uint256,uint256)"><code class="function-signature">Claimed(address fromPoolStakingAddress, address staker, uint256 stakingEpoch, uint256 amount)</code></a></li><li class="inherited"><a href="#StakingAuRa.Staked(address,address,uint256,uint256)"><code class="function-signature">Staked(address toPoolStakingAddress, address staker, uint256 stakingEpoch, uint256 amount)</code></a></li><li class="inherited"><a href="#StakingAuRa.StakeMoved(address,address,address,uint256,uint256)"><code class="function-signature">StakeMoved(address fromPoolStakingAddress, address toPoolStakingAddress, address staker, uint256 stakingEpoch, uint256 amount)</code></a></li><li class="inherited"><a href="#StakingAuRa.WithdrawalOrdered(address,address,uint256,int256)"><code class="function-signature">WithdrawalOrdered(address fromPoolStakingAddress, address staker, uint256 stakingEpoch, int256 amount)</code></a></li><li class="inherited"><a href="#StakingAuRa.Withdrawn(address,address,uint256,uint256)"><code class="function-signature">Withdrawn(address fromPoolStakingAddress, address staker, uint256 stakingEpoch, uint256 amount)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="StakingAuRa.addPool(uint256,address)"></a><code class="function-signature">addPool(uint256 _amount, address _miningAddress)</code></h4>

Adds a new candidate&#x27;s pool to the list of active pools (see the `getPools` getter) and
 moves the specified amount of staking tokens from the candidate&#x27;s staking address to the candidate&#x27;s pool.
 A participant calls this function using their staking address when they want to create a pool.
 This is a wrapper for the `stake` function.
 @param _amount The amount of tokens to be staked.
 @param _miningAddress The mining address of the candidate. The mining address is bound to the staking address
 (msg.sender). This address cannot be equal to `msg.sender`.



<h4><a class="anchor" aria-hidden="true" id="StakingAuRa.initialize(address,address,address[],uint256,uint256,uint256,uint256)"></a><code class="function-signature">initialize(address _validatorSetContract, address _erc20TokenContract, address[] _initialStakingAddresses, uint256 _delegatorMinStake, uint256 _candidateMinStake, uint256 _stakingEpochDuration, uint256 _stakeWithdrawDisallowPeriod)</code></h4>

Initializes the network parameters on the genesis block.
 Must be called by the constructor of the `InitializerAuRa` contract on the genesis block.
 @param _validatorSetContract The address of the `ValidatorSetAuRa` contract.
 @param _erc20TokenContract The address of the ERC20/677 staking token contract.
 Can be zero and defined later using the `setErc20TokenContract` function.
 @param _initialStakingAddresses The array of initial validators&#x27; staking addresses.
 @param _delegatorMinStake The minimum allowed amount of delegator stake in STAKE_UNITs.
 @param _candidateMinStake The minimum allowed amount of candidate/validator stake in STAKE_UNITs.
 @param _stakingEpochDuration The duration of a staking epoch in blocks
 (e.g., 120960 = 1 week for 5-seconds blocks in AuRa).
 @param _stakeWithdrawDisallowPeriod The duration period (in blocks) at the end of a staking epoch
 during which participants cannot stake or withdraw their staking tokens
 (e.g., 4320 = 6 hours for 5-seconds blocks in AuRa).



<h4><a class="anchor" aria-hidden="true" id="StakingAuRa.setStakingEpochStartBlock(uint256)"></a><code class="function-signature">setStakingEpochStartBlock(uint256 _blockNumber)</code></h4>

Sets the number of the first block in the upcoming staking epoch.
 Called by the `ValidatorSetAuRa.newValidatorSet` function at the last block of a staking epoch.
 @param _blockNumber The number of the very first block in the upcoming staking epoch.



<h4><a class="anchor" aria-hidden="true" id="StakingAuRa.areStakeAndWithdrawAllowed()"></a><code class="function-signature">areStakeAndWithdrawAllowed() <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Determines whether staking/withdrawal operations are allowed at the moment.
 Used by all staking/withdrawal functions.



<h4><a class="anchor" aria-hidden="true" id="StakingAuRa.stakeWithdrawDisallowPeriod()"></a><code class="function-signature">stakeWithdrawDisallowPeriod() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the duration period (in blocks) at the end of staking epoch during which
 participants are not allowed to stake and withdraw their staking tokens.



<h4><a class="anchor" aria-hidden="true" id="StakingAuRa.stakingEpochDuration()"></a><code class="function-signature">stakingEpochDuration() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the duration of a staking epoch in blocks.



<h4><a class="anchor" aria-hidden="true" id="StakingAuRa.stakingEpochStartBlock()"></a><code class="function-signature">stakingEpochStartBlock() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the number of the first block of the current staking epoch.



<h4><a class="anchor" aria-hidden="true" id="StakingAuRa.stakingEpochEndBlock()"></a><code class="function-signature">stakingEpochEndBlock() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the number of the last block of the current staking epoch.





### `StakingHBBFT`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#StakingHBBFT.addPool(bytes,uint256,address)"><code class="function-signature">addPool(bytes _publicKey, uint256 _amount, address _miningAddress)</code></a></li><li><a href="#StakingHBBFT.initialize(address,address,address[],uint256,uint256)"><code class="function-signature">initialize(address _validatorSetContract, address _erc20TokenContract, address[] _initialStakingAddresses, uint256 _delegatorMinStake, uint256 _candidateMinStake)</code></a></li><li><a href="#StakingHBBFT.areStakeAndWithdrawAllowed()"><code class="function-signature">areStakeAndWithdrawAllowed()</code></a></li><li><a href="#StakingHBBFT._addPoolActive(address,bool)"><code class="function-signature">_addPoolActive(address _stakingAddress, bool _toBeElected)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.clearUnremovableValidator(address)"><code class="function-signature">clearUnremovableValidator(address _unremovableStakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.incrementStakingEpoch()"><code class="function-signature">incrementStakingEpoch()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.removePool(address)"><code class="function-signature">removePool(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.removePool()"><code class="function-signature">removePool()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.moveStake(address,address,uint256)"><code class="function-signature">moveStake(address _fromPoolStakingAddress, address _toPoolStakingAddress, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.stake(address,uint256)"><code class="function-signature">stake(address _toPoolStakingAddress, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.withdraw(address,uint256)"><code class="function-signature">withdraw(address _fromPoolStakingAddress, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.orderWithdraw(address,int256)"><code class="function-signature">orderWithdraw(address _poolStakingAddress, int256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.claimOrderedWithdraw(address)"><code class="function-signature">claimOrderedWithdraw(address _poolStakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.setErc20TokenContract(address)"><code class="function-signature">setErc20TokenContract(address _erc20TokenContract)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.setCandidateMinStake(uint256)"><code class="function-signature">setCandidateMinStake(uint256 _minStake)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.setDelegatorMinStake(uint256)"><code class="function-signature">setDelegatorMinStake(uint256 _minStake)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.getPools()"><code class="function-signature">getPools()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.getPoolsInactive()"><code class="function-signature">getPoolsInactive()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.getPoolsLikelihood()"><code class="function-signature">getPoolsLikelihood()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.getPoolsToBeElected()"><code class="function-signature">getPoolsToBeElected()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.getPoolsToBeRemoved()"><code class="function-signature">getPoolsToBeRemoved()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.erc20TokenContract()"><code class="function-signature">erc20TokenContract()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.getCandidateMinStake()"><code class="function-signature">getCandidateMinStake()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.getDelegatorMinStake()"><code class="function-signature">getDelegatorMinStake()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.isPoolActive(address)"><code class="function-signature">isPoolActive(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.maxWithdrawAllowed(address,address)"><code class="function-signature">maxWithdrawAllowed(address _poolStakingAddress, address _staker)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.maxWithdrawOrderAllowed(address,address)"><code class="function-signature">maxWithdrawOrderAllowed(address _poolStakingAddress, address _staker)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.onTokenTransfer(address,uint256,bytes)"><code class="function-signature">onTokenTransfer(address, uint256, bytes)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.orderedWithdrawAmount(address,address)"><code class="function-signature">orderedWithdrawAmount(address _poolStakingAddress, address _staker)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.orderedWithdrawAmountTotal(address)"><code class="function-signature">orderedWithdrawAmountTotal(address _poolStakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.orderWithdrawEpoch(address,address)"><code class="function-signature">orderWithdrawEpoch(address _poolStakingAddress, address _staker)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.stakeAmountTotal(address)"><code class="function-signature">stakeAmountTotal(address _poolStakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.poolDelegators(address)"><code class="function-signature">poolDelegators(address _poolStakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.poolDelegatorIndex(address,address)"><code class="function-signature">poolDelegatorIndex(address _poolStakingAddress, address _delegator)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.poolDelegatorInactiveIndex(address,address)"><code class="function-signature">poolDelegatorInactiveIndex(address _poolStakingAddress, address _delegator)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.poolIndex(address)"><code class="function-signature">poolIndex(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.poolInactiveIndex(address)"><code class="function-signature">poolInactiveIndex(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.poolToBeElectedIndex(address)"><code class="function-signature">poolToBeElectedIndex(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.poolToBeRemovedIndex(address)"><code class="function-signature">poolToBeRemovedIndex(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.stakeAmount(address,address)"><code class="function-signature">stakeAmount(address _poolStakingAddress, address _staker)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.stakeAmountByCurrentEpoch(address,address)"><code class="function-signature">stakeAmountByCurrentEpoch(address _poolStakingAddress, address _staker)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.stakeAmountMinusOrderedWithdraw(address,address)"><code class="function-signature">stakeAmountMinusOrderedWithdraw(address _poolStakingAddress, address _staker)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.stakeAmountTotalMinusOrderedWithdraw(address)"><code class="function-signature">stakeAmountTotalMinusOrderedWithdraw(address _poolStakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase.stakingEpoch()"><code class="function-signature">stakingEpoch()</code></a></li><li class="inherited"><a href="abstracts#StakingBase.validatorSetContract()"><code class="function-signature">validatorSetContract()</code></a></li><li class="inherited"><a href="abstracts#StakingBase._addPoolInactive(address)"><code class="function-signature">_addPoolInactive(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._addPoolToBeElected(address)"><code class="function-signature">_addPoolToBeElected(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._addPoolToBeRemoved(address)"><code class="function-signature">_addPoolToBeRemoved(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._deletePoolToBeElected(address)"><code class="function-signature">_deletePoolToBeElected(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._deletePoolToBeRemoved(address)"><code class="function-signature">_deletePoolToBeRemoved(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._removePool(address)"><code class="function-signature">_removePool(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._removePoolInactive(address)"><code class="function-signature">_removePoolInactive(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._initialize(address,address,address[],uint256,uint256)"><code class="function-signature">_initialize(address _validatorSetContract, address _erc20TokenContract, address[] _initialStakingAddresses, uint256 _delegatorMinStake, uint256 _candidateMinStake)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setOrderWithdrawEpoch(address,address,uint256)"><code class="function-signature">_setOrderWithdrawEpoch(address _poolStakingAddress, address _staker, uint256 _stakingEpoch)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setPoolDelegatorIndex(address,address,uint256)"><code class="function-signature">_setPoolDelegatorIndex(address _poolStakingAddress, address _delegator, uint256 _index)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setPoolDelegatorInactiveIndex(address,address,uint256)"><code class="function-signature">_setPoolDelegatorInactiveIndex(address _poolStakingAddress, address _delegator, uint256 _index)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setPoolIndex(address,uint256)"><code class="function-signature">_setPoolIndex(address _stakingAddress, uint256 _index)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setPoolInactiveIndex(address,uint256)"><code class="function-signature">_setPoolInactiveIndex(address _stakingAddress, uint256 _index)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setPoolToBeElectedIndex(address,uint256)"><code class="function-signature">_setPoolToBeElectedIndex(address _stakingAddress, uint256 _index)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setPoolToBeRemovedIndex(address,uint256)"><code class="function-signature">_setPoolToBeRemovedIndex(address _stakingAddress, uint256 _index)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._addPoolDelegator(address,address)"><code class="function-signature">_addPoolDelegator(address _poolStakingAddress, address _delegator)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._addPoolDelegatorInactive(address,address)"><code class="function-signature">_addPoolDelegatorInactive(address _poolStakingAddress, address _delegator)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._removePoolDelegator(address,address)"><code class="function-signature">_removePoolDelegator(address _poolStakingAddress, address _delegator)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._removePoolDelegatorInactive(address,address)"><code class="function-signature">_removePoolDelegatorInactive(address _poolStakingAddress, address _delegator)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setLikelihood(address)"><code class="function-signature">_setLikelihood(address _poolStakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setOrderedWithdrawAmount(address,address,uint256)"><code class="function-signature">_setOrderedWithdrawAmount(address _poolStakingAddress, address _staker, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setOrderedWithdrawAmountTotal(address,uint256)"><code class="function-signature">_setOrderedWithdrawAmountTotal(address _poolStakingAddress, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setStakeAmount(address,address,uint256)"><code class="function-signature">_setStakeAmount(address _poolStakingAddress, address _staker, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setStakeAmountByCurrentEpoch(address,address,uint256)"><code class="function-signature">_setStakeAmountByCurrentEpoch(address _poolStakingAddress, address _staker, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setStakeAmountTotal(address,uint256)"><code class="function-signature">_setStakeAmountTotal(address _poolStakingAddress, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setDelegatorMinStake(uint256)"><code class="function-signature">_setDelegatorMinStake(uint256 _minStake)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._setCandidateMinStake(uint256)"><code class="function-signature">_setCandidateMinStake(uint256 _minStake)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._stake(address,uint256)"><code class="function-signature">_stake(address _toPoolStakingAddress, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._stake(address,address,uint256)"><code class="function-signature">_stake(address _poolStakingAddress, address _staker, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._withdraw(address,address,uint256)"><code class="function-signature">_withdraw(address _poolStakingAddress, address _staker, uint256 _amount)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._withdrawCheckPool(address,address)"><code class="function-signature">_withdrawCheckPool(address _poolStakingAddress, address _staker)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._getCurrentBlockNumber()"><code class="function-signature">_getCurrentBlockNumber()</code></a></li><li class="inherited"><a href="abstracts#StakingBase._getMaxCandidates()"><code class="function-signature">_getMaxCandidates()</code></a></li><li class="inherited"><a href="abstracts#StakingBase._isPoolToBeElected(address)"><code class="function-signature">_isPoolToBeElected(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#StakingBase._isWithdrawAllowed(address)"><code class="function-signature">_isWithdrawAllowed(address _miningAddress)</code></a></li></ul><span class="contract-index-title">Events</span><ul><li class="inherited"><a href="#StakingHBBFT.Claimed(address,address,uint256,uint256)"><code class="function-signature">Claimed(address fromPoolStakingAddress, address staker, uint256 stakingEpoch, uint256 amount)</code></a></li><li class="inherited"><a href="#StakingHBBFT.Staked(address,address,uint256,uint256)"><code class="function-signature">Staked(address toPoolStakingAddress, address staker, uint256 stakingEpoch, uint256 amount)</code></a></li><li class="inherited"><a href="#StakingHBBFT.StakeMoved(address,address,address,uint256,uint256)"><code class="function-signature">StakeMoved(address fromPoolStakingAddress, address toPoolStakingAddress, address staker, uint256 stakingEpoch, uint256 amount)</code></a></li><li class="inherited"><a href="#StakingHBBFT.WithdrawalOrdered(address,address,uint256,int256)"><code class="function-signature">WithdrawalOrdered(address fromPoolStakingAddress, address staker, uint256 stakingEpoch, int256 amount)</code></a></li><li class="inherited"><a href="#StakingHBBFT.Withdrawn(address,address,uint256,uint256)"><code class="function-signature">Withdrawn(address fromPoolStakingAddress, address staker, uint256 stakingEpoch, uint256 amount)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="StakingHBBFT.addPool(bytes,uint256,address)"></a><code class="function-signature">addPool(bytes _publicKey, uint256 _amount, address _miningAddress)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="StakingHBBFT.initialize(address,address,address[],uint256,uint256)"></a><code class="function-signature">initialize(address _validatorSetContract, address _erc20TokenContract, address[] _initialStakingAddresses, uint256 _delegatorMinStake, uint256 _candidateMinStake)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="StakingHBBFT.areStakeAndWithdrawAllowed()"></a><code class="function-signature">areStakeAndWithdrawAllowed() <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="StakingHBBFT._addPoolActive(address,bool)"></a><code class="function-signature">_addPoolActive(address _stakingAddress, bool _toBeElected)</code></h4>







### `TxPermission`

Controls the use of zero gas price by validators in service transactions,
 protecting the network against &quot;transaction spamming&quot; by malicious validators.
 The protection logic is declared in the `allowedTxTypes` function.

<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#TxPermission.initialize(address)"><code class="function-signature">initialize(address _allowedSender)</code></a></li><li><a href="#TxPermission.addAllowedSender(address)"><code class="function-signature">addAllowedSender(address _sender)</code></a></li><li><a href="#TxPermission.removeAllowedSender(address)"><code class="function-signature">removeAllowedSender(address _sender)</code></a></li><li><a href="#TxPermission.contractName()"><code class="function-signature">contractName()</code></a></li><li><a href="#TxPermission.contractNameHash()"><code class="function-signature">contractNameHash()</code></a></li><li><a href="#TxPermission.contractVersion()"><code class="function-signature">contractVersion()</code></a></li><li><a href="#TxPermission.allowedSenders()"><code class="function-signature">allowedSenders()</code></a></li><li><a href="#TxPermission.allowedTxTypes(address,address,uint256,uint256,bytes)"><code class="function-signature">allowedTxTypes(address _sender, address _to, uint256, uint256 _gasPrice, bytes _data)</code></a></li><li><a href="#TxPermission.limitBlockGas()"><code class="function-signature">limitBlockGas()</code></a></li><li><a href="#TxPermission.isSenderAllowed(address)"><code class="function-signature">isSenderAllowed(address _sender)</code></a></li><li><a href="#TxPermission._addAllowedSender(address)"><code class="function-signature">_addAllowedSender(address _sender)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="TxPermission.initialize(address)"></a><code class="function-signature">initialize(address _allowedSender)</code></h4>

Initializes the contract at network startup.
 Must be called by the constructor of the `Initializer` contract on the genesis block.
 @param _allowedSender The address for which transactions of any type must be allowed.
 See the `allowedTxTypes` getter.



<h4><a class="anchor" aria-hidden="true" id="TxPermission.addAllowedSender(address)"></a><code class="function-signature">addAllowedSender(address _sender)</code></h4>

Adds the address for which transactions of any type must be allowed.
 Can only be called by the `owner`. See also the `allowedTxTypes` getter.
 @param _sender The address for which transactions of any type must be allowed.



<h4><a class="anchor" aria-hidden="true" id="TxPermission.removeAllowedSender(address)"></a><code class="function-signature">removeAllowedSender(address _sender)</code></h4>

Removes the specified address from the array of addresses allowed
 to initiate transactions of any type. Can only be called by the `owner`.
 See also the `addAllowedSender` function and `allowedSenders` getter.
 @param _sender The removed address.



<h4><a class="anchor" aria-hidden="true" id="TxPermission.contractName()"></a><code class="function-signature">contractName() <span class="return-arrow">→</span> <span class="return-type">string</span></code></h4>

Returns the contract&#x27;s name recognizable by the Parity engine.



<h4><a class="anchor" aria-hidden="true" id="TxPermission.contractNameHash()"></a><code class="function-signature">contractNameHash() <span class="return-arrow">→</span> <span class="return-type">bytes32</span></code></h4>

Returns the contract name hash needed for the Parity engine.



<h4><a class="anchor" aria-hidden="true" id="TxPermission.contractVersion()"></a><code class="function-signature">contractVersion() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the contract&#x27;s version number needed for the Parity engine.



<h4><a class="anchor" aria-hidden="true" id="TxPermission.allowedSenders()"></a><code class="function-signature">allowedSenders() <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>

Returns the list of addresses allowed to initiate transactions of any type.
 For these addresses the `allowedTxTypes` getter always returns the `ALL` bit mask
 (see https://wiki.parity.io/Permissioning.html#how-it-works-1).



<h4><a class="anchor" aria-hidden="true" id="TxPermission.allowedTxTypes(address,address,uint256,uint256,bytes)"></a><code class="function-signature">allowedTxTypes(address _sender, address _to, uint256, uint256 _gasPrice, bytes _data) <span class="return-arrow">→</span> <span class="return-type">uint32,bool</span></code></h4>

Defines the allowed transaction types which may be initiated by the specified sender with
 the specified gas price and data. Used by the Parity engine each time a transaction is about to be
 included into a block. See https://wiki.parity.io/Permissioning.html#how-it-works-1
 @param _sender Transaction sender address.
 @param _to Transaction recipient address. If creating a contract, the `_to` address is zero.
 @param _gasPrice Gas price in wei for the transaction.
 @param _data Transaction data.
 @return typesMask Set of allowed transactions for `_sender` depending on tx `_to` address,
 `_gasPrice`, and `_data`. The result is represented as a set of flags:
 - 0x01 - basic transaction (e.g. ether transferring to user wallet)
 - 0x02 - contract call
 - 0x04 - contract creation
 - 0x08 - private transaction
 @return cache If `true` is returned, the same permissions will be applied from the same
 `_sender` without calling this contract again.



<h4><a class="anchor" aria-hidden="true" id="TxPermission.limitBlockGas()"></a><code class="function-signature">limitBlockGas() <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Returns a boolean flag indicating whether the current block gas limit must be limited.
 See https://github.com/poanetwork/parity-ethereum/issues/119



<h4><a class="anchor" aria-hidden="true" id="TxPermission.isSenderAllowed(address)"></a><code class="function-signature">isSenderAllowed(address _sender) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Returns a boolean flag indicating whether the specified address is allowed
 to initiate transactions of any type. Used by the `allowedTxTypes` getter.
 See also the `addAllowedSender` and `removeAllowedSender` functions.
 @param _sender The specified address to check.



<h4><a class="anchor" aria-hidden="true" id="TxPermission._addAllowedSender(address)"></a><code class="function-signature">_addAllowedSender(address _sender)</code></h4>

An internal function used by the `addAllowedSender` and `initialize` functions.
 @param _sender The address for which transactions of any type must be allowed.





### `ValidatorSetAuRa`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#ValidatorSetAuRa.newValidatorSet()"><code class="function-signature">newValidatorSet()</code></a></li><li><a href="#ValidatorSetAuRa.removeMaliciousValidator(address)"><code class="function-signature">removeMaliciousValidator(address _miningAddress)</code></a></li><li><a href="#ValidatorSetAuRa.reportMalicious(address,uint256,bytes)"><code class="function-signature">reportMalicious(address _maliciousMiningAddress, uint256 _blockNumber, bytes)</code></a></li><li><a href="#ValidatorSetAuRa.maliceReportedForBlock(address,uint256)"><code class="function-signature">maliceReportedForBlock(address _maliciousMiningAddress, uint256 _blockNumber)</code></a></li><li><a href="#ValidatorSetAuRa.reportingCounter(address,uint256)"><code class="function-signature">reportingCounter(address _reportingMiningAddress, uint256 _stakingEpoch)</code></a></li><li><a href="#ValidatorSetAuRa.reportingCounterTotal(uint256)"><code class="function-signature">reportingCounterTotal(uint256 _stakingEpoch)</code></a></li><li><a href="#ValidatorSetAuRa.reportMaliciousCallable(address,address,uint256)"><code class="function-signature">reportMaliciousCallable(address _reportingMiningAddress, address _maliciousMiningAddress, uint256 _blockNumber)</code></a></li><li><a href="#ValidatorSetAuRa._banStart()"><code class="function-signature">_banStart()</code></a></li><li><a href="#ValidatorSetAuRa._banUntil()"><code class="function-signature">_banUntil()</code></a></li><li><a href="#ValidatorSetAuRa._clearReportingCounter(address)"><code class="function-signature">_clearReportingCounter(address _miningAddress)</code></a></li><li><a href="#ValidatorSetAuRa._incrementReportingCounter(address)"><code class="function-signature">_incrementReportingCounter(address _reportingMiningAddress)</code></a></li><li><a href="#ValidatorSetAuRa._removeMaliciousValidatorAuRa(address)"><code class="function-signature">_removeMaliciousValidatorAuRa(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.clearUnremovableValidator()"><code class="function-signature">clearUnremovableValidator()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.emitInitiateChange()"><code class="function-signature">emitInitiateChange()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.finalizeChange()"><code class="function-signature">finalizeChange()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.initialize(address,address,address,address[],address[],bool)"><code class="function-signature">initialize(address _blockRewardContract, address _randomContract, address _stakingContract, address[] _initialMiningAddresses, address[] _initialStakingAddresses, bool _firstValidatorIsUnremovable)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.setStakingAddress(address,address)"><code class="function-signature">setStakingAddress(address _miningAddress, address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.banCounter(address)"><code class="function-signature">banCounter(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.bannedUntil(address)"><code class="function-signature">bannedUntil(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.blockRewardContract()"><code class="function-signature">blockRewardContract()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.changeRequestCount()"><code class="function-signature">changeRequestCount()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.emitInitiateChangeCallable()"><code class="function-signature">emitInitiateChangeCallable()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.getPreviousValidators()"><code class="function-signature">getPreviousValidators()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.getPendingValidators()"><code class="function-signature">getPendingValidators()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.getQueueValidators()"><code class="function-signature">getQueueValidators()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.getValidators()"><code class="function-signature">getValidators()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.initiateChangeAllowed()"><code class="function-signature">initiateChangeAllowed()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.isReportValidatorValid(address)"><code class="function-signature">isReportValidatorValid(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.isValidator(address)"><code class="function-signature">isValidator(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.isValidatorOnPreviousEpoch(address)"><code class="function-signature">isValidatorOnPreviousEpoch(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.isValidatorBanned(address)"><code class="function-signature">isValidatorBanned(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.miningByStakingAddress(address)"><code class="function-signature">miningByStakingAddress(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.randomContract()"><code class="function-signature">randomContract()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.stakingByMiningAddress(address)"><code class="function-signature">stakingByMiningAddress(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.stakingContract()"><code class="function-signature">stakingContract()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.unremovableValidator()"><code class="function-signature">unremovableValidator()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.validatorCounter(address)"><code class="function-signature">validatorCounter(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.validatorIndex(address)"><code class="function-signature">validatorIndex(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.validatorSetApplyBlock()"><code class="function-signature">validatorSetApplyBlock()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._applyQueueValidators(address[])"><code class="function-signature">_applyQueueValidators(address[] _queueValidators)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._banValidator(address)"><code class="function-signature">_banValidator(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._enqueuePendingValidators(bool)"><code class="function-signature">_enqueuePendingValidators(bool _newStakingEpoch)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._dequeuePendingValidators()"><code class="function-signature">_dequeuePendingValidators()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._incrementChangeRequestCount()"><code class="function-signature">_incrementChangeRequestCount()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._newValidatorSet()"><code class="function-signature">_newValidatorSet()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._removeMaliciousValidator(address)"><code class="function-signature">_removeMaliciousValidator(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._setInitiateChangeAllowed(bool)"><code class="function-signature">_setInitiateChangeAllowed(bool _allowed)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._setIsValidator(address,bool)"><code class="function-signature">_setIsValidator(address _miningAddress, bool _isValidator)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._setIsValidatorOnPreviousEpoch(address,bool)"><code class="function-signature">_setIsValidatorOnPreviousEpoch(address _miningAddress, bool _isValidator)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._setPendingValidators(contract IStaking,address[],address)"><code class="function-signature">_setPendingValidators(contract IStaking _stakingContract, address[] _stakingAddresses, address _unremovableStakingAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._setQueueValidators(address[],bool)"><code class="function-signature">_setQueueValidators(address[] _miningAddresses, bool _newStakingEpoch)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._setStakingAddress(address,address)"><code class="function-signature">_setStakingAddress(address _miningAddress, address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._setUnremovableValidator(address)"><code class="function-signature">_setUnremovableValidator(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._setValidatorIndex(address,uint256)"><code class="function-signature">_setValidatorIndex(address _miningAddress, uint256 _index)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._setValidatorSetApplyBlock(uint256)"><code class="function-signature">_setValidatorSetApplyBlock(uint256 _blockNumber)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._getCurrentBlockNumber()"><code class="function-signature">_getCurrentBlockNumber()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._getRandomIndex(int256[],int256,uint256)"><code class="function-signature">_getRandomIndex(int256[] _likelihood, int256 _likelihoodSum, uint256 _randomNumber)</code></a></li><li class="inherited"><a href="interfaces#IValidatorSet.MAX_VALIDATORS()"><code class="function-signature">MAX_VALIDATORS()</code></a></li></ul><span class="contract-index-title">Events</span><ul><li class="inherited"><a href="#ValidatorSetAuRa.ReportedMalicious(address,address,uint256)"><code class="function-signature">ReportedMalicious(address reportingValidator, address maliciousValidator, uint256 blockNumber)</code></a></li><li class="inherited"><a href="#ValidatorSetAuRa.InitiateChange(bytes32,address[])"><code class="function-signature">InitiateChange(bytes32 parentHash, address[] newSet)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetAuRa.newValidatorSet()"></a><code class="function-signature">newValidatorSet() <span class="return-arrow">→</span> <span class="return-type">bool,uint256</span></code></h4>

Implements the logic which forms a new validator set. Calls the internal `_newValidatorSet` function of
 the base contract. Automatically called by the `BlockRewardAuRa.reward` function on every block.
 @return called A boolean flag indicating whether the internal `_newValidatorSet` function was called.
 @return poolsToBeElectedLength The number of pools ready to be elected (see the `Staking.getPoolsToBeElected`
 function). Equals `0` if the `called` flag is `false`.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetAuRa.removeMaliciousValidator(address)"></a><code class="function-signature">removeMaliciousValidator(address _miningAddress)</code></h4>

Removes a malicious validator. Called by the `RandomAuRa.onFinishCollectRound` function.
 @param _miningAddress The mining address of the malicious validator.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetAuRa.reportMalicious(address,uint256,bytes)"></a><code class="function-signature">reportMalicious(address _maliciousMiningAddress, uint256 _blockNumber, bytes)</code></h4>

Reports that the malicious validator misbehaved at the specified block.
 Called by the node of each honest validator after the specified validator misbehaved.
 See https://wiki.parity.io/Validator-Set.html#reporting-contract
 Can only be called when the `reportMaliciousCallable` getter returns `true`.
 @param _maliciousMiningAddress The mining address of the malicious validator.
 @param _blockNumber The block number where the misbehavior was observed.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetAuRa.maliceReportedForBlock(address,uint256)"></a><code class="function-signature">maliceReportedForBlock(address _maliciousMiningAddress, uint256 _blockNumber) <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>

Returns an array of the validators (their mining addresses) which reported that the specified malicious
 validator misbehaved at the specified block.
 @param _maliciousMiningAddress The mining address of the malicious validator.
 @param _blockNumber The block number at which the misbehavior was observed.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetAuRa.reportingCounter(address,uint256)"></a><code class="function-signature">reportingCounter(address _reportingMiningAddress, uint256 _stakingEpoch) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the number of times the specified validator reported misbehaviors during the specified
 staking epoch. Used by the `reportMaliciousCallable` getter to determine whether a validator reported too often.
 @param _reportingMiningAddress The mining address of the reporting validator.
 @param _stakingEpoch The serial number of the staking epoch.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetAuRa.reportingCounterTotal(uint256)"></a><code class="function-signature">reportingCounterTotal(uint256 _stakingEpoch) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns how many times all validators reported misbehaviors during the specified staking epoch.
 Used by the `reportMaliciousCallable` getter to determine whether a validator reported too often.
 @param _stakingEpoch The serial number of the staking epoch.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetAuRa.reportMaliciousCallable(address,address,uint256)"></a><code class="function-signature">reportMaliciousCallable(address _reportingMiningAddress, address _maliciousMiningAddress, uint256 _blockNumber) <span class="return-arrow">→</span> <span class="return-type">bool,bool</span></code></h4>

Returns whether the `reportMalicious` function can be called by the specified validator with the
 given parameters. Used by the `reportMalicious` function and `TxPermission` contract. Also, returns
 a boolean flag indicating whether the reporting validator should be removed as malicious due to
 excessive reporting during the current staking epoch.
 @param _reportingMiningAddress The mining address of the reporting validator which is calling
 the `reportMalicious` function.
 @param _maliciousMiningAddress The mining address of the malicious validator which is passed to
 the `reportMalicious` function.
 @param _blockNumber The block number which is passed to the `reportMalicious` function.
 @return callable The boolean flag indicating whether the `reportMalicious` function can be called at the moment.
 @return removeReportingValidator The boolean flag indicating whether the reporting validator should be 
 removed as malicious due to excessive reporting. This flag is only used by the `reportMalicious` function.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetAuRa._banStart()"></a><code class="function-signature">_banStart() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the current block number for the `isValidatorBanned`, `_banUntil`, and `_banValidator` functions.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetAuRa._banUntil()"></a><code class="function-signature">_banUntil() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the future block number until which a validator is banned. Used by the `_banValidator` function.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetAuRa._clearReportingCounter(address)"></a><code class="function-signature">_clearReportingCounter(address _miningAddress)</code></h4>

Updates the total reporting counter (see the `reportingCounterTotal` getter) for the current staking epoch
 after the specified validator is removed as malicious. The `reportMaliciousCallable` getter uses this counter
 for reporting checks so it must be up-to-date. Called by the `_removeMaliciousValidatorAuRa` internal function.
 @param _miningAddress The mining address of the removed malicious validator.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetAuRa._incrementReportingCounter(address)"></a><code class="function-signature">_incrementReportingCounter(address _reportingMiningAddress)</code></h4>

Increments the reporting counter for the specified validator and the current staking epoch.
 See the `reportingCounter` and `reportingCounterTotal` getters. Called by the `reportMalicious`
 function when the validator reports a misbehavior.
 @param _reportingMiningAddress The mining address of reporting validator.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetAuRa._removeMaliciousValidatorAuRa(address)"></a><code class="function-signature">_removeMaliciousValidatorAuRa(address _miningAddress)</code></h4>

Removes the specified validator as malicious from the pending validator set and enqueues the updated
 pending validator set to be dequeued by the `emitInitiateChange` function. Does nothing if the specified
 validator is already banned, non-removable, or does not exist in the pending validator set.
 @param _miningAddress The mining address of the malicious validator.





<h4><a class="anchor" aria-hidden="true" id="ValidatorSetAuRa.ReportedMalicious(address,address,uint256)"></a><code class="function-signature">ReportedMalicious(address reportingValidator, address maliciousValidator, uint256 blockNumber)</code></h4>

Emitted by the `reportMalicious` function to signal that a specified validator reported
 misbehavior by a specified malicious validator at a specified block number.
 @param reportingValidator The mining address of the reporting validator.
 @param maliciousValidator The mining address of the malicious validator.
 @param blockNumber The block number at which the `maliciousValidator` misbehaved.



### `ValidatorSetHBBFT`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#ValidatorSetHBBFT.clearMaliceReported(address)"><code class="function-signature">clearMaliceReported(address _miningAddress)</code></a></li><li><a href="#ValidatorSetHBBFT.newValidatorSet()"><code class="function-signature">newValidatorSet()</code></a></li><li><a href="#ValidatorSetHBBFT.reportMaliciousValidators(address[],address[])"><code class="function-signature">reportMaliciousValidators(address[] _miningAddresses, address[] _reportingMiningAddresses)</code></a></li><li><a href="#ValidatorSetHBBFT.savePublicKey(address,bytes)"><code class="function-signature">savePublicKey(address _miningAddress, bytes _key)</code></a></li><li><a href="#ValidatorSetHBBFT.initializePublicKeys(bytes[])"><code class="function-signature">initializePublicKeys(bytes[] _keys)</code></a></li><li><a href="#ValidatorSetHBBFT.maliceReported(address)"><code class="function-signature">maliceReported(address _miningAddress)</code></a></li><li><a href="#ValidatorSetHBBFT.publicKey(address)"><code class="function-signature">publicKey(address _miningAddress)</code></a></li><li><a href="#ValidatorSetHBBFT._banStart()"><code class="function-signature">_banStart()</code></a></li><li><a href="#ValidatorSetHBBFT._banUntil()"><code class="function-signature">_banUntil()</code></a></li><li><a href="#ValidatorSetHBBFT._savePublicKey(address,bytes)"><code class="function-signature">_savePublicKey(address _miningAddress, bytes _key)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.clearUnremovableValidator()"><code class="function-signature">clearUnremovableValidator()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.emitInitiateChange()"><code class="function-signature">emitInitiateChange()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.finalizeChange()"><code class="function-signature">finalizeChange()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.initialize(address,address,address,address[],address[],bool)"><code class="function-signature">initialize(address _blockRewardContract, address _randomContract, address _stakingContract, address[] _initialMiningAddresses, address[] _initialStakingAddresses, bool _firstValidatorIsUnremovable)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.setStakingAddress(address,address)"><code class="function-signature">setStakingAddress(address _miningAddress, address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.banCounter(address)"><code class="function-signature">banCounter(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.bannedUntil(address)"><code class="function-signature">bannedUntil(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.blockRewardContract()"><code class="function-signature">blockRewardContract()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.changeRequestCount()"><code class="function-signature">changeRequestCount()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.emitInitiateChangeCallable()"><code class="function-signature">emitInitiateChangeCallable()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.getPreviousValidators()"><code class="function-signature">getPreviousValidators()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.getPendingValidators()"><code class="function-signature">getPendingValidators()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.getQueueValidators()"><code class="function-signature">getQueueValidators()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.getValidators()"><code class="function-signature">getValidators()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.initiateChangeAllowed()"><code class="function-signature">initiateChangeAllowed()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.isReportValidatorValid(address)"><code class="function-signature">isReportValidatorValid(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.isValidator(address)"><code class="function-signature">isValidator(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.isValidatorOnPreviousEpoch(address)"><code class="function-signature">isValidatorOnPreviousEpoch(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.isValidatorBanned(address)"><code class="function-signature">isValidatorBanned(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.miningByStakingAddress(address)"><code class="function-signature">miningByStakingAddress(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.randomContract()"><code class="function-signature">randomContract()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.stakingByMiningAddress(address)"><code class="function-signature">stakingByMiningAddress(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.stakingContract()"><code class="function-signature">stakingContract()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.unremovableValidator()"><code class="function-signature">unremovableValidator()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.validatorCounter(address)"><code class="function-signature">validatorCounter(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.validatorIndex(address)"><code class="function-signature">validatorIndex(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase.validatorSetApplyBlock()"><code class="function-signature">validatorSetApplyBlock()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._applyQueueValidators(address[])"><code class="function-signature">_applyQueueValidators(address[] _queueValidators)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._banValidator(address)"><code class="function-signature">_banValidator(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._enqueuePendingValidators(bool)"><code class="function-signature">_enqueuePendingValidators(bool _newStakingEpoch)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._dequeuePendingValidators()"><code class="function-signature">_dequeuePendingValidators()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._incrementChangeRequestCount()"><code class="function-signature">_incrementChangeRequestCount()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._newValidatorSet()"><code class="function-signature">_newValidatorSet()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._removeMaliciousValidator(address)"><code class="function-signature">_removeMaliciousValidator(address _miningAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._setInitiateChangeAllowed(bool)"><code class="function-signature">_setInitiateChangeAllowed(bool _allowed)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._setIsValidator(address,bool)"><code class="function-signature">_setIsValidator(address _miningAddress, bool _isValidator)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._setIsValidatorOnPreviousEpoch(address,bool)"><code class="function-signature">_setIsValidatorOnPreviousEpoch(address _miningAddress, bool _isValidator)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._setPendingValidators(contract IStaking,address[],address)"><code class="function-signature">_setPendingValidators(contract IStaking _stakingContract, address[] _stakingAddresses, address _unremovableStakingAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._setQueueValidators(address[],bool)"><code class="function-signature">_setQueueValidators(address[] _miningAddresses, bool _newStakingEpoch)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._setStakingAddress(address,address)"><code class="function-signature">_setStakingAddress(address _miningAddress, address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._setUnremovableValidator(address)"><code class="function-signature">_setUnremovableValidator(address _stakingAddress)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._setValidatorIndex(address,uint256)"><code class="function-signature">_setValidatorIndex(address _miningAddress, uint256 _index)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._setValidatorSetApplyBlock(uint256)"><code class="function-signature">_setValidatorSetApplyBlock(uint256 _blockNumber)</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._getCurrentBlockNumber()"><code class="function-signature">_getCurrentBlockNumber()</code></a></li><li class="inherited"><a href="abstracts#ValidatorSetBase._getRandomIndex(int256[],int256,uint256)"><code class="function-signature">_getRandomIndex(int256[] _likelihood, int256 _likelihoodSum, uint256 _randomNumber)</code></a></li><li class="inherited"><a href="interfaces#IValidatorSet.MAX_VALIDATORS()"><code class="function-signature">MAX_VALIDATORS()</code></a></li></ul><span class="contract-index-title">Events</span><ul><li class="inherited"><a href="#ValidatorSetHBBFT.InitiateChange(bytes32,address[])"><code class="function-signature">InitiateChange(bytes32 parentHash, address[] newSet)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetHBBFT.clearMaliceReported(address)"></a><code class="function-signature">clearMaliceReported(address _miningAddress)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="ValidatorSetHBBFT.newValidatorSet()"></a><code class="function-signature">newValidatorSet() <span class="return-arrow">→</span> <span class="return-type">bool,uint256</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="ValidatorSetHBBFT.reportMaliciousValidators(address[],address[])"></a><code class="function-signature">reportMaliciousValidators(address[] _miningAddresses, address[] _reportingMiningAddresses)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="ValidatorSetHBBFT.savePublicKey(address,bytes)"></a><code class="function-signature">savePublicKey(address _miningAddress, bytes _key)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="ValidatorSetHBBFT.initializePublicKeys(bytes[])"></a><code class="function-signature">initializePublicKeys(bytes[] _keys)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="ValidatorSetHBBFT.maliceReported(address)"></a><code class="function-signature">maliceReported(address _miningAddress) <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="ValidatorSetHBBFT.publicKey(address)"></a><code class="function-signature">publicKey(address _miningAddress) <span class="return-arrow">→</span> <span class="return-type">bytes</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="ValidatorSetHBBFT._banStart()"></a><code class="function-signature">_banStart() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="ValidatorSetHBBFT._banUntil()"></a><code class="function-signature">_banUntil() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="ValidatorSetHBBFT._savePublicKey(address,bytes)"></a><code class="function-signature">_savePublicKey(address _miningAddress, bytes _key)</code></h4>







</div>