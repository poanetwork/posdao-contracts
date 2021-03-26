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

const BlockReward = new web3.eth.Contract([{"constant":true,"inputs":[{"name":"","type":"uint256"},{"name":"","type":"uint256"}],"name":"snapshotPoolTotalStakeAmount","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_tokenMinterContract","type":"address"}],"name":"setTokenMinterContract","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"_stakingEpoch","type":"uint256"},{"name":"_poolId","type":"uint256"}],"name":"getValidatorReward","outputs":[{"name":"tokenReward","type":"uint256"},{"name":"nativeReward","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_amount","type":"uint256"}],"name":"addBridgeTokenFeeReceivers","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_bridgesAllowed","type":"address[]"}],"name":"setErcToNativeBridgesAllowed","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"},{"name":"","type":"uint256"}],"name":"epochPoolNativeReward","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_rewardToDistribute","type":"uint256"},{"name":"_blocksCreatedShareNum","type":"uint256[]"},{"name":"_blocksCreatedShareDenom","type":"uint256"},{"name":"_stakingEpoch","type":"uint256"}],"name":"currentPoolRewards","outputs":[{"name":"","type":"uint256[]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_amount","type":"uint256"}],"name":"addBridgeNativeRewardReceivers","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"blockRewardContractId","outputs":[{"name":"","type":"bytes4"}],"payable":false,"stateMutability":"pure","type":"function"},{"constant":true,"inputs":[{"name":"_stakingContract","type":"address"},{"name":"_stakingEpoch","type":"uint256"},{"name":"_totalRewardShareNum","type":"uint256"},{"name":"_totalRewardShareDenom","type":"uint256"},{"name":"_validators","type":"uint256[]"}],"name":"currentNativeRewardToDistribute","outputs":[{"name":"","type":"uint256"},{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"address"},{"name":"","type":"uint256"}],"name":"mintedForAccountInBlock","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"isInitialized","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_poolId","type":"uint256"}],"name":"validatorRewardPercent","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"address"}],"name":"mintedForAccount","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"ercToNativeBridgesAllowed","outputs":[{"name":"","type":"address[]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_stakingContract","type":"address"},{"name":"_stakingEpoch","type":"uint256"},{"name":"_totalRewardShareNum","type":"uint256"},{"name":"_totalRewardShareDenom","type":"uint256"},{"name":"_validators","type":"uint256[]"}],"name":"currentTokenRewardToDistribute","outputs":[{"name":"","type":"uint256"},{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"}],"name":"mintedInBlock","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_validatorSet","type":"address"},{"name":"_prevBlockReward","type":"address"}],"name":"initialize","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"STAKE_TOKEN_INFLATION_RATE","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_poolStakingAddress","type":"address"},{"name":"_staker","type":"address"}],"name":"epochsToClaimRewardFrom","outputs":[{"name":"epochsToClaimFrom","type":"uint256[]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_amount","type":"uint256"}],"name":"addBridgeNativeFeeReceivers","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"mintedTotally","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_stakingEpoch","type":"uint256"},{"name":"_delegatorStaked","type":"uint256"},{"name":"_validatorStaked","type":"uint256"},{"name":"_totalStaked","type":"uint256"},{"name":"_poolReward","type":"uint256"}],"name":"delegatorShare","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_amount","type":"uint256"}],"name":"addBridgeTokenRewardReceivers","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_bridgesAllowed","type":"address[]"}],"name":"setNativeToErcBridgesAllowed","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"tokenRewardUndistributed","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_tokens","type":"uint256"},{"name":"_nativeCoins","type":"uint256"},{"name":"_to","type":"address"}],"name":"transferReward","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"},{"name":"","type":"uint256"}],"name":"snapshotPoolValidatorStakeAmount","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_stakingEpoch","type":"uint256"},{"name":"_validatorStaked","type":"uint256"},{"name":"_totalStaked","type":"uint256"},{"name":"_poolReward","type":"uint256"}],"name":"validatorShare","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_delegatorStake","type":"uint256"},{"name":"_stakingEpoch","type":"uint256"},{"name":"_poolId","type":"uint256"}],"name":"getDelegatorReward","outputs":[{"name":"tokenReward","type":"uint256"},{"name":"nativeReward","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_bridgesAllowed","type":"address[]"}],"name":"setErcToErcBridgesAllowed","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"ercToErcBridgesAllowed","outputs":[{"name":"","type":"address[]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"address"},{"name":"","type":"uint256"},{"name":"","type":"bytes"}],"name":"onTokenTransfer","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"pure","type":"function"},{"constant":true,"inputs":[],"name":"extraReceiversQueueSize","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_amount","type":"uint256"},{"name":"_receiver","type":"address"}],"name":"addExtraReceiver","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"bridgeNativeReward","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"nativeRewardUndistributed","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"nativeToErcBridgesAllowed","outputs":[{"name":"","type":"address[]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"address"}],"name":"mintedTotallyByBridge","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[],"name":"clearBlocksCreated","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"tokenMinterContract","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"}],"name":"validatorMinRewardPercent","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"validatorSetContract","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"},{"name":"","type":"uint256"}],"name":"epochPoolTokenReward","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_poolId","type":"uint256"}],"name":"epochsPoolGotRewardFor","outputs":[{"name":"","type":"uint256[]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"},{"name":"","type":"uint256"}],"name":"blocksCreated","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"benefactors","type":"address[]"},{"name":"kind","type":"uint16[]"}],"name":"reward","outputs":[{"name":"receiversNative","type":"address[]"},{"name":"rewardsNative","type":"uint256[]"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"bridgeTokenReward","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"payable":true,"stateMutability":"payable","type":"fallback"},{"anonymous":false,"inputs":[{"indexed":false,"name":"amount","type":"uint256"},{"indexed":false,"name":"cumulativeAmount","type":"uint256"},{"indexed":true,"name":"bridge","type":"address"}],"name":"BridgeTokenRewardAdded","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"amount","type":"uint256"},{"indexed":true,"name":"receiver","type":"address"},{"indexed":true,"name":"bridge","type":"address"}],"name":"AddedReceiver","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"amount","type":"uint256"},{"indexed":false,"name":"cumulativeAmount","type":"uint256"},{"indexed":true,"name":"bridge","type":"address"}],"name":"BridgeNativeRewardAdded","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"receivers","type":"address[]"},{"indexed":false,"name":"rewards","type":"uint256[]"}],"name":"MintedNative","type":"event"}], '0x481c034c6d9441db23Ea48De68BCAe812C5d39bA');
const Random = new web3.eth.Contract([{"constant":true,"inputs":[],"name":"collectRoundLength","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"punishForUnreveal","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"currentSeed","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"validatorSetContract","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_numberHash","type":"bytes32"},{"name":"_cipher","type":"bytes"}],"name":"commitHash","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_number","type":"uint256"}],"name":"revealNumber","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_number","type":"uint256"}],"name":"revealSecret","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_punishForUnreveal","type":"bool"}],"name":"setPunishForUnreveal","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_collectRoundLength","type":"uint256"},{"name":"_validatorSet","type":"address"},{"name":"_punishForUnreveal","type":"bool"}],"name":"initialize","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[],"name":"onFinishCollectRound","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"commitPhaseLength","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"currentCollectRound","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"currentCollectRoundStartBlock","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_collectRound","type":"uint256"},{"name":"_miningAddress","type":"address"}],"name":"getCipher","outputs":[{"name":"","type":"bytes"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_collectRound","type":"uint256"},{"name":"_miningAddress","type":"address"}],"name":"getCommit","outputs":[{"name":"","type":"bytes32"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_collectRound","type":"uint256"},{"name":"_miningAddress","type":"address"}],"name":"getCommitAndCipher","outputs":[{"name":"","type":"bytes32"},{"name":"","type":"bytes"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_collectRound","type":"uint256"},{"name":"_miningAddress","type":"address"}],"name":"isCommitted","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"isCommitPhase","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"isInitialized","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"isRevealPhase","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_miningAddress","type":"address"},{"name":"_numberHash","type":"bytes32"}],"name":"commitHashCallable","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"nextCollectRoundStartBlock","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"nextCommitPhaseStartBlock","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"nextRevealPhaseStartBlock","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_miningAddress","type":"address"},{"name":"_number","type":"uint256"}],"name":"revealNumberCallable","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_miningAddress","type":"address"},{"name":"_number","type":"uint256"}],"name":"revealSecretCallable","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_stakingEpoch","type":"uint256"},{"name":"_miningAddress","type":"address"}],"name":"revealSkips","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_collectRound","type":"uint256"},{"name":"_miningAddress","type":"address"}],"name":"sentReveal","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"}], '0x5870b0527DeDB1cFBD9534343Feda1a41Ce47766');
const Staking = new web3.eth.Contract([{"constant":true,"inputs":[{"name":"","type":"uint256"},{"name":"","type":"address"}],"name":"poolDelegatorIndex","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_totalAmount","type":"uint256"}],"name":"initialValidatorStake","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"_poolId","type":"uint256"},{"name":"_delegatorOrZero","type":"address"}],"name":"stakeAmountByCurrentEpoch","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"},{"name":"","type":"address"}],"name":"poolDelegatorInactiveIndex","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[],"name":"removePools","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"},{"name":"","type":"address"},{"name":"","type":"uint256"}],"name":"rewardWasTaken","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_blockNumber","type":"uint256"}],"name":"setStakingEpochStartBlock","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_fromPoolStakingAddress","type":"address"},{"name":"_toPoolStakingAddress","type":"address"},{"name":"_amount","type":"uint256"}],"name":"moveStake","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"},{"name":"","type":"address"}],"name":"stakeFirstEpoch","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"}],"name":"stakeAmountTotal","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_minStake","type":"uint256"}],"name":"setDelegatorMinStake","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"erc677TokenContract","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_delegator","type":"address"},{"name":"_offset","type":"uint256"},{"name":"_length","type":"uint256"}],"name":"getDelegatorPools","outputs":[{"name":"result","type":"uint256[]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_unremovablePoolId","type":"uint256"}],"name":"clearUnremovableValidator","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_amount","type":"uint256"},{"name":"_miningAddress","type":"address"}],"name":"addPool","outputs":[{"name":"","type":"uint256"}],"payable":true,"stateMutability":"payable","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"},{"name":"","type":"address"}],"name":"stakeLastEpoch","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"isInitialized","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_stakingEpochs","type":"uint256[]"},{"name":"_poolStakingAddress","type":"address"}],"name":"claimReward","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"},{"name":"","type":"address"}],"name":"stakeAmount","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"}],"name":"orderedWithdrawAmountTotal","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_minStake","type":"uint256"}],"name":"setCandidateMinStake","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"_poolId","type":"uint256"}],"name":"poolDelegators","outputs":[{"name":"","type":"address[]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_erc677TokenContract","type":"address"}],"name":"setErc677TokenContract","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"candidateMinStake","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getPools","outputs":[{"name":"","type":"uint256[]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_poolStakingAddress","type":"address"},{"name":"_staker","type":"address"}],"name":"maxWithdrawAllowed","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"},{"name":"","type":"address"},{"name":"","type":"uint256"}],"name":"delegatorStakeSnapshot","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"}],"name":"poolInactiveIndex","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"stakingEpochStartBlock","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"lastChangeBlock","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"stakingEpoch","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_delegator","type":"address"}],"name":"getDelegatorPoolsLength","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"stakingEpochEndBlock","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_poolStakingAddress","type":"address"},{"name":"_staker","type":"address"}],"name":"maxWithdrawOrderAllowed","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getPoolsLikelihood","outputs":[{"name":"likelihoods","type":"uint256[]"},{"name":"sum","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"stakeWithdrawDisallowPeriod","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"}],"name":"poolToBeElectedIndex","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_poolId","type":"uint256"}],"name":"poolDelegatorsInactive","outputs":[{"name":"","type":"address[]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_poolId","type":"uint256"}],"name":"removePool","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_staker","type":"address"},{"name":"_amount","type":"uint256"},{"name":"_data","type":"bytes"}],"name":"onTokenTransfer","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"getPoolsToBeElected","outputs":[{"name":"","type":"uint256[]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_validatorSetContract","type":"address"},{"name":"_initialIds","type":"uint256[]"},{"name":"_delegatorMinStake","type":"uint256"},{"name":"_candidateMinStake","type":"uint256"},{"name":"_stakingEpochDuration","type":"uint256"},{"name":"_stakingEpochStartBlock","type":"uint256"},{"name":"_stakeWithdrawDisallowPeriod","type":"uint256"}],"name":"initialize","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_toPoolStakingAddress","type":"address"},{"name":"_amount","type":"uint256"}],"name":"stake","outputs":[],"payable":true,"stateMutability":"payable","type":"function"},{"constant":false,"inputs":[{"name":"_poolStakingAddress","type":"address"},{"name":"_amount","type":"int256"}],"name":"orderWithdraw","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"_poolId","type":"uint256"}],"name":"isPoolActive","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"}],"name":"poolToBeRemovedIndex","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"}],"name":"poolIndex","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_poolStakingAddress","type":"address"}],"name":"claimOrderedWithdraw","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"getPoolsToBeRemoved","outputs":[{"name":"","type":"uint256[]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"},{"name":"","type":"address"}],"name":"orderWithdrawEpoch","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"stakingEpochDuration","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"delegatorMinStake","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getPoolsInactive","outputs":[{"name":"","type":"uint256[]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"validatorSetContract","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"},{"name":"","type":"address"}],"name":"orderedWithdrawAmount","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[],"name":"removeMyPool","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[],"name":"incrementStakingEpoch","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"MAX_CANDIDATES","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_fromPoolStakingAddress","type":"address"},{"name":"_amount","type":"uint256"}],"name":"withdraw","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"areStakeAndWithdrawAllowed","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_stakingEpochs","type":"uint256[]"},{"name":"_poolStakingAddress","type":"address"},{"name":"_staker","type":"address"}],"name":"getRewardAmount","outputs":[{"name":"tokenRewardSum","type":"uint256"},{"name":"nativeRewardSum","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"payable":true,"stateMutability":"payable","type":"fallback"},{"anonymous":false,"inputs":[{"indexed":true,"name":"fromPoolStakingAddress","type":"address"},{"indexed":true,"name":"staker","type":"address"},{"indexed":true,"name":"stakingEpoch","type":"uint256"},{"indexed":false,"name":"tokensAmount","type":"uint256"},{"indexed":false,"name":"nativeCoinsAmount","type":"uint256"},{"indexed":false,"name":"fromPoolId","type":"uint256"}],"name":"ClaimedReward","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"poolStakingAddress","type":"address"},{"indexed":true,"name":"poolMiningAddress","type":"address"},{"indexed":false,"name":"poolId","type":"uint256"}],"name":"AddedPool","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"fromPoolStakingAddress","type":"address"},{"indexed":true,"name":"staker","type":"address"},{"indexed":true,"name":"stakingEpoch","type":"uint256"},{"indexed":false,"name":"amount","type":"uint256"},{"indexed":false,"name":"fromPoolId","type":"uint256"}],"name":"ClaimedOrderedWithdrawal","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"fromPoolStakingAddress","type":"address"},{"indexed":true,"name":"toPoolStakingAddress","type":"address"},{"indexed":true,"name":"staker","type":"address"},{"indexed":true,"name":"stakingEpoch","type":"uint256"},{"indexed":false,"name":"amount","type":"uint256"},{"indexed":false,"name":"fromPoolId","type":"uint256"},{"indexed":false,"name":"toPoolId","type":"uint256"}],"name":"MovedStake","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"fromPoolStakingAddress","type":"address"},{"indexed":true,"name":"staker","type":"address"},{"indexed":true,"name":"stakingEpoch","type":"uint256"},{"indexed":false,"name":"amount","type":"int256"},{"indexed":false,"name":"fromPoolId","type":"uint256"}],"name":"OrderedWithdrawal","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"toPoolStakingAddress","type":"address"},{"indexed":true,"name":"staker","type":"address"},{"indexed":true,"name":"stakingEpoch","type":"uint256"},{"indexed":false,"name":"amount","type":"uint256"},{"indexed":false,"name":"toPoolId","type":"uint256"}],"name":"PlacedStake","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"name":"fromPoolStakingAddress","type":"address"},{"indexed":true,"name":"staker","type":"address"},{"indexed":true,"name":"stakingEpoch","type":"uint256"},{"indexed":false,"name":"amount","type":"uint256"},{"indexed":false,"name":"fromPoolId","type":"uint256"}],"name":"WithdrewStake","type":"event"}], '0x2DdB8A7541e6cAA50F74e7FACFF9Fe9da00e0A6c');
const ValidatorSet = new web3.eth.Contract([{"constant":true,"inputs":[{"name":"","type":"address"}],"name":"miningByStakingAddress","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"}],"name":"stakingAddressById","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"address"}],"name":"stakingByMiningAddress","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"address"}],"name":"idByMiningAddress","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"blockRewardContract","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"address"}],"name":"hasEverBeenStakingAddress","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"unremovableValidator","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"MAX_VALIDATORS","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"lastChangeBlock","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"address"}],"name":"hasEverBeenMiningAddress","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"}],"name":"isValidatorById","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"address"}],"name":"idByStakingAddress","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"lastPoolId","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"validatorSetApplyBlock","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"randomContract","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"changeRequestCount","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"}],"name":"miningAddressById","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"stakingContract","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"anonymous":false,"inputs":[{"indexed":true,"name":"parentHash","type":"bytes32"},{"indexed":false,"name":"newSet","type":"address[]"}],"name":"InitiateChange","type":"event"},{"anonymous":false,"inputs":[{"indexed":false,"name":"reportingValidator","type":"address"},{"indexed":false,"name":"maliciousValidator","type":"address"},{"indexed":false,"name":"blockNumber","type":"uint256"},{"indexed":false,"name":"reportingPoolId","type":"uint256"},{"indexed":false,"name":"maliciousPoolId","type":"uint256"}],"name":"ReportedMalicious","type":"event"},{"constant":false,"inputs":[],"name":"clearUnremovableValidator","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[],"name":"emitInitiateChange","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[],"name":"finalizeChange","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_blockRewardContract","type":"address"},{"name":"_randomContract","type":"address"},{"name":"_stakingContract","type":"address"},{"name":"_initialMiningAddresses","type":"address[]"},{"name":"_initialStakingAddresses","type":"address[]"},{"name":"_firstValidatorIsUnremovable","type":"bool"}],"name":"initialize","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[],"name":"newValidatorSet","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_miningAddresses","type":"address[]"}],"name":"removeMaliciousValidators","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_maliciousMiningAddress","type":"address"},{"name":"_blockNumber","type":"uint256"},{"name":"","type":"bytes"}],"name":"reportMalicious","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"_miningAddress","type":"address"},{"name":"_stakingAddress","type":"address"}],"name":"addPool","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[{"name":"_miningAddress","type":"address"}],"name":"areDelegatorsBanned","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_poolId","type":"uint256"}],"name":"areIdDelegatorsBanned","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_miningAddress","type":"address"}],"name":"banCounter","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_miningAddress","type":"address"}],"name":"bannedUntil","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_miningAddress","type":"address"}],"name":"bannedDelegatorsUntil","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_miningAddress","type":"address"}],"name":"banReason","outputs":[{"name":"","type":"bytes32"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"emitInitiateChangeCallable","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getPendingValidators","outputs":[{"name":"","type":"address[]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getPendingValidatorsIds","outputs":[{"name":"","type":"uint256[]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getValidators","outputs":[{"name":"","type":"address[]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getValidatorsIds","outputs":[{"name":"","type":"uint256[]"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"initiateChangeAllowed","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"isInitialized","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_miningAddress","type":"address"}],"name":"isValidator","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_miningAddress","type":"address"}],"name":"isReportValidatorValid","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_miningAddress","type":"address"}],"name":"isValidatorBanned","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_poolId","type":"uint256"}],"name":"isValidatorIdBanned","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_poolId","type":"uint256"}],"name":"isValidatorOrPending","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_reportingMiningAddress","type":"address"},{"name":"_maliciousMiningAddress","type":"address"},{"name":"_blockNumber","type":"uint256"}],"name":"reportMaliciousCallable","outputs":[{"name":"callable","type":"bool"},{"name":"removeReportingValidator","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_reportingMiningAddress","type":"address"},{"name":"_maliciousMiningAddress","type":"address"},{"name":"_blockNumber","type":"uint256"}],"name":"shouldValidatorReport","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_miningAddress","type":"address"}],"name":"validatorCounter","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"validatorsToBeFinalized","outputs":[{"name":"miningAddresses","type":"address[]"},{"name":"forNewEpoch","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"validatorsToBeFinalizedIds","outputs":[{"name":"","type":"uint256[]"}],"payable":false,"stateMutability":"view","type":"function"}], '0xB87BE9f7196F2AE084Ca1DE6af5264292976e013');
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
  '0xb76756f95A9fB6ff9ad3E6cb41b734c1bd805103': 'Portis',
  '0x0000999dc55126CA626c20377F0045946db69b6E': 'Galt Project',
  '0x9488f50c33e9616EE3B5B09CD3A9c603A108db4a': 'POA Network 2',
  '0x1A740616e96E07d86203707C1619d9871614922A': 'Nethermind',
  '0x642C40173134f6E457a62D4C2033259433A53E8C': 'xDaiDev',
  '0x35770EF700Ff88D5f650597068e3Aaf051F3D5a4': '1Hive',
  '0x1438087186FdbFd4c256Fa2DF446921E30E54Df8': 'Gnosis',
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
  const { blocksCreated, revealSkips } = await getBlocksCreatedAndRevealSkips(stakingEpoch, currentBlock.number);
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
  getPools.forEach((poolId, index) => {
    console.log(`    ${(index + 1).toString().padStart(2, ' ')}. ${poolId}`);
  });
  console.log(`  getPoolsToBeElected(${getPoolsToBeElected.length}):`);
  getPoolsToBeElected.forEach((poolId, index) => {
    console.log(`    ${(index + 1).toString().padStart(2, ' ')}. ${poolId}`);
  });
  if (getPoolsToBeRemoved.length) {
    console.log(`  getPoolsToBeRemoved(${getPoolsToBeRemoved.length}):`);
    getPoolsToBeRemoved.forEach((poolId, index) => {
      console.log(`    ${(index + 1).toString().padStart(2, ' ')}. ${poolId}`);
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
        batch.add(Staking.methods.orderWithdrawEpoch(validator.poolId, delegator).call.request({}, blockNumber, (err, result) => {
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
      batch.add(Staking.methods.stakeAmountTotal(validator.poolId).call.request({}, blockNumber, (err, result) => {
        if (err) reject(err);
        else resolve({ stakeAmountTotal: result, i });
      }));
    }));
    promises.push(new Promise((resolve, reject) => {
      batch.add(Staking.methods.orderedWithdrawAmountTotal(validator.poolId).call.request({}, blockNumber, (err, result) => {
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
    if (validators.some(v => v.poolId == event.returnValues.fromPoolId)) {
      const stakerAddress = event.returnValues.staker.toLowerCase();
      orderedWithdrawAmountTotalThisEpoch = orderedWithdrawAmountTotalThisEpoch.add(eventAmount);
      if (howMuchStakerOrderedOnThisEpoch.hasOwnProperty(stakerAddress)) {
        howMuchStakerOrderedOnThisEpoch[stakerAddress] = howMuchStakerOrderedOnThisEpoch[stakerAddress].add(eventAmount);
      } else {
        howMuchStakerOrderedOnThisEpoch[stakerAddress] = eventAmount;
      }
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
        batch.add(Staking.methods.stakeAmount(validator.poolId, delegator).call.request({}, blockNumber, (err, result) => {
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

async function getBlocksCreatedAndRevealSkips(stakingEpoch, blockNumber) {
  const promises = [];
  const batch = new web3.BatchRequest();
  validators.forEach((validator, i) => {
    promises.push(new Promise((resolve, reject) => {
      batch.add(BlockReward.methods.blocksCreated(stakingEpoch, validator.poolId).call.request({}, blockNumber, (err, result) => {
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
  promises = [];
  batch = new web3.BatchRequest();
  miningAddresses.forEach(miningAddress => {
    promises.push(new Promise((resolve, reject) => {
      batch.add(ValidatorSet.methods.idByMiningAddress(miningAddress).call.request({}, blockNumber, (err, result) => {
        if (err) reject(err);
        else resolve(result);
      }));
    }));
  });
  await batch.execute();
  const poolIds = await Promise.all(promises);
  miningAddresses.forEach((miningAddress, index) => {
    const stakingAddress = stakingAddresses[index];
    const stakingAddressShort = stakingAddress.slice(0, 6) + '-' + stakingAddress.slice(-6);
    const name = knownNames[miningAddress] || stakingAddressShort;
    if (knownNames[miningAddress]) {
      knownNames[stakingAddress] = name;
    }
    validators.push({ miningAddress, stakingAddress, stakingAddressShort, name, poolId: poolIds[index] });
  });
}

async function getPoolDelegators(blockNumber) {
  const promises = [];
  const batch = new web3.BatchRequest();
  validators.forEach((validator, i) => {
    promises.push(new Promise((resolve, reject) => {
      batch.add(Staking.methods.poolDelegators(validator.poolId).call.request({}, blockNumber, (err, result) => {
        if (err) reject(err);
        else resolve({ poolDelegators: result, i });
      }));
    }));
    promises.push(new Promise((resolve, reject) => {
      batch.add(Staking.methods.poolDelegatorsInactive(validator.poolId).call.request({}, blockNumber, (err, result) => {
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

  let promises = [];
  let batch = new web3.BatchRequest();
  promises.push(new Promise((resolve, reject) => {
    batch.add(ValidatorSet.methods.getValidators().call.request({}, blockNumber, (err, result) => {
      if (err) reject(err);
      else resolve(result);
    }));
  }));
  promises.push(new Promise((resolve, reject) => {
    batch.add(ValidatorSet.methods.getValidatorsIds().call.request({}, blockNumber, (err, result) => {
      if (err) reject(err);
      else resolve(result);
    }));
  }));
  await batch.execute();
  const [miningAddresses, poolIds] = await Promise.all(promises);
  
  promises = [];
  batch = new web3.BatchRequest();
  poolIds.forEach(poolId => {
    promises.push(new Promise((resolve, reject) => {
      batch.add(ValidatorSet.methods.stakingAddressById(poolId).call.request({}, blockNumber, (err, result) => {
        if (err) reject(err);
        else resolve(result);
      }));
    }));
  });
  await batch.execute();
  const stakingAddresses = await Promise.all(promises);
  const miningAddressById = {};
  const stakingAddressById = {};
  promises = [];
  batch = new web3.BatchRequest();
  stakingAddresses.forEach((stakingAddress, index) => {
  	const poolId = poolIds[index];
    miningAddressById[poolId] = miningAddresses[index];
    stakingAddressById[poolId] = stakingAddress;
    promises.push(new Promise((resolve, reject) => {
      batch.add(Staking.methods.poolDelegators(poolId).call.request({}, startBlock - 1, (err, delegators) => {
        if (err) reject(err);
        else resolve({ poolId, delegators });
      }));
    }));
  });
  await batch.execute();
  const poolDelegators = await Promise.all(promises);
  promises = [];
  batch = new web3.BatchRequest();
  poolDelegators.forEach(({ poolId, delegators }) => {
    delegators.forEach(delegator => {
      promises.push(new Promise((resolve, reject) => {
        batch.add(Staking.methods.stakeAmount(poolId, delegator).call.request({}, startBlock - 1, (err, amount) => {
          if (err) reject(err);
          else resolve({ poolId, delegator, amount: new BN(amount) });
        }));
      }));
    });
  });
  await batch.execute();
  const amounts = await Promise.all(promises);
  amounts.sort((a, b) => b.amount.cmp(a.amount));
  const delegatorAmountByPool = {};
  const delegatorTotalAmount = {};
  amounts.forEach(({ poolId, delegator, amount }) => {
  	if (!delegatorAmountByPool.hasOwnProperty(poolId)) {
      delegatorAmountByPool[poolId] = {};
    }
    delegatorAmountByPool[poolId][delegator] = amount;
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
    for (const poolId in delegatorAmountByPool) {
      const stakingAddress = stakingAddressById[poolId];
      let poolTotalAmount = new BN(0);
      const name = knownNames[stakingAddress] || knownNames[miningAddressById[poolId]];
      if (name) {
        console.log(`${name} [stakingAddress: ${stakingAddress}, poolId: ${poolId}]`);
      } else {
        console.log(`Staking address: ${stakingAddress}, poolId: ${poolId}`);
      }
      console.log('------------------------------------------------------------------------------------');
      console.log('|     | Delegator                                  | Amount                        |');
      console.log('------------------------------------------------------------------------------------');
      let index = 1;
      for (const delegator in delegatorAmountByPool[poolId]) {
        const amount = delegatorAmountByPool[poolId][delegator];
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
      batch.add(Staking.methods.poolDelegators(v.poolId).call.request({}, currentStakingEpochStartBlock - 1, (err, delegators) => {
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
    const poolId = validators[validatorIndex].poolId;
    const stakingAddress = validators[validatorIndex].stakingAddress;
    promises.push(new Promise((resolve, reject) => {
      batch.add(Staking.methods.stakeAmount(poolId, '0x0000000000000000000000000000000000000000').call.request({}, currentStakingEpochStartBlock - 1, (err, amount) => {
        if (err) reject(err);
        else resolve({ validatorIndex, staker: stakingAddress, amount: new BN(amount) });
      }));
    }));
    delegators.forEach(delegator => {
      promises.push(new Promise((resolve, reject) => {
        batch.add(Staking.methods.stakeAmount(poolId, delegator).call.request({}, currentStakingEpochStartBlock - 1, (err, amount) => {
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
    const poolId = validators[validatorIndex].poolId;
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
    console.log(`Validator ${knownNames[miningAddress]} [stakingAddress: ${stakingAddress}, poolId: ${poolId}]`);
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
