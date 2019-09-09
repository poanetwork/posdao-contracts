const BlockRewardAuRa = artifacts.require('BlockRewardAuRaMock');
const ERC677BridgeTokenRewardable = artifacts.require('ERC677BridgeTokenRewardableMock');
const AdminUpgradeabilityProxy = artifacts.require('AdminUpgradeabilityProxy');
const RandomAuRa = artifacts.require('RandomAuRaMock');
const ValidatorSetAuRa = artifacts.require('ValidatorSetAuRaMock');
const StakingAuRa = artifacts.require('StakingAuRaMock');

const ERROR_MSG = 'VM Exception while processing transaction: revert';
const BN = web3.utils.BN;

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bn')(BN))
  .should();

contract('BlockRewardAuRa', async accounts => {
  let owner;
  let blockRewardAuRa;
  let randomAuRa;
  let stakingAuRa;
  let validatorSetAuRa;
  let erc20Token;
  let candidateMinStake;
  let delegatorMinStake;

  const COLLECT_ROUND_LENGTH = 114;
  const STAKING_EPOCH_DURATION = 120954;
  const STAKING_EPOCH_START_BLOCK = STAKING_EPOCH_DURATION * 10 + 1;
  const STAKE_WITHDRAW_DISALLOW_PERIOD = 4320;

  describe('reward()', async () => {
    it('network started', async () => {
      owner = accounts[0];

      const initialValidators = accounts.slice(1, 3 + 1); // accounts[1...3]
      const initialStakingAddresses = accounts.slice(4, 6 + 1); // accounts[4...6]
      initialStakingAddresses.length.should.be.equal(3);
      initialStakingAddresses[0].should.not.be.equal('0x0000000000000000000000000000000000000000');
      initialStakingAddresses[1].should.not.be.equal('0x0000000000000000000000000000000000000000');
      initialStakingAddresses[2].should.not.be.equal('0x0000000000000000000000000000000000000000');
      // Deploy BlockRewardAuRa contract
      blockRewardAuRa = await BlockRewardAuRa.new();
      blockRewardAuRa = await AdminUpgradeabilityProxy.new(blockRewardAuRa.address, owner, []);
      blockRewardAuRa = await BlockRewardAuRa.at(blockRewardAuRa.address);
      // Deploy RandomAuRa contract
      randomAuRa = await RandomAuRa.new();
      randomAuRa = await AdminUpgradeabilityProxy.new(randomAuRa.address, owner, []);
      randomAuRa = await RandomAuRa.at(randomAuRa.address);
      // Deploy StakingAuRa contract
      stakingAuRa = await StakingAuRa.new();
      stakingAuRa = await AdminUpgradeabilityProxy.new(stakingAuRa.address, owner, []);
      stakingAuRa = await StakingAuRa.at(stakingAuRa.address);
      // Deploy ValidatorSetAuRa contract
      validatorSetAuRa = await ValidatorSetAuRa.new();
      validatorSetAuRa = await AdminUpgradeabilityProxy.new(validatorSetAuRa.address, owner, []);
      validatorSetAuRa = await ValidatorSetAuRa.at(validatorSetAuRa.address);

      // Initialize ValidatorSetAuRa
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        randomAuRa.address, // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false // _firstValidatorIsUnremovable
      ).should.be.fulfilled;

      // Initialize StakingAuRa
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        STAKING_EPOCH_DURATION, // _stakingEpochDuration
        STAKING_EPOCH_START_BLOCK, // _stakingEpochStartBlock
        STAKE_WITHDRAW_DISALLOW_PERIOD, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.fulfilled;

      candidateMinStake = await stakingAuRa.candidateMinStake.call();
      delegatorMinStake = await stakingAuRa.delegatorMinStake.call();

      // Initialize BlockRewardAuRa
      await blockRewardAuRa.initialize(
        validatorSetAuRa.address
      ).should.be.fulfilled;

      // Initialize RandomAuRa
      await randomAuRa.initialize(
        COLLECT_ROUND_LENGTH,
        validatorSetAuRa.address
      ).should.be.fulfilled;

      // Start the network
      await setCurrentBlockNumber(STAKING_EPOCH_START_BLOCK);
      await callFinalizeChange();
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK));

      // Deploy ERC20 contract
      erc20Token = await ERC677BridgeTokenRewardable.new("POSDAO20", "POSDAO20", 18, {from: owner});
      await stakingAuRa.setErc20TokenContract(erc20Token.address, {from: owner}).should.be.fulfilled;
      await erc20Token.setBlockRewardContract(blockRewardAuRa.address).should.be.fulfilled;
      await erc20Token.setStakingContract(stakingAuRa.address).should.be.fulfilled;
    });

    it('staking epoch #0 finished', async () => {
      const stakingEpoch = await stakingAuRa.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(0));

      const stakingEpochEndBlock = (await stakingAuRa.stakingEpochStartBlock.call()).add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      const validators = await validatorSetAuRa.getValidators.call();
      for (let i = 0; i < validators.length; i++) {
        await randomAuRa.setSentReveal(validators[i]).should.be.fulfilled;
      }

      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      await callReward();
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(stakingEpoch.add(new BN(1)));
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(true);
    });

    it('staking epoch #1 started', async () => {
      const validators = await validatorSetAuRa.getValidators.call();

      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      await setCurrentBlockNumber(stakingEpochStartBlock);

      const {logs} = await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.be.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal(validators);

      const validatorsToBeFinalized = await validatorSetAuRa.validatorsToBeFinalized.call();
      validatorsToBeFinalized.miningAddresses.should.be.deep.equal(validators);
      validatorsToBeFinalized.forNewEpoch.should.be.equal(true);

      const currentBlock = stakingEpochStartBlock.add(new BN(Math.floor(validators.length / 2) + 1));
      await setCurrentBlockNumber(currentBlock);

      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      await callFinalizeChange();
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(currentBlock);
      (await validatorSetAuRa.getValidators.call()).should.be.deep.equal(validators);
    });

    it('validators and their delegators place stakes during the epoch #1', async () => {
      const validators = await validatorSetAuRa.getValidators.call();

      for (let i = 0; i < validators.length; i++) {
        // Mint some balance for each validator (imagine that each validator got the tokens from a bridge)
        const stakingAddress = await validatorSetAuRa.stakingByMiningAddress.call(validators[i]);
        await erc20Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc20Token.balanceOf.call(stakingAddress));

        // Validator places stake on themselves
        await stakingAuRa.stake(stakingAddress, candidateMinStake, {from: stakingAddress}).should.be.fulfilled;

        const delegatorsLength = 3;
        const delegators = accounts.slice(11 + i*delegatorsLength, 11 + i*delegatorsLength + delegatorsLength);
        for (let j = 0; j < delegators.length; j++) {
          // Mint some balance for each delegator (imagine that each delegator got the tokens from a bridge)
          await erc20Token.mint(delegators[j], delegatorMinStake, {from: owner}).should.be.fulfilled;
          delegatorMinStake.should.be.bignumber.equal(await erc20Token.balanceOf.call(delegators[j]));

          // Delegator places stake on the validator
          await stakingAuRa.stake(stakingAddress, delegatorMinStake, {from: delegators[j]}).should.be.fulfilled;
        }
      }
    });

    it('bridge fee accumulated during the epoch #1', async () => {
      await accrueBridgeFees();
    });

    it('staking epoch #1 finished', async () => {
      const stakingEpoch = await stakingAuRa.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(1));

      const stakingEpochEndBlock = (await stakingAuRa.stakingEpochStartBlock.call()).add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      const validators = await validatorSetAuRa.getValidators.call();
      const blocksCreated = stakingEpochEndBlock.sub(await validatorSetAuRa.validatorSetApplyBlock.call()).div(new BN(validators.length));
      blocksCreated.should.be.bignumber.above(new BN(0));
      for (let i = 0; i < validators.length; i++) {
        await blockRewardAuRa.setBlocksCreated(stakingEpoch, validators[i], blocksCreated).should.be.fulfilled;
        await randomAuRa.setSentReveal(validators[i]).should.be.fulfilled;
      }

      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1));
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(true);

      (await erc20Token.balanceOf.call(blockRewardAuRa.address)).should.be.bignumber.equal(new BN(0));
      (await blockRewardAuRa.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardAuRa.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardAuRa.tokenRewardUndistributed.call()).should.be.bignumber.equal(web3.utils.toWei('1'));
      (await blockRewardAuRa.nativeRewardUndistributed.call()).should.be.bignumber.equal(web3.utils.toWei('1'));

      const pendingValidators = await validatorSetAuRa.getPendingValidators.call();
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }
    });

    it('staking epoch #2 started', async () => {
      const validators = await validatorSetAuRa.getValidators.call();

      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      await setCurrentBlockNumber(stakingEpochStartBlock);

      const {logs} = await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.be.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal(validators);

      const validatorsToBeFinalized = await validatorSetAuRa.validatorsToBeFinalized.call();
      validatorsToBeFinalized.miningAddresses.should.be.deep.equal(validators);
      validatorsToBeFinalized.forNewEpoch.should.be.equal(true);

      const currentBlock = stakingEpochStartBlock.add(new BN(Math.floor(validators.length / 2) + 1));
      await setCurrentBlockNumber(currentBlock);

      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      await callFinalizeChange();
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(currentBlock);
      (await validatorSetAuRa.getValidators.call()).should.be.deep.equal(validators);

      (await blockRewardAuRa.snapshotTotalStakeAmount.call()).should.be.bignumber.equal(
        candidateMinStake.add(delegatorMinStake.mul(new BN(3))).mul(new BN(3))
      );
    });

    it('bridge fee accumulated during the epoch #2', async () => {
      await accrueBridgeFees();
    });

    it('staking epoch #2 finished', async () => {
      const stakingEpoch = await stakingAuRa.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(2));

      const stakingEpochEndBlock = (await stakingAuRa.stakingEpochStartBlock.call()).add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      const validators = await validatorSetAuRa.getValidators.call();
      const blocksCreated = stakingEpochEndBlock.sub(await validatorSetAuRa.validatorSetApplyBlock.call()).div(new BN(validators.length));
      blocksCreated.should.be.bignumber.above(new BN(0));
      for (let i = 0; i < validators.length; i++) {
        await blockRewardAuRa.setBlocksCreated(stakingEpoch, validators[i], blocksCreated).should.be.fulfilled;
        await randomAuRa.setSentReveal(validators[i]).should.be.fulfilled;
      }

      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1));
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(true);

      let rewardDistributed = new BN(0);
      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardAuRa.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        epochPoolTokenReward.should.be.bignumber.above(new BN(0));
        rewardDistributed = rewardDistributed.add(epochPoolTokenReward);
        const epochsPoolGotRewardFor = await blockRewardAuRa.epochsPoolGotRewardFor.call(validators[i]);
        epochsPoolGotRewardFor.length.should.be.equal(1);
        epochsPoolGotRewardFor[0].should.be.bignumber.equal(new BN(2));
      }
      rewardDistributed.should.be.bignumber.above(web3.utils.toWei(new BN(2)));

      (await erc20Token.balanceOf.call(blockRewardAuRa.address)).should.be.bignumber.equal(rewardDistributed);
      (await blockRewardAuRa.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardAuRa.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetAuRa.getPendingValidators.call();
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }
    });

    it('staking epoch #3 started', async () => {
      const validators = await validatorSetAuRa.getValidators.call();

      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      await setCurrentBlockNumber(stakingEpochStartBlock);

      const {logs} = await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.be.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal(validators);

      const validatorsToBeFinalized = await validatorSetAuRa.validatorsToBeFinalized.call();
      validatorsToBeFinalized.miningAddresses.should.be.deep.equal(validators);
      validatorsToBeFinalized.forNewEpoch.should.be.equal(true);

      const currentBlock = stakingEpochStartBlock.add(new BN(Math.floor(validators.length / 2) + 1));
      await setCurrentBlockNumber(currentBlock);

      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      await callFinalizeChange();
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(currentBlock);
      (await validatorSetAuRa.getValidators.call()).should.be.deep.equal(validators);

      (await blockRewardAuRa.snapshotTotalStakeAmount.call()).should.be.bignumber.equal(
        candidateMinStake.add(delegatorMinStake.mul(new BN(3))).mul(new BN(3))
      );
    });

    it('three other candidates are added during the epoch #3', async () => {
      const candidatesMiningAddresses = accounts.slice(21, 23 + 1); // accounts[21...23]
      const candidatesStakingAddresses = accounts.slice(24, 26 + 1); // accounts[24...26]

      for (let i = 0; i < candidatesMiningAddresses.length; i++) {
        // Mint some balance for each candidate (imagine that each candidate got the tokens from a bridge)
        const miningAddress = candidatesMiningAddresses[i];
        const stakingAddress = candidatesStakingAddresses[i];
        await erc20Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc20Token.balanceOf.call(stakingAddress));

        // Candidate places stake on themselves
        await stakingAuRa.addPool(candidateMinStake, miningAddress, {from: stakingAddress}).should.be.fulfilled;

        const delegatorsLength = 3;
        const delegators = accounts.slice(31 + i*delegatorsLength, 31 + i*delegatorsLength + delegatorsLength);
        for (let j = 0; j < delegators.length; j++) {
          // Mint some balance for each delegator (imagine that each delegator got the tokens from a bridge)
          await erc20Token.mint(delegators[j], delegatorMinStake, {from: owner}).should.be.fulfilled;
          delegatorMinStake.should.be.bignumber.equal(await erc20Token.balanceOf.call(delegators[j]));

          // Delegator places stake on the validator
          await stakingAuRa.stake(stakingAddress, delegatorMinStake, {from: delegators[j]}).should.be.fulfilled;
        }
      }
    });

    it('bridge fee accumulated during the epoch #3', async () => {
      await accrueBridgeFees();
    });

    // ...
  });

  async function accrueBridgeFees() {
    const fee = web3.utils.toWei('1');
    await blockRewardAuRa.setNativeToErcBridgesAllowed([owner], {from: owner}).should.be.fulfilled;
    await blockRewardAuRa.setErcToNativeBridgesAllowed([owner], {from: owner}).should.be.fulfilled;
    await blockRewardAuRa.addBridgeTokenFeeReceivers(fee, {from: owner}).should.be.fulfilled;
    await blockRewardAuRa.addBridgeNativeFeeReceivers(fee, {from: owner}).should.be.fulfilled;
    (await blockRewardAuRa.bridgeTokenFee.call()).should.be.bignumber.equal(fee);
    (await blockRewardAuRa.bridgeNativeFee.call()).should.be.bignumber.equal(fee);
  }

  async function callFinalizeChange() {
    await validatorSetAuRa.setSystemAddress(owner).should.be.fulfilled;
    await validatorSetAuRa.finalizeChange({from: owner}).should.be.fulfilled;
    await validatorSetAuRa.setSystemAddress('0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE').should.be.fulfilled;
  }

  async function callReward() {
    const validators = await validatorSetAuRa.getValidators.call();
    await blockRewardAuRa.setSystemAddress(owner).should.be.fulfilled;
    await blockRewardAuRa.reward([validators[0]], [0], {from: owner}).should.be.fulfilled;
    await blockRewardAuRa.setSystemAddress('0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE').should.be.fulfilled;
  }

  async function setCurrentBlockNumber(blockNumber) {
    await blockRewardAuRa.setCurrentBlockNumber(blockNumber).should.be.fulfilled;
    await randomAuRa.setCurrentBlockNumber(blockNumber).should.be.fulfilled;
    await stakingAuRa.setCurrentBlockNumber(blockNumber).should.be.fulfilled;
    await validatorSetAuRa.setCurrentBlockNumber(blockNumber).should.be.fulfilled;
  }

  // TODO: ...add other tests...
});
