const Web3 = require('web3');
const { program } = require('commander');
const web3 = new Web3();
const BN = web3.utils.BN;

// web3.eth.subscribe('newBlockHeaders', function(error, result){
// }).on("data", blockHeader => onNewBlock(blockHeader));
// function onNewBlock(block) {
//   let nowTime = new Date();
//   let tsTime = new Date(block.step * 5 * 1000);
//   console.log(`New Block: ${block.number}`);
//   console.log(`Author: ${block.miner}`);
//   console.log(`Time: ${nowTime.getMinutes()}:${nowTime.getSeconds()}:${nowTime.getMilliseconds()}`);
//   console.log(`Timestamp: ${tsTime.getMinutes()}:${tsTime.getSeconds()}:${tsTime.getMilliseconds()}`);
//   console.log();
// }

const BlockReward = new web3.eth.Contract([{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"setTokenMinterContract","inputs":[{"type":"address","name":"_tokenMinterContract"}],"constant":false},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"addBridgeTokenFeeReceivers","inputs":[{"type":"uint256","name":"_amount"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"snapshotPoolValidatorStakeAmount","inputs":[{"type":"uint256","name":""},{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"setErcToNativeBridgesAllowed","inputs":[{"type":"address[]","name":"_bridgesAllowed"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256[]","name":""}],"name":"currentPoolRewards","inputs":[{"type":"uint256","name":"_rewardToDistribute"},{"type":"uint256[]","name":"_blocksCreatedShareNum"},{"type":"uint256","name":"_blocksCreatedShareDenom"},{"type":"uint256","name":"_stakingEpoch"}],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"addBridgeNativeRewardReceivers","inputs":[{"type":"uint256","name":"_amount"}],"constant":false},{"type":"function","stateMutability":"pure","payable":false,"outputs":[{"type":"bytes4","name":""}],"name":"blockRewardContractId","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"mintedForAccountInBlock","inputs":[{"type":"address","name":""},{"type":"uint256","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"epochPoolNativeReward","inputs":[{"type":"uint256","name":""},{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"isInitialized","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""},{"type":"uint256","name":""}],"name":"currentNativeRewardToDistribute","inputs":[{"type":"address","name":"_stakingContract"},{"type":"uint256","name":"_stakingEpoch"},{"type":"uint256","name":"_totalRewardShareNum"},{"type":"uint256","name":"_totalRewardShareDenom"},{"type":"address[]","name":"_validators"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"mintedForAccount","inputs":[{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address[]","name":""}],"name":"ercToNativeBridgesAllowed","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"mintedInBlock","inputs":[{"type":"uint256","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""},{"type":"uint256","name":""}],"name":"currentTokenRewardToDistribute","inputs":[{"type":"address","name":"_stakingContract"},{"type":"uint256","name":"_stakingEpoch"},{"type":"uint256","name":"_totalRewardShareNum"},{"type":"uint256","name":"_totalRewardShareDenom"},{"type":"address[]","name":"_validators"}],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"initialize","inputs":[{"type":"address","name":"_validatorSet"},{"type":"address","name":"_prevBlockReward"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"STAKE_TOKEN_INFLATION_RATE","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256[]","name":"epochsToClaimFrom"}],"name":"epochsToClaimRewardFrom","inputs":[{"type":"address","name":"_poolStakingAddress"},{"type":"address","name":"_staker"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"validatorRewardPercent","inputs":[{"type":"address","name":"_stakingAddress"}],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"addBridgeNativeFeeReceivers","inputs":[{"type":"uint256","name":"_amount"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"mintedTotally","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"delegatorShare","inputs":[{"type":"uint256","name":"_stakingEpoch"},{"type":"uint256","name":"_delegatorStaked"},{"type":"uint256","name":"_validatorStaked"},{"type":"uint256","name":"_totalStaked"},{"type":"uint256","name":"_poolReward"}],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"addBridgeTokenRewardReceivers","inputs":[{"type":"uint256","name":"_amount"}],"constant":false},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"setNativeToErcBridgesAllowed","inputs":[{"type":"address[]","name":"_bridgesAllowed"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"tokenRewardUndistributed","inputs":[],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"transferReward","inputs":[{"type":"uint256","name":"_tokens"},{"type":"uint256","name":"_nativeCoins"},{"type":"address","name":"_to"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"snapshotPoolTotalStakeAmount","inputs":[{"type":"uint256","name":""},{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"validatorShare","inputs":[{"type":"uint256","name":"_stakingEpoch"},{"type":"uint256","name":"_validatorStaked"},{"type":"uint256","name":"_totalStaked"},{"type":"uint256","name":"_poolReward"}],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"setErcToErcBridgesAllowed","inputs":[{"type":"address[]","name":"_bridgesAllowed"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address[]","name":""}],"name":"ercToErcBridgesAllowed","inputs":[],"constant":true},{"type":"function","stateMutability":"pure","payable":false,"outputs":[{"type":"bool","name":""}],"name":"onTokenTransfer","inputs":[{"type":"address","name":""},{"type":"uint256","name":""},{"type":"bytes","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"extraReceiversQueueSize","inputs":[],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"addExtraReceiver","inputs":[{"type":"uint256","name":"_amount"},{"type":"address","name":"_receiver"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"bridgeNativeReward","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"nativeRewardUndistributed","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address[]","name":""}],"name":"nativeToErcBridgesAllowed","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"mintedTotallyByBridge","inputs":[{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"epochPoolTokenReward","inputs":[{"type":"uint256","name":""},{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":"tokenReward"},{"type":"uint256","name":"nativeReward"}],"name":"getValidatorReward","inputs":[{"type":"uint256","name":"_stakingEpoch"},{"type":"address","name":"_poolMiningAddress"}],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"clearBlocksCreated","inputs":[],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address","name":""}],"name":"tokenMinterContract","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"validatorMinRewardPercent","inputs":[{"type":"uint256","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256[]","name":""}],"name":"epochsPoolGotRewardFor","inputs":[{"type":"address","name":"_miningAddress"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address","name":""}],"name":"validatorSetContract","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":"tokenReward"},{"type":"uint256","name":"nativeReward"}],"name":"getDelegatorReward","inputs":[{"type":"uint256","name":"_delegatorStake"},{"type":"uint256","name":"_stakingEpoch"},{"type":"address","name":"_poolMiningAddress"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"blocksCreated","inputs":[{"type":"uint256","name":""},{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[{"type":"address[]","name":"receiversNative"},{"type":"uint256[]","name":"rewardsNative"}],"name":"reward","inputs":[{"type":"address[]","name":"benefactors"},{"type":"uint16[]","name":"kind"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"bridgeTokenReward","inputs":[],"constant":true},{"type":"fallback","stateMutability":"payable","payable":true},{"type":"event","name":"BridgeTokenRewardAdded","inputs":[{"type":"uint256","name":"amount","indexed":false},{"type":"uint256","name":"cumulativeAmount","indexed":false},{"type":"address","name":"bridge","indexed":true}],"anonymous":false},{"type":"event","name":"AddedReceiver","inputs":[{"type":"uint256","name":"amount","indexed":false},{"type":"address","name":"receiver","indexed":true},{"type":"address","name":"bridge","indexed":true}],"anonymous":false},{"type":"event","name":"BridgeNativeRewardAdded","inputs":[{"type":"uint256","name":"amount","indexed":false},{"type":"uint256","name":"cumulativeAmount","indexed":false},{"type":"address","name":"bridge","indexed":true}],"anonymous":false},{"type":"event","name":"MintedNative","inputs":[{"type":"address[]","name":"receivers","indexed":false},{"type":"uint256[]","name":"rewards","indexed":false}],"anonymous":false}], '0x481c034c6d9441db23Ea48De68BCAe812C5d39bA');
const Random = new web3.eth.Contract([{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bytes","name":""}],"name":"getCipher","inputs":[{"type":"uint256","name":"_collectRound"},{"type":"address","name":"_miningAddress"}],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"commitHash","inputs":[{"type":"bytes32","name":"_numberHash"},{"type":"bytes","name":"_cipher"}],"constant":false},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"onFinishCollectRound","inputs":[],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"collectRoundLength","inputs":[],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"initialize","inputs":[{"type":"uint256","name":"_collectRoundLength"},{"type":"address","name":"_validatorSet"},{"type":"bool","name":"_punishForUnreveal"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"isInitialized","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"punishForUnreveal","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"commitPhaseLength","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"revealSkips","inputs":[{"type":"uint256","name":""},{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"sentReveal","inputs":[{"type":"uint256","name":""},{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bytes32","name":""},{"type":"bytes","name":""}],"name":"getCommitAndCipher","inputs":[{"type":"uint256","name":"_collectRound"},{"type":"address","name":"_miningAddress"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"isCommitPhase","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"nextCommitPhaseStartBlock","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"currentCollectRound","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"nextCollectRoundStartBlock","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"currentSeed","inputs":[],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"revealSecret","inputs":[{"type":"uint256","name":"_number"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"revealSecretCallable","inputs":[{"type":"address","name":"_miningAddress"},{"type":"uint256","name":"_number"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"isCommitted","inputs":[{"type":"uint256","name":"_collectRound"},{"type":"address","name":"_miningAddress"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"isRevealPhase","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"nextRevealPhaseStartBlock","inputs":[],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"setPunishForUnreveal","inputs":[{"type":"bool","name":"_punishForUnreveal"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"commitHashCallable","inputs":[{"type":"address","name":"_miningAddress"},{"type":"bytes32","name":"_numberHash"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address","name":""}],"name":"validatorSetContract","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bytes32","name":""}],"name":"getCommit","inputs":[{"type":"uint256","name":"_collectRound"},{"type":"address","name":"_miningAddress"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"currentCollectRoundStartBlock","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"revealNumberCallable","inputs":[{"type":"address","name":"_miningAddress"},{"type":"uint256","name":"_number"}],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"revealNumber","inputs":[{"type":"uint256","name":"_number"}],"constant":false}], '0x5870b0527DeDB1cFBD9534343Feda1a41Ce47766');
const Staking = new web3.eth.Contract([{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"delegatorStakeSnapshot","inputs":[{"type":"address","name":""},{"type":"address","name":""},{"type":"uint256","name":""}],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"initialValidatorStake","inputs":[{"type":"uint256","name":"_totalAmount"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"poolDelegatorIndex","inputs":[{"type":"address","name":""},{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"removePools","inputs":[],"constant":false},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"initialize","inputs":[{"type":"address","name":"_validatorSetContract"},{"type":"address[]","name":"_initialStakingAddresses"},{"type":"uint256","name":"_delegatorMinStake"},{"type":"uint256","name":"_candidateMinStake"},{"type":"uint256","name":"_stakingEpochDuration"},{"type":"uint256","name":"_stakingEpochStartBlock"},{"type":"uint256","name":"_stakeWithdrawDisallowPeriod"}],"constant":false},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"setStakingEpochStartBlock","inputs":[{"type":"uint256","name":"_blockNumber"}],"constant":false},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"moveStake","inputs":[{"type":"address","name":"_fromPoolStakingAddress"},{"type":"address","name":"_toPoolStakingAddress"},{"type":"uint256","name":"_amount"}],"constant":false},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"setDelegatorMinStake","inputs":[{"type":"uint256","name":"_minStake"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address","name":""}],"name":"erc677TokenContract","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"rewardWasTaken","inputs":[{"type":"address","name":""},{"type":"address","name":""},{"type":"uint256","name":""}],"constant":true},{"type":"function","stateMutability":"payable","payable":true,"outputs":[],"name":"addPool","inputs":[{"type":"uint256","name":"_amount"},{"type":"address","name":"_miningAddress"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"isInitialized","inputs":[],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"removePool","inputs":[{"type":"address","name":"_stakingAddress"}],"constant":false},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"claimReward","inputs":[{"type":"uint256[]","name":"_stakingEpochs"},{"type":"address","name":"_poolStakingAddress"}],"constant":false},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"setCandidateMinStake","inputs":[{"type":"uint256","name":"_minStake"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"stakeAmountTotal","inputs":[{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"stakeFirstEpoch","inputs":[{"type":"address","name":""},{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"setErc677TokenContract","inputs":[{"type":"address","name":"_erc677TokenContract"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"candidateMinStake","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"poolInactiveIndex","inputs":[{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address[]","name":""}],"name":"getPools","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"maxWithdrawAllowed","inputs":[{"type":"address","name":"_poolStakingAddress"},{"type":"address","name":"_staker"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"stakingEpochStartBlock","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address[]","name":""}],"name":"poolDelegatorsInactive","inputs":[{"type":"address","name":"_poolStakingAddress"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"stakeAmountByCurrentEpoch","inputs":[{"type":"address","name":"_poolStakingAddress"},{"type":"address","name":"_staker"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"stakingEpoch","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"stakingEpochEndBlock","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"maxWithdrawOrderAllowed","inputs":[{"type":"address","name":"_poolStakingAddress"},{"type":"address","name":"_staker"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"poolDelegatorInactiveIndex","inputs":[{"type":"address","name":""},{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256[]","name":"likelihoods"},{"type":"uint256","name":"sum"}],"name":"getPoolsLikelihood","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"stakeWithdrawDisallowPeriod","inputs":[],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"clearUnremovableValidator","inputs":[{"type":"address","name":"_unremovableStakingAddress"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address[]","name":"result"}],"name":"getStakerPools","inputs":[{"type":"address","name":"_staker"},{"type":"uint256","name":"_offset"},{"type":"uint256","name":"_length"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address[]","name":""}],"name":"poolDelegators","inputs":[{"type":"address","name":"_poolStakingAddress"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"orderWithdrawEpoch","inputs":[{"type":"address","name":""},{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"pure","payable":false,"outputs":[{"type":"bool","name":""}],"name":"onTokenTransfer","inputs":[{"type":"address","name":""},{"type":"uint256","name":""},{"type":"bytes","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address[]","name":""}],"name":"getPoolsToBeElected","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"stakeAmount","inputs":[{"type":"address","name":""},{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"getStakerPoolsLength","inputs":[{"type":"address","name":"_staker"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"isPoolActive","inputs":[{"type":"address","name":"_stakingAddress"}],"constant":true},{"type":"function","stateMutability":"payable","payable":true,"outputs":[],"name":"stake","inputs":[{"type":"address","name":"_toPoolStakingAddress"},{"type":"uint256","name":"_amount"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"poolIndex","inputs":[{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"orderWithdraw","inputs":[{"type":"address","name":"_poolStakingAddress"},{"type":"int256","name":"_amount"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"stakeLastEpoch","inputs":[{"type":"address","name":""},{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"claimOrderedWithdraw","inputs":[{"type":"address","name":"_poolStakingAddress"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address[]","name":""}],"name":"getPoolsToBeRemoved","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"stakingEpochDuration","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"delegatorMinStake","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"orderedWithdrawAmountTotal","inputs":[{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address[]","name":""}],"name":"getPoolsInactive","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address","name":""}],"name":"validatorSetContract","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"orderedWithdrawAmount","inputs":[{"type":"address","name":""},{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"removeMyPool","inputs":[],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"poolToBeRemovedIndex","inputs":[{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"incrementStakingEpoch","inputs":[],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"MAX_CANDIDATES","inputs":[],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"withdraw","inputs":[{"type":"address","name":"_fromPoolStakingAddress"},{"type":"uint256","name":"_amount"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"areStakeAndWithdrawAllowed","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"poolToBeElectedIndex","inputs":[{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":"tokenRewardSum"},{"type":"uint256","name":"nativeRewardSum"}],"name":"getRewardAmount","inputs":[{"type":"uint256[]","name":"_stakingEpochs"},{"type":"address","name":"_poolStakingAddress"},{"type":"address","name":"_staker"}],"constant":true},{"type":"fallback","stateMutability":"payable","payable":true},{"type":"event","name":"ClaimedReward","inputs":[{"type":"address","name":"fromPoolStakingAddress","indexed":true},{"type":"address","name":"staker","indexed":true},{"type":"uint256","name":"stakingEpoch","indexed":true},{"type":"uint256","name":"tokensAmount","indexed":false},{"type":"uint256","name":"nativeCoinsAmount","indexed":false}],"anonymous":false},{"type":"event","name":"AddedPool","inputs":[{"type":"address","name":"poolStakingAddress","indexed":true}],"anonymous":false},{"type":"event","name":"ClaimedOrderedWithdrawal","inputs":[{"type":"address","name":"fromPoolStakingAddress","indexed":true},{"type":"address","name":"staker","indexed":true},{"type":"uint256","name":"stakingEpoch","indexed":true},{"type":"uint256","name":"amount","indexed":false}],"anonymous":false},{"type":"event","name":"MovedStake","inputs":[{"type":"address","name":"fromPoolStakingAddress","indexed":false},{"type":"address","name":"toPoolStakingAddress","indexed":true},{"type":"address","name":"staker","indexed":true},{"type":"uint256","name":"stakingEpoch","indexed":true},{"type":"uint256","name":"amount","indexed":false}],"anonymous":false},{"type":"event","name":"OrderedWithdrawal","inputs":[{"type":"address","name":"fromPoolStakingAddress","indexed":true},{"type":"address","name":"staker","indexed":true},{"type":"uint256","name":"stakingEpoch","indexed":true},{"type":"int256","name":"amount","indexed":false}],"anonymous":false},{"type":"event","name":"PlacedStake","inputs":[{"type":"address","name":"toPoolStakingAddress","indexed":true},{"type":"address","name":"staker","indexed":true},{"type":"uint256","name":"stakingEpoch","indexed":true},{"type":"uint256","name":"amount","indexed":false}],"anonymous":false},{"type":"event","name":"RemovedPool","inputs":[{"type":"address","name":"poolStakingAddress","indexed":true}],"anonymous":false},{"type":"event","name":"WithdrewStake","inputs":[{"type":"address","name":"fromPoolStakingAddress","indexed":true},{"type":"address","name":"staker","indexed":true},{"type":"uint256","name":"stakingEpoch","indexed":true},{"type":"uint256","name":"amount","indexed":false}],"anonymous":false}], '0x2DdB8A7541e6cAA50F74e7FACFF9Fe9da00e0A6c');
const ValidatorSet = new web3.eth.Contract([{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address[]","name":"miningAddresses"},{"type":"bool","name":"forNewEpoch"}],"name":"validatorsToBeFinalized","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address","name":""}],"name":"miningByStakingAddress","inputs":[{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"removeMaliciousValidators","inputs":[{"type":"address[]","name":"_miningAddresses"}],"constant":false},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"setStakingAddress","inputs":[{"type":"address","name":"_miningAddress"},{"type":"address","name":"_stakingAddress"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"initiateChangeAllowed","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"bannedDelegatorsUntil","inputs":[{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"banCounter","inputs":[{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address","name":""}],"name":"stakingByMiningAddress","inputs":[{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"reportingCounter","inputs":[{"type":"address","name":""},{"type":"uint256","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"isInitialized","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"emitInitiateChangeCallable","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address","name":""}],"name":"blockRewardContract","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"bannedUntil","inputs":[{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"newValidatorSet","inputs":[],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address","name":""}],"name":"unremovableValidator","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"MAX_VALIDATORS","inputs":[],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"clearUnremovableValidator","inputs":[],"constant":false},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"finalizeChange","inputs":[],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address[]","name":""}],"name":"getPreviousValidators","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"isReportValidatorValid","inputs":[{"type":"address","name":"_miningAddress"}],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"emitInitiateChange","inputs":[],"constant":false},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"initialize","inputs":[{"type":"address","name":"_blockRewardContract"},{"type":"address","name":"_randomContract"},{"type":"address","name":"_stakingContract"},{"type":"address[]","name":"_initialMiningAddresses"},{"type":"address[]","name":"_initialStakingAddresses"},{"type":"bool","name":"_firstValidatorIsUnremovable"}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"isValidatorOrPending","inputs":[{"type":"address","name":"_miningAddress"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":"callable"},{"type":"bool","name":"removeReportingValidator"}],"name":"reportMaliciousCallable","inputs":[{"type":"address","name":"_reportingMiningAddress"},{"type":"address","name":"_maliciousMiningAddress"},{"type":"uint256","name":"_blockNumber"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"isValidatorPrevious","inputs":[{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"areDelegatorsBanned","inputs":[{"type":"address","name":"_miningAddress"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"isValidatorBanned","inputs":[{"type":"address","name":"_miningAddress"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"validatorCounter","inputs":[{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address[]","name":""}],"name":"maliceReportedForBlock","inputs":[{"type":"address","name":"_miningAddress"},{"type":"uint256","name":"_blockNumber"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address[]","name":""}],"name":"getValidators","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"validatorSetApplyBlock","inputs":[],"constant":true},{"type":"function","stateMutability":"nonpayable","payable":false,"outputs":[],"name":"reportMalicious","inputs":[{"type":"address","name":"_maliciousMiningAddress"},{"type":"uint256","name":"_blockNumber"},{"type":"bytes","name":""}],"constant":false},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bytes32","name":""}],"name":"banReason","inputs":[{"type":"address","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"shouldValidatorReport","inputs":[{"type":"address","name":"_reportingMiningAddress"},{"type":"address","name":"_maliciousMiningAddress"},{"type":"uint256","name":"_blockNumber"}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address","name":""}],"name":"randomContract","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"changeRequestCount","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"uint256","name":""}],"name":"reportingCounterTotal","inputs":[{"type":"uint256","name":""}],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address","name":""}],"name":"stakingContract","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"address[]","name":""}],"name":"getPendingValidators","inputs":[],"constant":true},{"type":"function","stateMutability":"view","payable":false,"outputs":[{"type":"bool","name":""}],"name":"isValidator","inputs":[{"type":"address","name":""}],"constant":true},{"type":"event","name":"InitiateChange","inputs":[{"type":"bytes32","name":"parentHash","indexed":true},{"type":"address[]","name":"newSet","indexed":false}],"anonymous":false},{"type":"event","name":"ReportedMalicious","inputs":[{"type":"address","name":"reportingValidator","indexed":false},{"type":"address","name":"maliciousValidator","indexed":false},{"type":"uint256","name":"blockNumber","indexed":false}],"anonymous":false}], '0xB87BE9f7196F2AE084Ca1DE6af5264292976e013');
const Token = new web3.eth.Contract([{"constant":false,"inputs":[{"name":"_bridge","type":"address"}],"name":"removeBridge","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function","signature":"0x04df017d"},{"constant":true,"inputs":[],"name":"name","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function","signature":"0x06fdde03"},{"constant":false,"inputs":[{"name":"_spender","type":"address"},{"name":"_value","type":"uint256"}],"name":"approve","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function","signature":"0x095ea7b3"},{"constant":true,"inputs":[],"name":"totalSupply","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function","signature":"0x18160ddd"},{"constant":true,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"payable":false,"stateMutability":"view","type":"function","signature":"0x313ce567"},{"constant":false,"inputs":[{"name":"spender","type":"address"},{"name":"addedValue","type":"uint256"}],"name":"increaseAllowance","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function","signature":"0x39509351"},{"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"},{"name":"_data","type":"bytes"}],"name":"transferAndCall","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function","signature":"0x4000aea0"},{"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_amount","type":"uint256"}],"name":"mint","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function","signature":"0x40c10f19"},{"constant":false,"inputs":[{"name":"_value","type":"uint256"}],"name":"burn","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function","signature":"0x42966c68"},{"constant":true,"inputs":[{"name":"","type":"address"}],"name":"bridgePointers","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function","signature":"0x4bcb88bc"},{"constant":true,"inputs":[],"name":"blockRewardContract","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function","signature":"0x56b54bae"},{"constant":false,"inputs":[{"name":"_spender","type":"address"},{"name":"_subtractedValue","type":"uint256"}],"name":"decreaseApproval","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function","signature":"0x66188463"},{"constant":false,"inputs":[{"name":"_token","type":"address"},{"name":"_to","type":"address"}],"name":"claimTokens","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function","signature":"0x69ffa08a"},{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function","signature":"0x70a08231"},{"constant":true,"inputs":[{"name":"_address","type":"address"}],"name":"isBridge","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function","signature":"0x726600ce"},{"constant":true,"inputs":[],"name":"getTokenInterfacesVersion","outputs":[{"name":"major","type":"uint64"},{"name":"minor","type":"uint64"},{"name":"patch","type":"uint64"}],"payable":false,"stateMutability":"pure","type":"function","signature":"0x859ba28c"},{"constant":true,"inputs":[],"name":"owner","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function","signature":"0x8da5cb5b"},{"constant":true,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function","signature":"0x95d89b41"},{"constant":false,"inputs":[{"name":"_bridge","type":"address"}],"name":"addBridge","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function","signature":"0x9712fdf8"},{"constant":true,"inputs":[],"name":"bridgeList","outputs":[{"name":"","type":"address[]"}],"payable":false,"stateMutability":"view","type":"function","signature":"0x9da38e2f"},{"constant":false,"inputs":[{"name":"spender","type":"address"},{"name":"subtractedValue","type":"uint256"}],"name":"decreaseAllowance","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function","signature":"0xa457c2d7"},{"constant":true,"inputs":[],"name":"F_ADDR","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function","signature":"0xc794c769"},{"constant":false,"inputs":[{"name":"_spender","type":"address"},{"name":"_addedValue","type":"uint256"}],"name":"increaseApproval","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function","signature":"0xd73dd623"},{"constant":true,"inputs":[{"name":"_owner","type":"address"},{"name":"_spender","type":"address"}],"name":"allowance","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function","signature":"0xdd62ed3e"},{"constant":true,"inputs":[],"name":"stakingContract","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function","signature":"0xee99205c"},{"constant":false,"inputs":[{"name":"_newOwner","type":"address"}],"name":"transferOwnership","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function","signature":"0xf2fde38b"},{"constant":true,"inputs":[],"name":"bridgeCount","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function","signature":"0xfbb2a53f"},{"inputs":[{"name":"_name","type":"string"},{"name":"_symbol","type":"string"},{"name":"_decimals","type":"uint8"}],"payable":false,"stateMutability":"nonpayable","type":"constructor","signature":"constructor"},{"anonymous":false,"inputs":[{"indexed":true,"name":"bridge","type":"address"}],"name":"BridgeAdded","type":"event","signature":"0x3cda433c5679ae4c6a5dea50840e222a42cba3695e4663de4366be8993484221"},{"anonymous":false,"inputs":[{"indexed":true,"name":"bridge","type":"address"}],"name":"BridgeRemoved","type":"event","signature":"0x5d9d5034656cb3ebfb0655057cd7f9b4077a9b42ff42ce223cbac5bc586d2126"},{"anonymous":false,"inputs":[{"indexed":false,"name":"from","type":"address"},{"indexed":false,"name":"to","type":"address"},{"indexed":false,"name":"value","type":"uint256"}],"name":"ContractFallbackCallFailed","type":"event","signature":"0x11249f0fc79fc134a15a10d1da8291b79515bf987e036ced05b9ec119614070b"},{"anonymous":false,"inputs":[{"indexed":true,"name":"to","type":"address"},{"indexed":false,"name":"amount","type":"uint256"}],"name":"Mint","type":"event","signature":"0x0f6798a560793a54c3bcfe86a93cde1e73087d944c0ea20544137d4121396885"},{"anonymous":false,"inputs":[{"indexed":true,"name":"previousOwner","type":"address"},{"indexed":true,"name":"newOwner","type":"address"}],"name":"OwnershipTransferred","type":"event","signature":"0x8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0"},{"anonymous":false,"inputs":[{"indexed":true,"name":"burner","type":"address"},{"indexed":false,"name":"value","type":"uint256"}],"name":"Burn","type":"event","signature":"0xcc16f5dbb4873280815c1ee09dbd06736cffcc184412cf7a71a0fdb75d397ca5"},{"anonymous":false,"inputs":[{"indexed":true,"name":"from","type":"address"},{"indexed":true,"name":"to","type":"address"},{"indexed":false,"name":"value","type":"uint256"},{"indexed":false,"name":"data","type":"bytes"}],"name":"Transfer","type":"event","signature":"0xe19260aff97b920c7df27010903aeb9c8d2be5d310a2c67824cf3f15396e4c16"},{"anonymous":false,"inputs":[{"indexed":true,"name":"owner","type":"address"},{"indexed":true,"name":"spender","type":"address"},{"indexed":false,"name":"value","type":"uint256"}],"name":"Approval","type":"event","signature":"0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925"},{"anonymous":false,"inputs":[{"indexed":true,"name":"from","type":"address"},{"indexed":true,"name":"to","type":"address"},{"indexed":false,"name":"value","type":"uint256"}],"name":"Transfer","type":"event","signature":"0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"},{"constant":false,"inputs":[{"name":"_blockRewardContract","type":"address"}],"name":"setBlockRewardContract","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function","signature":"0x27a3e16b"},{"constant":false,"inputs":[{"name":"_stakingContract","type":"address"}],"name":"setStakingContract","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function","signature":"0x9dd373b9"},{"constant":false,"inputs":[{"name":"_amount","type":"uint256"}],"name":"mintReward","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function","signature":"0x91c0aabf"},{"constant":false,"inputs":[{"name":"_staker","type":"address"},{"name":"_amount","type":"uint256"}],"name":"stake","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function","signature":"0xadc9772e"},{"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function","signature":"0xa9059cbb"},{"constant":false,"inputs":[{"name":"_from","type":"address"},{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transferFrom","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function","signature":"0x23b872dd"}], '0xb7D311E2Eb55F2f68a9440da38e7989210b9A05e');

const knownNames = {
  // miningAddress (or stakingAddress) -> name
  '0x9233042B8E9E03D5DC6454BBBe5aee83818fF103': 'POA Network 1',
  '0x6dC0c0be4c8B2dFE750156dc7d59FaABFb5B923D': 'Giveth',
  '0x9e41BA620FebA8198369c26351063B26eC5b7C9E': 'MakerDAO',
  '0xA13D45301207711B7C0328c6b2b64862abFe9b7a': 'Protofire',
  '0x657eA4A9572DfdBFd95899eAdA0f6197211527BE': 'Burner Wallet',
  '0x06d563905b085A6B3070C819BDB96a44E5665005': 'POA Network 4',
  '0xDb1c683758F493Cef2E7089A3640502AB306322a': 'Anyblock Analytics',
  '0x657E832b1a67CDEF9e117aFd2F419387259Fa93e': 'Syncnode',
  '0x10AaE121b3c62F3DAfec9cC46C27b4c1dfe4A835': 'Lab10',
  '0x1438087186FdbFd4c256Fa2DF446921E30E54Df8': 'Gnosis',
  '0x0000999dc55126CA626c20377F0045946db69b6E': 'Galt Project',
  '0x9488f50c33e9616EE3B5B09CD3A9c603A108db4a': 'POA Network 2',
  '0x1A740616e96E07d86203707C1619d9871614922A': 'Nethermind',
  '0x642C40173134f6E457a62D4C2033259433A53E8C': 'xDaiDev',
  '0xb76756f95A9fB6ff9ad3E6cb41b734c1bd805103': 'Portis',
  '0x35770EF700Ff88D5f650597068e3Aaf051F3D5a4': '1Hive',
};

const validators = [];

main();

async function main() {
  program.name("npm run watch").usage("-- <options>");
  program.option('-r, --rpc <rpc>', 'RPC Node URL', 'https://rpc.xdaichain.com');
  program.option('-g, --general', 'Shows general info (ignored for --epoch-delegators and --apy).');
  program.option('-e, --epoch-delegators <epoch>', 'Shows active delegator list (excluding pending) for the given staking epoch,\nsorted by stake amount. Requires using RPC from an archive node.');
  program.option('-u, --show-unique', 'Shows unique delegator list for the current staking epoch\n(used with --general, ignored for --epoch-delegators and --apy).');
  program.option('-a, --apy', 'Shows approximate Annual Percentage Yield for the current moment. Requires using RPC from an archive node.');
  program.parse(process.argv);

  if (!program.general && !program.epochDelegators && !program.apy) {
    program.help();
  }

  web3.setProvider(program.rpc);

  // let prodStat = {};
  // const startBlock = 11687654;
  //
  // for (let i = startBlock-2184; i <= startBlock; i++) {
  //   console.log(i);
  //   const block = await web3.eth.getBlock(i);
  //   const miner = block.miner.toLowerCase();
  //   if (!prodStat.hasOwnProperty(miner)) {
  //     prodStat[miner] = 0;
  //   }
  //   prodStat[miner]++;
  //
  //   console.log();
  //   for (let j = 0; j < validators.length; j++) {
  //     const miner = validators[j].miningAddress.toLowerCase();
  //     const produced = prodStat[miner];
  //
  //     console.log(`${miner} : ${produced}`);
  //   }
  //   console.log();
  // }
  //
  // return;

  const currentBlock = await web3.eth.getBlock('latest');
  let averageBlockTime;
  if (!program.epochDelegators) {
    const oldBlock = await web3.eth.getBlock(currentBlock.number - 50);
    console.log(`CURRENT BLOCK ${currentBlock.number}`);
    console.log();

    // Calculate average block time
    averageBlockTime = (currentBlock.timestamp - oldBlock.timestamp) / (currentBlock.number - oldBlock.number);
    console.log(`averageBlockTime = ${averageBlockTime} sec`);
    console.log();
  }

  const methods = [
    [Staking.methods.getPools, []],
    [Staking.methods.getPoolsToBeElected, []],
    [Staking.methods.getPoolsToBeRemoved, []],
    [Staking.methods.stakingEpoch, []],
    [Staking.methods.stakingEpochStartBlock, []],
    [Staking.methods.stakingEpochEndBlock, []],
    [Staking.methods.stakingEpochDuration, []],
    [ValidatorSet.methods.validatorSetApplyBlock, []],
    [ValidatorSet.methods.getValidators, []],
    [ValidatorSet.methods.getPendingValidators, []],
    [ValidatorSet.methods.unremovableValidator, []],
    [Token.methods.totalSupply, []],
    [Token.methods.balanceOf, [Staking.options.address]],
    [Token.methods.balanceOf, [BlockReward.options.address]],
    [web3.eth.getBalance, [BlockReward.options.address, currentBlock.number]],
  ];

  let promises = [];
  let batch = new web3.BatchRequest();
  methods.forEach(item => {
    promises.push(new Promise((resolve, reject) => {
      const method = item[0];
      const arguments = item[1];
      let request;
      function requestCallback(err, result) {
        if (err) reject(err);
        else resolve(result);
      }
      if (method == web3.eth.getBalance) {
        request = method.request(...arguments, requestCallback);
      } else {
        request = method(...arguments).call.request({}, currentBlock.number, requestCallback);
      }
      batch.add(request);
    }));
  });
  await batch.execute();
  const [
    getPools,
    getPoolsToBeElected,
    getPoolsToBeRemoved,
    stakingEpoch,
    stakingEpochStartBlock,
    stakingEpochEndBlock,
    stakingEpochDuration,
    validatorSetApplyBlock,
    getValidators,
    getPendingValidators,
    unremovableValidator,
    totalSupply,
    stakingBalance,
    blockRewardTokenBalance,
    blockRewardNativeBalance
  ] = await Promise.all(promises);

  await getCurrentValidators(getValidators, currentBlock.number);

  if (program.epochDelegators) {
    console.log(`Current staking epoch: ${stakingEpoch}`);
    console.log(`Requested staking epoch: ${program.epochDelegators}`);
    console.log();
    await showActiveDelegatorsByStakingEpoch(
      program.epochDelegators,
      stakingEpochDuration,
      stakingEpoch,
      stakingEpochStartBlock,
      currentBlock.number
    );
    process.exit(0);
  } else if (program.apy) {
  	await showAPY(
      stakingEpoch,
      stakingEpochStartBlock,
      stakingEpochDuration,
      currentBlock.number,
      averageBlockTime,
      validatorSetApplyBlock
    );
  	process.exit(0);
  }

  // Calculate approximate stakingEpochEndTime
  const stakingEpochEndTime = new Date();
  stakingEpochEndTime.setTime((Math.floor(Date.now() / 1000) + Math.ceil((stakingEpochEndBlock - currentBlock.number) * averageBlockTime)) * 1000);

  console.log('Blocks creation and random reveal skipping statistics for the current staking epoch');
  const { blocksCreated, revealSkips } = await getBlocksCreatedAndRevealSkips(validators, stakingEpoch, currentBlock.number);
  const maxValidatorNameLength = validators.reduce((acc, val) => Math.max(val.name.length, acc), 0);
  const dashes = '-'.repeat(102 + maxValidatorNameLength);
  let blocksCreatedTotal = 0, revealSkipsTotal = 0;
  console.log(dashes);
  console.log(`| ${'Name'.padEnd(maxValidatorNameLength, ' ')} | Staking address | Mining address                             | Blocks created | Reveals skipped | `);
  console.log(dashes);
  let validatorIndexes = [...Array(validators.length).keys()];
  validatorIndexes.sort((a, b) => blocksCreated[b] - blocksCreated[a]);
  validatorIndexes.forEach(i => {
    console.log(`| ${validators[i].name.padEnd(maxValidatorNameLength, ' ')} | ${validators[i].stakingAddressShort.toLowerCase().padEnd(15, ' ')} | ${validators[i].miningAddress} | ${blocksCreated[i].padStart(14, ' ')} | ${revealSkips[i].padStart(15, ' ')} | `);
    blocksCreatedTotal += blocksCreated[i] - 0;
    revealSkipsTotal += revealSkips[i] - 0;
  });
  console.log(dashes);
  console.log(`| ${'Total'.padEnd(maxValidatorNameLength, ' ')} |                 |                                            | ${blocksCreatedTotal.toString().padStart(14, ' ')} | ${revealSkipsTotal.toString().padStart(15, ' ')} | `);
  console.log(dashes);
  console.log();

  console.log('Staking');
  console.log(`  getPools(${getPools.length}):`);
  getPools.forEach((stakingAddress, index) => {
    console.log(`    ${(index + 1).toString().padStart(2, ' ')}. ${stakingAddress}`);
  });
  console.log(`  getPoolsToBeElected(${getPoolsToBeElected.length}):`);
  getPoolsToBeElected.forEach((stakingAddress, index) => {
    console.log(`    ${(index + 1).toString().padStart(2, ' ')}. ${stakingAddress}`);
  });
  if (getPoolsToBeRemoved.length) {
    console.log(`  getPoolsToBeRemoved(${getPoolsToBeRemoved.length}):`);
    getPoolsToBeRemoved.forEach((stakingAddress, index) => {
      console.log(`    ${(index + 1).toString().padStart(2, ' ')}. ${stakingAddress}`);
    });
  }
  let {
    poolDelegators,
    allPoolsDelegatorsUnique,
    poolDelegatorsInactive
  } = await getPoolDelegators(currentBlock.number);
  const {
    stakeAmountTotal,
    orderedWithdrawAmountTotal,
    orderedWithdrawAmountTotalThisEpoch,
    howMuchStakerOrderedOnThisEpoch,
    howMuchDelegatorHolds
  } = await getAmounts(poolDelegators, stakingEpochStartBlock, currentBlock.number);
  const {
    totalDelegators,
    totalOrderedWithdrawDelegators,
    orderedWithdrawDelegatorsUnique
  } = await countDelegators(
    stakingEpoch,
    poolDelegators,
    poolDelegatorsInactive,
    howMuchDelegatorHolds,
    currentBlock.number
  );
  allPoolsDelegatorsUnique = Array.from(new Set(allPoolsDelegatorsUnique.concat(orderedWithdrawDelegatorsUnique)));
  console.log(`  stakingEpoch:               ${stakingEpoch}`);
  console.log(`  stakingEpochStartBlock:     ${stakingEpochStartBlock}`);
  console.log(`  stakingEpochEndBlock:       ${stakingEpochEndBlock} (at ~ ${stakingEpochEndTime.toUTCString()})`);
  console.log(`  orderedWithdrawAmountTotal: ${web3.utils.fromWei(orderedWithdrawAmountTotal)} (incl. ${web3.utils.fromWei(orderedWithdrawAmountTotalThisEpoch)} on this epoch)`);
  console.log(`  stakeAmountTotal:           ${web3.utils.fromWei(stakeAmountTotal)} (excl. orderedWithdrawAmountTotal)`);
  console.log(`  totalDelegators:            ${totalDelegators} (incl. ${totalOrderedWithdrawDelegators} who want to exit after this epoch; incl. pending delegators)`);
  console.log(`  totalDelegatorsUnique:      ${allPoolsDelegatorsUnique.length} (incl. ${orderedWithdrawDelegatorsUnique.length} who want to exit after this epoch; incl. pending delegators)`);
  if (program.showUnique) {
    const uniqueDelegatorsList = [];
    console.log('  uniqueDelegatorsList:');
    allPoolsDelegatorsUnique.forEach(delegator => {
      const delegatorLowercased = delegator.toLowerCase();
      const orderedAmount = howMuchStakerOrderedOnThisEpoch[delegatorLowercased] || new BN(0);
      const holdAmount = (howMuchDelegatorHolds[delegatorLowercased] || new BN(0)).add(orderedAmount);
      const exits = orderedWithdrawDelegatorsUnique.some(d => d.toLowerCase() == delegatorLowercased);
      uniqueDelegatorsList.push({ delegator, holdAmount, orderedAmount, exits });
    });
    uniqueDelegatorsList.sort((a, b) => {
      const cmpResult = b.holdAmount.cmp(a.holdAmount);
      if (cmpResult != 0) {
        return cmpResult;
      } else {
        return a.exits >= b.exits ? 1 : -1;
      }
    });
    uniqueDelegatorsList.forEach(({ delegator, holdAmount, orderedAmount, exits }, index) => {
      const delegatorLowercased = delegator.toLowerCase();
      let includingOrdered = '';
      if (!orderedAmount.isZero()) {
        includingOrdered = `, ordered ${toFixed(web3.utils.fromWei(orderedAmount), 2)} on this epoch`;
      }
      let wantsToExit = '';
      if (exits) {
        wantsToExit = ', wants to exit'
      }
      console.log(`    ${(index + 1).toString().padStart(2, ' ')}. ${delegator} (stakes ${toFixed(web3.utils.fromWei(holdAmount), 2)} tokens${includingOrdered}${wantsToExit})`);
    });
  }
  console.log();

  console.log('ValidatorSet');
  console.log(`  getValidators(${getValidators.length}):`);
  getValidators.forEach((miningAddress, index) => {
    console.log(`    ${(index + 1).toString().padStart(2, ' ')}. ${miningAddress}`);
  });
  console.log(`  getPendingValidators(${getPendingValidators.length}):`);
  getPendingValidators.forEach((miningAddress, index) => {
    console.log(`    ${(index + 1).toString().padStart(2, ' ')}. ${miningAddress}`);
  });
  console.log(`  validatorSetApplyBlock = ${validatorSetApplyBlock}`);
  console.log(`  unremovableValidator = ${unremovableValidator}`);
  console.log();

  console.log('Balance');
  console.log('  Native');
  console.log(`    blockRewardBalance = ${blockRewardNativeBalance}`);
  console.log('  Token');
  console.log(`    blockRewardBalance = ${blockRewardTokenBalance}`);
  console.log(`    stakingBalance = ${stakingBalance}`);
  console.log(`    totalSupply = ${totalSupply}`);

  console.log('==================================================================');
  process.exit(0);
}

async function countDelegators(stakingEpoch, poolDelegators, poolDelegatorsInactive, howMuchDelegatorHolds, blockNumber) {
  let totalDelegators = 0;
  for (let i = 0; i < validators.length; i++) {
    totalDelegators += poolDelegators[i].length;
  }
  const promises = [];
  const batch = new web3.BatchRequest();
  validators.forEach((validator, i) => {
    poolDelegatorsInactive[i].forEach(delegator => {
      promises.push(new Promise((resolve, reject) => {
        batch.add(Staking.methods.orderWithdrawEpoch(validator.stakingAddress, delegator).call.request({}, blockNumber, (err, result) => {
          if (err) reject(err);
          else resolve({ epoch: result, delegator });
        }));
      }));
    });
  });
  await batch.execute();
  const orderWithdrawEpoch = await Promise.all(promises);
  const allPoolsDelegatorsInactive = [];
  let totalOrderedWithdrawDelegators = 0;
  orderWithdrawEpoch.forEach(result => {
    if (result.epoch == stakingEpoch) {
      totalDelegators++;
      totalOrderedWithdrawDelegators++;
      if (!howMuchDelegatorHolds.hasOwnProperty(result.delegator.toLowerCase())) {
        allPoolsDelegatorsInactive.push(result.delegator);
      }
    }
  });
  const orderedWithdrawDelegatorsUnique = Array.from(new Set(allPoolsDelegatorsInactive));
  return {
    totalDelegators,
    totalOrderedWithdrawDelegators,
    orderedWithdrawDelegatorsUnique
  };
}

async function getAmounts(poolDelegators, stakingEpochStartBlock, blockNumber) {
  // Calculate total amount of tokens currently staked into
  // the current validator pools and total amount of tokens
  // ordered for withdrawal from the current validator pools
  let promises = [];
  let batch = new web3.BatchRequest();
  validators.forEach((validator, i) => {
    promises.push(new Promise((resolve, reject) => {
      batch.add(Staking.methods.stakeAmountTotal(validator.stakingAddress).call.request({}, blockNumber, (err, result) => {
        if (err) reject(err);
        else resolve({ stakeAmountTotal: result, i });
      }));
    }));
    promises.push(new Promise((resolve, reject) => {
      batch.add(Staking.methods.orderedWithdrawAmountTotal(validator.stakingAddress).call.request({}, blockNumber, (err, result) => {
        if (err) reject(err);
        else resolve({ orderedWithdrawAmountTotal: result, i });
      }));
    }));
  });
  await batch.execute();
  let items = await Promise.all(promises);
  let stakeAmountTotal = [], orderedWithdrawAmountTotal = [];
  items.forEach(result => {
    if (result.hasOwnProperty('stakeAmountTotal')) {
      stakeAmountTotal[result.i] = result.stakeAmountTotal;
    } else {
      orderedWithdrawAmountTotal[result.i] = result.orderedWithdrawAmountTotal;
    }
  });
  stakeAmountTotal = stakeAmountTotal.reduce((acc, val) => acc.add(new BN(val)), new BN(0));
  orderedWithdrawAmountTotal = orderedWithdrawAmountTotal.reduce((acc, val) => acc.add(new BN(val)), new BN(0));

  // Determine how much tokens each staker ordered to withdraw
  // during the current staking epoch from the current validator pools
  // and calculate the corresponding total ordered amount
  let orderedWithdrawAmountTotalThisEpoch = new BN(0);
  const howMuchStakerOrderedOnThisEpoch = {};
  const events = await Staking.getPastEvents('OrderedWithdrawal', { fromBlock: stakingEpochStartBlock, toBlock: blockNumber });
  events.forEach(event => {
    const eventAmount = new BN(event.returnValues.amount);
    if (validators.some(v => v.stakingAddress.toLowerCase() == event.returnValues.fromPoolStakingAddress.toLowerCase())) {
      const stakerAddress = event.returnValues.staker.toLowerCase();
      orderedWithdrawAmountTotalThisEpoch = orderedWithdrawAmountTotalThisEpoch.add(eventAmount);
      if (howMuchStakerOrderedOnThisEpoch.hasOwnProperty(stakerAddress)) {
        howMuchStakerOrderedOnThisEpoch[stakerAddress] = howMuchStakerOrderedOnThisEpoch[stakerAddress].add(eventAmount);
      } else {
        howMuchStakerOrderedOnThisEpoch[stakerAddress] = eventAmount;
      }
      //console.log(`OrderedWithdrawal: ${event.returnValues.fromPoolStakingAddress} - ${stakerAddress}: ${web3.utils.fromWei(eventAmount)}`);
    }
  });

  // Determine how much tokens each delegator currently holds
  // in the current validator pools
  const howMuchDelegatorHolds = {};
  promises = [];
  batch = new web3.BatchRequest();
  validators.forEach((validator, i) => {
    poolDelegators[i].forEach((delegator, j) => {
      promises.push(new Promise((resolve, reject) => {
        batch.add(Staking.methods.stakeAmount(validator.stakingAddress, delegator).call.request({}, blockNumber, (err, result) => {
          if (err) reject(err);
          else resolve({ i, j, stakeAmount: result });
        }));
      }));
    });
  });
  await batch.execute();
  items = await Promise.all(promises);
  items.forEach(item => {
    const delegator = poolDelegators[item.i][item.j].toLowerCase();
    const stakeAmount = new BN(item.stakeAmount);
    if (howMuchDelegatorHolds.hasOwnProperty(delegator)) {
      howMuchDelegatorHolds[delegator] = howMuchDelegatorHolds[delegator].add(stakeAmount);
    } else {
      howMuchDelegatorHolds[delegator] = stakeAmount;
    }
  });

  return {
    stakeAmountTotal,
    orderedWithdrawAmountTotal,
    orderedWithdrawAmountTotalThisEpoch,
    howMuchStakerOrderedOnThisEpoch,
    howMuchDelegatorHolds
  };
}

async function getBlocksCreatedAndRevealSkips(validators, stakingEpoch, blockNumber) {
  const promises = [];
  const batch = new web3.BatchRequest();
  validators.forEach((validator, i) => {
    promises.push(new Promise((resolve, reject) => {
      batch.add(BlockReward.methods.blocksCreated(stakingEpoch, validator.stakingAddress).call.request({}, blockNumber, (err, result) => {
        if (err) reject(err);
        else resolve({ blocksCreated: result, i });
      }));
    }));
    promises.push(new Promise((resolve, reject) => {
      batch.add(Random.methods.revealSkips(stakingEpoch, validator.miningAddress).call.request({}, blockNumber, (err, result) => {
        if (err) reject(err);
        else resolve({ revealSkips: result, i });
      }));
    }));
  });
  await batch.execute();
  const blocksCreatedAndRevealSkips = await Promise.all(promises);
  const blocksCreated = [], revealSkips = [];
  blocksCreatedAndRevealSkips.forEach(result => {
    if (result.hasOwnProperty('blocksCreated')) {
      blocksCreated[result.i] = result.blocksCreated;
    } else {
      revealSkips[result.i] = result.revealSkips;
    }
  });
  return { blocksCreated, revealSkips };
}

async function getCurrentValidators(miningAddresses, blockNumber) {
  const promises = [];
  const batch = new web3.BatchRequest();
  miningAddresses.forEach(miningAddress => {
    promises.push(new Promise((resolve, reject) => {
      batch.add(ValidatorSet.methods.stakingByMiningAddress(miningAddress).call.request({}, blockNumber, (err, result) => {
        if (err) reject(err);
        else resolve(result);
      }));
    }));
  });
  await batch.execute();
  const stakingAddresses = await Promise.all(promises);
  miningAddresses.forEach((miningAddress, index) => {
    const stakingAddress = stakingAddresses[index];
    const stakingAddressShort = stakingAddress.slice(0, 6) + '-' + stakingAddress.slice(-6);
    const name = knownNames[miningAddress] || stakingAddressShort;
    if (knownNames[miningAddress]) {
      knownNames[stakingAddress] = name;
    }
    validators.push({ miningAddress, stakingAddress, stakingAddressShort, name });
  });
}

async function getPoolDelegators(blockNumber) {
  const promises = [];
  const batch = new web3.BatchRequest();
  validators.forEach((validator, i) => {
    promises.push(new Promise((resolve, reject) => {
      batch.add(Staking.methods.poolDelegators(validator.stakingAddress).call.request({}, blockNumber, (err, result) => {
        if (err) reject(err);
        else resolve({ poolDelegators: result, i });
      }));
    }));
    promises.push(new Promise((resolve, reject) => {
      batch.add(Staking.methods.poolDelegatorsInactive(validator.stakingAddress).call.request({}, blockNumber, (err, result) => {
        if (err) reject(err);
        else resolve({ poolDelegatorsInactive: result, i });
      }));
    }));
  });
  await batch.execute();
  const items = await Promise.all(promises);
  const poolDelegators = [], poolDelegatorsInactive = [];
  items.forEach(result => {
    if (result.hasOwnProperty('poolDelegators')) {
      poolDelegators[result.i] = result.poolDelegators;
    } else {
      poolDelegatorsInactive[result.i] = result.poolDelegatorsInactive;
    }
  });
  let allPoolsDelegators = [];
  for (let i = 0; i < validators.length; i++) {
    allPoolsDelegators = allPoolsDelegators.concat(poolDelegators[i]);
  }
  const allPoolsDelegatorsUnique = Array.from(new Set(allPoolsDelegators));
  return { poolDelegators, allPoolsDelegatorsUnique, poolDelegatorsInactive };
}

async function showActiveDelegatorsByStakingEpoch(stakingEpoch, stakingEpochDuration, currentEpochNumber, currentEpochStartBlock, currentBlockNumber) {
  if (stakingEpoch > currentEpochNumber) {
    console.log('Unable to find any delegators for the given staking epoch');
    return;
  }
  const { startBlock, endBlock } = blocksByStakingEpochNumber(stakingEpoch, stakingEpochDuration, currentEpochNumber, currentEpochStartBlock);
  const blockNumber = endBlock > currentBlockNumber ? currentBlockNumber : endBlock;
  const miningAddresses = await ValidatorSet.methods.getValidators().call({}, blockNumber);
  let promises = [];
  let batch = new web3.BatchRequest();
  miningAddresses.forEach(miningAddress => {
    promises.push(new Promise((resolve, reject) => {
      batch.add(ValidatorSet.methods.stakingByMiningAddress(miningAddress).call.request({}, blockNumber, (err, result) => {
        if (err) reject(err);
        else resolve(result);
      }));
    }));
  });
  await batch.execute();
  const stakingAddresses = await Promise.all(promises);
  const miningByStakingAddress = {};
  promises = [];
  batch = new web3.BatchRequest();
  stakingAddresses.forEach((stakingAddress, index) => {
    miningByStakingAddress[stakingAddress] = miningAddresses[index];
    promises.push(new Promise((resolve, reject) => {
      batch.add(Staking.methods.poolDelegators(stakingAddress).call.request({}, startBlock - 1, (err, delegators) => {
        if (err) reject(err);
        else resolve({ stakingAddress, delegators });
      }));
    }));
  });
  await batch.execute();
  const poolDelegators = await Promise.all(promises);
  promises = [];
  batch = new web3.BatchRequest();
  poolDelegators.forEach(({ stakingAddress, delegators }) => {
    delegators.forEach(delegator => {
      promises.push(new Promise((resolve, reject) => {
        batch.add(Staking.methods.stakeAmount(stakingAddress, delegator).call.request({}, startBlock - 1, (err, amount) => {
          if (err) reject(err);
          else resolve({ stakingAddress, delegator, amount: new BN(amount) });
        }));
      }));
    });
  });
  await batch.execute();
  const amounts = await Promise.all(promises);
  amounts.sort((a, b) => b.amount.cmp(a.amount));
  const delegatorAmountByPool = {};
  const delegatorTotalAmount = {};
  amounts.forEach(({ stakingAddress, delegator, amount }) => {
  	if (!delegatorAmountByPool.hasOwnProperty(stakingAddress)) {
      delegatorAmountByPool[stakingAddress] = {};
    }
    delegatorAmountByPool[stakingAddress][delegator] = amount;
    if (delegatorTotalAmount.hasOwnProperty(delegator)) {
      delegatorTotalAmount[delegator] = delegatorTotalAmount[delegator].add(amount);
    } else {
      delegatorTotalAmount[delegator] = amount;
    }
  });
  const delegators = Object.keys(delegatorTotalAmount);
  if (delegators.length) {
    console.log(`Delegator list for the staking epoch # ${stakingEpoch} (does not include pending delegators):`);
    console.log();
    delegators.sort((a, b) => delegatorTotalAmount[b].cmp(delegatorTotalAmount[a]));
    console.log('------------------------------------------------------------------------------------');
    console.log('|     | Delegator                                  | Amount                        |');
    console.log('------------------------------------------------------------------------------------');
    delegators.forEach((delegator, index) => {
      console.log(`| ${(index + 1).toString().padStart(3, ' ')} | ${delegator} | ${web3.utils.fromWei(delegatorTotalAmount[delegator]).padEnd(29, ' ')} |`);
    });
    console.log('------------------------------------------------------------------------------------');
    console.log();
    console.log();

    console.log(`Delegators by each validator pool:`);
    console.log();
    console.log();
    for (const stakingAddress in delegatorAmountByPool) {
      let poolTotalAmount = new BN(0);
      const name = knownNames[stakingAddress] || knownNames[miningByStakingAddress[stakingAddress]];
      if (name) {
        console.log(`${name} [stakingAddress: ${stakingAddress}]`);
      } else {
        console.log(`Staking address: ${stakingAddress}`);
      }
      console.log('------------------------------------------------------------------------------------');
      console.log('|     | Delegator                                  | Amount                        |');
      console.log('------------------------------------------------------------------------------------');
      let index = 1;
      for (const delegator in delegatorAmountByPool[stakingAddress]) {
        const amount = delegatorAmountByPool[stakingAddress][delegator];
        console.log(`| ${(index++).toString().padStart(3, ' ')} | ${delegator} | ${web3.utils.fromWei(amount).padEnd(29, ' ')} |`);
        poolTotalAmount = poolTotalAmount.add(amount);
      }
      console.log('------------------------------------------------------------------------------------');
      console.log(`|     | Total:                                     | ${web3.utils.fromWei(poolTotalAmount).padEnd(29, ' ')} |`);
      console.log('------------------------------------------------------------------------------------');
      console.log();
      console.log();
    }
  } else {
    console.log('Unable to find any delegators for the given staking epoch');
  }
}

async function showAPY(currentStakingEpoch, currentStakingEpochStartBlock, stakingEpochDuration, currentBlockNumber, averageBlockTime, validatorSetApplyBlock) {
  if (currentStakingEpoch == 0) {
    console.log('Current approximate Annual Percentage Yield (APY) cannot be displayed for the initial (zero) staking epoch.');
    return;
  }
  if (validatorSetApplyBlock == 0) {
    console.log('Current approximate Annual Percentage Yield (APY) cannot be displayed at the very beginning of the staking epoch as the new validator set is not finalized yet. Please, try a bit later in a few blocks.');
    return;
  }
  const apyStartBlockNumber = validatorSetApplyBlock - 0 + validators.length * 10; // skip a few AuRa rounds
  if (currentBlockNumber < apyStartBlockNumber) {
    console.log(`Current approximate Annual Percentage Yield (APY) cannot be displayed at the very beginning of the staking epoch as we currently do not know blocks creating statistics. Please, try after block ${apyStartBlockNumber}`);
    return;
  }
  console.log(`Current approximate Annual Percentage Yield (APY) is calculated based on the current staking amounts (excluding pending amounts) for the current staking epoch ${currentStakingEpoch}.`);
  console.log();
  const epochsPerYear = new BN(Math.floor(31536000 / averageBlockTime / stakingEpochDuration));
  const rewardToDistribute = await BlockReward.methods.currentTokenRewardToDistribute(Staking.options.address, currentStakingEpoch, 0, 0, []).call({}, currentBlockNumber);
  console.log(`Reward to distribute (among all validator pools): ${web3.utils.fromWei(rewardToDistribute[0])} tokens`);
  console.log(`Predicted number of staking epochs in calendar year: ${epochsPerYear}`);
  console.log();
  console.log();
  const poolRewards = await BlockReward.methods.currentPoolRewards(rewardToDistribute[0], [], 0, currentStakingEpoch).call({}, currentBlockNumber);

  let promises = [];
  let batch = new web3.BatchRequest();
  validators.forEach(v => {
    promises.push(new Promise((resolve, reject) => {
      batch.add(Staking.methods.poolDelegators(v.stakingAddress).call.request({}, currentStakingEpochStartBlock - 1, (err, delegators) => {
        if (err) reject(err);
        else resolve(delegators);
      }));
    }));
  });
  await batch.execute();
  const poolDelegators = await Promise.all(promises);

  promises = [];
  batch = new web3.BatchRequest();
  poolDelegators.forEach((delegators, validatorIndex) => {
    const stakingAddress = validators[validatorIndex].stakingAddress;
    promises.push(new Promise((resolve, reject) => {
      batch.add(Staking.methods.stakeAmount(stakingAddress, stakingAddress).call.request({}, currentStakingEpochStartBlock - 1, (err, amount) => {
        if (err) reject(err);
        else resolve({ validatorIndex, staker: stakingAddress, amount: new BN(amount) });
      }));
    }));
    delegators.forEach(delegator => {
      promises.push(new Promise((resolve, reject) => {
        batch.add(Staking.methods.stakeAmount(stakingAddress, delegator).call.request({}, currentStakingEpochStartBlock - 1, (err, amount) => {
          if (err) reject(err);
          else resolve({ validatorIndex, staker: delegator, amount: new BN(amount) });
        }));
      }));
    });
  });
  await batch.execute();
  const amounts = await Promise.all(promises);

  const stakeAmounts = [];
  amounts.forEach(({ validatorIndex, staker, amount }) => {
    if (!stakeAmounts[validatorIndex]) {
      stakeAmounts[validatorIndex] = {};
    }
    stakeAmounts[validatorIndex][staker] = amount;
  });

  promises = [];
  batch = new web3.BatchRequest();
  poolDelegators.forEach((delegators, validatorIndex) => {
    const stakingAddress = validators[validatorIndex].stakingAddress;
    const validatorStaked = stakeAmounts[validatorIndex][stakingAddress];
    const totalStaked = delegators.reduce((acc, delegator) => acc.add(stakeAmounts[validatorIndex][delegator]), validatorStaked);
    const poolReward = poolRewards[validatorIndex];
    promises.push(new Promise((resolve, reject) => {
      batch.add(BlockReward.methods.validatorShare(currentStakingEpoch, validatorStaked.toString(), totalStaked.toString(), poolReward).call.request({}, currentBlockNumber, (err, reward) => {
        if (err) reject(err);
        else resolve({ validatorIndex, staker: stakingAddress, reward: new BN(reward) });
      }));
    }));
    delegators.forEach(delegator => {
      const delegatorStaked = stakeAmounts[validatorIndex][delegator];
      promises.push(new Promise((resolve, reject) => {
        batch.add(BlockReward.methods.delegatorShare(currentStakingEpoch, delegatorStaked.toString(), validatorStaked.toString(), totalStaked.toString(), poolReward).call.request({}, currentBlockNumber, (err, reward) => {
          if (err) reject(err);
          else resolve({ validatorIndex, staker: delegator, reward: new BN(reward) });
        }));
      }));
    });
  });
  await batch.execute();
  const rewards = await Promise.all(promises);

  const stakerRewards = [];
  rewards.forEach(({ validatorIndex, staker, reward }) => {
    if (!stakerRewards[validatorIndex]) {
      stakerRewards[validatorIndex] = {};
    }
    stakerRewards[validatorIndex][staker] = reward;
  });

  poolDelegators.forEach((delegators, validatorIndex) => {
    const miningAddress = validators[validatorIndex].miningAddress;
    const stakingAddress = validators[validatorIndex].stakingAddress;
    let rewardSum = new BN(0);
    let stakeAmountSum = new BN(0);

    let reward = stakerRewards[validatorIndex][stakingAddress];
    let stakeAmount = stakeAmounts[validatorIndex][stakingAddress];
    let percentagePerYear = parseFloat(web3.utils.fromWei(reward.mul(new BN('100000000000000000000')).div(stakeAmount).mul(epochsPerYear)));
    percentagePerYear = (Math.floor(percentagePerYear * 100) / 100).toString() + '%';
    rewardSum = rewardSum.add(reward);
    stakeAmountSum = stakeAmountSum.add(stakeAmount);
    console.log(`Validator ${knownNames[miningAddress]} [stakingAddress: ${stakingAddress}]`);
    console.log('-----------------------------------------------------------------------------------------------------------------------------');
    console.log('|     | Staker                                     | Non-pending stake, tokens     | Predicted reward, tokens      | ~APY   |');
    console.log('-----------------------------------------------------------------------------------------------------------------------------');
    console.log(`|   1 | ${stakingAddress} | ${web3.utils.fromWei(stakeAmount).padEnd(29, ' ')} | ${web3.utils.fromWei(reward).padEnd(29, ' ')} | ${percentagePerYear.padEnd(6, ' ')} |`);
    
    delegators.sort((a, b) => stakerRewards[validatorIndex][b].cmp(stakerRewards[validatorIndex][a]));
    delegators.forEach((delegator, index) => {
      reward = stakerRewards[validatorIndex][delegator];
      stakeAmount = stakeAmounts[validatorIndex][delegator];
      percentagePerYear = parseFloat(web3.utils.fromWei(reward.mul(new BN('100000000000000000000')).div(stakeAmount).mul(epochsPerYear)));
      percentagePerYear = (Math.floor(percentagePerYear * 100) / 100).toString() + '%';
      rewardSum = rewardSum.add(reward);
      stakeAmountSum = stakeAmountSum.add(stakeAmount);
      console.log(`| ${(index + 2).toString().padStart(3, ' ')} | ${delegator} | ${web3.utils.fromWei(stakeAmount).padEnd(29, ' ')} | ${web3.utils.fromWei(reward).padEnd(29, ' ')} | ${percentagePerYear.padEnd(6, ' ')} |`);
    });

    percentagePerYear = parseFloat(web3.utils.fromWei(rewardSum.mul(new BN('100000000000000000000')).div(stakeAmountSum).mul(epochsPerYear)));
    percentagePerYear = (Math.floor(percentagePerYear * 100) / 100).toString() + '%';
    console.log('-----------------------------------------------------------------------------------------------------------------------------');
    console.log(`|     | Total:                                     | ${web3.utils.fromWei(stakeAmountSum).padEnd(29, ' ')} | ${web3.utils.fromWei(rewardSum).padEnd(29, ' ')} | ${percentagePerYear.padEnd(6, ' ')} |`);
    console.log('-----------------------------------------------------------------------------------------------------------------------------');
    console.log();
    console.log();
  });
}

function blocksByStakingEpochNumber(stakingEpoch, stakingEpochDuration, currentEpochNumber, currentEpochStartBlock) {
  const diff = currentEpochNumber - stakingEpoch;
  const startBlock = currentEpochStartBlock - stakingEpochDuration * diff;
  const endBlock = stakingEpochDuration - 1 + startBlock;
  return { startBlock, endBlock };
}

function toFixed(x, n) {
  const v = (typeof x === 'string' ? x : x.toString()).split('.');
  if (n <= 0) return v[0];
  let f = v[1] || '';
  if (f.length > n) return `${v[0]}.${f.substr(0,n)}`;
  while (f.length < n) f += '0';
  return `${v[0]}.${f}`
}
