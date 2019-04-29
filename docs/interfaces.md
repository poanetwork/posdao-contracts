---
title: Interfaces
---

<div class="contracts">

## Contracts

### `IBlockReward`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#IBlockReward.DELEGATORS_ALIQUOT()"><code class="function-signature">DELEGATORS_ALIQUOT()</code></a></li><li><a href="#IBlockReward.isRewarding()"><code class="function-signature">isRewarding()</code></a></li><li><a href="#IBlockReward.isSnapshotting()"><code class="function-signature">isSnapshotting()</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="IBlockReward.DELEGATORS_ALIQUOT()"></a><code class="function-signature">DELEGATORS_ALIQUOT() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IBlockReward.isRewarding()"></a><code class="function-signature">isRewarding() <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IBlockReward.isSnapshotting()"></a><code class="function-signature">isSnapshotting() <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>







### `ICertifier`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#ICertifier.initialize(address)"><code class="function-signature">initialize(address)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="ICertifier.initialize(address)"></a><code class="function-signature">initialize(address)</code></h4>







### `IERC20Minting`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#IERC20Minting.mintReward(address[],uint256[])"><code class="function-signature">mintReward(address[] _receivers, uint256[] _rewards)</code></a></li><li><a href="#IERC20Minting.stake(address,uint256)"><code class="function-signature">stake(address _staker, uint256 _amount)</code></a></li><li><a href="#IERC20Minting.withdraw(address,uint256)"><code class="function-signature">withdraw(address _staker, uint256 _amount)</code></a></li><li><a href="#IERC20Minting.balanceOf(address)"><code class="function-signature">balanceOf(address)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="IERC20Minting.mintReward(address[],uint256[])"></a><code class="function-signature">mintReward(address[] _receivers, uint256[] _rewards)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="IERC20Minting.stake(address,uint256)"></a><code class="function-signature">stake(address _staker, uint256 _amount)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="IERC20Minting.withdraw(address,uint256)"></a><code class="function-signature">withdraw(address _staker, uint256 _amount)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="IERC20Minting.balanceOf(address)"></a><code class="function-signature">balanceOf(address) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>







### `IEternalStorageProxy`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#IEternalStorageProxy.upgradeTo(address)"><code class="function-signature">upgradeTo(address)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="IEternalStorageProxy.upgradeTo(address)"></a><code class="function-signature">upgradeTo(address) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>







### `IMetadataRegistry`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#IMetadataRegistry.getData(bytes32,string)"><code class="function-signature">getData(bytes32 _name, string _key)</code></a></li><li><a href="#IMetadataRegistry.getAddress(bytes32,string)"><code class="function-signature">getAddress(bytes32 _name, string _key)</code></a></li><li><a href="#IMetadataRegistry.getUint(bytes32,string)"><code class="function-signature">getUint(bytes32 _name, string _key)</code></a></li></ul><span class="contract-index-title">Events</span><ul><li class="inherited"><a href="#IMetadataRegistry.DataChanged(bytes32,string,string)"><code class="function-signature">DataChanged(bytes32 name, string key, string plainKey)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="IMetadataRegistry.getData(bytes32,string)"></a><code class="function-signature">getData(bytes32 _name, string _key) <span class="return-arrow">→</span> <span class="return-type">bytes32</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IMetadataRegistry.getAddress(bytes32,string)"></a><code class="function-signature">getAddress(bytes32 _name, string _key) <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IMetadataRegistry.getUint(bytes32,string)"></a><code class="function-signature">getUint(bytes32 _name, string _key) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>







<h4><a class="anchor" aria-hidden="true" id="IMetadataRegistry.DataChanged(bytes32,string,string)"></a><code class="function-signature">DataChanged(bytes32 name, string key, string plainKey)</code></h4>





### `IOwnerRegistry`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#IOwnerRegistry.getOwner(bytes32)"><code class="function-signature">getOwner(bytes32 _name)</code></a></li></ul><span class="contract-index-title">Events</span><ul><li class="inherited"><a href="#IOwnerRegistry.Reserved(bytes32,address)"><code class="function-signature">Reserved(bytes32 name, address owner)</code></a></li><li class="inherited"><a href="#IOwnerRegistry.Transferred(bytes32,address,address)"><code class="function-signature">Transferred(bytes32 name, address oldOwner, address newOwner)</code></a></li><li class="inherited"><a href="#IOwnerRegistry.Dropped(bytes32,address)"><code class="function-signature">Dropped(bytes32 name, address owner)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="IOwnerRegistry.getOwner(bytes32)"></a><code class="function-signature">getOwner(bytes32 _name) <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>







<h4><a class="anchor" aria-hidden="true" id="IOwnerRegistry.Reserved(bytes32,address)"></a><code class="function-signature">Reserved(bytes32 name, address owner)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="IOwnerRegistry.Transferred(bytes32,address,address)"></a><code class="function-signature">Transferred(bytes32 name, address oldOwner, address newOwner)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="IOwnerRegistry.Dropped(bytes32,address)"></a><code class="function-signature">Dropped(bytes32 name, address owner)</code></h4>





### `IRandom`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#IRandom.getCurrentSeed()"><code class="function-signature">getCurrentSeed()</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="IRandom.getCurrentSeed()"></a><code class="function-signature">getCurrentSeed() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>







### `IRandomAuRa`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#IRandomAuRa.initialize(uint256)"><code class="function-signature">initialize(uint256)</code></a></li><li><a href="#IRandomAuRa.onFinishCollectRound()"><code class="function-signature">onFinishCollectRound()</code></a></li><li><a href="#IRandomAuRa.commitHashCallable(address,bytes32)"><code class="function-signature">commitHashCallable(address, bytes32)</code></a></li><li><a href="#IRandomAuRa.revealSecretCallable(address,uint256)"><code class="function-signature">revealSecretCallable(address, uint256)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="IRandomAuRa.initialize(uint256)"></a><code class="function-signature">initialize(uint256)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="IRandomAuRa.onFinishCollectRound()"></a><code class="function-signature">onFinishCollectRound()</code></h4>





<h4><a class="anchor" aria-hidden="true" id="IRandomAuRa.commitHashCallable(address,bytes32)"></a><code class="function-signature">commitHashCallable(address, bytes32) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IRandomAuRa.revealSecretCallable(address,uint256)"></a><code class="function-signature">revealSecretCallable(address, uint256) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>







### `IReverseRegistry`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#IReverseRegistry.hasReverse(bytes32)"><code class="function-signature">hasReverse(bytes32 _name)</code></a></li><li><a href="#IReverseRegistry.getReverse(bytes32)"><code class="function-signature">getReverse(bytes32 _name)</code></a></li><li><a href="#IReverseRegistry.canReverse(address)"><code class="function-signature">canReverse(address _data)</code></a></li><li><a href="#IReverseRegistry.reverse(address)"><code class="function-signature">reverse(address _data)</code></a></li></ul><span class="contract-index-title">Events</span><ul><li class="inherited"><a href="#IReverseRegistry.ReverseConfirmed(string,address)"><code class="function-signature">ReverseConfirmed(string name, address reverse)</code></a></li><li class="inherited"><a href="#IReverseRegistry.ReverseRemoved(string,address)"><code class="function-signature">ReverseRemoved(string name, address reverse)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="IReverseRegistry.hasReverse(bytes32)"></a><code class="function-signature">hasReverse(bytes32 _name) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IReverseRegistry.getReverse(bytes32)"></a><code class="function-signature">getReverse(bytes32 _name) <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IReverseRegistry.canReverse(address)"></a><code class="function-signature">canReverse(address _data) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IReverseRegistry.reverse(address)"></a><code class="function-signature">reverse(address _data) <span class="return-arrow">→</span> <span class="return-type">string</span></code></h4>







<h4><a class="anchor" aria-hidden="true" id="IReverseRegistry.ReverseConfirmed(string,address)"></a><code class="function-signature">ReverseConfirmed(string name, address reverse)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="IReverseRegistry.ReverseRemoved(string,address)"></a><code class="function-signature">ReverseRemoved(string name, address reverse)</code></h4>





### `IStaking`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#IStaking.clearUnremovableValidator(address)"><code class="function-signature">clearUnremovableValidator(address)</code></a></li><li><a href="#IStaking.incrementStakingEpoch()"><code class="function-signature">incrementStakingEpoch()</code></a></li><li><a href="#IStaking.removePool(address)"><code class="function-signature">removePool(address)</code></a></li><li><a href="#IStaking.erc20TokenContract()"><code class="function-signature">erc20TokenContract()</code></a></li><li><a href="#IStaking.getPoolsLikelihood()"><code class="function-signature">getPoolsLikelihood()</code></a></li><li><a href="#IStaking.getPoolsToBeElected()"><code class="function-signature">getPoolsToBeElected()</code></a></li><li><a href="#IStaking.getPoolsToBeRemoved()"><code class="function-signature">getPoolsToBeRemoved()</code></a></li><li><a href="#IStaking.poolDelegators(address)"><code class="function-signature">poolDelegators(address)</code></a></li><li><a href="#IStaking.stakeAmountMinusOrderedWithdraw(address,address)"><code class="function-signature">stakeAmountMinusOrderedWithdraw(address, address)</code></a></li><li><a href="#IStaking.stakeAmountTotalMinusOrderedWithdraw(address)"><code class="function-signature">stakeAmountTotalMinusOrderedWithdraw(address)</code></a></li><li><a href="#IStaking.stakingEpoch()"><code class="function-signature">stakingEpoch()</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="IStaking.clearUnremovableValidator(address)"></a><code class="function-signature">clearUnremovableValidator(address)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="IStaking.incrementStakingEpoch()"></a><code class="function-signature">incrementStakingEpoch()</code></h4>





<h4><a class="anchor" aria-hidden="true" id="IStaking.removePool(address)"></a><code class="function-signature">removePool(address)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="IStaking.erc20TokenContract()"></a><code class="function-signature">erc20TokenContract() <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IStaking.getPoolsLikelihood()"></a><code class="function-signature">getPoolsLikelihood() <span class="return-arrow">→</span> <span class="return-type">int256[],int256</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IStaking.getPoolsToBeElected()"></a><code class="function-signature">getPoolsToBeElected() <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IStaking.getPoolsToBeRemoved()"></a><code class="function-signature">getPoolsToBeRemoved() <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IStaking.poolDelegators(address)"></a><code class="function-signature">poolDelegators(address) <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IStaking.stakeAmountMinusOrderedWithdraw(address,address)"></a><code class="function-signature">stakeAmountMinusOrderedWithdraw(address, address) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IStaking.stakeAmountTotalMinusOrderedWithdraw(address)"></a><code class="function-signature">stakeAmountTotalMinusOrderedWithdraw(address) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IStaking.stakingEpoch()"></a><code class="function-signature">stakingEpoch() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>







### `IStakingAuRa`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#IStakingAuRa.initialize(address,address,address[],uint256,uint256,uint256,uint256)"><code class="function-signature">initialize(address, address, address[], uint256, uint256, uint256, uint256)</code></a></li><li><a href="#IStakingAuRa.setStakingEpochStartBlock(uint256)"><code class="function-signature">setStakingEpochStartBlock(uint256)</code></a></li><li><a href="#IStakingAuRa.stakeWithdrawDisallowPeriod()"><code class="function-signature">stakeWithdrawDisallowPeriod()</code></a></li><li><a href="#IStakingAuRa.stakingEpochDuration()"><code class="function-signature">stakingEpochDuration()</code></a></li><li><a href="#IStakingAuRa.stakingEpochEndBlock()"><code class="function-signature">stakingEpochEndBlock()</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="IStakingAuRa.initialize(address,address,address[],uint256,uint256,uint256,uint256)"></a><code class="function-signature">initialize(address, address, address[], uint256, uint256, uint256, uint256)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="IStakingAuRa.setStakingEpochStartBlock(uint256)"></a><code class="function-signature">setStakingEpochStartBlock(uint256)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="IStakingAuRa.stakeWithdrawDisallowPeriod()"></a><code class="function-signature">stakeWithdrawDisallowPeriod() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IStakingAuRa.stakingEpochDuration()"></a><code class="function-signature">stakingEpochDuration() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IStakingAuRa.stakingEpochEndBlock()"></a><code class="function-signature">stakingEpochEndBlock() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>







### `IStakingHBBFT`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#IStakingHBBFT.initialize(address,address,address[],uint256,uint256)"><code class="function-signature">initialize(address, address, address[], uint256, uint256)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="IStakingHBBFT.initialize(address,address,address[],uint256,uint256)"></a><code class="function-signature">initialize(address, address, address[], uint256, uint256)</code></h4>







### `ITxPermission`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#ITxPermission.initialize(address)"><code class="function-signature">initialize(address)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="ITxPermission.initialize(address)"></a><code class="function-signature">initialize(address)</code></h4>







### `IValidatorSet`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#IValidatorSet.initialize(address,address,address,address[],address[],bool)"><code class="function-signature">initialize(address, address, address, address[], address[], bool)</code></a></li><li><a href="#IValidatorSet.newValidatorSet()"><code class="function-signature">newValidatorSet()</code></a></li><li><a href="#IValidatorSet.setStakingAddress(address,address)"><code class="function-signature">setStakingAddress(address, address)</code></a></li><li><a href="#IValidatorSet.blockRewardContract()"><code class="function-signature">blockRewardContract()</code></a></li><li><a href="#IValidatorSet.changeRequestCount()"><code class="function-signature">changeRequestCount()</code></a></li><li><a href="#IValidatorSet.emitInitiateChangeCallable()"><code class="function-signature">emitInitiateChangeCallable()</code></a></li><li><a href="#IValidatorSet.getPendingValidators()"><code class="function-signature">getPendingValidators()</code></a></li><li><a href="#IValidatorSet.getPreviousValidators()"><code class="function-signature">getPreviousValidators()</code></a></li><li><a href="#IValidatorSet.getValidators()"><code class="function-signature">getValidators()</code></a></li><li><a href="#IValidatorSet.isReportValidatorValid(address)"><code class="function-signature">isReportValidatorValid(address)</code></a></li><li><a href="#IValidatorSet.isValidator(address)"><code class="function-signature">isValidator(address)</code></a></li><li><a href="#IValidatorSet.isValidatorBanned(address)"><code class="function-signature">isValidatorBanned(address)</code></a></li><li><a href="#IValidatorSet.MAX_VALIDATORS()"><code class="function-signature">MAX_VALIDATORS()</code></a></li><li><a href="#IValidatorSet.miningByStakingAddress(address)"><code class="function-signature">miningByStakingAddress(address)</code></a></li><li><a href="#IValidatorSet.randomContract()"><code class="function-signature">randomContract()</code></a></li><li><a href="#IValidatorSet.stakingByMiningAddress(address)"><code class="function-signature">stakingByMiningAddress(address)</code></a></li><li><a href="#IValidatorSet.stakingContract()"><code class="function-signature">stakingContract()</code></a></li><li><a href="#IValidatorSet.unremovableValidator()"><code class="function-signature">unremovableValidator()</code></a></li><li><a href="#IValidatorSet.validatorIndex(address)"><code class="function-signature">validatorIndex(address)</code></a></li><li><a href="#IValidatorSet.validatorSetApplyBlock()"><code class="function-signature">validatorSetApplyBlock()</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="IValidatorSet.initialize(address,address,address,address[],address[],bool)"></a><code class="function-signature">initialize(address, address, address, address[], address[], bool)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSet.newValidatorSet()"></a><code class="function-signature">newValidatorSet() <span class="return-arrow">→</span> <span class="return-type">bool,uint256</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSet.setStakingAddress(address,address)"></a><code class="function-signature">setStakingAddress(address, address)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSet.blockRewardContract()"></a><code class="function-signature">blockRewardContract() <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSet.changeRequestCount()"></a><code class="function-signature">changeRequestCount() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSet.emitInitiateChangeCallable()"></a><code class="function-signature">emitInitiateChangeCallable() <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSet.getPendingValidators()"></a><code class="function-signature">getPendingValidators() <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSet.getPreviousValidators()"></a><code class="function-signature">getPreviousValidators() <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSet.getValidators()"></a><code class="function-signature">getValidators() <span class="return-arrow">→</span> <span class="return-type">address[]</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSet.isReportValidatorValid(address)"></a><code class="function-signature">isReportValidatorValid(address) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSet.isValidator(address)"></a><code class="function-signature">isValidator(address) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSet.isValidatorBanned(address)"></a><code class="function-signature">isValidatorBanned(address) <span class="return-arrow">→</span> <span class="return-type">bool</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSet.MAX_VALIDATORS()"></a><code class="function-signature">MAX_VALIDATORS() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSet.miningByStakingAddress(address)"></a><code class="function-signature">miningByStakingAddress(address) <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSet.randomContract()"></a><code class="function-signature">randomContract() <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSet.stakingByMiningAddress(address)"></a><code class="function-signature">stakingByMiningAddress(address) <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSet.stakingContract()"></a><code class="function-signature">stakingContract() <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSet.unremovableValidator()"></a><code class="function-signature">unremovableValidator() <span class="return-arrow">→</span> <span class="return-type">address</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSet.validatorIndex(address)"></a><code class="function-signature">validatorIndex(address) <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSet.validatorSetApplyBlock()"></a><code class="function-signature">validatorSetApplyBlock() <span class="return-arrow">→</span> <span class="return-type">uint256</span></code></h4>







### `IValidatorSetAuRa`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#IValidatorSetAuRa.removeMaliciousValidator(address)"><code class="function-signature">removeMaliciousValidator(address)</code></a></li><li><a href="#IValidatorSetAuRa.reportMaliciousCallable(address,address,uint256)"><code class="function-signature">reportMaliciousCallable(address, address, uint256)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="IValidatorSetAuRa.removeMaliciousValidator(address)"></a><code class="function-signature">removeMaliciousValidator(address)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSetAuRa.reportMaliciousCallable(address,address,uint256)"></a><code class="function-signature">reportMaliciousCallable(address, address, uint256) <span class="return-arrow">→</span> <span class="return-type">bool,bool</span></code></h4>







### `IValidatorSetHBBFT`



<div class="contract-index"><span class="contract-index-title">Functions</span><ul><li><a href="#IValidatorSetHBBFT.clearMaliceReported(address)"><code class="function-signature">clearMaliceReported(address)</code></a></li><li><a href="#IValidatorSetHBBFT.initializePublicKeys(bytes[])"><code class="function-signature">initializePublicKeys(bytes[])</code></a></li><li><a href="#IValidatorSetHBBFT.savePublicKey(address,bytes)"><code class="function-signature">savePublicKey(address, bytes)</code></a></li></ul></div>



<h4><a class="anchor" aria-hidden="true" id="IValidatorSetHBBFT.clearMaliceReported(address)"></a><code class="function-signature">clearMaliceReported(address)</code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSetHBBFT.initializePublicKeys(bytes[])"></a><code class="function-signature">initializePublicKeys(bytes[])</code></h4>





<h4><a class="anchor" aria-hidden="true" id="IValidatorSetHBBFT.savePublicKey(address,bytes)"></a><code class="function-signature">savePublicKey(address, bytes)</code></h4>







</div>