---
title: Abstracts
---

<div class="contracts">

## Contracts

### `BlockRewardBase`

The base contract for the BlockRewardAuRa and BlockRewardHBBFT contracts.

<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#BlockRewardBase.addBridgeNativeFeeReceivers(uint256)"><code class="function-signature">addBridgeNativeFeeReceivers(uint256 _amount)</code></a></li><li><a href="#BlockRewardBase.addBridgeTokenFeeReceivers(uint256)"><code class="function-signature">addBridgeTokenFeeReceivers(uint256 _amount)</code></a></li><li><a href="#BlockRewardBase.addExtraReceiver(uint256,address)"><code class="function-signature">addExtraReceiver(uint256 _amount, address _receiver)</code></a></li><li><a href="#BlockRewardBase.setErcToNativeBridgesAllowed(address[])"><code class="function-signature">setErcToNativeBridgesAllowed(address[] _bridgesAllowed)</code></a></li><li><a href="#BlockRewardBase.setNativeToErcBridgesAllowed(address[])"><code class="function-signature">setNativeToErcBridgesAllowed(address[] _bridgesAllowed)</code></a></li><li><a href="#BlockRewardBase.setErcToErcBridgesAllowed(address[])"><code class="function-signature">setErcToErcBridgesAllowed(address[] _bridgesAllowed)</code></a></li><li><a href="#BlockRewardBase.ercToErcBridgesAllowed()"><code class="function-signature">ercToErcBridgesAllowed()</code></a></li><li><a href="#BlockRewardBase.ercToNativeBridgesAllowed()"><code class="function-signature">ercToNativeBridgesAllowed()</code></a></li><li><a href="#BlockRewardBase.extraReceiversQueueSize()"><code class="function-signature">extraReceiversQueueSize()</code></a></li><li><a href="#BlockRewardBase.getBridgeNativeFee()"><code class="function-signature">getBridgeNativeFee()</code></a></li><li><a href="#BlockRewardBase.getBridgeTokenFee()"><code class="function-signature">getBridgeTokenFee()</code></a></li><li><a href="#BlockRewardBase.isRewarding()"><code class="function-signature">isRewarding()</code></a></li><li><a href="#BlockRewardBase.isSnapshotting()"><code class="function-signature">isSnapshotting()</code></a></li><li><a href="#BlockRewardBase.mintedForAccount(address)"><code class="function-signature">mintedForAccount(address _account)</code></a></li><li><a href="#BlockRewardBase.mintedForAccountInBlock(address,uint256)"><code class="function-signature">mintedForAccountInBlock(address _account, uint256 _blockNumber)</code></a></li><li><a href="#BlockRewardBase.mintedInBlock(uint256)"><code class="function-signature">mintedInBlock(uint256 _blockNumber)</code></a></li><li><a href="#BlockRewardBase.mintedTotallyByBridge(address)"><code class="function-signature">mintedTotallyByBridge(address _bridge)</code></a></li><li><a href="#BlockRewardBase.mintedTotally()"><code class="function-signature">mintedTotally()</code></a></li><li><a href="#BlockRewardBase.nativeToErcBridgesAllowed()"><code class="function-signature">nativeToErcBridgesAllowed()</code></a></li><li><a href="#BlockRewardBase.snapshotRewardPercents(address)"><code class="function-signature">snapshotRewardPercents(address _validatorStakingAddress)</code></a></li><li><a href="#BlockRewardBase.snapshotStakers(address)"><code class="function-signature">snapshotStakers(address _validatorStakingAddress)</code></a></li><li><a href="#BlockRewardBase.snapshotStakingAddresses()"><code class="function-signature">snapshotStakingAddresses()</code></a></li><li><a href="#BlockRewardBase.snapshotTotalStakeAmount()"><code class="function-signature">snapshotTotalStakeAmount()</code></a></li><li><a href="#BlockRewardBase._mintNativeCoinsByErcToNativeBridge(address[],uint256[],uint256)"><code class="function-signature">_mintNativeCoinsByErcToNativeBridge(address[] _bridgeFeeReceivers, uint256[] _bridgeFeeRewards, uint256 _queueLimit)</code></a></li><li><a href="#BlockRewardBase._dequeueExtraReceiver()"><code class="function-signature">_dequeueExtraReceiver()</code></a></li><li><a href="#BlockRewardBase._enqueueExtraReceiver(uint256,address,address)"><code class="function-signature">_enqueueExtraReceiver(uint256 _amount, address _receiver, address _bridge)</code></a></li><li><a href="#BlockRewardBase._setMinted(uint256,address,address)"><code class="function-signature">_setMinted(uint256 _amount, address _account, address _bridge)</code></a></li><li><a href="#BlockRewardBase._setSnapshot(address,contract IStaking,uint256)"><code class="function-signature">_setSnapshot(address _stakingAddress, contract IStaking _stakingContract, uint256 _offset)</code></a></li><li class="inherited"><a href="interfaces#IBlockReward.DELEGATORS_ALIQUOT()"><code class="function-signature">DELEGATORS_ALIQUOT()</code></a></li></ul><span class="contract-index-title">Events</span><ul><li class="inherited"><a href="#BlockRewardBase.AddedReceiver(uint256,address,address)"><code class="function-signature">AddedReceiver(uint256 amount, address receiver, address bridge)</code></a></li><li class="inherited"><a href="#BlockRewardBase.MintedNative(address[],uint256[])"><code class="function-signature">MintedNative(address[] receivers, uint256[] rewards)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.addBridgeNativeFeeReceivers(uint256)"></a><code class="function-signature">addBridgeNativeFeeReceivers(uint256 _amount)</code></h4>

Called by the `erc-to-native` bridge contract when a portion of the bridge fee should be distributed to
 participants (validators and their delegators) in native coins. The specified amount is used by the
 `_distributeRewards` function.
 @param _amount The fee amount distributed to participants.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.addBridgeTokenFeeReceivers(uint256)"></a><code class="function-signature">addBridgeTokenFeeReceivers(uint256 _amount)</code></h4>

Called by the `erc-to-erc` or `native-to-erc` bridge contract when a portion of the bridge fee should be
 distributed to participants in staking tokens. The specified amount is used by the `_distributeRewards`
 function.
 @param _amount The fee amount distributed to participants.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.addExtraReceiver(uint256,address)"></a><code class="function-signature">addExtraReceiver(uint256 _amount, address _receiver)</code></h4>

Called by the `erc-to-native` bridge contract when the bridge needs to mint a specified amount of native
 coins for a specified address using the `reward` function.
 @param _amount The amount of native coins which must be minted for the `_receiver` address.
 @param _receiver The address for which the `_amount` of native coins must be minted.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.setErcToNativeBridgesAllowed(address[])"></a><code class="function-signature">setErcToNativeBridgesAllowed(address[] _bridgesAllowed)</code></h4>

Sets the array of `erc-to-native` bridge addresses which are allowed to call some of the functions with
 the `onlyErcToNativeBridge` modifier. This setter can only be called by the `owner`.
 @param _bridgesAllowed The array of bridge addresses.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.setNativeToErcBridgesAllowed(address[])"></a><code class="function-signature">setNativeToErcBridgesAllowed(address[] _bridgesAllowed)</code></h4>

Sets the array of `native-to-erc` bridge addresses which are allowed to call some of the functions with
 the `onlyXToErcBridge` modifier. This setter can only be called by the `owner`.
 @param _bridgesAllowed The array of bridge addresses.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.setErcToErcBridgesAllowed(address[])"></a><code class="function-signature">setErcToErcBridgesAllowed(address[] _bridgesAllowed)</code></h4>

Sets the array of `erc-to-erc` bridge addresses which are allowed to call some of the functions with
 the `onlyXToErcBridge` modifier. This setter can only be called by the `owner`.
 @param _bridgesAllowed The array of bridge addresses.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.ercToErcBridgesAllowed()"></a><code class="function-signature">ercToErcBridgesAllowed() <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>

Returns the array of `erc-to-erc` bridge addresses set by the `setErcToErcBridgesAllowed` setter.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.ercToNativeBridgesAllowed()"></a><code class="function-signature">ercToNativeBridgesAllowed() <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>

Returns the array of `erc-to-native` bridge addresses set by the `setErcToNativeBridgesAllowed` setter.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.extraReceiversQueueSize()"></a><code class="function-signature">extraReceiversQueueSize() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the current size of the address queue created by the `addExtraReceiver` function.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.getBridgeNativeFee()"></a><code class="function-signature">getBridgeNativeFee() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the current total fee amount of native coins accumulated by
 the `addBridgeNativeFeeReceivers` function.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.getBridgeTokenFee()"></a><code class="function-signature">getBridgeTokenFee() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the current total fee amount of staking tokens accumulated by
 the `addBridgeTokenFeeReceivers` function.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.isRewarding()"></a><code class="function-signature">isRewarding() <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Returns a boolean flag indicating if the reward process is occuring for the current block.
 The value of this boolean flag is changed by the `_distributeRewards` function.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.isSnapshotting()"></a><code class="function-signature">isSnapshotting() <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Returns a boolean flag indicating if the snapshotting process is occuring for the current block.
 The value of this boolean flag is changed by the `reward` function.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.mintedForAccount(address)"></a><code class="function-signature">mintedForAccount(address _account) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the total amount of native coins minted for the specified address
 by the `erc-to-native` bridges through the `addExtraReceiver` function.
 @param _account The address for which the getter must return the minted amount.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.mintedForAccountInBlock(address,uint256)"></a><code class="function-signature">mintedForAccountInBlock(address _account, uint256 _blockNumber) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the amount of native coins minted at the specified block for the specified
 address by the `erc-to-native` bridges through the `addExtraReceiver` function.
 @param _account The address for which the getter must return the amount minted at the `_blockNumber`.
 @param _blockNumber The block number for which the getter must return the amount minted for the `_account`.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.mintedInBlock(uint256)"></a><code class="function-signature">mintedInBlock(uint256 _blockNumber) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the total amount of native coins minted at the specified block
 by the `erc-to-native` bridges through the `addExtraReceiver` function.
 @param _blockNumber The block number for which the getter must return the minted amount.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.mintedTotallyByBridge(address)"></a><code class="function-signature">mintedTotallyByBridge(address _bridge) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the total amount of native coins minted by the specified
 `erc-to-native` bridge through the `addExtraReceiver` function.
 @param _bridge The address of the bridge contract.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.mintedTotally()"></a><code class="function-signature">mintedTotally() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the total amount of native coins minted by the
 `erc-to-native` bridges through the `addExtraReceiver` function.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.nativeToErcBridgesAllowed()"></a><code class="function-signature">nativeToErcBridgesAllowed() <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>

Returns the array of `native-to-erc` bridge addresses which were set by
 the `setNativeToErcBridgesAllowed` setter.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.snapshotRewardPercents(address)"></a><code class="function-signature">snapshotRewardPercents(address _validatorStakingAddress) <span class="return-arrow">→</span> <span class="return-type">uint256[]</span></code></h4>

Returns an array of reward coefficients which corresponds to the array of stakers
 for a specified validator and the current staking epoch. The size of the returned array
 is the same as the size of the staker array returned by the `snapshotStakers` getter. The reward
 coefficients are calculated by the `_setSnapshot` function at the beginning of the staking epoch
 and then used by the `_distributeRewards` function at the end of the staking epoch.
 @param _validatorStakingAddress The staking address of the validator pool for which the getter
 must return the coefficient array.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.snapshotStakers(address)"></a><code class="function-signature">snapshotStakers(address _validatorStakingAddress) <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>

Returns an array of stakers for the specified validator and the current staking epoch
 snapshotted at the beginning of the staking epoch by the `_setSnapshot` function. This array is
 used by the `_distributeRewards` function at the end of the staking epoch.
 @param _validatorStakingAddress The staking address of the validator pool for which the getter
 must return the array of stakers.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.snapshotStakingAddresses()"></a><code class="function-signature">snapshotStakingAddresses() <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>

Returns an array of the pools snapshotted by the `_setSnapshot` function
 at the beginning of the current staking epoch.
 The getter returns the staking addresses of the pools.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.snapshotTotalStakeAmount()"></a><code class="function-signature">snapshotTotalStakeAmount() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the total amount staked during the previous staking epoch. This value is used by the
 `_distributeRewards` function at the end of the current staking epoch to calculate the inflation amount 
 for the staking token in the current staking epoch.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase._mintNativeCoinsByErcToNativeBridge(address[],uint256[],uint256)"></a><code class="function-signature">_mintNativeCoinsByErcToNativeBridge(address[] _bridgeFeeReceivers, uint256[] _bridgeFeeRewards, uint256 _queueLimit) <span class="return-arrow">→</span> <span class="return-type">address[],uint256[]</span></code></h4>

Joins two native coin receiver elements into a single set and returns the result
 to the `reward` function: the first element comes from the `erc-to-native` bridge fee distribution,
 the second from the `erc-to-native` bridge when native coins are minted for the specified addresses.
 Dequeues the addresses enqueued with the `addExtraReceiver` function by the `erc-to-native` bridge.
 Accumulates minting statistics for the `erc-to-native` bridges.
 @param _bridgeFeeReceivers The array of native coin receivers formed by the `_distributeRewards` function.
 @param _bridgeFeeRewards The array of native coin amounts to be minted for the corresponding
 `_bridgeFeeReceivers`. The size of this array is equal to the size of the `_bridgeFeeReceivers` array.
 @param _queueLimit Max number of addresses which can be dequeued from the queue formed by the
 `addExtraReceiver` function.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase._dequeueExtraReceiver()"></a><code class="function-signature">_dequeueExtraReceiver() <span class="return-arrow">→</span> <span class="return-type">uint256,address,address</span></code></h4>

Dequeues the information about the native coins receiver enqueued with the `addExtraReceiver`
 function by the `erc-to-native` bridge. This function is used by `_mintNativeCoinsByErcToNativeBridge`.
 @return amount The amount to be minted for the `receiver` address.
 @return receiver The address for which the `amount` is minted.
 @return bridge The address of the bridge contract which called the `addExtraReceiver` function.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase._enqueueExtraReceiver(uint256,address,address)"></a><code class="function-signature">_enqueueExtraReceiver(uint256 _amount, address _receiver, address _bridge)</code></h4>

Enqueues the information about the receiver of native coins which must be minted for the
 specified `erc-to-native` bridge. This function is used by the `addExtraReceiver` function.
 @param _amount The amount of native coins which must be minted for the `_receiver` address.
 @param _receiver The address for which the `_amount` of native coins must be minted.
 @param _bridge The address of the bridge contract which requested the minting of native coins.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase._setMinted(uint256,address,address)"></a><code class="function-signature">_setMinted(uint256 _amount, address _account, address _bridge)</code></h4>

Accumulates minting statistics for the `erc-to-native` bridge.
 This function is used by the `_mintNativeCoinsByErcToNativeBridge` function.
 @param _amount The amount minted for the `_account` address.
 @param _account The address for which the `_amount` is minted.
 @param _bridge The address of the bridge contract which called the `addExtraReceiver` function.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase._setSnapshot(address,contract IStaking,uint256)"></a><code class="function-signature">_setSnapshot(address _stakingAddress, contract IStaking _stakingContract, uint256 _offset)</code></h4>

Calculates the reward coefficient for each pool&#x27;s staker and saves it so it can be used at
 the end of the staking epoch for the reward distribution phase. Specifies a section of the coefficients&#x27;
 snapshot thus limiting the coefficient calculations for each block. This function is called by
 the `reward` function at the beginning of the staking epoch.
 @param _stakingAddress The staking address of a pool for which the snapshot must be done.
 @param _stakingContract The address of the `Staking` contract.
 @param _offset The section of the delegator array to snapshot at the current block.
 The `_offset` range is [0, DELEGATORS_ALIQUOT - 1]. The `_offset` value is set based on the `DELEGATORS_ALIQUOT`
 constant - see the code of the `reward` function.





<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.AddedReceiver(uint256,address,address)"></a><code class="function-signature">AddedReceiver(uint256 amount, address receiver, address bridge)</code></h4>

Emitted by the `addExtraReceiver` function.
 @param amount The amount of native coins which must be minted for the `receiver` by the `erc-to-native`
 `bridge` with the `reward` function.
 @param receiver The address for which the `amount` of native coins must be minted.
 @param bridge The bridge address which called the `addExtraReceiver` function.



<h4><a class="anchor" aria-hidden="true" id="BlockRewardBase.MintedNative(address[],uint256[])"></a><code class="function-signature">MintedNative(address[] receivers, uint256[] rewards)</code></h4>

Emitted by the `_mintNativeCoinsByErcToNativeBridge` function which is called by the `reward` function.
 This event is only used by the unit tests because the `reward` function cannot emit events.
 @param receivers The array of receiver addresses for which native coins are minted. The length of this
 array is equal to the length of the `rewards` array.
 @param rewards The array of amounts minted for the relevant `receivers`. The length of this array
 is equal to the length of the `receivers` array.



### `ContractsAddresses`

This contract lists all contract addresses in one place.
 Contracts requiring these addresses inherit the values from here.

<div class="contract-index"></div>





### `RandomBase`

The base contract for the RandomAuRa and RandomHBBFT contracts.

<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#RandomBase.getCurrentSeed()"><code class="function-signature">getCurrentSeed()</code></a></li><li><a href="#RandomBase._setCurrentSeed(uint256)"><code class="function-signature">_setCurrentSeed(uint256 _seed)</code></a></li><li><a href="#RandomBase._getCurrentSeed()"><code class="function-signature">_getCurrentSeed()</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="RandomBase.getCurrentSeed()"></a><code class="function-signature">getCurrentSeed() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the current random seed accumulated during RANDAO or another process (depending on
 implementation). This getter can only be called by the `ValidatorSet` contract.



<h4><a class="anchor" aria-hidden="true" id="RandomBase._setCurrentSeed(uint256)"></a><code class="function-signature">_setCurrentSeed(uint256 _seed)</code></h4>

Updates the current random seed.
 @param _seed A new random seed.



<h4><a class="anchor" aria-hidden="true" id="RandomBase._getCurrentSeed()"></a><code class="function-signature">_getCurrentSeed() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Reads the current random seed from the state.





### `StakingBase`

The base contract for the StakingAuRa and StakingHBBFT contracts.

<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#StakingBase.clearUnremovableValidator(address)"><code class="function-signature">clearUnremovableValidator(address _unremovableStakingAddress)</code></a></li><li><a href="#StakingBase.incrementStakingEpoch()"><code class="function-signature">incrementStakingEpoch()</code></a></li><li><a href="#StakingBase.removePool(address)"><code class="function-signature">removePool(address _stakingAddress)</code></a></li><li><a href="#StakingBase.removePool()"><code class="function-signature">removePool()</code></a></li><li><a href="#StakingBase.moveStake(address,address,uint256)"><code class="function-signature">moveStake(address _fromPoolStakingAddress, address _toPoolStakingAddress, uint256 _amount)</code></a></li><li><a href="#StakingBase.stake(address,uint256)"><code class="function-signature">stake(address _toPoolStakingAddress, uint256 _amount)</code></a></li><li><a href="#StakingBase.withdraw(address,uint256)"><code class="function-signature">withdraw(address _fromPoolStakingAddress, uint256 _amount)</code></a></li><li><a href="#StakingBase.orderWithdraw(address,int256)"><code class="function-signature">orderWithdraw(address _poolStakingAddress, int256 _amount)</code></a></li><li><a href="#StakingBase.claimOrderedWithdraw(address)"><code class="function-signature">claimOrderedWithdraw(address _poolStakingAddress)</code></a></li><li><a href="#StakingBase.setErc20TokenContract(address)"><code class="function-signature">setErc20TokenContract(address _erc20TokenContract)</code></a></li><li><a href="#StakingBase.setCandidateMinStake(uint256)"><code class="function-signature">setCandidateMinStake(uint256 _minStake)</code></a></li><li><a href="#StakingBase.setDelegatorMinStake(uint256)"><code class="function-signature">setDelegatorMinStake(uint256 _minStake)</code></a></li><li><a href="#StakingBase.getPools()"><code class="function-signature">getPools()</code></a></li><li><a href="#StakingBase.getPoolsInactive()"><code class="function-signature">getPoolsInactive()</code></a></li><li><a href="#StakingBase.getPoolsLikelihood()"><code class="function-signature">getPoolsLikelihood()</code></a></li><li><a href="#StakingBase.getPoolsToBeElected()"><code class="function-signature">getPoolsToBeElected()</code></a></li><li><a href="#StakingBase.getPoolsToBeRemoved()"><code class="function-signature">getPoolsToBeRemoved()</code></a></li><li><a href="#StakingBase.areStakeAndWithdrawAllowed()"><code class="function-signature">areStakeAndWithdrawAllowed()</code></a></li><li><a href="#StakingBase.erc20TokenContract()"><code class="function-signature">erc20TokenContract()</code></a></li><li><a href="#StakingBase.getCandidateMinStake()"><code class="function-signature">getCandidateMinStake()</code></a></li><li><a href="#StakingBase.getDelegatorMinStake()"><code class="function-signature">getDelegatorMinStake()</code></a></li><li><a href="#StakingBase.isPoolActive(address)"><code class="function-signature">isPoolActive(address _stakingAddress)</code></a></li><li><a href="#StakingBase.maxWithdrawAllowed(address,address)"><code class="function-signature">maxWithdrawAllowed(address _poolStakingAddress, address _staker)</code></a></li><li><a href="#StakingBase.maxWithdrawOrderAllowed(address,address)"><code class="function-signature">maxWithdrawOrderAllowed(address _poolStakingAddress, address _staker)</code></a></li><li><a href="#StakingBase.onTokenTransfer(address,uint256,bytes)"><code class="function-signature">onTokenTransfer(address, uint256, bytes)</code></a></li><li><a href="#StakingBase.orderedWithdrawAmount(address,address)"><code class="function-signature">orderedWithdrawAmount(address _poolStakingAddress, address _staker)</code></a></li><li><a href="#StakingBase.orderedWithdrawAmountTotal(address)"><code class="function-signature">orderedWithdrawAmountTotal(address _poolStakingAddress)</code></a></li><li><a href="#StakingBase.orderWithdrawEpoch(address,address)"><code class="function-signature">orderWithdrawEpoch(address _poolStakingAddress, address _staker)</code></a></li><li><a href="#StakingBase.stakeAmountTotal(address)"><code class="function-signature">stakeAmountTotal(address _poolStakingAddress)</code></a></li><li><a href="#StakingBase.poolDelegators(address)"><code class="function-signature">poolDelegators(address _poolStakingAddress)</code></a></li><li><a href="#StakingBase.poolDelegatorIndex(address,address)"><code class="function-signature">poolDelegatorIndex(address _poolStakingAddress, address _delegator)</code></a></li><li><a href="#StakingBase.poolDelegatorInactiveIndex(address,address)"><code class="function-signature">poolDelegatorInactiveIndex(address _poolStakingAddress, address _delegator)</code></a></li><li><a href="#StakingBase.poolIndex(address)"><code class="function-signature">poolIndex(address _stakingAddress)</code></a></li><li><a href="#StakingBase.poolInactiveIndex(address)"><code class="function-signature">poolInactiveIndex(address _stakingAddress)</code></a></li><li><a href="#StakingBase.poolToBeElectedIndex(address)"><code class="function-signature">poolToBeElectedIndex(address _stakingAddress)</code></a></li><li><a href="#StakingBase.poolToBeRemovedIndex(address)"><code class="function-signature">poolToBeRemovedIndex(address _stakingAddress)</code></a></li><li><a href="#StakingBase.stakeAmount(address,address)"><code class="function-signature">stakeAmount(address _poolStakingAddress, address _staker)</code></a></li><li><a href="#StakingBase.stakeAmountByCurrentEpoch(address,address)"><code class="function-signature">stakeAmountByCurrentEpoch(address _poolStakingAddress, address _staker)</code></a></li><li><a href="#StakingBase.stakeAmountMinusOrderedWithdraw(address,address)"><code class="function-signature">stakeAmountMinusOrderedWithdraw(address _poolStakingAddress, address _staker)</code></a></li><li><a href="#StakingBase.stakeAmountTotalMinusOrderedWithdraw(address)"><code class="function-signature">stakeAmountTotalMinusOrderedWithdraw(address _poolStakingAddress)</code></a></li><li><a href="#StakingBase.stakingEpoch()"><code class="function-signature">stakingEpoch()</code></a></li><li><a href="#StakingBase.validatorSetContract()"><code class="function-signature">validatorSetContract()</code></a></li><li><a href="#StakingBase._addPoolActive(address,bool)"><code class="function-signature">_addPoolActive(address _stakingAddress, bool _toBeElected)</code></a></li><li><a href="#StakingBase._addPoolInactive(address)"><code class="function-signature">_addPoolInactive(address _stakingAddress)</code></a></li><li><a href="#StakingBase._addPoolToBeElected(address)"><code class="function-signature">_addPoolToBeElected(address _stakingAddress)</code></a></li><li><a href="#StakingBase._addPoolToBeRemoved(address)"><code class="function-signature">_addPoolToBeRemoved(address _stakingAddress)</code></a></li><li><a href="#StakingBase._deletePoolToBeElected(address)"><code class="function-signature">_deletePoolToBeElected(address _stakingAddress)</code></a></li><li><a href="#StakingBase._deletePoolToBeRemoved(address)"><code class="function-signature">_deletePoolToBeRemoved(address _stakingAddress)</code></a></li><li><a href="#StakingBase._removePool(address)"><code class="function-signature">_removePool(address _stakingAddress)</code></a></li><li><a href="#StakingBase._removePoolInactive(address)"><code class="function-signature">_removePoolInactive(address _stakingAddress)</code></a></li><li><a href="#StakingBase._initialize(address,address,address[],uint256,uint256)"><code class="function-signature">_initialize(address _validatorSetContract, address _erc20TokenContract, address[] _initialStakingAddresses, uint256 _delegatorMinStake, uint256 _candidateMinStake)</code></a></li><li><a href="#StakingBase._setOrderWithdrawEpoch(address,address,uint256)"><code class="function-signature">_setOrderWithdrawEpoch(address _poolStakingAddress, address _staker, uint256 _stakingEpoch)</code></a></li><li><a href="#StakingBase._setPoolDelegatorIndex(address,address,uint256)"><code class="function-signature">_setPoolDelegatorIndex(address _poolStakingAddress, address _delegator, uint256 _index)</code></a></li><li><a href="#StakingBase._setPoolDelegatorInactiveIndex(address,address,uint256)"><code class="function-signature">_setPoolDelegatorInactiveIndex(address _poolStakingAddress, address _delegator, uint256 _index)</code></a></li><li><a href="#StakingBase._setPoolIndex(address,uint256)"><code class="function-signature">_setPoolIndex(address _stakingAddress, uint256 _index)</code></a></li><li><a href="#StakingBase._setPoolInactiveIndex(address,uint256)"><code class="function-signature">_setPoolInactiveIndex(address _stakingAddress, uint256 _index)</code></a></li><li><a href="#StakingBase._setPoolToBeElectedIndex(address,uint256)"><code class="function-signature">_setPoolToBeElectedIndex(address _stakingAddress, uint256 _index)</code></a></li><li><a href="#StakingBase._setPoolToBeRemovedIndex(address,uint256)"><code class="function-signature">_setPoolToBeRemovedIndex(address _stakingAddress, uint256 _index)</code></a></li><li><a href="#StakingBase._addPoolDelegator(address,address)"><code class="function-signature">_addPoolDelegator(address _poolStakingAddress, address _delegator)</code></a></li><li><a href="#StakingBase._addPoolDelegatorInactive(address,address)"><code class="function-signature">_addPoolDelegatorInactive(address _poolStakingAddress, address _delegator)</code></a></li><li><a href="#StakingBase._removePoolDelegator(address,address)"><code class="function-signature">_removePoolDelegator(address _poolStakingAddress, address _delegator)</code></a></li><li><a href="#StakingBase._removePoolDelegatorInactive(address,address)"><code class="function-signature">_removePoolDelegatorInactive(address _poolStakingAddress, address _delegator)</code></a></li><li><a href="#StakingBase._setLikelihood(address)"><code class="function-signature">_setLikelihood(address _poolStakingAddress)</code></a></li><li><a href="#StakingBase._setOrderedWithdrawAmount(address,address,uint256)"><code class="function-signature">_setOrderedWithdrawAmount(address _poolStakingAddress, address _staker, uint256 _amount)</code></a></li><li><a href="#StakingBase._setOrderedWithdrawAmountTotal(address,uint256)"><code class="function-signature">_setOrderedWithdrawAmountTotal(address _poolStakingAddress, uint256 _amount)</code></a></li><li><a href="#StakingBase._setStakeAmount(address,address,uint256)"><code class="function-signature">_setStakeAmount(address _poolStakingAddress, address _staker, uint256 _amount)</code></a></li><li><a href="#StakingBase._setStakeAmountByCurrentEpoch(address,address,uint256)"><code class="function-signature">_setStakeAmountByCurrentEpoch(address _poolStakingAddress, address _staker, uint256 _amount)</code></a></li><li><a href="#StakingBase._setStakeAmountTotal(address,uint256)"><code class="function-signature">_setStakeAmountTotal(address _poolStakingAddress, uint256 _amount)</code></a></li><li><a href="#StakingBase._setDelegatorMinStake(uint256)"><code class="function-signature">_setDelegatorMinStake(uint256 _minStake)</code></a></li><li><a href="#StakingBase._setCandidateMinStake(uint256)"><code class="function-signature">_setCandidateMinStake(uint256 _minStake)</code></a></li><li><a href="#StakingBase._stake(address,uint256)"><code class="function-signature">_stake(address _toPoolStakingAddress, uint256 _amount)</code></a></li><li><a href="#StakingBase._stake(address,address,uint256)"><code class="function-signature">_stake(address _poolStakingAddress, address _staker, uint256 _amount)</code></a></li><li><a href="#StakingBase._withdraw(address,address,uint256)"><code class="function-signature">_withdraw(address _poolStakingAddress, address _staker, uint256 _amount)</code></a></li><li><a href="#StakingBase._withdrawCheckPool(address,address)"><code class="function-signature">_withdrawCheckPool(address _poolStakingAddress, address _staker)</code></a></li><li><a href="#StakingBase._getCurrentBlockNumber()"><code class="function-signature">_getCurrentBlockNumber()</code></a></li><li><a href="#StakingBase._getMaxCandidates()"><code class="function-signature">_getMaxCandidates()</code></a></li><li><a href="#StakingBase._isPoolToBeElected(address)"><code class="function-signature">_isPoolToBeElected(address _stakingAddress)</code></a></li><li><a href="#StakingBase._isWithdrawAllowed(address)"><code class="function-signature">_isWithdrawAllowed(address _miningAddress)</code></a></li></ul><span class="contract-index-title">Events</span><ul><li class="inherited"><a href="#StakingBase.Claimed(address,address,uint256,uint256)"><code class="function-signature">Claimed(address fromPoolStakingAddress, address staker, uint256 stakingEpoch, uint256 amount)</code></a></li><li class="inherited"><a href="#StakingBase.Staked(address,address,uint256,uint256)"><code class="function-signature">Staked(address toPoolStakingAddress, address staker, uint256 stakingEpoch, uint256 amount)</code></a></li><li class="inherited"><a href="#StakingBase.StakeMoved(address,address,address,uint256,uint256)"><code class="function-signature">StakeMoved(address fromPoolStakingAddress, address toPoolStakingAddress, address staker, uint256 stakingEpoch, uint256 amount)</code></a></li><li class="inherited"><a href="#StakingBase.WithdrawalOrdered(address,address,uint256,int256)"><code class="function-signature">WithdrawalOrdered(address fromPoolStakingAddress, address staker, uint256 stakingEpoch, int256 amount)</code></a></li><li class="inherited"><a href="#StakingBase.Withdrawn(address,address,uint256,uint256)"><code class="function-signature">Withdrawn(address fromPoolStakingAddress, address staker, uint256 stakingEpoch, uint256 amount)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="StakingBase.clearUnremovableValidator(address)"></a><code class="function-signature">clearUnremovableValidator(address _unremovableStakingAddress)</code></h4>

Adds the `unremovable validator` to either the `poolsToBeElected` or the `poolsToBeRemoved` array
 depending on their own stake in their own pool when they become removable. This allows the
 `ValidatorSet._newValidatorSet` function to recognize the unremovable validator as a regular removable pool.
 Called by the `ValidatorSet.clearUnremovableValidator` function.
 @param _unremovableStakingAddress The staking address of the unremovable validator.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.incrementStakingEpoch()"></a><code class="function-signature">incrementStakingEpoch()</code></h4>

Increments the serial number of the current staking epoch. Called by the `ValidatorSet._newValidatorSet` at
 the last block of the finished staking epoch.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.removePool(address)"></a><code class="function-signature">removePool(address _stakingAddress)</code></h4>

Removes a specified pool from the `pools` array (a list of active pools which can be retrieved by the
 `getPools` getter). Called by the `ValidatorSet._removeMaliciousValidator` or
 the `ValidatorSet._newValidatorSet` function when a pool must be removed by the algorithm.
 @param _stakingAddress The staking address of the pool to be removed.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.removePool()"></a><code class="function-signature">removePool()</code></h4>

Removes the candidate&#x27;s or validator&#x27;s pool from the `pools` array (a list of active pools which
 can be retrieved by the `getPools` getter). When a candidate or validator wants to remove their pool,
 they should call this function from their staking address. A validator cannot remove their pool while
 they are an `unremovable validator`.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.moveStake(address,address,uint256)"></a><code class="function-signature">moveStake(address _fromPoolStakingAddress, address _toPoolStakingAddress, uint256 _amount)</code></h4>

Moves staking tokens from one pool to another. A staker calls this function when they want
 to move their tokens from one pool to another without withdrawing their tokens.
 @param _fromPoolStakingAddress The staking address of the source pool.
 @param _toPoolStakingAddress The staking address of the target pool.
 @param _amount The amount of staking tokens to be moved. The amount cannot exceed the value returned
 by the `maxWithdrawAllowed` getter.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.stake(address,uint256)"></a><code class="function-signature">stake(address _toPoolStakingAddress, uint256 _amount)</code></h4>

Moves the specified amount of staking tokens from the staker&#x27;s address to the staking address of
 the specified pool. A staker calls this function when they want to make a stake into a pool.
 @param _toPoolStakingAddress The staking address of the pool where the tokens should be staked.
 @param _amount The amount of tokens to be staked.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.withdraw(address,uint256)"></a><code class="function-signature">withdraw(address _fromPoolStakingAddress, uint256 _amount)</code></h4>

Moves the specified amount of staking tokens from the staking address of
 the specified pool to the staker&#x27;s address. A staker calls this function when they want to withdraw
 their tokens.
 @param _fromPoolStakingAddress The staking address of the pool from which the tokens should be withdrawn.
 @param _amount The amount of tokens to be withdrawn. The amount cannot exceed the value returned
 by the `maxWithdrawAllowed` getter.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.orderWithdraw(address,int256)"></a><code class="function-signature">orderWithdraw(address _poolStakingAddress, int256 _amount)</code></h4>

Orders a token withdrawal from the staking address of the specified pool to the
 staker&#x27;s address. The requested tokens can be claimed after the current staking epoch is complete using the
 `claimOrderedWithdraw` function.
 @param _poolStakingAddress The staking address of the pool from which the amount will be withdrawn.
 @param _amount The amount to be withdrawn. A positive value means the staker wants to either set or
 increase their withdrawal amount. A negative value means the staker wants to decrease a
 withdrawal amount that was previously set. The amount cannot exceed the value returned by the
 `maxWithdrawOrderAllowed` getter.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.claimOrderedWithdraw(address)"></a><code class="function-signature">claimOrderedWithdraw(address _poolStakingAddress)</code></h4>

Withdraws the staking tokens from the specified pool ordered during the previous staking epochs with the
 `orderWithdraw` function. The ordered amount can be retrieved by the `orderedWithdrawAmount` getter.
 @param _poolStakingAddress The staking address of the pool from which the ordered tokens are withdrawn.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.setErc20TokenContract(address)"></a><code class="function-signature">setErc20TokenContract(address _erc20TokenContract)</code></h4>

Sets (updates) the address of the ERC20/ERC677 staking token contract. Can only be called by the `owner`.
 @param _erc20TokenContract The address of the contract.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.setCandidateMinStake(uint256)"></a><code class="function-signature">setCandidateMinStake(uint256 _minStake)</code></h4>

Sets (updates) the limit of the minimum candidate stake (CANDIDATE_MIN_STAKE).
 Can only be called by the `owner`.
 @param _minStake The value of a new limit in STAKE_UNITs.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.setDelegatorMinStake(uint256)"></a><code class="function-signature">setDelegatorMinStake(uint256 _minStake)</code></h4>

Sets (updates) the limit of minimum delegator stake (DELEGATOR_MIN_STAKE).
 Can only be called by the `owner`.
 @param _minStake The value of a new limit in STAKE_UNITs.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.getPools()"></a><code class="function-signature">getPools() <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>

Returns an array of the current active pools (the staking addresses of candidates and validators).
 The size of the array cannot exceed MAX_CANDIDATES. A pool can be added to this array with the `_addPoolActive`
 function which is called by the `stake` or `orderWithdraw` function. A pool is considered active
 if its address has at least the minimum stake and this stake is not ordered to be withdrawn.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.getPoolsInactive()"></a><code class="function-signature">getPoolsInactive() <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>

Returns an array of the current inactive pools (the staking addresses of former candidates).
 A pool can be added to this array with the `_addPoolInactive` function which is called by `_removePool`.
 A pool is considered inactive if it is banned for some reason, if its address has zero stake, or 
 if its entire stake is ordered to be withdrawn.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.getPoolsLikelihood()"></a><code class="function-signature">getPoolsLikelihood() <span class="return-arrow">→</span> <span class="return-type">int256[],int256</span></code></h4>

Returns the list of probability coefficients of being selected as a validator for each corresponding
 address in the `poolsToBeElected` array (see the `getPoolsToBeElected` getter) and a sum of these coefficients.
 Used by the `ValidatorSet._newValidatorSet` function when randomly selecting new validators at the last
 block of a staking epoch. A pool&#x27;s coefficient is updated every time any staked amount is changed in this pool
 (see the `_setLikelihood` function).
 @return likelihoods The array of the coefficients. The array length is always equal to the length of the
 `poolsToBeElected` array.
 @return sum The sum of the coefficients.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.getPoolsToBeElected()"></a><code class="function-signature">getPoolsToBeElected() <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>

Returns the list of pools (their staking addresses) which will participate in a new validator set
 selection process in the `ValidatorSet._newValidatorSet` function. This is an array of pools
 which will be considered as candidates when forming a new validator set (at the last block of a staking epoch).
 This array is kept updated by the `_addPoolToBeElected` and `_deletePoolToBeElected` functions.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.getPoolsToBeRemoved()"></a><code class="function-signature">getPoolsToBeRemoved() <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>

Returns the list of pools (their staking addresses) which will be removed by the
 `ValidatorSet._newValidatorSet` function from the active `pools` array (at the last block
 of a staking epoch). This array is kept updated by the `_addPoolToBeRemoved`
 and `_deletePoolToBeRemoved` functions. A pool is added to this array when the pool&#x27;s address
 withdraws all of its own staking tokens from the pool, inactivating the pool.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.areStakeAndWithdrawAllowed()"></a><code class="function-signature">areStakeAndWithdrawAllowed() <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Returns a boolean flag indicating whether the stake and withdraw operations are allowed
 at the moment.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.erc20TokenContract()"></a><code class="function-signature">erc20TokenContract() <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>

Returns the address of the ERC20/677 staking token contract.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.getCandidateMinStake()"></a><code class="function-signature">getCandidateMinStake() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the limit of the minimum candidate stake (CANDIDATE_MIN_STAKE).



<h4><a class="anchor" aria-hidden="true" id="StakingBase.getDelegatorMinStake()"></a><code class="function-signature">getDelegatorMinStake() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the limit of the minimum delegator stake (DELEGATOR_MIN_STAKE).



<h4><a class="anchor" aria-hidden="true" id="StakingBase.isPoolActive(address)"></a><code class="function-signature">isPoolActive(address _stakingAddress) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Returns a flag indicating whether a specified address is in the `pools` array.
 See the `getPools` getter.
 @param _stakingAddress The staking address of the pool.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.maxWithdrawAllowed(address,address)"></a><code class="function-signature">maxWithdrawAllowed(address _poolStakingAddress, address _staker) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the maximum amount which can be withdrawn from the specified pool by the specified staker
 at the moment. Used by the `withdraw` function.
 @param _poolStakingAddress The pool staking address from which the withdrawal will be made.
 @param _staker The staker address that is going to withdraw.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.maxWithdrawOrderAllowed(address,address)"></a><code class="function-signature">maxWithdrawOrderAllowed(address _poolStakingAddress, address _staker) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the maximum amount which can be ordered to be withdrawn from the specified pool by the
 specified staker at the moment. Used by the `orderWithdraw` function.
 @param _poolStakingAddress The pool staking address from which the withdrawal will be ordered.
 @param _staker The staker address that is going to order the withdrawal.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.onTokenTransfer(address,uint256,bytes)"></a><code class="function-signature">onTokenTransfer(address, uint256, bytes) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Prevents sending tokens directly to the `Staking` contract address
 by the `ERC677BridgeTokenRewardable.transferAndCall` function.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.orderedWithdrawAmount(address,address)"></a><code class="function-signature">orderedWithdrawAmount(address _poolStakingAddress, address _staker) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the current amount of staking tokens ordered for withdrawal from the specified
 pool by the specified staker. Used by the `orderWithdraw` and `claimOrderedWithdraw` functions.
 @param _poolStakingAddress The pool staking address from which the amount will be withdrawn.
 @param _staker The staker address that ordered the withdrawal.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.orderedWithdrawAmountTotal(address)"></a><code class="function-signature">orderedWithdrawAmountTotal(address _poolStakingAddress) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the current total amount of staking tokens ordered for withdrawal from
 the specified pool by all of its stakers.
 @param _poolStakingAddress The pool staking address from which the amount will be withdrawn.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.orderWithdrawEpoch(address,address)"></a><code class="function-signature">orderWithdrawEpoch(address _poolStakingAddress, address _staker) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the number of the staking epoch during which the specified staker ordered
 the latest withdraw from the specified pool. Used by the `claimOrderedWithdraw` function
 to allow the ordered amount to be claimed only in future staking epochs.
 @param _poolStakingAddress The pool staking address from which the withdrawal will occur.
 @param _staker The staker address that ordered the withdrawal.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.stakeAmountTotal(address)"></a><code class="function-signature">stakeAmountTotal(address _poolStakingAddress) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the total amount of staking tokens currently staked into the specified pool.
 Doesn&#x27;t take into account the ordered amounts to be withdrawn (use the
 `stakeAmountTotalMinusOrderedWithdraw` instead).
 @param _poolStakingAddress The pool staking address.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.poolDelegators(address)"></a><code class="function-signature">poolDelegators(address _poolStakingAddress) <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>

Returns an array of the current active delegators of the specified pool.
 A delegator is considered active if they have staked into the specified
 pool and their stake is not ordered to be withdrawn.
 @param _poolStakingAddress The pool staking address.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.poolDelegatorIndex(address,address)"></a><code class="function-signature">poolDelegatorIndex(address _poolStakingAddress, address _delegator) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the delegator&#x27;s index in the array returned by the `poolDelegators` getter.
 Used by the `_removePoolDelegator` function.
 @param _poolStakingAddress The pool staking address.
 @param _delegator The delegator&#x27;s address.
 @return If the returned value is zero, it may mean the array doesn&#x27;t contain the delegator.
 Check if the delegator is in the array using the `poolDelegators` getter.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.poolDelegatorInactiveIndex(address,address)"></a><code class="function-signature">poolDelegatorInactiveIndex(address _poolStakingAddress, address _delegator) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the delegator&#x27;s index in the `poolDelegatorsInactive` array.
 Used by the `_removePoolDelegatorInactive` function.
 A delegator is considered inactive if they have withdrawn all their tokens from
 the specified pool or their entire stake is ordered to be withdrawn.
 @param _poolStakingAddress The pool staking address for which the inactive delegator&#x27;s index is returned.
 @param _delegator The delegator address.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.poolIndex(address)"></a><code class="function-signature">poolIndex(address _stakingAddress) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the pool&#x27;s index in the array returned by the `getPools` getter.
 Used by the `_removePool` function.
 @param _stakingAddress The pool staking address.
 @return If the returned value is zero, it may mean the array doesn&#x27;t contain the address.
 Check the address is in the array using the `isPoolActive` getter.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.poolInactiveIndex(address)"></a><code class="function-signature">poolInactiveIndex(address _stakingAddress) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the pool&#x27;s index in the array returned by the `getPoolsInactive` getter.
 Used by the `_removePoolInactive` function.
 @param _stakingAddress The pool staking address.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.poolToBeElectedIndex(address)"></a><code class="function-signature">poolToBeElectedIndex(address _stakingAddress) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the pool&#x27;s index in the array returned by the `getPoolsToBeElected` getter.
 Used by the `_deletePoolToBeElected` and `_isPoolToBeElected` functions.
 @param _stakingAddress The pool staking address.
 @return If the returned value is zero, it may mean the array doesn&#x27;t contain the address.
 Check the address is in the array using the `getPoolsToBeElected` getter.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.poolToBeRemovedIndex(address)"></a><code class="function-signature">poolToBeRemovedIndex(address _stakingAddress) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the pool&#x27;s index in the array returned by the `getPoolsToBeRemoved` getter.
 Used by the `_deletePoolToBeRemoved` function.
 @param _stakingAddress The pool staking address.
 @return If the returned value is zero, it may mean the array doesn&#x27;t contain the address.
 Check the address is in the array using the `getPoolsToBeRemoved` getter.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.stakeAmount(address,address)"></a><code class="function-signature">stakeAmount(address _poolStakingAddress, address _staker) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the amount of staking tokens currently staked into the specified pool by the specified staker.
 Doesn&#x27;t take into account the ordered amount to be withdrawn (use the
 `stakeAmountMinusOrderedWithdraw` instead).
 @param _poolStakingAddress The pool staking address.
 @param _staker The staker&#x27;s address.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.stakeAmountByCurrentEpoch(address,address)"></a><code class="function-signature">stakeAmountByCurrentEpoch(address _poolStakingAddress, address _staker) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the amount of staking tokens staked into the specified pool by the specified staker
 during the current staking epoch (see the `stakingEpoch` getter).
 Used by the `stake`, `withdraw`, and `orderWithdraw` functions.
 @param _poolStakingAddress The pool staking address.
 @param _staker The staker&#x27;s address.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.stakeAmountMinusOrderedWithdraw(address,address)"></a><code class="function-signature">stakeAmountMinusOrderedWithdraw(address _poolStakingAddress, address _staker) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the amount of staking tokens currently staked into the specified pool by the specified staker
 taking into account the ordered amount to be withdrawn. See also the `stakeAmount` and `orderedWithdrawAmount`.
 @param _poolStakingAddress The pool staking address.
 @param _staker The staker&#x27;s address.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.stakeAmountTotalMinusOrderedWithdraw(address)"></a><code class="function-signature">stakeAmountTotalMinusOrderedWithdraw(address _poolStakingAddress) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the total amount of staking tokens currently staked into the specified pool taking into account
 the ordered amounts to be withdrawn. See also the `stakeAmountTotal` and `orderedWithdrawAmountTotal` getters.
 @param _poolStakingAddress The pool staking address.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.stakingEpoch()"></a><code class="function-signature">stakingEpoch() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the serial number of the current staking epoch.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.validatorSetContract()"></a><code class="function-signature">validatorSetContract() <span class="return-arrow">→</span> <span class="return-type">contract IValidatorSet</span></code></h4>

Returns the address of the `ValidatorSet` contract.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._addPoolActive(address,bool)"></a><code class="function-signature">_addPoolActive(address _stakingAddress, bool _toBeElected)</code></h4>

Adds the specified staking address to the array of active pools returned by
 the `getPools` getter. Used by the `stake` and `orderWithdraw` functions.
 @param _stakingAddress The pool added to the array of active pools.
 @param _toBeElected The boolean flag which defines whether the specified address should be
 added simultaneously to the `poolsToBeElected` array. See the `getPoolsToBeElected` getter.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._addPoolInactive(address)"></a><code class="function-signature">_addPoolInactive(address _stakingAddress)</code></h4>

Adds the specified staking address to the array of inactive pools returned by
 the `getPoolsInactive` getter. Used by the `_removePool` function.
 @param _stakingAddress The pool added to the array of inactive pools.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._addPoolToBeElected(address)"></a><code class="function-signature">_addPoolToBeElected(address _stakingAddress)</code></h4>

Adds the specified staking address to the array of pools returned by the `getPoolsToBeElected`
 getter. Used by the `_addPoolActive` function. See the `getPoolsToBeElected` getter.
 @param _stakingAddress The pool added to the `poolsToBeElected` array.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._addPoolToBeRemoved(address)"></a><code class="function-signature">_addPoolToBeRemoved(address _stakingAddress)</code></h4>

Adds the specified staking address to the array of pools returned by the `getPoolsToBeRemoved`
 getter. Used by withdrawal functions. See the `getPoolsToBeRemoved` getter.
 @param _stakingAddress The pool added to the `poolsToBeRemoved` array.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._deletePoolToBeElected(address)"></a><code class="function-signature">_deletePoolToBeElected(address _stakingAddress)</code></h4>

Deletes the specified staking address from the array of pools returned by the
 `getPoolsToBeElected` getter. Used by the `_addPoolToBeRemoved` and `_removePool` functions.
 See the `getPoolsToBeElected` getter.
 @param _stakingAddress The pool deleted from the `poolsToBeElected` array.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._deletePoolToBeRemoved(address)"></a><code class="function-signature">_deletePoolToBeRemoved(address _stakingAddress)</code></h4>

Deletes the specified staking address from the array of pools returned by the
 `getPoolsToBeRemoved` getter. Used by the `_addPoolToBeElected` and `_removePool` functions.
 See the `getPoolsToBeRemoved` getter.
 @param _stakingAddress The pool deleted from the `poolsToBeRemoved` array.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._removePool(address)"></a><code class="function-signature">_removePool(address _stakingAddress)</code></h4>

Removes the specified staking address from the array of active pools returned by
 the `getPools` getter. Used by the `removePool` and withdrawal functions.
 @param _stakingAddress The pool removed from the array of active pools.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._removePoolInactive(address)"></a><code class="function-signature">_removePoolInactive(address _stakingAddress)</code></h4>

Removes the specified staking address from the array of inactive pools returned by
 the `getPoolsInactive` getter. Used by the `_addPoolActive` and `_removePool` functions.
 @param _stakingAddress The pool removed from the array of inactive pools.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._initialize(address,address,address[],uint256,uint256)"></a><code class="function-signature">_initialize(address _validatorSetContract, address _erc20TokenContract, address[] _initialStakingAddresses, uint256 _delegatorMinStake, uint256 _candidateMinStake)</code></h4>

Initializes the network parameters on the genesis block. Used by the
 `initialize` function of a child contract.
 @param _validatorSetContract The address of the `ValidatorSet` contract.
 @param _erc20TokenContract The address of the ERC20/677 staking token contract.
 Can be zero and defined later using the `setErc20TokenContract` function.
 @param _initialStakingAddresses The array of initial validators&#x27; staking addresses.
 @param _delegatorMinStake The minimum allowed amount of delegator stake in STAKE_UNITs.
 @param _candidateMinStake The minimum allowed amount of candidate/validator stake in STAKE_UNITs.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._setOrderWithdrawEpoch(address,address,uint256)"></a><code class="function-signature">_setOrderWithdrawEpoch(address _poolStakingAddress, address _staker, uint256 _stakingEpoch)</code></h4>

Sets the number of the staking epoch during which the specified staker ordered
 the latest withdraw from the specified pool. Used by the `orderWithdraw` function
 to allow the ordered amount to be claimed only in future staking epochs.
 See also the `orderWithdrawEpoch` getter.
 @param _poolStakingAddress The pool staking address from which the withdrawal will occur.
 @param _staker The staker&#x27;s address that ordered the withdrawal.
 @param _stakingEpoch The number of the current staking epoch.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._setPoolDelegatorIndex(address,address,uint256)"></a><code class="function-signature">_setPoolDelegatorIndex(address _poolStakingAddress, address _delegator, uint256 _index)</code></h4>

Sets the delegator&#x27;s index in the array returned by the `poolDelegators` getter.
 Used by the `_addPoolDelegator` and `_removePoolDelegator` functions.
 @param _poolStakingAddress The pool staking address.
 @param _delegator The delegator&#x27;s address.
 @param _index The index of the delegator in the `poolDelegators` array.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._setPoolDelegatorInactiveIndex(address,address,uint256)"></a><code class="function-signature">_setPoolDelegatorInactiveIndex(address _poolStakingAddress, address _delegator, uint256 _index)</code></h4>

Sets the delegator&#x27;s index in the `poolDelegatorsInactive` array.
 Used by the `_addPoolDelegatorInactive` and `_removePoolDelegatorInactive` functions.
 @param _poolStakingAddress The pool staking address.
 @param _delegator The delegator&#x27;s address.
 @param _index The index of the delegator in the `poolDelegatorsInactive` array.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._setPoolIndex(address,uint256)"></a><code class="function-signature">_setPoolIndex(address _stakingAddress, uint256 _index)</code></h4>

Sets the index for the specified address which indicates the position of the address in the array
 returned by the `getPools` getter. Used by the `_addPoolActive` and `_removePool` functions.
 @param _stakingAddress The pool staking address.
 @param _index The index value.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._setPoolInactiveIndex(address,uint256)"></a><code class="function-signature">_setPoolInactiveIndex(address _stakingAddress, uint256 _index)</code></h4>

Sets the index for the specified address which indicates the position of the address in the array
 returned by the `getPoolsInactive` getter. Used by the `_addPoolInactive` and `_removePoolInactive` functions.
 @param _stakingAddress The pool staking address.
 @param _index The index value.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._setPoolToBeElectedIndex(address,uint256)"></a><code class="function-signature">_setPoolToBeElectedIndex(address _stakingAddress, uint256 _index)</code></h4>

Sets the index for the specified address which indicates the position of the address in the array
 returned by the `getPoolsToBeElected` getter.
 Used by the `_addPoolToBeElected` and `_deletePoolToBeElected` functions.
 @param _stakingAddress The pool staking address.
 @param _index The index value.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._setPoolToBeRemovedIndex(address,uint256)"></a><code class="function-signature">_setPoolToBeRemovedIndex(address _stakingAddress, uint256 _index)</code></h4>

Sets the index for the specified address which indicates the position of the address in the array
 returned by the `getPoolsToBeRemoved` getter.
 Used by the `_addPoolToBeRemoved` and `_deletePoolToBeRemoved` functions.
 @param _stakingAddress The pool staking address.
 @param _index The index value.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._addPoolDelegator(address,address)"></a><code class="function-signature">_addPoolDelegator(address _poolStakingAddress, address _delegator)</code></h4>

Adds the specified address to the array of the current active delegators of the specified pool.
 Used by the `stake` and `orderWithdraw` functions. See the `poolDelegators` getter.
 @param _poolStakingAddress The pool staking address.
 @param _delegator The delegator&#x27;s address.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._addPoolDelegatorInactive(address,address)"></a><code class="function-signature">_addPoolDelegatorInactive(address _poolStakingAddress, address _delegator)</code></h4>

Adds the specified address to the array of the current inactive delegators of the specified pool.
 Used by the `_removePoolDelegator` function.
 @param _poolStakingAddress The pool staking address.
 @param _delegator The delegator&#x27;s address.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._removePoolDelegator(address,address)"></a><code class="function-signature">_removePoolDelegator(address _poolStakingAddress, address _delegator)</code></h4>

Removes the specified address from the array of the current active delegators of the specified pool.
 Used by the withdrawal functions. See the `poolDelegators` getter.
 @param _poolStakingAddress The pool staking address.
 @param _delegator The delegator&#x27;s address.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._removePoolDelegatorInactive(address,address)"></a><code class="function-signature">_removePoolDelegatorInactive(address _poolStakingAddress, address _delegator)</code></h4>

Removes the specified address from the array of the inactive delegators of the specified pool.
 Used by the `_addPoolDelegator` and `_removePoolDelegator` functions.
 @param _poolStakingAddress The pool staking address.
 @param _delegator The delegator&#x27;s address.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._setLikelihood(address)"></a><code class="function-signature">_setLikelihood(address _poolStakingAddress)</code></h4>

Calculates (updates) the probability of being selected as a validator for the specified pool
 and updates the total sum of probability coefficients. See the `getPoolsLikelihood` getter.
 Used by the staking and withdrawal functions.
 @param _poolStakingAddress The address of the pool for which the probability coefficient must be updated.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._setOrderedWithdrawAmount(address,address,uint256)"></a><code class="function-signature">_setOrderedWithdrawAmount(address _poolStakingAddress, address _staker, uint256 _amount)</code></h4>

Sets the current amount of staking tokens ordered for withdrawal from the specified
 pool by the specified staker. Used by the `orderWithdraw` and `claimOrderedWithdraw` functions.
 @param _poolStakingAddress The pool staking address from which the amount will be withdrawn.
 @param _staker The staker&#x27;s address that ordered the withdrawal.
 @param _amount The amount of staking tokens ordered for withdrawal.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._setOrderedWithdrawAmountTotal(address,uint256)"></a><code class="function-signature">_setOrderedWithdrawAmountTotal(address _poolStakingAddress, uint256 _amount)</code></h4>

Sets the total amount of staking tokens ordered for withdrawal from
 the specified pool by all its stakers.
 @param _poolStakingAddress The pool staking address from which the amount will be withdrawn.
 @param _amount The total amount of staking tokens ordered for withdrawal.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._setStakeAmount(address,address,uint256)"></a><code class="function-signature">_setStakeAmount(address _poolStakingAddress, address _staker, uint256 _amount)</code></h4>

Sets the amount of staking tokens currently staked into the specified pool by the specified staker.
 Used by the `stake`, `withdraw`, and `claimOrderedWithdraw` functions. See the `stakeAmount` getter.
 @param _poolStakingAddress The pool staking address.
 @param _staker The staker&#x27;s address.
 @param _amount The amount of staking tokens.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._setStakeAmountByCurrentEpoch(address,address,uint256)"></a><code class="function-signature">_setStakeAmountByCurrentEpoch(address _poolStakingAddress, address _staker, uint256 _amount)</code></h4>

Sets the amount of staking tokens staked into the specified pool by the specified staker during the
 current staking epoch (see the `stakingEpoch` getter). See also the `stakeAmountByCurrentEpoch` getter.
 Used by the `_stake` and `_withdraw` functions.
 @param _poolStakingAddress The pool staking address.
 @param _staker The staker&#x27;s address.
 @param _amount The amount of staking tokens.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._setStakeAmountTotal(address,uint256)"></a><code class="function-signature">_setStakeAmountTotal(address _poolStakingAddress, uint256 _amount)</code></h4>

Sets the total amount of staking tokens currently staked into the specified pool.
 @param _poolStakingAddress The pool staking address.
 @param _amount The total amount of staking tokens.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._setDelegatorMinStake(uint256)"></a><code class="function-signature">_setDelegatorMinStake(uint256 _minStake)</code></h4>

Sets (updates) the limit of the minimum delegator stake (DELEGATOR_MIN_STAKE).
 Used by the `_initialize` and `setDelegatorMinStake` functions.
 @param _minStake The value of a new limit in STAKE_UNITs.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._setCandidateMinStake(uint256)"></a><code class="function-signature">_setCandidateMinStake(uint256 _minStake)</code></h4>

Sets (updates) the limit of the minimum candidate stake (CANDIDATE_MIN_STAKE).
 Used by the `_initialize` and `setCandidateMinStake` functions.
 @param _minStake The value of a new limit in STAKE_UNITs.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._stake(address,uint256)"></a><code class="function-signature">_stake(address _toPoolStakingAddress, uint256 _amount)</code></h4>

The internal function used by the `stake` and `addPool` functions.
 See the `stake` public function for more details.
 @param _toPoolStakingAddress The staking address of the pool where the tokens should be staked.
 @param _amount The amount of tokens to be staked.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._stake(address,address,uint256)"></a><code class="function-signature">_stake(address _poolStakingAddress, address _staker, uint256 _amount)</code></h4>

The internal function used by the `_stake` and `moveStake` functions.
 See the `stake` public function for more details.
 @param _poolStakingAddress The staking address of the pool where the tokens should be staked.
 @param _staker The staker&#x27;s address.
 @param _amount The amount of tokens to be staked.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._withdraw(address,address,uint256)"></a><code class="function-signature">_withdraw(address _poolStakingAddress, address _staker, uint256 _amount)</code></h4>

The internal function used by the `withdraw` and `moveStake` functions.
 See the `withdraw` public function for more details.
 @param _poolStakingAddress The staking address of the pool from which the tokens should be withdrawn.
 @param _staker The staker&#x27;s address.
 @param _amount The amount of the tokens to be withdrawn.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._withdrawCheckPool(address,address)"></a><code class="function-signature">_withdrawCheckPool(address _poolStakingAddress, address _staker)</code></h4>

The internal function used by the `_withdraw` and `claimOrderedWithdraw` functions.
 Contains a common logic for these functions.
 @param _poolStakingAddress The staking address of the pool from which the tokens are withdrawn.
 @param _staker The staker&#x27;s address.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._getCurrentBlockNumber()"></a><code class="function-signature">_getCurrentBlockNumber() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the current block number. Needed mostly for unit tests.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._getMaxCandidates()"></a><code class="function-signature">_getMaxCandidates() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the max number of candidates (including validators). See the MAX_CANDIDATES constant.
 Needed mostly for unit tests.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._isPoolToBeElected(address)"></a><code class="function-signature">_isPoolToBeElected(address _stakingAddress) <span class="return-arrow">→</span> <span class="return-type">bool,uint256</span></code></h4>

Determines if the specified pool is in the `poolsToBeElected` array. See the `getPoolsToBeElected` getter.
 Used by the `_setLikelihood` function.
 @param _stakingAddress The staking address of the pool.
 @return toBeElected The boolean flag indicating whether the `_stakingAddress` is in the
 `poolsToBeElected` array.
 @return index The position of the item in the `poolsToBeElected` array if `toBeElected` is `true`.



<h4><a class="anchor" aria-hidden="true" id="StakingBase._isWithdrawAllowed(address)"></a><code class="function-signature">_isWithdrawAllowed(address _miningAddress) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Returns `true` if withdrawal from the pool of the specified validator is allowed at the moment.
 Used by all withdrawal functions.
 @param _miningAddress The mining address of the validator&#x27;s pool.





<h4><a class="anchor" aria-hidden="true" id="StakingBase.Claimed(address,address,uint256,uint256)"></a><code class="function-signature">Claimed(address fromPoolStakingAddress, address staker, uint256 stakingEpoch, uint256 amount)</code></h4>

Emitted by the `claimOrderedWithdraw` function to signal the staker withdrew the specified
 amount of requested tokens from the specified pool during the specified staking epoch.
 @param fromPoolStakingAddress The pool from which the `staker` withdrew the `amount`.
 @param staker The address of the staker that withdrew the `amount`.
 @param stakingEpoch The serial number of the staking epoch during which the claim was made.
 @param amount The withdrawal amount.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.Staked(address,address,uint256,uint256)"></a><code class="function-signature">Staked(address toPoolStakingAddress, address staker, uint256 stakingEpoch, uint256 amount)</code></h4>

Emitted by the `stake` function to signal the staker placed a stake of the specified
 amount for the specified pool during the specified staking epoch.
 @param toPoolStakingAddress The pool in which the `staker` placed the stake.
 @param staker The address of the staker that placed the stake.
 @param stakingEpoch The serial number of the staking epoch during which the stake was made.
 @param amount The stake amount.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.StakeMoved(address,address,address,uint256,uint256)"></a><code class="function-signature">StakeMoved(address fromPoolStakingAddress, address toPoolStakingAddress, address staker, uint256 stakingEpoch, uint256 amount)</code></h4>

Emitted by the `moveStake` function to signal the staker moved the specified
 amount of stake from one pool to another during the specified staking epoch.
 @param fromPoolStakingAddress The pool from which the `staker` moved the stake.
 @param toPoolStakingAddress The destination pool where the `staker` moved the stake.
 @param staker The address of the staker who moved the `amount`.
 @param stakingEpoch The serial number of the staking epoch during which the `amount` was moved.
 @param amount The stake amount.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.WithdrawalOrdered(address,address,uint256,int256)"></a><code class="function-signature">WithdrawalOrdered(address fromPoolStakingAddress, address staker, uint256 stakingEpoch, int256 amount)</code></h4>

Emitted by the `orderWithdraw` function to signal the staker ordered the withdrawal of the
 specified amount of their stake from the specified pool during the specified staking epoch.
 @param fromPoolStakingAddress The pool from which the `staker` ordered a withdrawal of the `amount`.
 @param staker The address of the staker that ordered the withdrawal of the `amount`.
 @param stakingEpoch The serial number of the staking epoch during which the order was made.
 @param amount The ordered withdrawal amount. Can be either positive or negative.
 See the `orderWithdraw` function.



<h4><a class="anchor" aria-hidden="true" id="StakingBase.Withdrawn(address,address,uint256,uint256)"></a><code class="function-signature">Withdrawn(address fromPoolStakingAddress, address staker, uint256 stakingEpoch, uint256 amount)</code></h4>

Emitted by the `withdraw` function to signal the staker withdrew the specified
 amount of a stake from the specified pool during the specified staking epoch.
 @param fromPoolStakingAddress The pool from which the `staker` withdrew the `amount`.
 @param staker The address of staker that withdrew the `amount`.
 @param stakingEpoch The serial number of the staking epoch during which the withdrawal was made.
 @param amount The withdrawal amount.



### `ValidatorSetBase`

The base contract for the ValidatorSetAuRa and ValidatorSetHBBFT contracts.

<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#ValidatorSetBase.clearUnremovableValidator()"><code class="function-signature">clearUnremovableValidator()</code></a></li><li><a href="#ValidatorSetBase.emitInitiateChange()"><code class="function-signature">emitInitiateChange()</code></a></li><li><a href="#ValidatorSetBase.finalizeChange()"><code class="function-signature">finalizeChange()</code></a></li><li><a href="#ValidatorSetBase.initialize(address,address,address,address[],address[],bool)"><code class="function-signature">initialize(address _blockRewardContract, address _randomContract, address _stakingContract, address[] _initialMiningAddresses, address[] _initialStakingAddresses, bool _firstValidatorIsUnremovable)</code></a></li><li><a href="#ValidatorSetBase.setStakingAddress(address,address)"><code class="function-signature">setStakingAddress(address _miningAddress, address _stakingAddress)</code></a></li><li><a href="#ValidatorSetBase.banCounter(address)"><code class="function-signature">banCounter(address _miningAddress)</code></a></li><li><a href="#ValidatorSetBase.bannedUntil(address)"><code class="function-signature">bannedUntil(address _miningAddress)</code></a></li><li><a href="#ValidatorSetBase.blockRewardContract()"><code class="function-signature">blockRewardContract()</code></a></li><li><a href="#ValidatorSetBase.changeRequestCount()"><code class="function-signature">changeRequestCount()</code></a></li><li><a href="#ValidatorSetBase.emitInitiateChangeCallable()"><code class="function-signature">emitInitiateChangeCallable()</code></a></li><li><a href="#ValidatorSetBase.getPreviousValidators()"><code class="function-signature">getPreviousValidators()</code></a></li><li><a href="#ValidatorSetBase.getPendingValidators()"><code class="function-signature">getPendingValidators()</code></a></li><li><a href="#ValidatorSetBase.getQueueValidators()"><code class="function-signature">getQueueValidators()</code></a></li><li><a href="#ValidatorSetBase.getValidators()"><code class="function-signature">getValidators()</code></a></li><li><a href="#ValidatorSetBase.initiateChangeAllowed()"><code class="function-signature">initiateChangeAllowed()</code></a></li><li><a href="#ValidatorSetBase.isReportValidatorValid(address)"><code class="function-signature">isReportValidatorValid(address _miningAddress)</code></a></li><li><a href="#ValidatorSetBase.isValidator(address)"><code class="function-signature">isValidator(address _miningAddress)</code></a></li><li><a href="#ValidatorSetBase.isValidatorOnPreviousEpoch(address)"><code class="function-signature">isValidatorOnPreviousEpoch(address _miningAddress)</code></a></li><li><a href="#ValidatorSetBase.isValidatorBanned(address)"><code class="function-signature">isValidatorBanned(address _miningAddress)</code></a></li><li><a href="#ValidatorSetBase.miningByStakingAddress(address)"><code class="function-signature">miningByStakingAddress(address _stakingAddress)</code></a></li><li><a href="#ValidatorSetBase.randomContract()"><code class="function-signature">randomContract()</code></a></li><li><a href="#ValidatorSetBase.stakingByMiningAddress(address)"><code class="function-signature">stakingByMiningAddress(address _miningAddress)</code></a></li><li><a href="#ValidatorSetBase.stakingContract()"><code class="function-signature">stakingContract()</code></a></li><li><a href="#ValidatorSetBase.unremovableValidator()"><code class="function-signature">unremovableValidator()</code></a></li><li><a href="#ValidatorSetBase.validatorCounter(address)"><code class="function-signature">validatorCounter(address _miningAddress)</code></a></li><li><a href="#ValidatorSetBase.validatorIndex(address)"><code class="function-signature">validatorIndex(address _miningAddress)</code></a></li><li><a href="#ValidatorSetBase.validatorSetApplyBlock()"><code class="function-signature">validatorSetApplyBlock()</code></a></li><li><a href="#ValidatorSetBase._applyQueueValidators(address[])"><code class="function-signature">_applyQueueValidators(address[] _queueValidators)</code></a></li><li><a href="#ValidatorSetBase._banValidator(address)"><code class="function-signature">_banValidator(address _miningAddress)</code></a></li><li><a href="#ValidatorSetBase._enqueuePendingValidators(bool)"><code class="function-signature">_enqueuePendingValidators(bool _newStakingEpoch)</code></a></li><li><a href="#ValidatorSetBase._dequeuePendingValidators()"><code class="function-signature">_dequeuePendingValidators()</code></a></li><li><a href="#ValidatorSetBase._incrementChangeRequestCount()"><code class="function-signature">_incrementChangeRequestCount()</code></a></li><li><a href="#ValidatorSetBase._newValidatorSet()"><code class="function-signature">_newValidatorSet()</code></a></li><li><a href="#ValidatorSetBase._removeMaliciousValidator(address)"><code class="function-signature">_removeMaliciousValidator(address _miningAddress)</code></a></li><li><a href="#ValidatorSetBase._setInitiateChangeAllowed(bool)"><code class="function-signature">_setInitiateChangeAllowed(bool _allowed)</code></a></li><li><a href="#ValidatorSetBase._setIsValidator(address,bool)"><code class="function-signature">_setIsValidator(address _miningAddress, bool _isValidator)</code></a></li><li><a href="#ValidatorSetBase._setIsValidatorOnPreviousEpoch(address,bool)"><code class="function-signature">_setIsValidatorOnPreviousEpoch(address _miningAddress, bool _isValidator)</code></a></li><li><a href="#ValidatorSetBase._setPendingValidators(contract IStaking,address[],address)"><code class="function-signature">_setPendingValidators(contract IStaking _stakingContract, address[] _stakingAddresses, address _unremovableStakingAddress)</code></a></li><li><a href="#ValidatorSetBase._setQueueValidators(address[],bool)"><code class="function-signature">_setQueueValidators(address[] _miningAddresses, bool _newStakingEpoch)</code></a></li><li><a href="#ValidatorSetBase._setStakingAddress(address,address)"><code class="function-signature">_setStakingAddress(address _miningAddress, address _stakingAddress)</code></a></li><li><a href="#ValidatorSetBase._setUnremovableValidator(address)"><code class="function-signature">_setUnremovableValidator(address _stakingAddress)</code></a></li><li><a href="#ValidatorSetBase._setValidatorIndex(address,uint256)"><code class="function-signature">_setValidatorIndex(address _miningAddress, uint256 _index)</code></a></li><li><a href="#ValidatorSetBase._setValidatorSetApplyBlock(uint256)"><code class="function-signature">_setValidatorSetApplyBlock(uint256 _blockNumber)</code></a></li><li><a href="#ValidatorSetBase._banStart()"><code class="function-signature">_banStart()</code></a></li><li><a href="#ValidatorSetBase._banUntil()"><code class="function-signature">_banUntil()</code></a></li><li><a href="#ValidatorSetBase._getCurrentBlockNumber()"><code class="function-signature">_getCurrentBlockNumber()</code></a></li><li><a href="#ValidatorSetBase._getRandomIndex(int256[],int256,uint256)"><code class="function-signature">_getRandomIndex(int256[] _likelihood, int256 _likelihoodSum, uint256 _randomNumber)</code></a></li><li class="inherited"><a href="interfaces#IValidatorSet.newValidatorSet()"><code class="function-signature">newValidatorSet()</code></a></li><li class="inherited"><a href="interfaces#IValidatorSet.MAX_VALIDATORS()"><code class="function-signature">MAX_VALIDATORS()</code></a></li></ul><span class="contract-index-title">Events</span><ul><li class="inherited"><a href="#ValidatorSetBase.InitiateChange(bytes32,address[])"><code class="function-signature">InitiateChange(bytes32 parentHash, address[] newSet)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.clearUnremovableValidator()"></a><code class="function-signature">clearUnremovableValidator()</code></h4>

Makes the non-removable validator removable. Can only be called by the staking address of the
 non-removable validator or by the `owner`.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.emitInitiateChange()"></a><code class="function-signature">emitInitiateChange()</code></h4>

Emits the `InitiateChange` event to pass a new validator set to the validator nodes.
 Called automatically by one of the current validator&#x27;s nodes when the `emitInitiateChangeCallable` getter
 returns `true` (when some validator needs to be removed as malicious or the validator set needs to be
 updated at the beginning of a new staking epoch). The new validator set is passed to the validator nodes
 through the `InitiateChange` event and saved for later use by the `finalizeChange` function.
 See https://wiki.parity.io/Validator-Set.html for more info about the `InitiateChange` event.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.finalizeChange()"></a><code class="function-signature">finalizeChange()</code></h4>

Called by the system when an initiated validator set change reaches finality and is activated.
 Only valid when msg.sender == SUPER_USER (EIP96, 2**160 - 2). Stores a new validator set saved
 before by the `emitInitiateChange` function and passed through the `InitiateChange` event.
 After this function is called, the `getValidators` getter returns the new validator set.
 If this function finalizes a new validator set formed by the `newValidatorSet` function,
 an old validator set is also stored and can be read by the `getPreviousValidators` getter.
 The `finalizeChange` is only called once for each `InitiateChange` event emitted. The next `InitiateChange`
 event is not emitted until the previous one is not yet finalized by the `finalizeChange`
 (this is achieved by the queue, `emitInitiateChange` function, and `initiateChangeAllowed` boolean flag -
 see the `_setInitiateChangeAllowed` function).



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.initialize(address,address,address,address[],address[],bool)"></a><code class="function-signature">initialize(address _blockRewardContract, address _randomContract, address _stakingContract, address[] _initialMiningAddresses, address[] _initialStakingAddresses, bool _firstValidatorIsUnremovable)</code></h4>

Initializes the network parameters on the genesis block. Used by the
 constructor of the `InitializerAuRa` or `InitializerHBBFT` contract.
 @param _blockRewardContract The address of the `BlockReward` contract.
 @param _randomContract The address of the `Random` contract.
 @param _stakingContract The address of the `Staking` contract.
 @param _initialMiningAddresses The array of initial validators&#x27; mining addresses.
 @param _initialStakingAddresses The array of initial validators&#x27; staking addresses.
 @param _firstValidatorIsUnremovable The boolean flag defining whether the first validator in the
 `_initialMiningAddresses/_initialStakingAddresses` array is non-removable.
 Must be `false` for a production network.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.setStakingAddress(address,address)"></a><code class="function-signature">setStakingAddress(address _miningAddress, address _stakingAddress)</code></h4>

Binds a mining address to the specified staking address. Called by the `Staking.addPool` function
 when a user wants to become a candidate and create a pool.
 See also the `miningByStakingAddress` and `stakingByMiningAddress` getters.
 @param _miningAddress The mining address of the newly created pool. Cannot be equal to the `_stakingAddress`.
 @param _stakingAddress The staking address of the newly created pool. Cannot be equal to the `_miningAddress`.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.banCounter(address)"></a><code class="function-signature">banCounter(address _miningAddress) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns how many times a given mining address was banned.
 @param _miningAddress The mining address of a candidate or validator.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.bannedUntil(address)"></a><code class="function-signature">bannedUntil(address _miningAddress) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the block number or unix timestamp (depending on the consensus algorithm)
 when the ban will be lifted for the specified mining address.
 @param _miningAddress The mining address of a participant.
 @return The block number (for AuRa) or unix timestamp (for HBBFT) from which the ban will be lifted for the
 specified address.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.blockRewardContract()"></a><code class="function-signature">blockRewardContract() <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>

Returns the address of the `BlockReward` contract.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.changeRequestCount()"></a><code class="function-signature">changeRequestCount() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the serial number of a validator set change request. The counter is incremented
 by the `_incrementChangeRequestCount` function every time a validator set needs to be changed.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.emitInitiateChangeCallable()"></a><code class="function-signature">emitInitiateChangeCallable() <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Returns a boolean flag indicating whether the `emitInitiateChange` function can be called
 at the moment. Used by a validator&#x27;s node and `TxPermission` contract (to deny dummy calling).



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.getPreviousValidators()"></a><code class="function-signature">getPreviousValidators() <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>

Returns the validator set (validators&#x27; mining addresses array) which was active
 at the end of the previous staking epoch. The array is stored by the `finalizeChange` function
 when a new staking epoch&#x27;s validator set is finalized.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.getPendingValidators()"></a><code class="function-signature">getPendingValidators() <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>

Returns the current array of validators which is not yet finalized by the
 `finalizeChange` function. The pending array is changed when a validator is removed as malicious
 or the validator set is updated at the beginning of a new staking epoch (see the `_newValidatorSet` function).
 Every time the pending array is updated, it is enqueued by the `_enqueuePendingValidators` and then
 dequeued by the `emitInitiateChange` function which emits the `InitiateChange` event to all
 validator nodes.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.getQueueValidators()"></a><code class="function-signature">getQueueValidators() <span class="return-arrow">→</span> <span class="return-type">address[],bool</span></code></h4>

Returns a validator set to be finalized by the `finalizeChange` function.
 Used by the `finalizeChange` function.
 @param miningAddresses An array set by the `emitInitiateChange` function.
 @param newStakingEpoch A boolean flag indicating whether the `miningAddresses` array was formed by the
 `_newValidatorSet` function. The `finalizeChange` function logic depends on this flag.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.getValidators()"></a><code class="function-signature">getValidators() <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>

Returns the current validator set (an array of mining addresses)
 which always matches the validator set in the Parity engine.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.initiateChangeAllowed()"></a><code class="function-signature">initiateChangeAllowed() <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Returns a boolean flag indicating whether the `emitInitiateChange` can be called at the moment.
 Used by the `emitInitiateChangeCallable` getter. This flag is set to `false` by the `emitInitiateChange`
 and set to `true` by the `finalizeChange` function. When the `InitiateChange` event is emitted by
 `emitInitiateChange`, the next `emitInitiateChange` call is not possible until the previous call is
 finalized by the `finalizeChange` function.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.isReportValidatorValid(address)"></a><code class="function-signature">isReportValidatorValid(address _miningAddress) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Returns a boolean flag indicating whether the specified validator (mining address)
 can call the `reportMalicious` function or whether the specified validator (mining address)
 can be reported as malicious. This function also allows a validator to call the `reportMalicious`
 function several blocks after ceasing to be a validator. This is possible if a
 validator did not have the opportunity to call the `reportMalicious` function prior to the
 engine calling the `finalizeChange` function.
 @param _miningAddress The validator&#x27;s mining address.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.isValidator(address)"></a><code class="function-signature">isValidator(address _miningAddress) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Returns a boolean flag indicating whether the specified mining address is in the current validator set.
 See the `getValidators` getter.
 @param _miningAddress The mining address.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.isValidatorOnPreviousEpoch(address)"></a><code class="function-signature">isValidatorOnPreviousEpoch(address _miningAddress) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Returns a boolean flag indicating whether the specified mining address was a validator at the end of
 the previous staking epoch. See the `getPreviousValidators` getter.
 @param _miningAddress The mining address.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.isValidatorBanned(address)"></a><code class="function-signature">isValidatorBanned(address _miningAddress) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Returns a boolean flag indicating whether the specified mining address is currently banned.
 A validator can be banned when they misbehave (see the `_banValidator` function).
 @param _miningAddress The mining address.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.miningByStakingAddress(address)"></a><code class="function-signature">miningByStakingAddress(address _stakingAddress) <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>

Returns a mining address bound to a specified staking address.
 See the `_setStakingAddress` function.
 @param _stakingAddress The staking address for which the function must return the corresponding mining address.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.randomContract()"></a><code class="function-signature">randomContract() <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>

Returns the `Random` contract address.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.stakingByMiningAddress(address)"></a><code class="function-signature">stakingByMiningAddress(address _miningAddress) <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>

Returns a staking address bound to a specified mining address.
 See the `_setStakingAddress` function.
 @param _miningAddress The mining address for which the function must return the corresponding staking address.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.stakingContract()"></a><code class="function-signature">stakingContract() <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>

Returns the `Staking` contract address.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.unremovableValidator()"></a><code class="function-signature">unremovableValidator() <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>

Returns the staking address of the non-removable validator.
 Returns zero if a non-removable validator is not defined.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.validatorCounter(address)"></a><code class="function-signature">validatorCounter(address _miningAddress) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns how many times the given address has become a validator.
 @param _miningAddress The mining address.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.validatorIndex(address)"></a><code class="function-signature">validatorIndex(address _miningAddress) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the index of the specified validator in the current validator set
 returned by the `getValidators` getter.
 @param _miningAddress The mining address the index is returned for.
 @return If the returned value is zero, it may mean the array doesn&#x27;t contain the address.
 Check the address is in the current validator set using the `isValidator` getter.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.validatorSetApplyBlock()"></a><code class="function-signature">validatorSetApplyBlock() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the block number when the `finalizeChange` function was called to apply
 the current validator set formed by the `_newValidatorSet` function. If it returns zero,
 it means the `_newValidatorSet` function has already been called (a new staking epoch has been started),
 but the new staking epoch&#x27;s validator set hasn&#x27;t yet been finalized by the `finalizeChange` function.
 See the `_setValidatorSetApplyBlock` function which is called by the `finalizeChange` and
 `_newValidatorSet` functions.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase._applyQueueValidators(address[])"></a><code class="function-signature">_applyQueueValidators(address[] _queueValidators)</code></h4>

Sets a new validator set returned by the `getValidators` getter.
 Called by the `finalizeChange` function.
 @param _queueValidators An array of new validators (their mining addresses).



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase._banValidator(address)"></a><code class="function-signature">_banValidator(address _miningAddress)</code></h4>

Sets the future block number or unix timestamp (depending on the consensus algorithm)
 until which the specified mining address is banned. Updates the banning statistics.
 Called by the `_removeMaliciousValidator` function.
 @param _miningAddress The banned mining address.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase._enqueuePendingValidators(bool)"></a><code class="function-signature">_enqueuePendingValidators(bool _newStakingEpoch)</code></h4>

Enqueues the pending validator set which is returned by the `getPendingValidators` getter
 to be dequeued later by the `emitInitiateChange` function. Called when a validator is removed
 from the set as malicious or when a new validator set is formed by the `_newValidatorSet` function.
 @param _newStakingEpoch A boolean flag defining whether the pending validator set was formed by the
 `_newValidatorSet` function. The `finalizeChange` function logic depends on this flag.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase._dequeuePendingValidators()"></a><code class="function-signature">_dequeuePendingValidators() <span class="return-arrow">→</span> <span class="return-type">address[],bool</span></code></h4>

Dequeues the pending validator set to pass it to the `InitiateChange` event
 (and then to the `finalizeChange` function). Called by the `emitInitiateChange` function.
 @param newSet An array of mining addresses.
 @param newStakingEpoch A boolean flag indicating whether the `newSet` array was formed by the
 `_newValidatorSet` function. The `finalizeChange` function logic depends on this flag.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase._incrementChangeRequestCount()"></a><code class="function-signature">_incrementChangeRequestCount()</code></h4>

Increments the serial number of a validator set changing request. The counter is incremented
 every time a validator set needs to be changed.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase._newValidatorSet()"></a><code class="function-signature">_newValidatorSet() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

An internal function implementing the logic which forms a new validator set. If the number of active pools
 is greater than MAX_VALIDATORS, the logic chooses the validators randomly using a random seed generated and
 stored by the `Random` contract.
 This function is called by the `newValidatorSet` function of a child contract.
 @return The number of pools ready to be elected (see the `Staking.getPoolsToBeElected` function).



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase._removeMaliciousValidator(address)"></a><code class="function-signature">_removeMaliciousValidator(address _miningAddress) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>

Removes the specified validator as malicious. Used by a child contract.
 @param _miningAddress The removed validator mining address.
 @return Returns `true` if the specified validator has been removed from the pending validator set.
 Otherwise returns `false` (if the specified validator was already removed).



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase._setInitiateChangeAllowed(bool)"></a><code class="function-signature">_setInitiateChangeAllowed(bool _allowed)</code></h4>

Sets a boolean flag defining whether the `emitInitiateChange` can be called.
 Called by the `emitInitiateChange` and `finalizeChange` functions.
 See the `initiateChangeAllowed` getter.
 @param _allowed The boolean flag.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase._setIsValidator(address,bool)"></a><code class="function-signature">_setIsValidator(address _miningAddress, bool _isValidator)</code></h4>

Sets a boolean flag defining whether the specified mining address is a validator
 (whether it is existed in the array returned by the `getValidators` getter).
 See the `_applyQueueValidators` function and `isValidator`/`getValidators` getters.
 @param _miningAddress The mining address.
 @param _isValidator The boolean flag.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase._setIsValidatorOnPreviousEpoch(address,bool)"></a><code class="function-signature">_setIsValidatorOnPreviousEpoch(address _miningAddress, bool _isValidator)</code></h4>

Sets a boolean flag indicating whether the specified mining address was a validator at the end of
 the previous staking epoch. See the `getPreviousValidators` and `isValidatorOnPreviousEpoch` getters.
 @param _miningAddress The mining address.
 @param _isValidator The boolean flag.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase._setPendingValidators(contract IStaking,address[],address)"></a><code class="function-signature">_setPendingValidators(contract IStaking _stakingContract, address[] _stakingAddresses, address _unremovableStakingAddress)</code></h4>

Sets a new validator set as a pending (which is not yet finalized by the `finalizeChange` function).
 Removes the pools in the `poolsToBeRemoved` array (see the `Staking.getPoolsToBeRemoved` function).
 Called by the `_newValidatorSet` function.
 @param _stakingContract The `Staking` contract address.
 @param _stakingAddresses The array of the new validators&#x27; staking addresses.
 @param _unremovableStakingAddress The staking address of a non-removable validator.
 See the `unremovableValidator` getter.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase._setQueueValidators(address[],bool)"></a><code class="function-signature">_setQueueValidators(address[] _miningAddresses, bool _newStakingEpoch)</code></h4>

Sets a validator set for the `finalizeChange` function.
 Called by the `emitInitiateChange` function.
 @param _miningAddresses An array of the new validator set mining addresses.
 @param _newStakingEpoch A boolean flag indicating whether the `_miningAddresses` array was formed by the
 `_newValidatorSet` function. The `finalizeChange` function logic depends on this flag.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase._setStakingAddress(address,address)"></a><code class="function-signature">_setStakingAddress(address _miningAddress, address _stakingAddress)</code></h4>

Binds a mining address to the specified staking address. Used by the `setStakingAddress` function.
 See also the `miningByStakingAddress` and `stakingByMiningAddress` getters.
 @param _miningAddress The mining address of a newly created pool. Cannot be equal to the `_stakingAddress`.
 @param _stakingAddress The staking address of a newly created pool. Cannot be equal to the `_miningAddress`.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase._setUnremovableValidator(address)"></a><code class="function-signature">_setUnremovableValidator(address _stakingAddress)</code></h4>

Sets the staking address of a non-removable validator.
 Used by the `initialize` and `clearUnremovableValidator` functions.
 @param _stakingAddress The staking address of a non-removable validator.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase._setValidatorIndex(address,uint256)"></a><code class="function-signature">_setValidatorIndex(address _miningAddress, uint256 _index)</code></h4>

Stores the index of the specified validator in the current validator set
 returned by the `getValidators` getter. Used by the `_applyQueueValidators` function.
 @param _miningAddress The mining address the index is saved for.
 @param _index The index value.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase._setValidatorSetApplyBlock(uint256)"></a><code class="function-signature">_setValidatorSetApplyBlock(uint256 _blockNumber)</code></h4>

Sets the block number at which the `finalizeChange` function was called to apply
 the current validator set formed by the `_newValidatorSet` function.
 Called by the `finalizeChange` and `_newValidatorSet` functions.
 @param _blockNumber The current block number. Set to zero when calling with `_newValidatorSet`.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase._banStart()"></a><code class="function-signature">_banStart() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the current block number or unix timestamp (depending on the consensus algorithm).
 Used by the `isValidatorBanned`, `_banUntil`, and `_banValidator` functions.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase._banUntil()"></a><code class="function-signature">_banUntil() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the future block number or unix timestamp (depending on the consensus algorithm)
 until which a validator is banned.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase._getCurrentBlockNumber()"></a><code class="function-signature">_getCurrentBlockNumber() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns the current block number. Needed mostly for unit tests.



<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase._getRandomIndex(int256[],int256,uint256)"></a><code class="function-signature">_getRandomIndex(int256[] _likelihood, int256 _likelihoodSum, uint256 _randomNumber) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>

Returns an index of a pool in the `poolsToBeElected` array (see the `Staking.getPoolsToBeElected` getter)
 by a random number and the corresponding probability coefficients.
 @param _likelihood An array of probability coefficients.
 @param _likelihoodSum A sum of probability coefficients.
 @param _randomNumber A random number.





<h4><a class="anchor" aria-hidden="true" id="ValidatorSetBase.InitiateChange(bytes32,address[])"></a><code class="function-signature">InitiateChange(bytes32 parentHash, address[] newSet)</code></h4>

Emitted by the `emitInitiateChange` function when a new validator set
 needs to be applied in the Parity engine. See https://wiki.parity.io/Validator-Set.html
 @param parentHash Should be the parent block hash, otherwise the signal won&#x27;t be recognized.
 @param newSet An array of new validators (their mining addresses).



</div>