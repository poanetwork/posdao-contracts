/*
const BlockRewardAuRa = artifacts.require('BlockRewardAuRaMock');
const ERC677BridgeTokenRewardable = artifacts.require('ERC677BridgeTokenRewardableMock');
const AdminUpgradeabilityProxy = artifacts.require('AdminUpgradeabilityProxy');
const RandomAuRa = artifacts.require('RandomAuRaMock');
const ValidatorSetAuRa = artifacts.require('ValidatorSetAuRaMock');
const StakingAuRa = artifacts.require('StakingAuRaTokensMock');

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
  let tokenRewardUndistributed = new BN(0);

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
        web3.utils.toWei('1', 'ether'), // _delegatorMinStake
        web3.utils.toWei('1', 'ether'), // _candidateMinStake
        STAKING_EPOCH_DURATION, // _stakingEpochDuration
        STAKING_EPOCH_START_BLOCK, // _stakingEpochStartBlock
        STAKE_WITHDRAW_DISALLOW_PERIOD // _stakeWithdrawDisallowPeriod
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
      (await blockRewardAuRa.tokenRewardUndistributed.call()).should.be.bignumber.equal(tokenRewardUndistributed);
    });

    it('staking epoch #1 started', async () => {
      const validators = await validatorSetAuRa.getValidators.call();

      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 1));
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

    it('  validators and their delegators place stakes during the epoch #1', async () => {
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

    it('  bridge fee accumulated during the epoch #1', async () => {
      const fee = await accrueBridgeFees();
      tokenRewardUndistributed = tokenRewardUndistributed.add(fee);
    });

    it('staking epoch #1 finished', async () => {
      const stakingEpoch = await stakingAuRa.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(1));

      const stakingEpochEndBlock = (await stakingAuRa.stakingEpochStartBlock.call()).add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetAuRa.getValidators.call();
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
      (await blockRewardAuRa.tokenRewardUndistributed.call()).should.be.bignumber.equal(tokenRewardUndistributed);

      const pendingValidators = await validatorSetAuRa.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[1],
        accounts[2],
        accounts[3]
      ]);

      validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[1],
        accounts[2],
        accounts[3]
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }

      const validatorsToBeFinalized = (await validatorSetAuRa.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.length.should.be.equal(0);
    });

    it('staking epoch #2 started', async () => {
      const validators = await validatorSetAuRa.getValidators.call();

      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 2));
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

    it('  bridge fee accumulated during the epoch #2', async () => {
      const fee = await accrueBridgeFees();
      tokenRewardUndistributed = tokenRewardUndistributed.add(fee);
    });

    it('staking epoch #2 finished', async () => {
      const stakingEpoch = await stakingAuRa.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(2));

      const stakingEpochEndBlock = (await stakingAuRa.stakingEpochStartBlock.call()).add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetAuRa.getValidators.call();
      const blocksCreated = stakingEpochEndBlock.sub(await validatorSetAuRa.validatorSetApplyBlock.call()).div(new BN(validators.length));
      blocksCreated.should.be.bignumber.above(new BN(0));
      for (let i = 0; i < validators.length; i++) {
        await blockRewardAuRa.setBlocksCreated(stakingEpoch, validators[i], blocksCreated).should.be.fulfilled;
        await randomAuRa.setSentReveal(validators[i]).should.be.fulfilled;
      }

      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 3
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
      rewardDistributed.should.be.bignumber.above(new BN(web3.utils.toWei('1.9')));
      rewardDistributed.should.be.bignumber.below(new BN(web3.utils.toWei('2.1')));
      tokenRewardUndistributed = tokenRewardUndistributed.sub(rewardDistributed);
      tokenRewardUndistributed.should.be.bignumber.equal(await blockRewardAuRa.tokenRewardUndistributed.call());

      (await erc20Token.balanceOf.call(blockRewardAuRa.address)).should.be.bignumber.equal(rewardDistributed);
      (await blockRewardAuRa.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardAuRa.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetAuRa.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[1],
        accounts[2],
        accounts[3]
      ]);

      validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[1],
        accounts[2],
        accounts[3]
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }

      const validatorsToBeFinalized = (await validatorSetAuRa.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.length.should.be.equal(0);
    });

    it('staking epoch #3 started', async () => {
      const validators = await validatorSetAuRa.getValidators.call();

      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 3));
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

    it('  three other candidates are added during the epoch #3', async () => {
      const candidatesMiningAddresses = accounts.slice(31, 33 + 1); // accounts[31...33]
      const candidatesStakingAddresses = accounts.slice(34, 36 + 1); // accounts[34...36]

      for (let i = 0; i < candidatesMiningAddresses.length; i++) {
        // Mint some balance for each candidate (imagine that each candidate got the tokens from a bridge)
        const miningAddress = candidatesMiningAddresses[i];
        const stakingAddress = candidatesStakingAddresses[i];
        await erc20Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc20Token.balanceOf.call(stakingAddress));

        // Candidate places stake on themselves
        await stakingAuRa.addPool(candidateMinStake, miningAddress, {from: stakingAddress}).should.be.fulfilled;

        const delegatorsLength = 3;
        const delegators = accounts.slice(41 + i*delegatorsLength, 41 + i*delegatorsLength + delegatorsLength);
        for (let j = 0; j < delegators.length; j++) {
          // Mint some balance for each delegator (imagine that each delegator got the tokens from a bridge)
          await erc20Token.mint(delegators[j], delegatorMinStake, {from: owner}).should.be.fulfilled;
          delegatorMinStake.should.be.bignumber.equal(await erc20Token.balanceOf.call(delegators[j]));

          // Delegator places stake on the candidate
          await stakingAuRa.stake(stakingAddress, delegatorMinStake, {from: delegators[j]}).should.be.fulfilled;
        }
      }
    });

    it('  bridge fee accumulated during the epoch #3', async () => {
      const fee = await accrueBridgeFees();
      tokenRewardUndistributed = tokenRewardUndistributed.add(fee);
    });

    it('staking epoch #3 finished', async () => {
      const stakingEpoch = await stakingAuRa.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(3));

      const stakingEpochEndBlock = (await stakingAuRa.stakingEpochStartBlock.call()).add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetAuRa.getValidators.call();
      const blocksCreated = stakingEpochEndBlock.sub(await validatorSetAuRa.validatorSetApplyBlock.call()).div(new BN(validators.length));
      blocksCreated.should.be.bignumber.above(new BN(0));
      for (let i = 0; i < validators.length; i++) {
        await blockRewardAuRa.setBlocksCreated(stakingEpoch, validators[i], blocksCreated).should.be.fulfilled;
        if (i == 0) { // the last two validators turn off their nodes
          await randomAuRa.setSentReveal(validators[i]).should.be.fulfilled;
        }
      }

      const blockRewardBalanceBeforeReward = await erc20Token.balanceOf.call(blockRewardAuRa.address);

      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      (await validatorSetAuRa.isValidatorBanned.call(validators[2])).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 4
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(true);
      (await validatorSetAuRa.isValidatorBanned.call(validators[2])).should.be.equal(true);

      let rewardDistributed = new BN(0);
      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardAuRa.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        if (i == 0) {
          epochPoolTokenReward.should.be.bignumber.above(new BN(0));
        } else {
          epochPoolTokenReward.should.be.bignumber.equal(new BN(0));
        }
        rewardDistributed = rewardDistributed.add(epochPoolTokenReward);
        const epochsPoolGotRewardFor = await blockRewardAuRa.epochsPoolGotRewardFor.call(validators[i]);
        if (i == 0) {
          epochsPoolGotRewardFor.length.should.be.equal(2);
          epochsPoolGotRewardFor[0].should.be.bignumber.equal(new BN(2));
          epochsPoolGotRewardFor[1].should.be.bignumber.equal(new BN(3));
        } else {
          epochsPoolGotRewardFor.length.should.be.equal(1);
          epochsPoolGotRewardFor[0].should.be.bignumber.equal(new BN(2));
        }
      }
      rewardDistributed.should.be.bignumber.above(web3.utils.toWei(new BN(1)));
      tokenRewardUndistributed = tokenRewardUndistributed.sub(rewardDistributed);
      tokenRewardUndistributed.should.be.bignumber.equal(await blockRewardAuRa.tokenRewardUndistributed.call());

      const blockRewardBalanceAfterReward = await erc20Token.balanceOf.call(blockRewardAuRa.address);

      blockRewardBalanceAfterReward.should.be.bignumber.equal(blockRewardBalanceBeforeReward.add(rewardDistributed));
      (await blockRewardAuRa.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardAuRa.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetAuRa.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[1],
        accounts[31],
        accounts[32],
        accounts[33],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }

      validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[1],
        accounts[2],
        accounts[3]
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }

      const validatorsToBeFinalized = (await validatorSetAuRa.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.length.should.be.equal(0);
    });

    it('staking epoch #4 started', async () => {
      const prevValidators = await validatorSetAuRa.getValidators.call();
      const pendingValidators = await validatorSetAuRa.getPendingValidators.call();

      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 4));
      let currentBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION / 2));
      await setCurrentBlockNumber(currentBlock);

      const {logs} = await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.be.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal(pendingValidators);

      const validatorsToBeFinalized = await validatorSetAuRa.validatorsToBeFinalized.call();
      validatorsToBeFinalized.miningAddresses.should.be.deep.equal(pendingValidators);
      validatorsToBeFinalized.forNewEpoch.should.be.equal(true);

      currentBlock = currentBlock.add(new BN(Math.floor(prevValidators.length / 2) + 1));
      await setCurrentBlockNumber(currentBlock);

      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      await callFinalizeChange();
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(currentBlock);
      (await validatorSetAuRa.getValidators.call()).should.be.deep.equal(pendingValidators);
    });

    it('  bridge fee accumulated during the epoch #4', async () => {
      const fee = await accrueBridgeFees();
      tokenRewardUndistributed = tokenRewardUndistributed.add(fee);
    });

    it('  three other candidates are added during the epoch #4', async () => {
      const candidatesMiningAddresses = accounts.slice(61, 63 + 1); // accounts[61...63]
      const candidatesStakingAddresses = accounts.slice(64, 66 + 1); // accounts[64...66]

      for (let i = 0; i < candidatesMiningAddresses.length; i++) {
        // Mint some balance for each candidate (imagine that each candidate got the tokens from a bridge)
        const miningAddress = candidatesMiningAddresses[i];
        const stakingAddress = candidatesStakingAddresses[i];
        await erc20Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc20Token.balanceOf.call(stakingAddress));

        // Candidate places stake on themselves
        await stakingAuRa.addPool(candidateMinStake, miningAddress, {from: stakingAddress}).should.be.fulfilled;

        const delegatorsLength = 3;
        const delegators = accounts.slice(71 + i*delegatorsLength, 71 + i*delegatorsLength + delegatorsLength);
        for (let j = 0; j < delegators.length; j++) {
          // Mint some balance for each delegator (imagine that each delegator got the tokens from a bridge)
          await erc20Token.mint(delegators[j], delegatorMinStake, {from: owner}).should.be.fulfilled;
          delegatorMinStake.should.be.bignumber.equal(await erc20Token.balanceOf.call(delegators[j]));

          // Delegator places stake on the candidate
          await stakingAuRa.stake(stakingAddress, delegatorMinStake, {from: delegators[j]}).should.be.fulfilled;
        }
      }
    });

    it('  current validators remove their pools during the epoch #4', async () => {
      const validators = await validatorSetAuRa.getValidators.call();
      for (let i = 0; i < validators.length; i++) {
        const stakingAddress = await validatorSetAuRa.stakingByMiningAddress.call(validators[i]);
        await stakingAuRa.removeMyPool({from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('staking epoch #4 finished', async () => {
      const stakingEpoch = await stakingAuRa.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(4));

      const stakingEpochEndBlock = (await stakingAuRa.stakingEpochStartBlock.call()).add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetAuRa.getValidators.call();
      const blocksCreated = stakingEpochEndBlock.sub(await validatorSetAuRa.validatorSetApplyBlock.call()).div(new BN(validators.length));
      blocksCreated.should.be.bignumber.above(new BN(0));
      for (let i = 0; i < validators.length; i++) {
        await blockRewardAuRa.setBlocksCreated(stakingEpoch, validators[i], blocksCreated).should.be.fulfilled;
        await randomAuRa.setSentReveal(validators[i]).should.be.fulfilled;
      }

      const blockRewardBalanceBeforeReward = await erc20Token.balanceOf.call(blockRewardAuRa.address);

      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 4
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(true);

      let rewardDistributed = new BN(0);
      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardAuRa.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        epochPoolTokenReward.should.be.bignumber.above(new BN(0));
        rewardDistributed = rewardDistributed.add(epochPoolTokenReward);
        const epochsPoolGotRewardFor = await blockRewardAuRa.epochsPoolGotRewardFor.call(validators[i]);
        if (i == 0) {
          epochsPoolGotRewardFor.length.should.be.equal(3);
          epochsPoolGotRewardFor[0].should.be.bignumber.equal(new BN(2));
          epochsPoolGotRewardFor[1].should.be.bignumber.equal(new BN(3));
          epochsPoolGotRewardFor[2].should.be.bignumber.equal(new BN(4));
        } else {
          epochsPoolGotRewardFor.length.should.be.equal(1);
          epochsPoolGotRewardFor[0].should.be.bignumber.equal(new BN(4));
        }
      }
      rewardDistributed.should.be.bignumber.above(web3.utils.toWei(new BN(1)).div(new BN(2)));
      rewardDistributed.should.be.bignumber.below(web3.utils.toWei(new BN(1)));
      tokenRewardUndistributed = tokenRewardUndistributed.sub(rewardDistributed);
      tokenRewardUndistributed.should.be.bignumber.equal(await blockRewardAuRa.tokenRewardUndistributed.call());

      const blockRewardBalanceAfterReward = await erc20Token.balanceOf.call(blockRewardAuRa.address);

      blockRewardBalanceAfterReward.should.be.bignumber.equal(blockRewardBalanceBeforeReward.add(rewardDistributed));
      (await blockRewardAuRa.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardAuRa.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetAuRa.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }

      validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[1],
        accounts[31],
        accounts[32],
        accounts[33],
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }

      const validatorsToBeFinalized = (await validatorSetAuRa.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.length.should.be.equal(0);
    });

    it('staking epoch #5 started', async () => {
      const prevValidators = await validatorSetAuRa.getValidators.call();
      const pendingValidators = await validatorSetAuRa.getPendingValidators.call();

      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 5));
      await setCurrentBlockNumber(stakingEpochStartBlock);

      const {logs} = await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.be.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal(pendingValidators); // 61 62 63

      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
    });

    it('  bridge fee accumulated during the epoch #5', async () => {
      const fee = await accrueBridgeFees();
      tokenRewardUndistributed = tokenRewardUndistributed.add(fee);
    });

    it('  current pending validators remove their pools during the epoch #5', async () => {
      const pendingValidators = await validatorSetAuRa.getPendingValidators.call();
      for (let i = 0; i < pendingValidators.length; i++) {
        const stakingAddress = await validatorSetAuRa.stakingByMiningAddress.call(pendingValidators[i]);
        await stakingAuRa.removeMyPool({from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('  three other candidates are added during the epoch #5', async () => {
      const candidatesMiningAddresses = accounts.slice(91, 93 + 1); // accounts[91...93]
      const candidatesStakingAddresses = accounts.slice(94, 96 + 1); // accounts[94...96]

      for (let i = 0; i < candidatesMiningAddresses.length; i++) {
        // Mint some balance for each candidate (imagine that each candidate got the tokens from a bridge)
        const miningAddress = candidatesMiningAddresses[i];
        const stakingAddress = candidatesStakingAddresses[i];
        await erc20Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc20Token.balanceOf.call(stakingAddress));

        // Candidate places stake on themselves
        await stakingAuRa.addPool(candidateMinStake, miningAddress, {from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('staking epoch #5 finished', async () => {
      const stakingEpoch = await stakingAuRa.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(5));

      const stakingEpochEndBlock = (await stakingAuRa.stakingEpochStartBlock.call()).add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[1],
        accounts[31],
        accounts[32],
        accounts[33]
      ]);
      for (let i = 0; i < validators.length; i++) {
        // the last two validators turn off their nodes
        if (validators[i] == accounts[1] || validators[i] == accounts[31]) {
          await randomAuRa.setSentReveal(validators[i]).should.be.fulfilled;
        }
      }

      const blockRewardBalanceBeforeReward = await erc20Token.balanceOf.call(blockRewardAuRa.address);

      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      (await validatorSetAuRa.isValidatorBanned.call(accounts[32])).should.be.equal(false);
      (await validatorSetAuRa.isValidatorBanned.call(accounts[33])).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 6
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      (await validatorSetAuRa.isValidatorBanned.call(accounts[32])).should.be.equal(true);
      (await validatorSetAuRa.isValidatorBanned.call(accounts[33])).should.be.equal(true);

      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardAuRa.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        epochPoolTokenReward.should.be.bignumber.equal(new BN(0));
      }

      const blockRewardBalanceAfterReward = await erc20Token.balanceOf.call(blockRewardAuRa.address);

      blockRewardBalanceAfterReward.should.be.bignumber.equal(blockRewardBalanceBeforeReward);
      (await blockRewardAuRa.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardAuRa.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetAuRa.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[91],
        accounts[92],
        accounts[93],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[1],
        accounts[31],
        accounts[32],
        accounts[33],
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }

      const validatorsToBeFinalized = (await validatorSetAuRa.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63]
      ]);
      for (let i = 0; i < validatorsToBeFinalized.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validatorsToBeFinalized[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validatorsToBeFinalized[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }
    });

    it('staking epoch #6 started', async () => {
      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 6));
      let currentBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION / 2));
      await setCurrentBlockNumber(currentBlock);

      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      await callFinalizeChange();
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(currentBlock);
      const validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63]
      ]);

      const {logs} = await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.be.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal([
        accounts[91],
        accounts[92],
        accounts[93]
      ]);
    });

    it('  bridge fee accumulated during the epoch #6', async () => {
      const fee = await accrueBridgeFees();
      tokenRewardUndistributed = tokenRewardUndistributed.add(fee);
    });

    it('  all upcoming validators remove their pools during the epoch #6', async () => {
      const validatorsToBeFinalized = (await validatorSetAuRa.validatorsToBeFinalized.call()).miningAddresses;
      for (let i = 0; i < validatorsToBeFinalized.length; i++) {
        const stakingAddress = await validatorSetAuRa.stakingByMiningAddress.call(validatorsToBeFinalized[i]);
        await stakingAuRa.removeMyPool({from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('  three other candidates are added during the epoch #6', async () => {
      const candidatesMiningAddresses = accounts.slice(101, 103 + 1); // accounts[101...103]
      const candidatesStakingAddresses = accounts.slice(104, 106 + 1); // accounts[104...106]

      for (let i = 0; i < candidatesMiningAddresses.length; i++) {
        // Mint some balance for each candidate (imagine that each candidate got the tokens from a bridge)
        const miningAddress = candidatesMiningAddresses[i];
        const stakingAddress = candidatesStakingAddresses[i];
        await erc20Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc20Token.balanceOf.call(stakingAddress));

        // Candidate places stake on themselves
        await stakingAuRa.addPool(candidateMinStake, miningAddress, {from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('staking epoch #6 finished', async () => {
      const stakingEpoch = await stakingAuRa.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(6));

      const stakingEpochEndBlock = (await stakingAuRa.stakingEpochStartBlock.call()).add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetAuRa.getValidators.call();
      const blocksCreated = stakingEpochEndBlock.sub(await validatorSetAuRa.validatorSetApplyBlock.call()).div(new BN(validators.length));
      blocksCreated.should.be.bignumber.above(new BN(0));
      validators.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63]
      ]);
      for (let i = 0; i < validators.length; i++) {
        await blockRewardAuRa.setBlocksCreated(stakingEpoch, validators[i], blocksCreated).should.be.fulfilled;
        // the last two validators turn off their nodes
        if (validators[i] == accounts[61]) {
          await randomAuRa.setSentReveal(validators[i]).should.be.fulfilled;
        }
      }

      const blockRewardBalanceBeforeReward = await erc20Token.balanceOf.call(blockRewardAuRa.address);

      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      (await validatorSetAuRa.isValidatorBanned.call(accounts[62])).should.be.equal(false);
      (await validatorSetAuRa.isValidatorBanned.call(accounts[63])).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 7
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      (await validatorSetAuRa.isValidatorBanned.call(accounts[62])).should.be.equal(true);
      (await validatorSetAuRa.isValidatorBanned.call(accounts[63])).should.be.equal(true);

      let rewardDistributed = new BN(0);
      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardAuRa.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        if (validators[i] == accounts[61]) {
          epochPoolTokenReward.should.be.bignumber.above(new BN(0));
        } else {
          epochPoolTokenReward.should.be.bignumber.equal(new BN(0));
        }
        rewardDistributed = rewardDistributed.add(epochPoolTokenReward);
      }
      Math.round(Number(web3.utils.fromWei(rewardDistributed)) * 100).should.be.equal(
        Math.round(Number(web3.utils.fromWei(tokenRewardUndistributed.div(new BN(2)))) * 100)
      );
      tokenRewardUndistributed = tokenRewardUndistributed.sub(rewardDistributed);
      tokenRewardUndistributed.should.be.bignumber.equal(await blockRewardAuRa.tokenRewardUndistributed.call());

      const blockRewardBalanceAfterReward = await erc20Token.balanceOf.call(blockRewardAuRa.address);

      blockRewardBalanceAfterReward.should.be.bignumber.equal(blockRewardBalanceBeforeReward.add(rewardDistributed));
      (await blockRewardAuRa.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardAuRa.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetAuRa.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[101],
        accounts[102],
        accounts[103],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63],
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }

      const validatorsToBeFinalized = (await validatorSetAuRa.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.sortedEqual([
        accounts[91],
        accounts[92],
        accounts[93]
      ]);
      for (let i = 0; i < validatorsToBeFinalized.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validatorsToBeFinalized[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validatorsToBeFinalized[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }
    });

    it('staking epoch #7 started', async () => {
      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 7));
      await setCurrentBlockNumber(stakingEpochStartBlock);

      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      const validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63]
      ]);

      await validatorSetAuRa.emitInitiateChange().should.be.rejectedWith(ERROR_MSG);
    });

    it('  bridge fee accumulated during the epoch #7', async () => {
      const fee = await accrueBridgeFees();
      tokenRewardUndistributed = tokenRewardUndistributed.add(fee);
    });

    it('  all pending validators remove their pools during the epoch #7', async () => {
      const pendingValidators = await validatorSetAuRa.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[101],
        accounts[102],
        accounts[103],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        const stakingAddress = await validatorSetAuRa.stakingByMiningAddress.call(pendingValidators[i]);
        await stakingAuRa.removeMyPool({from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('  three other candidates are added during the epoch #7', async () => {
      const candidatesMiningAddresses = accounts.slice(111, 113 + 1); // accounts[111...113]
      const candidatesStakingAddresses = accounts.slice(114, 116 + 1); // accounts[114...116]

      for (let i = 0; i < candidatesMiningAddresses.length; i++) {
        // Mint some balance for each candidate (imagine that each candidate got the tokens from a bridge)
        const miningAddress = candidatesMiningAddresses[i];
        const stakingAddress = candidatesStakingAddresses[i];
        await erc20Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc20Token.balanceOf.call(stakingAddress));

        // Candidate places stake on themselves
        await stakingAuRa.addPool(candidateMinStake, miningAddress, {from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('staking epoch #7 finished', async () => {
      const stakingEpoch = await stakingAuRa.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(7));

      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      const stakingEpochEndBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63]
      ]);
      for (let i = 0; i < validators.length; i++) {
        await blockRewardAuRa.setBlocksCreated(stakingEpoch, validators[i], new BN(0)).should.be.fulfilled;
        // the last two validators still didn't turn on their nodes
        if (validators[i] == accounts[61]) {
          await randomAuRa.setSentReveal(validators[i]).should.be.fulfilled;
        }
      }

      const blockRewardBalanceBeforeReward = await erc20Token.balanceOf.call(blockRewardAuRa.address);

      const bannedUntil62 = await validatorSetAuRa.bannedUntil.call(accounts[62]);
      const bannedUntil63 = await validatorSetAuRa.bannedUntil.call(accounts[63]);
      const bannedDelegatorsUntil62 = await validatorSetAuRa.bannedDelegatorsUntil.call(accounts[62]);
      const bannedDelegatorsUntil63 = await validatorSetAuRa.bannedDelegatorsUntil.call(accounts[63]);

      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      (await validatorSetAuRa.isValidatorBanned.call(accounts[62])).should.be.equal(true);
      (await validatorSetAuRa.isValidatorBanned.call(accounts[63])).should.be.equal(true);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 8
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      (await validatorSetAuRa.isValidatorBanned.call(accounts[62])).should.be.equal(true);
      (await validatorSetAuRa.isValidatorBanned.call(accounts[63])).should.be.equal(true);
      (await validatorSetAuRa.bannedUntil.call(accounts[62])).should.be.bignumber.equal(bannedUntil62.add(new BN(STAKING_EPOCH_DURATION)));
      (await validatorSetAuRa.bannedUntil.call(accounts[63])).should.be.bignumber.equal(bannedUntil63.add(new BN(STAKING_EPOCH_DURATION)));
      (await validatorSetAuRa.bannedDelegatorsUntil.call(accounts[62])).should.be.bignumber.equal(bannedDelegatorsUntil62);
      (await validatorSetAuRa.bannedDelegatorsUntil.call(accounts[63])).should.be.bignumber.equal(bannedDelegatorsUntil63);

      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardAuRa.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        epochPoolTokenReward.should.be.bignumber.equal(new BN(0));
      }
      tokenRewardUndistributed.should.be.bignumber.equal(await blockRewardAuRa.tokenRewardUndistributed.call());

      const blockRewardBalanceAfterReward = await erc20Token.balanceOf.call(blockRewardAuRa.address);

      blockRewardBalanceAfterReward.should.be.bignumber.equal(blockRewardBalanceBeforeReward);
      (await blockRewardAuRa.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardAuRa.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetAuRa.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[111],
        accounts[112],
        accounts[113],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63],
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }

      const validatorsToBeFinalized = (await validatorSetAuRa.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.sortedEqual([
        accounts[91],
        accounts[92],
        accounts[93]
      ]);
      for (let i = 0; i < validatorsToBeFinalized.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validatorsToBeFinalized[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validatorsToBeFinalized[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }
    });

    it('staking epoch #8 started', async () => {
      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 8));
      await setCurrentBlockNumber(stakingEpochStartBlock);

      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      const validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63]
      ]);

      await validatorSetAuRa.emitInitiateChange().should.be.rejectedWith(ERROR_MSG);
    });

    it('  bridge fee accumulated during the epoch #8', async () => {
      const fee = await accrueBridgeFees();
      tokenRewardUndistributed = tokenRewardUndistributed.add(fee);
    });

    it('  all pending validators remove their pools during the epoch #8', async () => {
      const pendingValidators = await validatorSetAuRa.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[111],
        accounts[112],
        accounts[113],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        const stakingAddress = await validatorSetAuRa.stakingByMiningAddress.call(pendingValidators[i]);
        await stakingAuRa.removeMyPool({from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('  three other candidates are added during the epoch #8', async () => {
      const candidatesMiningAddresses = accounts.slice(121, 123 + 1); // accounts[121...123]
      const candidatesStakingAddresses = accounts.slice(124, 126 + 1); // accounts[124...126]

      for (let i = 0; i < candidatesMiningAddresses.length; i++) {
        // Mint some balance for each candidate (imagine that each candidate got the tokens from a bridge)
        const miningAddress = candidatesMiningAddresses[i];
        const stakingAddress = candidatesStakingAddresses[i];
        await erc20Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc20Token.balanceOf.call(stakingAddress));

        // Candidate places stake on themselves
        await stakingAuRa.addPool(candidateMinStake, miningAddress, {from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('staking epoch #8 finished', async () => {
      const stakingEpoch = await stakingAuRa.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(8));

      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      const stakingEpochEndBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63]
      ]);
      for (let i = 0; i < validators.length; i++) {
        await blockRewardAuRa.setBlocksCreated(stakingEpoch, validators[i], new BN(0)).should.be.fulfilled;
        // the last two validators still didn't turn on their nodes
        if (validators[i] == accounts[61]) {
          await randomAuRa.setSentReveal(validators[i]).should.be.fulfilled;
        }
      }

      const blockRewardBalanceBeforeReward = await erc20Token.balanceOf.call(blockRewardAuRa.address);

      const bannedUntil62 = await validatorSetAuRa.bannedUntil.call(accounts[62]);
      const bannedUntil63 = await validatorSetAuRa.bannedUntil.call(accounts[63]);
      const bannedDelegatorsUntil62 = await validatorSetAuRa.bannedDelegatorsUntil.call(accounts[62]);
      const bannedDelegatorsUntil63 = await validatorSetAuRa.bannedDelegatorsUntil.call(accounts[63]);

      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      (await validatorSetAuRa.isValidatorBanned.call(accounts[62])).should.be.equal(true);
      (await validatorSetAuRa.isValidatorBanned.call(accounts[63])).should.be.equal(true);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 9
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      (await validatorSetAuRa.isValidatorBanned.call(accounts[62])).should.be.equal(true);
      (await validatorSetAuRa.isValidatorBanned.call(accounts[63])).should.be.equal(true);
      (await validatorSetAuRa.bannedUntil.call(accounts[62])).should.be.bignumber.equal(bannedUntil62.add(new BN(STAKING_EPOCH_DURATION)));
      (await validatorSetAuRa.bannedUntil.call(accounts[63])).should.be.bignumber.equal(bannedUntil63.add(new BN(STAKING_EPOCH_DURATION)));
      (await validatorSetAuRa.bannedDelegatorsUntil.call(accounts[62])).should.be.bignumber.equal(bannedDelegatorsUntil62);
      (await validatorSetAuRa.bannedDelegatorsUntil.call(accounts[63])).should.be.bignumber.equal(bannedDelegatorsUntil63);

      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardAuRa.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        epochPoolTokenReward.should.be.bignumber.equal(new BN(0));
      }
      tokenRewardUndistributed.should.be.bignumber.equal(await blockRewardAuRa.tokenRewardUndistributed.call());

      const blockRewardBalanceAfterReward = await erc20Token.balanceOf.call(blockRewardAuRa.address);

      blockRewardBalanceAfterReward.should.be.bignumber.equal(blockRewardBalanceBeforeReward);
      (await blockRewardAuRa.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardAuRa.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetAuRa.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[121],
        accounts[122],
        accounts[123],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63],
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }

      const validatorsToBeFinalized = (await validatorSetAuRa.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.sortedEqual([
        accounts[91],
        accounts[92],
        accounts[93]
      ]);
      for (let i = 0; i < validatorsToBeFinalized.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validatorsToBeFinalized[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validatorsToBeFinalized[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }
    });

    it('staking epoch #9 started', async () => {
      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 9));
      let currentBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION / 4));
      await setCurrentBlockNumber(currentBlock);

      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      await callFinalizeChange();
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(currentBlock);
      let validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[91],
        accounts[92],
        accounts[93]
      ]);

      currentBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION / 2));
      await setCurrentBlockNumber(currentBlock);

      const {logs} = await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.be.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal([
        accounts[121],
        accounts[122],
        accounts[123]
      ]);

      await callFinalizeChange();

      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(currentBlock);
      validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[121],
        accounts[122],
        accounts[123]
      ]);
    });

    it('  bridge fee accumulated during the epoch #9', async () => {
      const fee = await accrueBridgeFees();
      tokenRewardUndistributed = tokenRewardUndistributed.add(fee);
    });

    it('  all current validators remove their pools during the epoch #9', async () => {
      const validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[121],
        accounts[122],
        accounts[123],
      ]);
      for (let i = 0; i < validators.length; i++) {
        const stakingAddress = await validatorSetAuRa.stakingByMiningAddress.call(validators[i]);
        await stakingAuRa.removeMyPool({from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('  three other candidates are added during the epoch #9', async () => {
      const candidatesMiningAddresses = accounts.slice(131, 133 + 1); // accounts[131...133]
      const candidatesStakingAddresses = accounts.slice(134, 136 + 1); // accounts[134...136]

      for (let i = 0; i < candidatesMiningAddresses.length; i++) {
        // Mint some balance for each candidate (imagine that each candidate got the tokens from a bridge)
        const miningAddress = candidatesMiningAddresses[i];
        const stakingAddress = candidatesStakingAddresses[i];
        await erc20Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc20Token.balanceOf.call(stakingAddress));

        // Candidate places stake on themselves
        await stakingAuRa.addPool(candidateMinStake, miningAddress, {from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('staking epoch #9 finished', async () => {
      const stakingEpoch = await stakingAuRa.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(9));

      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      const stakingEpochEndBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[121],
        accounts[122],
        accounts[123]
      ]);
      const blocksCreated = stakingEpochEndBlock.sub(await validatorSetAuRa.validatorSetApplyBlock.call()).div(new BN(validators.length));
      blocksCreated.should.be.bignumber.above(new BN(0));
      for (let i = 0; i < validators.length; i++) {
        await blockRewardAuRa.setBlocksCreated(stakingEpoch, validators[i], blocksCreated).should.be.fulfilled;
        await randomAuRa.setSentReveal(validators[i]).should.be.fulfilled;
      }

      const blockRewardBalanceBeforeReward = await erc20Token.balanceOf.call(blockRewardAuRa.address);

      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 10
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(true);

      let rewardDistributed = new BN(0);
      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardAuRa.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        epochPoolTokenReward.should.be.bignumber.above(new BN(0));
        rewardDistributed = rewardDistributed.add(epochPoolTokenReward);
      }
      rewardDistributed.toString().substring(0, 3).should.be.equal(tokenRewardUndistributed.div(new BN(2)).toString().substring(0, 3));
      tokenRewardUndistributed = tokenRewardUndistributed.sub(rewardDistributed);
      tokenRewardUndistributed.should.be.bignumber.equal(await blockRewardAuRa.tokenRewardUndistributed.call());

      const blockRewardBalanceAfterReward = await erc20Token.balanceOf.call(blockRewardAuRa.address);

      blockRewardBalanceAfterReward.should.be.bignumber.equal(blockRewardBalanceBeforeReward.add(rewardDistributed));
      (await blockRewardAuRa.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardAuRa.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetAuRa.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[131],
        accounts[132],
        accounts[133],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[121],
        accounts[122],
        accounts[123],
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      const validatorsToBeFinalized = (await validatorSetAuRa.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.length.should.be.equal(0);
    });

    it('staking epoch #10 started', async () => {
      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 10));
      await setCurrentBlockNumber(stakingEpochStartBlock);

      const {logs} = await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.be.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal([
        accounts[131],
        accounts[132],
        accounts[133]
      ]);

      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      await callFinalizeChange();
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(stakingEpochStartBlock);
      let validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[131],
        accounts[132],
        accounts[133]
      ]);
    });

    it('  bridge fee accumulated during the epoch #10', async () => {
      const fee = await accrueBridgeFees();
      tokenRewardUndistributed = tokenRewardUndistributed.add(fee);
    });

    it('  all current validators remove their pools during the epoch #10', async () => {
      const validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[131],
        accounts[132],
        accounts[133],
      ]);
      for (let i = 0; i < validators.length; i++) {
        const stakingAddress = await validatorSetAuRa.stakingByMiningAddress.call(validators[i]);
        await stakingAuRa.removeMyPool({from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('  three other candidates are added during the epoch #10', async () => {
      const candidatesMiningAddresses = accounts.slice(141, 143 + 1); // accounts[141...143]
      const candidatesStakingAddresses = accounts.slice(144, 146 + 1); // accounts[144...146]

      for (let i = 0; i < candidatesMiningAddresses.length; i++) {
        // Mint some balance for each candidate (imagine that each candidate got the tokens from a bridge)
        const miningAddress = candidatesMiningAddresses[i];
        const stakingAddress = candidatesStakingAddresses[i];
        await erc20Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc20Token.balanceOf.call(stakingAddress));

        // Candidate places stake on themselves
        await stakingAuRa.addPool(candidateMinStake, miningAddress, {from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('  the last validator is removed as malicious', async () => {
      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      const currentBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION - 10));
      await setCurrentBlockNumber(currentBlock);

      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);

      let result = await validatorSetAuRa.reportMalicious(accounts[133], currentBlock.sub(new BN(1)), [], {from: accounts[131]}).should.be.fulfilled;
      result.logs[0].event.should.be.equal("ReportedMalicious");
      result.logs[0].args.reportingValidator.should.be.equal(accounts[131]);
      result = await validatorSetAuRa.reportMalicious(accounts[133], currentBlock.sub(new BN(1)), [], {from: accounts[132]}).should.be.fulfilled;
      result.logs[0].event.should.be.equal("ReportedMalicious");
      result.logs[0].args.reportingValidator.should.be.equal(accounts[132]);

      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(true);
      result = await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
      result.logs[0].event.should.be.equal("InitiateChange");
      result.logs[0].args.newSet.should.be.deep.equal([
        accounts[131],
        accounts[132]
      ]);

      (await validatorSetAuRa.isValidatorBanned.call(accounts[133])).should.be.equal(true);
    });

    it('staking epoch #10 finished', async () => {
      const stakingEpoch = await stakingAuRa.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(10));

      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      const stakingEpochEndBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[131],
        accounts[132],
        accounts[133]
      ]);
      const blocksCreated = stakingEpochEndBlock.sub(await validatorSetAuRa.validatorSetApplyBlock.call()).div(new BN(validators.length));
      blocksCreated.should.be.bignumber.above(new BN(0));
      for (let i = 0; i < validators.length; i++) {
        await blockRewardAuRa.setBlocksCreated(stakingEpoch, validators[i], blocksCreated).should.be.fulfilled;
        await randomAuRa.setSentReveal(validators[i]).should.be.fulfilled;
      }

      const blockRewardBalanceBeforeReward = await erc20Token.balanceOf.call(blockRewardAuRa.address);

      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 11
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);

      let rewardDistributed = new BN(0);
      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardAuRa.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        if (validators[i] == accounts[131] || validators[i] == accounts[132]) {
          epochPoolTokenReward.should.be.bignumber.above(new BN(0));
        } else {
          epochPoolTokenReward.should.be.bignumber.equal(new BN(0));
        }
        rewardDistributed = rewardDistributed.add(epochPoolTokenReward);
      }
      tokenRewardUndistributed = tokenRewardUndistributed.sub(rewardDistributed);
      tokenRewardUndistributed.should.be.bignumber.equal(await blockRewardAuRa.tokenRewardUndistributed.call());

      const blockRewardBalanceAfterReward = await erc20Token.balanceOf.call(blockRewardAuRa.address);

      blockRewardBalanceAfterReward.should.be.bignumber.equal(blockRewardBalanceBeforeReward.add(rewardDistributed));
      (await blockRewardAuRa.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardAuRa.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetAuRa.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[141],
        accounts[142],
        accounts[143],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[131],
        accounts[132],
        accounts[133],
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      const validatorsToBeFinalized = (await validatorSetAuRa.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.sortedEqual([
        accounts[131],
        accounts[132]
      ]);
    });

    it('staking epoch #11 started', async () => {
      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 11));
      await setCurrentBlockNumber(stakingEpochStartBlock);

      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      await callFinalizeChange();
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));

      const validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[131],
        accounts[132]
      ]);

      const {logs} = await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.be.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal([
        accounts[141],
        accounts[142],
        accounts[143]
      ]);
    });

    it('  bridge fee accumulated during the epoch #11', async () => {
      const fee = await accrueBridgeFees();
      tokenRewardUndistributed = tokenRewardUndistributed.add(fee);
    });

    it('  all pending validators remove their pools during the epoch #11', async () => {
      const pendingValidators = await validatorSetAuRa.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[141],
        accounts[142],
        accounts[143],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        const stakingAddress = await validatorSetAuRa.stakingByMiningAddress.call(pendingValidators[i]);
        await stakingAuRa.removeMyPool({from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('  three other candidates are added during the epoch #11', async () => {
      const candidatesMiningAddresses = accounts.slice(151, 153 + 1); // accounts[151...153]
      const candidatesStakingAddresses = accounts.slice(154, 156 + 1); // accounts[154...156]

      for (let i = 0; i < candidatesMiningAddresses.length; i++) {
        // Mint some balance for each candidate (imagine that each candidate got the tokens from a bridge)
        const miningAddress = candidatesMiningAddresses[i];
        const stakingAddress = candidatesStakingAddresses[i];
        await erc20Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc20Token.balanceOf.call(stakingAddress));

        // Candidate places stake on themselves
        await stakingAuRa.addPool(candidateMinStake, miningAddress, {from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('staking epoch #11 finished', async () => {
      const stakingEpoch = await stakingAuRa.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(11));

      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      const stakingEpochEndBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[131],
        accounts[132]
      ]);
      for (let i = 0; i < validators.length; i++) {
        await blockRewardAuRa.setBlocksCreated(stakingEpoch, validators[i], new BN(0)).should.be.fulfilled;
        await randomAuRa.setSentReveal(validators[i]).should.be.fulfilled;
      }
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));

      const blockRewardBalanceBeforeReward = await erc20Token.balanceOf.call(blockRewardAuRa.address);

      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 12
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);

      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardAuRa.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        epochPoolTokenReward.should.be.bignumber.equal(new BN(0));
      }
      tokenRewardUndistributed.should.be.bignumber.equal(await blockRewardAuRa.tokenRewardUndistributed.call());

      const blockRewardBalanceAfterReward = await erc20Token.balanceOf.call(blockRewardAuRa.address);

      blockRewardBalanceAfterReward.should.be.bignumber.equal(blockRewardBalanceBeforeReward);
      (await blockRewardAuRa.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardAuRa.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetAuRa.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[151],
        accounts[152],
        accounts[153],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[131],
        accounts[132]
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      const validatorsToBeFinalized = (await validatorSetAuRa.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.sortedEqual([
        accounts[141],
        accounts[142],
        accounts[143]
      ]);
      for (let i = 0; i < validatorsToBeFinalized.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validatorsToBeFinalized[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validatorsToBeFinalized[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }
    });

    it('staking epoch #12 started', async () => {
      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 12));
      await setCurrentBlockNumber(stakingEpochStartBlock);

      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      await callFinalizeChange();
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(stakingEpochStartBlock);
      let validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[141],
        accounts[142],
        accounts[143]
      ]);

      const {logs} = await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.be.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal([
        accounts[151],
        accounts[152],
        accounts[153]
      ]);

      const currentBlock = stakingEpochStartBlock.add(new BN(10));
      await setCurrentBlockNumber(currentBlock);

      await callFinalizeChange();
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(currentBlock);
      validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[151],
        accounts[152],
        accounts[153]
      ]);
    });

    it('  bridge fee accumulated during the epoch #12', async () => {
      const fee = await accrueBridgeFees();
      tokenRewardUndistributed = tokenRewardUndistributed.add(fee);
    });

    it('staking epoch #12 finished', async () => {
      const stakingEpoch = await stakingAuRa.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(12));

      const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
      const stakingEpochEndBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[151],
        accounts[152],
        accounts[153]
      ]);
      const blocksCreated = stakingEpochEndBlock.sub(await validatorSetAuRa.validatorSetApplyBlock.call()).div(new BN(validators.length));
      blocksCreated.should.be.bignumber.above(new BN(0));
      for (let i = 0; i < validators.length; i++) {
        await blockRewardAuRa.setBlocksCreated(stakingEpoch, validators[i], blocksCreated).should.be.fulfilled;
        await randomAuRa.setSentReveal(validators[i]).should.be.fulfilled;
      }

      const blockRewardBalanceBeforeReward = await erc20Token.balanceOf.call(blockRewardAuRa.address);

      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 13
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(true);

      let rewardDistributed = new BN(0);
      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardAuRa.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        epochPoolTokenReward.should.be.bignumber.above(new BN(0));
        rewardDistributed = rewardDistributed.add(epochPoolTokenReward);
      }
      tokenRewardUndistributed = tokenRewardUndistributed.sub(rewardDistributed);
      tokenRewardUndistributed.should.be.bignumber.equal(await blockRewardAuRa.tokenRewardUndistributed.call());

      const blockRewardBalanceAfterReward = await erc20Token.balanceOf.call(blockRewardAuRa.address);

      blockRewardBalanceAfterReward.should.be.bignumber.equal(blockRewardBalanceBeforeReward.add(rewardDistributed));
      (await blockRewardAuRa.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardAuRa.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetAuRa.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[151],
        accounts[152],
        accounts[153],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      validators = await validatorSetAuRa.getValidators.call();
      validators.sortedEqual([
        accounts[151],
        accounts[152],
        accounts[153],
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardAuRa.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardAuRa.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      const validatorsToBeFinalized = (await validatorSetAuRa.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.length.should.be.equal(0);
    });
  });

  Array.prototype.sortedEqual = function(arr) {
    [...this].sort().should.be.deep.equal([...arr].sort());
  }

  async function accrueBridgeFees() {
    const fee = web3.utils.toWei('1');
    await blockRewardAuRa.setNativeToErcBridgesAllowed([owner], {from: owner}).should.be.fulfilled;
    await blockRewardAuRa.setErcToNativeBridgesAllowed([owner], {from: owner}).should.be.fulfilled;
    await blockRewardAuRa.addBridgeTokenFeeReceivers(fee, {from: owner}).should.be.fulfilled;
    await blockRewardAuRa.addBridgeNativeFeeReceivers(fee, {from: owner}).should.be.fulfilled;
    (await blockRewardAuRa.bridgeTokenFee.call()).should.be.bignumber.equal(fee);
    (await blockRewardAuRa.bridgeNativeFee.call()).should.be.bignumber.equal(fee);
    return new BN(fee);
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
*/