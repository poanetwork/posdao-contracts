const BlockRewardHbbft = artifacts.require('BlockRewardHbbftTokensMock');
const ERC677BridgeTokenRewardable = artifacts.require('ERC677BridgeTokenRewardableMock');
const AdminUpgradeabilityProxy = artifacts.require('AdminUpgradeabilityProxy');
const RandomHbbft = artifacts.require('RandomHbbftMock');
const ValidatorSetHbbft = artifacts.require('ValidatorSetHbbftMock');
const StakingHbbft = artifacts.require('StakingHbbftTokensMock');

const ERROR_MSG = 'VM Exception while processing transaction: revert';
const BN = web3.utils.BN;

const fp = require('lodash/fp');
require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bn')(BN))
  .should();

contract('BlockRewardHbbft', async accounts => {
  let owner;
  let blockRewardHbbft;
  let randomHbbft;
  let stakingHbbft;
  let validatorSetHbbft;
  let erc677Token;
  let candidateMinStake;
  let delegatorMinStake;
  let tokenRewardUndistributed = new BN(0);
  let initialValidatorsPubKeys;
  let initialValidatorsIpAddresses;

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
      // Deploy BlockRewardHbbft contract
      blockRewardHbbft = await BlockRewardHbbft.new();
      blockRewardHbbft = await AdminUpgradeabilityProxy.new(blockRewardHbbft.address, owner, []);
      blockRewardHbbft = await BlockRewardHbbft.at(blockRewardHbbft.address);
      // Deploy RandomHbbft contract
      randomHbbft = await RandomHbbft.new();
      randomHbbft = await AdminUpgradeabilityProxy.new(randomHbbft.address, owner, []);
      randomHbbft = await RandomHbbft.at(randomHbbft.address);
      // Deploy StakingHbbft contract
      stakingHbbft = await StakingHbbft.new();
      stakingHbbft = await AdminUpgradeabilityProxy.new(stakingHbbft.address, owner, []);
      stakingHbbft = await StakingHbbft.at(stakingHbbft.address);
      // Deploy ValidatorSetHbbft contract
      validatorSetHbbft = await ValidatorSetHbbft.new();
      validatorSetHbbft = await AdminUpgradeabilityProxy.new(validatorSetHbbft.address, owner, []);
      validatorSetHbbft = await ValidatorSetHbbft.at(validatorSetHbbft.address);

      // The following private keys belong to the accounts 1-3, fixed by using the "--mnemonic" option when starting ganache.
      // const initialValidatorsPrivKeys = ["0x272b8400a202c08e23641b53368d603e5fec5c13ea2f438bce291f7be63a02a7", "0xa8ea110ffc8fe68a069c8a460ad6b9698b09e21ad5503285f633b3ad79076cf7", "0x5da461ff1378256f69cb9a9d0a8b370c97c460acbe88f5d897cb17209f891ffc"];
      // Public keys corresponding to the three private keys above.
      initialValidatorsPubKeys = fp.flatMap(x => [x.substring(0, 66), '0x' + x.substring(66, 130)])
        (['0x52be8f332b0404dff35dd0b2ba44993a9d3dc8e770b9ce19a849dff948f1e14c57e7c8219d522c1a4cce775adbee5330f222520f0afdabfdb4a4501ceeb8dcee',
          '0x99edf3f524a6f73e7f5d561d0030fc6bcc3e4bd33971715617de7791e12d9bdf6258fa65b74e7161bbbf7ab36161260f56f68336a6f65599dc37e7f2e397f845',
          '0xa255fd7ad199f0ee814ee00cce44ef2b1fa1b52eead5d8013ed85eade03034ae4c246658946c2e1d7ded96394a1247fb4d093c32474317ae388e8d25692a0f56']);
      // The IP addresses are irrelevant for these unit test, just initialize them to 0.
      initialValidatorsIpAddresses = ['0x00000000000000000000000000000000', '0x00000000000000000000000000000000', '0x00000000000000000000000000000000'];

      // Initialize ValidatorSetHbbft
      await validatorSetHbbft.initialize(
        blockRewardHbbft.address, // _blockRewardContract
        randomHbbft.address, // _randomContract
        stakingHbbft.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false // _firstValidatorIsUnremovable
      ).should.be.fulfilled;

      // Initialize StakingHbbft
      await stakingHbbft.initialize(
        validatorSetHbbft.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        web3.utils.toWei('1', 'ether'), // _delegatorMinStake
        web3.utils.toWei('1', 'ether'), // _candidateMinStake
        STAKING_EPOCH_DURATION, // _stakingEpochDuration
        STAKING_EPOCH_START_BLOCK, // _stakingEpochStartBlock
        STAKE_WITHDRAW_DISALLOW_PERIOD, // _stakeWithdrawDisallowPeriod
        initialValidatorsPubKeys, // _publicKeys
        initialValidatorsIpAddresses // _internetAddresses
      ).should.be.fulfilled;

      candidateMinStake = await stakingHbbft.candidateMinStake.call();
      delegatorMinStake = await stakingHbbft.delegatorMinStake.call();

      // Initialize BlockRewardHbbft
      await blockRewardHbbft.initialize(
        validatorSetHbbft.address
      ).should.be.fulfilled;

      // Initialize RandomHbbft
      await randomHbbft.initialize(
        validatorSetHbbft.address
      ).should.be.fulfilled;

      // Start the network
      await setCurrentBlockNumber(STAKING_EPOCH_START_BLOCK);
      await callFinalizeChange();
      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK));

      // Deploy ERC677 contract
      erc677Token = await ERC677BridgeTokenRewardable.new("STAKE", "STAKE", 18, {from: owner});
      await stakingHbbft.setErc677TokenContract(erc677Token.address, {from: owner}).should.be.fulfilled;
      await erc677Token.setBlockRewardContract(blockRewardHbbft.address).should.be.fulfilled;
      await erc677Token.setStakingContract(stakingHbbft.address).should.be.fulfilled;
    });

    it('staking epoch #0 finished', async () => {
      const stakingEpoch = await stakingHbbft.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(0));

      const stakingEpochEndBlock = (await stakingHbbft.stakingEpochStartBlock.call()).add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      const validators = await validatorSetHbbft.getValidators.call();

      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(false);
      await callReward();
      (await stakingHbbft.stakingEpoch.call()).should.be.bignumber.equal(stakingEpoch.add(new BN(1)));
      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(true);
      (await blockRewardHbbft.tokenRewardUndistributed.call()).should.be.bignumber.equal(tokenRewardUndistributed);
    });

    it('staking epoch #1 started', async () => {
      const validators = await validatorSetHbbft.getValidators.call();

      const stakingEpochStartBlock = await stakingHbbft.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 1));
      await setCurrentBlockNumber(stakingEpochStartBlock);

      const {logs} = await validatorSetHbbft.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.be.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal(validators);

      const validatorsToBeFinalized = await validatorSetHbbft.validatorsToBeFinalized.call();
      validatorsToBeFinalized.miningAddresses.should.be.deep.equal(validators);
      validatorsToBeFinalized.forNewEpoch.should.be.equal(true);

      const currentBlock = stakingEpochStartBlock.add(new BN(Math.floor(validators.length / 2) + 1));
      await setCurrentBlockNumber(currentBlock);

      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      await callFinalizeChange();
      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(currentBlock);
      (await validatorSetHbbft.getValidators.call()).should.be.deep.equal(validators);
    });

    it('validators and their delegators place stakes during the epoch #1', async () => {
      const validators = await validatorSetHbbft.getValidators.call();

      for (let i = 0; i < validators.length; i++) {
        // Mint some balance for each validator (imagine that each validator got the tokens from a bridge)
        const stakingAddress = await validatorSetHbbft.stakingByMiningAddress.call(validators[i]);
        await erc677Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc677Token.balanceOf.call(stakingAddress));

        // Validator places stake on themselves
        await stakingHbbft.stake(stakingAddress, candidateMinStake, {from: stakingAddress}).should.be.fulfilled;

        const delegatorsLength = 3;
        const delegators = accounts.slice(11 + i*delegatorsLength, 11 + i*delegatorsLength + delegatorsLength);
        for (let j = 0; j < delegators.length; j++) {
          // Mint some balance for each delegator (imagine that each delegator got the tokens from a bridge)
          await erc677Token.mint(delegators[j], delegatorMinStake, {from: owner}).should.be.fulfilled;
          delegatorMinStake.should.be.bignumber.equal(await erc677Token.balanceOf.call(delegators[j]));

          // Delegator places stake on the validator
          await stakingHbbft.stake(stakingAddress, delegatorMinStake, {from: delegators[j]}).should.be.fulfilled;
        }
      }
    });

    it('bridge fee accumulated during the epoch #1', async () => {
      const fee = await accrueBridgeFees();
      tokenRewardUndistributed = tokenRewardUndistributed.add(fee);
    });

    it('staking epoch #1 finished', async () => {
      const stakingEpoch = await stakingHbbft.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(1));

      const stakingEpochEndBlock = (await stakingHbbft.stakingEpochStartBlock.call()).add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetHbbft.getValidators.call();
      const blocksCreated = stakingEpochEndBlock.sub(await validatorSetHbbft.validatorSetApplyBlock.call()).div(new BN(validators.length));
      blocksCreated.should.be.bignumber.above(new BN(0));
      for (let i = 0; i < validators.length; i++) {
        await blockRewardHbbft.setBlocksCreated(stakingEpoch, validators[i], blocksCreated).should.be.fulfilled;
      }

      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1));
      (await stakingHbbft.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(true);

      (await erc677Token.balanceOf.call(blockRewardHbbft.address)).should.be.bignumber.equal(new BN(0));
      (await blockRewardHbbft.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardHbbft.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardHbbft.tokenRewardUndistributed.call()).should.be.bignumber.equal(tokenRewardUndistributed);

      const pendingValidators = await validatorSetHbbft.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[1],
        accounts[2],
        accounts[3]
      ]);

      validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[1],
        accounts[2],
        accounts[3]
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }

      const validatorsToBeFinalized = (await validatorSetHbbft.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.length.should.be.equal(0);
    });

    it('staking epoch #2 started', async () => {
      const validators = await validatorSetHbbft.getValidators.call();

      const stakingEpochStartBlock = await stakingHbbft.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 2));
      await setCurrentBlockNumber(stakingEpochStartBlock);

      const {logs} = await validatorSetHbbft.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.be.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal(validators);

      const validatorsToBeFinalized = await validatorSetHbbft.validatorsToBeFinalized.call();
      validatorsToBeFinalized.miningAddresses.should.be.deep.equal(validators);
      validatorsToBeFinalized.forNewEpoch.should.be.equal(true);

      const currentBlock = stakingEpochStartBlock.add(new BN(Math.floor(validators.length / 2) + 1));
      await setCurrentBlockNumber(currentBlock);

      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      await callFinalizeChange();
      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(currentBlock);
      (await validatorSetHbbft.getValidators.call()).should.be.deep.equal(validators);
    });

    it('bridge fee accumulated during the epoch #2', async () => {
      const fee = await accrueBridgeFees();
      tokenRewardUndistributed = tokenRewardUndistributed.add(fee);
    });

    it('staking epoch #2 finished', async () => {
      const stakingEpoch = await stakingHbbft.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(2));

      const stakingEpochEndBlock = (await stakingHbbft.stakingEpochStartBlock.call()).add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetHbbft.getValidators.call();
      const blocksCreated = stakingEpochEndBlock.sub(await validatorSetHbbft.validatorSetApplyBlock.call()).div(new BN(validators.length));
      blocksCreated.should.be.bignumber.above(new BN(0));
      for (let i = 0; i < validators.length; i++) {
        await blockRewardHbbft.setBlocksCreated(stakingEpoch, validators[i], blocksCreated).should.be.fulfilled;
      }

      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 3
      (await stakingHbbft.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(true);

      let rewardDistributed = new BN(0);
      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardHbbft.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        epochPoolTokenReward.should.be.bignumber.above(new BN(0));
        rewardDistributed = rewardDistributed.add(epochPoolTokenReward);
        const epochsPoolGotRewardFor = await blockRewardHbbft.epochsPoolGotRewardFor.call(validators[i]);
        epochsPoolGotRewardFor.length.should.be.equal(1);
        epochsPoolGotRewardFor[0].should.be.bignumber.equal(new BN(2));
      }
      rewardDistributed.should.be.bignumber.above(new BN(web3.utils.toWei('1.9')));
      rewardDistributed.should.be.bignumber.below(new BN(web3.utils.toWei('2.1')));
      tokenRewardUndistributed = tokenRewardUndistributed.sub(rewardDistributed);
      tokenRewardUndistributed.should.be.bignumber.equal(await blockRewardHbbft.tokenRewardUndistributed.call());

      (await erc677Token.balanceOf.call(blockRewardHbbft.address)).should.be.bignumber.equal(rewardDistributed);
      (await blockRewardHbbft.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardHbbft.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetHbbft.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[1],
        accounts[2],
        accounts[3]
      ]);

      validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[1],
        accounts[2],
        accounts[3]
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }

      const validatorsToBeFinalized = (await validatorSetHbbft.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.length.should.be.equal(0);
    });

    it('staking epoch #3 started', async () => {
      const validators = await validatorSetHbbft.getValidators.call();

      const stakingEpochStartBlock = await stakingHbbft.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 3));
      await setCurrentBlockNumber(stakingEpochStartBlock);

      const {logs} = await validatorSetHbbft.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.be.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal(validators);

      const validatorsToBeFinalized = await validatorSetHbbft.validatorsToBeFinalized.call();
      validatorsToBeFinalized.miningAddresses.should.be.deep.equal(validators);
      validatorsToBeFinalized.forNewEpoch.should.be.equal(true);

      const currentBlock = stakingEpochStartBlock.add(new BN(Math.floor(validators.length / 2) + 1));
      await setCurrentBlockNumber(currentBlock);

      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      await callFinalizeChange();
      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(currentBlock);
      (await validatorSetHbbft.getValidators.call()).should.be.deep.equal(validators);
    });

    it('three other candidates are added during the epoch #3', async () => {
      const candidatesMiningAddresses = accounts.slice(31, 33 + 1); // accounts[31...33]
      const candidatesStakingAddresses = accounts.slice(34, 36 + 1); // accounts[34...36]

      for (let i = 0; i < candidatesMiningAddresses.length; i++) {
        // Mint some balance for each candidate (imagine that each candidate got the tokens from a bridge)
        const miningAddress = candidatesMiningAddresses[i];
        const stakingAddress = candidatesStakingAddresses[i];
        await erc677Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc677Token.balanceOf.call(stakingAddress));

        // Candidate places stake on themselves
        await stakingHbbft.addPool(candidateMinStake, miningAddress,'0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
        '0x00000000000000000000000000000000', {from: stakingAddress}).should.be.fulfilled;

        const delegatorsLength = 3;
        const delegators = accounts.slice(41 + i*delegatorsLength, 41 + i*delegatorsLength + delegatorsLength);
        for (let j = 0; j < delegators.length; j++) {
          // Mint some balance for each delegator (imagine that each delegator got the tokens from a bridge)
          await erc677Token.mint(delegators[j], delegatorMinStake, {from: owner}).should.be.fulfilled;
          delegatorMinStake.should.be.bignumber.equal(await erc677Token.balanceOf.call(delegators[j]));

          // Delegator places stake on the candidate
          await stakingHbbft.stake(stakingAddress, delegatorMinStake, {from: delegators[j]}).should.be.fulfilled;
        }
    }
    });

    it('bridge fee accumulated during the epoch #3', async () => {
      const fee = await accrueBridgeFees();
      tokenRewardUndistributed = tokenRewardUndistributed.add(fee);
    });

    it('staking epoch #3 finished', async () => {
      const stakingEpoch = await stakingHbbft.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(3));

      const stakingEpochEndBlock = (await stakingHbbft.stakingEpochStartBlock.call()).add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetHbbft.getValidators.call();
      const blocksCreated = stakingEpochEndBlock.sub(await validatorSetHbbft.validatorSetApplyBlock.call()).div(new BN(validators.length));
      blocksCreated.should.be.bignumber.above(new BN(0));
      for (let i = 0; i < validators.length; i++) {
        await blockRewardHbbft.setBlocksCreated(stakingEpoch, validators[i], blocksCreated).should.be.fulfilled;
      }

      const blockRewardBalanceBeforeReward = await erc677Token.balanceOf.call(blockRewardHbbft.address);

      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(false);
      // (await validatorSetHbbft.isValidatorBanned.call(validators[2])).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 4
      (await stakingHbbft.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(true);
      // (await validatorSetHbbft.isValidatorBanned.call(validators[2])).should.be.equal(true);

      let rewardDistributed = new BN(0);
      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardHbbft.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        // if (i == 0) {
        epochPoolTokenReward.should.be.bignumber.above(new BN(0));
        // } else {
        //   epochPoolTokenReward.should.be.bignumber.equal(new BN(0));
        // }
        rewardDistributed = rewardDistributed.add(epochPoolTokenReward);
        const epochsPoolGotRewardFor = await blockRewardHbbft.epochsPoolGotRewardFor.call(validators[i]);
        // if (i == 0) {
        epochsPoolGotRewardFor.length.should.be.equal(2);
        epochsPoolGotRewardFor[0].should.be.bignumber.equal(new BN(2));
        epochsPoolGotRewardFor[1].should.be.bignumber.equal(new BN(3));
        // } else {
          // epochsPoolGotRewardFor.length.should.be.equal(2);
          // epochsPoolGotRewardFor[0].should.be.bignumber.equal(new BN(2));
        // }
      }
      rewardDistributed.should.be.bignumber.above(new BN(0));
      tokenRewardUndistributed = tokenRewardUndistributed.sub(rewardDistributed);
      tokenRewardUndistributed.should.be.bignumber.equal(await blockRewardHbbft.tokenRewardUndistributed.call());

      const blockRewardBalanceAfterReward = await erc677Token.balanceOf.call(blockRewardHbbft.address);

      blockRewardBalanceAfterReward.should.be.bignumber.equal(blockRewardBalanceBeforeReward.add(rewardDistributed));
      (await blockRewardHbbft.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardHbbft.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetHbbft.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[1],
        accounts[2],
        accounts[3],
        accounts[31],
        accounts[32],
        accounts[33],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }

      validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[1],
        accounts[2],
        accounts[3]
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }

      const validatorsToBeFinalized = (await validatorSetHbbft.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.length.should.be.equal(0);
    });

    it('staking epoch #4 started', async () => {
      const prevValidators = await validatorSetHbbft.getValidators.call();
      const pendingValidators = await validatorSetHbbft.getPendingValidators.call();

      const stakingEpochStartBlock = await stakingHbbft.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 4));
      let currentBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION / 2));
      await setCurrentBlockNumber(currentBlock);

      const {logs} = await validatorSetHbbft.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.be.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal(pendingValidators);

      const validatorsToBeFinalized = await validatorSetHbbft.validatorsToBeFinalized.call();
      validatorsToBeFinalized.miningAddresses.should.be.deep.equal(pendingValidators);
      validatorsToBeFinalized.forNewEpoch.should.be.equal(true);

      currentBlock = currentBlock.add(new BN(Math.floor(prevValidators.length / 2) + 1));
      await setCurrentBlockNumber(currentBlock);

      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      await callFinalizeChange();
      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(currentBlock);
      (await validatorSetHbbft.getValidators.call()).should.be.deep.equal(pendingValidators);
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
        await erc677Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc677Token.balanceOf.call(stakingAddress));

        // Candidate places stake on themselves
        await stakingHbbft.addPool(candidateMinStake, miningAddress, '0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
        '0x00000000000000000000000000000000', {from: stakingAddress}).should.be.fulfilled;

        const delegatorsLength = 3;
        const delegators = accounts.slice(71 + i*delegatorsLength, 71 + i*delegatorsLength + delegatorsLength);
        for (let j = 0; j < delegators.length; j++) {
          // Mint some balance for each delegator (imagine that each delegator got the tokens from a bridge)
          await erc677Token.mint(delegators[j], delegatorMinStake, {from: owner}).should.be.fulfilled;
          delegatorMinStake.should.be.bignumber.equal(await erc677Token.balanceOf.call(delegators[j]));

          // Delegator places stake on the candidate
          await stakingHbbft.stake(stakingAddress, delegatorMinStake, {from: delegators[j]}).should.be.fulfilled;
        }
      }
    });

    it('  current validators remove their pools during the epoch #4', async () => {
      const validators = await validatorSetHbbft.getValidators.call();
      for (let i = 0; i < validators.length; i++) {
        const stakingAddress = await validatorSetHbbft.stakingByMiningAddress.call(validators[i]);
        await stakingHbbft.removeMyPool({from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('staking epoch #4 finished', async () => {
      const stakingEpoch = await stakingHbbft.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(4));

      const stakingEpochEndBlock = (await stakingHbbft.stakingEpochStartBlock.call()).add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetHbbft.getValidators.call();
      const blocksCreated = stakingEpochEndBlock.sub(await validatorSetHbbft.validatorSetApplyBlock.call()).div(new BN(validators.length));
      blocksCreated.should.be.bignumber.above(new BN(0));
      for (let i = 0; i < validators.length; i++) {
        await blockRewardHbbft.setBlocksCreated(stakingEpoch, validators[i], blocksCreated).should.be.fulfilled;
      }

      const blockRewardBalanceBeforeReward = await erc677Token.balanceOf.call(blockRewardHbbft.address);

      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 4
      (await stakingHbbft.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(true);

      let rewardDistributed = new BN(0);
      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardHbbft.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        epochPoolTokenReward.should.be.bignumber.above(new BN(0));
        rewardDistributed = rewardDistributed.add(epochPoolTokenReward);
        const epochsPoolGotRewardFor = await blockRewardHbbft.epochsPoolGotRewardFor.call(validators[i]);
        if (i == 0) {
          epochsPoolGotRewardFor.length.should.be.equal(3);
          epochsPoolGotRewardFor[0].should.be.bignumber.equal(new BN(2));
          epochsPoolGotRewardFor[1].should.be.bignumber.equal(new BN(3));
          epochsPoolGotRewardFor[2].should.be.bignumber.equal(new BN(4));
        }
        // else {
        //   epochsPoolGotRewardFor.length.should.be.equal(1);
        //   epochsPoolGotRewardFor[0].should.be.bignumber.equal(new BN(4));
        // }
      }
      rewardDistributed.should.be.bignumber.above(web3.utils.toWei(new BN(1)).div(new BN(2)));
      rewardDistributed.should.be.bignumber.below(web3.utils.toWei(new BN(1)));
      tokenRewardUndistributed = tokenRewardUndistributed.sub(rewardDistributed);
      tokenRewardUndistributed.should.be.bignumber.equal(await blockRewardHbbft.tokenRewardUndistributed.call());

      const blockRewardBalanceAfterReward = await erc677Token.balanceOf.call(blockRewardHbbft.address);

      blockRewardBalanceAfterReward.should.be.bignumber.equal(blockRewardBalanceBeforeReward.add(rewardDistributed));
      (await blockRewardHbbft.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardHbbft.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetHbbft.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }

      validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[1],
        accounts[2],
        accounts[3],
        accounts[31],
        accounts[32],
        accounts[33],
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }

      const validatorsToBeFinalized = (await validatorSetHbbft.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.length.should.be.equal(0);
    });

    it('staking epoch #5 started', async () => {
      const prevValidators = await validatorSetHbbft.getValidators.call();
      const pendingValidators = await validatorSetHbbft.getPendingValidators.call();

      const stakingEpochStartBlock = await stakingHbbft.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 5));
      await setCurrentBlockNumber(stakingEpochStartBlock);

      const {logs} = await validatorSetHbbft.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.be.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal(pendingValidators); // 61 62 63

      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
    });

    it('  bridge fee accumulated during the epoch #5', async () => {
      const fee = await accrueBridgeFees();
      tokenRewardUndistributed = tokenRewardUndistributed.add(fee);
    });

    it('  current pending validators remove their pools during the epoch #5', async () => {
      const pendingValidators = await validatorSetHbbft.getPendingValidators.call();
      for (let i = 0; i < pendingValidators.length; i++) {
        const stakingAddress = await validatorSetHbbft.stakingByMiningAddress.call(pendingValidators[i]);
        await stakingHbbft.removeMyPool({from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('  three other candidates are added during the epoch #5', async () => {
      const candidatesMiningAddresses = accounts.slice(91, 93 + 1); // accounts[91...93]
      const candidatesStakingAddresses = accounts.slice(94, 96 + 1); // accounts[94...96]

      for (let i = 0; i < candidatesMiningAddresses.length; i++) {
        // Mint some balance for each candidate (imagine that each candidate got the tokens from a bridge)
        const miningAddress = candidatesMiningAddresses[i];
        const stakingAddress = candidatesStakingAddresses[i];
        await erc677Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc677Token.balanceOf.call(stakingAddress));

        // Candidate places stake on themselves
        await stakingHbbft.addPool(candidateMinStake, miningAddress, '0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
        '0x00000000000000000000000000000000', {from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('staking epoch #5 finished', async () => {
      const stakingEpoch = await stakingHbbft.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(5));

      const stakingEpochEndBlock = (await stakingHbbft.stakingEpochStartBlock.call()).add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[1],
        accounts[2],
        accounts[3],
        accounts[31],
        accounts[32],
        accounts[33]
      ]);

      const blockRewardBalanceBeforeReward = await erc677Token.balanceOf.call(blockRewardHbbft.address);

      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(false);
      (await validatorSetHbbft.isValidatorBanned.call(accounts[32])).should.be.equal(false);
      (await validatorSetHbbft.isValidatorBanned.call(accounts[33])).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 6
      (await stakingHbbft.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(false);
      // (await validatorSetHbbft.isValidatorBanned.call(accounts[32])).should.be.equal(true);
      // (await validatorSetHbbft.isValidatorBanned.call(accounts[33])).should.be.equal(true);

      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardHbbft.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        epochPoolTokenReward.should.be.bignumber.equal(new BN(0));
      }

      const blockRewardBalanceAfterReward = await erc677Token.balanceOf.call(blockRewardHbbft.address);

      blockRewardBalanceAfterReward.should.be.bignumber.equal(blockRewardBalanceBeforeReward);
      (await blockRewardHbbft.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardHbbft.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetHbbft.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[91],
        accounts[92],
        accounts[93],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[1],
        accounts[2],
        accounts[3],
        accounts[31],
        accounts[32],
        accounts[33],
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }

      const validatorsToBeFinalized = (await validatorSetHbbft.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63]
      ]);
      for (let i = 0; i < validatorsToBeFinalized.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validatorsToBeFinalized[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validatorsToBeFinalized[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }
    });

    it('staking epoch #6 started', async () => {
      const stakingEpochStartBlock = await stakingHbbft.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 6));
      let currentBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION / 2));
      await setCurrentBlockNumber(currentBlock);

      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      await callFinalizeChange();
      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(currentBlock);
      const validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63]
      ]);

      const {logs} = await validatorSetHbbft.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.be.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal([
        accounts[91],
        accounts[92],
        accounts[93]
      ]);
    });

    it('bridge fee accumulated during the epoch #6', async () => {
      const fee = await accrueBridgeFees();
      tokenRewardUndistributed = tokenRewardUndistributed.add(fee);
    });

    it('  all upcoming validators remove their pools during the epoch #6', async () => {
      const validatorsToBeFinalized = (await validatorSetHbbft.validatorsToBeFinalized.call()).miningAddresses;
      for (let i = 0; i < validatorsToBeFinalized.length; i++) {
        const stakingAddress = await validatorSetHbbft.stakingByMiningAddress.call(validatorsToBeFinalized[i]);
        await stakingHbbft.removeMyPool({from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('three other candidates are added during the epoch #6', async () => {
      const candidatesMiningAddresses = accounts.slice(101, 103 + 1); // accounts[101...103]
      const candidatesStakingAddresses = accounts.slice(104, 106 + 1); // accounts[104...106]

      for (let i = 0; i < candidatesMiningAddresses.length; i++) {
        // Mint some balance for each candidate (imagine that each candidate got the tokens from a bridge)
        const miningAddress = candidatesMiningAddresses[i];
        const stakingAddress = candidatesStakingAddresses[i];
        await erc677Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc677Token.balanceOf.call(stakingAddress));

        // Candidate places stake on themselves
        await stakingHbbft.addPool(candidateMinStake, miningAddress, '0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
        '0x00000000000000000000000000000000', {from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('staking epoch #6 finished', async () => {
      const stakingEpoch = await stakingHbbft.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(6));

      const stakingEpochEndBlock = (await stakingHbbft.stakingEpochStartBlock.call()).add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetHbbft.getValidators.call();
      const blocksCreated = stakingEpochEndBlock.sub(await validatorSetHbbft.validatorSetApplyBlock.call()).div(new BN(validators.length));
      blocksCreated.should.be.bignumber.above(new BN(0));
      validators.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63]
      ]);
      for (let i = 0; i < validators.length; i++) {
        await blockRewardHbbft.setBlocksCreated(stakingEpoch, validators[i], blocksCreated).should.be.fulfilled;
      }

      const blockRewardBalanceBeforeReward = await erc677Token.balanceOf.call(blockRewardHbbft.address);

      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(false);
      (await validatorSetHbbft.isValidatorBanned.call(accounts[62])).should.be.equal(false);
      (await validatorSetHbbft.isValidatorBanned.call(accounts[63])).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 7
      (await stakingHbbft.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(false);
      // (await validatorSetHbbft.isValidatorBanned.call(accounts[62])).should.be.equal(true);
      // (await validatorSetHbbft.isValidatorBanned.call(accounts[63])).should.be.equal(true);

      let rewardDistributed = new BN(0);
      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardHbbft.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        // if (validators[i] == accounts[61]) {
          epochPoolTokenReward.should.be.bignumber.above(new BN(0));
        // } else {
          // epochPoolTokenReward.should.be.bignumber.equal(new BN(0));
        // }
        rewardDistributed = rewardDistributed.add(epochPoolTokenReward);
      }
      Math.round(Number(web3.utils.fromWei(rewardDistributed)) * 100).should.be.equal(
        Math.round(Number(web3.utils.fromWei(tokenRewardUndistributed.div(new BN(2)))) * 100)
      );
      tokenRewardUndistributed = tokenRewardUndistributed.sub(rewardDistributed);
      tokenRewardUndistributed.should.be.bignumber.equal(await blockRewardHbbft.tokenRewardUndistributed.call());

      const blockRewardBalanceAfterReward = await erc677Token.balanceOf.call(blockRewardHbbft.address);

      blockRewardBalanceAfterReward.should.be.bignumber.equal(blockRewardBalanceBeforeReward.add(rewardDistributed));
      (await blockRewardHbbft.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardHbbft.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetHbbft.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[101],
        accounts[102],
        accounts[103],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63],
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }

      const validatorsToBeFinalized = (await validatorSetHbbft.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.sortedEqual([
        accounts[91],
        accounts[92],
        accounts[93]
      ]);
      for (let i = 0; i < validatorsToBeFinalized.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validatorsToBeFinalized[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validatorsToBeFinalized[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }
    });

    it('staking epoch #7 started', async () => {
      const stakingEpochStartBlock = await stakingHbbft.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 7));
      await setCurrentBlockNumber(stakingEpochStartBlock);

      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      const validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63]
      ]);

      await validatorSetHbbft.emitInitiateChange().should.be.rejectedWith(ERROR_MSG);
    });

    it('  bridge fee accumulated during the epoch #7', async () => {
      const fee = await accrueBridgeFees();
      tokenRewardUndistributed = tokenRewardUndistributed.add(fee);
    });

    it('  all pending validators remove their pools during the epoch #7', async () => {
      const pendingValidators = await validatorSetHbbft.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[101],
        accounts[102],
        accounts[103],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        const stakingAddress = await validatorSetHbbft.stakingByMiningAddress.call(pendingValidators[i]);
        await stakingHbbft.removeMyPool({from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('  three other candidates are added during the epoch #7', async () => {
      const candidatesMiningAddresses = accounts.slice(111, 113 + 1); // accounts[111...113]
      const candidatesStakingAddresses = accounts.slice(114, 116 + 1); // accounts[114...116]

      for (let i = 0; i < candidatesMiningAddresses.length; i++) {
        // Mint some balance for each candidate (imagine that each candidate got the tokens from a bridge)
        const miningAddress = candidatesMiningAddresses[i];
        const stakingAddress = candidatesStakingAddresses[i];
        await erc677Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc677Token.balanceOf.call(stakingAddress));

        // Candidate places stake on themselves
        await stakingHbbft.addPool(candidateMinStake, miningAddress, '0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
        '0x00000000000000000000000000000000', {from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('staking epoch #7 finished', async () => {
      const stakingEpoch = await stakingHbbft.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(7));

      const stakingEpochStartBlock = await stakingHbbft.stakingEpochStartBlock.call();
      const stakingEpochEndBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63]
      ]);
      for (let i = 0; i < validators.length; i++) {
        await blockRewardHbbft.setBlocksCreated(stakingEpoch, validators[i], new BN(0)).should.be.fulfilled;
      }

      const blockRewardBalanceBeforeReward = await erc677Token.balanceOf.call(blockRewardHbbft.address);

      const bannedUntil62 = await validatorSetHbbft.bannedUntil.call(accounts[62]);
      const bannedUntil63 = await validatorSetHbbft.bannedUntil.call(accounts[63]);
      const bannedDelegatorsUntil62 = await validatorSetHbbft.bannedDelegatorsUntil.call(accounts[62]);
      const bannedDelegatorsUntil63 = await validatorSetHbbft.bannedDelegatorsUntil.call(accounts[63]);

      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(false);
      // (await validatorSetHbbft.isValidatorBanned.call(accounts[62])).should.be.equal(true);
      // (await validatorSetHbbft.isValidatorBanned.call(accounts[63])).should.be.equal(true);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 8
      (await stakingHbbft.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(false);
      // (await validatorSetHbbft.isValidatorBanned.call(accounts[62])).should.be.equal(true);
      // (await validatorSetHbbft.isValidatorBanned.call(accounts[63])).should.be.equal(true);
      // (await validatorSetHbbft.bannedUntil.call(accounts[62])).should.be.bignumber.equal(bannedUntil62.add(new BN(STAKING_EPOCH_DURATION)));
      // (await validatorSetHbbft.bannedUntil.call(accounts[63])).should.be.bignumber.equal(bannedUntil63.add(new BN(STAKING_EPOCH_DURATION)));
      // (await validatorSetHbbft.bannedDelegatorsUntil.call(accounts[62])).should.be.bignumber.equal(bannedDelegatorsUntil62);
      // (await validatorSetHbbft.bannedDelegatorsUntil.call(accounts[63])).should.be.bignumber.equal(bannedDelegatorsUntil63);

      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardHbbft.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        epochPoolTokenReward.should.be.bignumber.equal(new BN(0));
      }
      tokenRewardUndistributed.should.be.bignumber.equal(await blockRewardHbbft.tokenRewardUndistributed.call());

      const blockRewardBalanceAfterReward = await erc677Token.balanceOf.call(blockRewardHbbft.address);

      blockRewardBalanceAfterReward.should.be.bignumber.equal(blockRewardBalanceBeforeReward);
      (await blockRewardHbbft.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardHbbft.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetHbbft.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[111],
        accounts[112],
        accounts[113],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63],
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }

      const validatorsToBeFinalized = (await validatorSetHbbft.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.sortedEqual([
        accounts[91],
        accounts[92],
        accounts[93]
      ]);
      for (let i = 0; i < validatorsToBeFinalized.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validatorsToBeFinalized[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validatorsToBeFinalized[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }
    });

    it('staking epoch #8 started', async () => {
      const stakingEpochStartBlock = await stakingHbbft.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 8));
      await setCurrentBlockNumber(stakingEpochStartBlock);

      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      const validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63]
      ]);

      await validatorSetHbbft.emitInitiateChange().should.be.rejectedWith(ERROR_MSG);
    });

    it('  bridge fee accumulated during the epoch #8', async () => {
      const fee = await accrueBridgeFees();
      tokenRewardUndistributed = tokenRewardUndistributed.add(fee);
    });

    it('  all pending validators remove their pools during the epoch #8', async () => {
      const pendingValidators = await validatorSetHbbft.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[111],
        accounts[112],
        accounts[113],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        const stakingAddress = await validatorSetHbbft.stakingByMiningAddress.call(pendingValidators[i]);
        await stakingHbbft.removeMyPool({from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('  three other candidates are added during the epoch #8', async () => {
      const candidatesMiningAddresses = accounts.slice(121, 123 + 1); // accounts[121...123]
      const candidatesStakingAddresses = accounts.slice(124, 126 + 1); // accounts[124...126]

      for (let i = 0; i < candidatesMiningAddresses.length; i++) {
        // Mint some balance for each candidate (imagine that each candidate got the tokens from a bridge)
        const miningAddress = candidatesMiningAddresses[i];
        const stakingAddress = candidatesStakingAddresses[i];
        await erc677Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc677Token.balanceOf.call(stakingAddress));

        // Candidate places stake on themselves
        await stakingHbbft.addPool(candidateMinStake, miningAddress, '0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
        '0x00000000000000000000000000000000', {from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('staking epoch #8 finished', async () => {
      const stakingEpoch = await stakingHbbft.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(8));

      const stakingEpochStartBlock = await stakingHbbft.stakingEpochStartBlock.call();
      const stakingEpochEndBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63]
      ]);
      for (let i = 0; i < validators.length; i++) {
        await blockRewardHbbft.setBlocksCreated(stakingEpoch, validators[i], new BN(0)).should.be.fulfilled;
      }

      const blockRewardBalanceBeforeReward = await erc677Token.balanceOf.call(blockRewardHbbft.address);

      // const bannedUntil62 = await validatorSetHbbft.bannedUntil.call(accounts[62]);
      // const bannedUntil63 = await validatorSetHbbft.bannedUntil.call(accounts[63]);
      // const bannedDelegatorsUntil62 = await validatorSetHbbft.bannedDelegatorsUntil.call(accounts[62]);
      // const bannedDelegatorsUntil63 = await validatorSetHbbft.bannedDelegatorsUntil.call(accounts[63]);

      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(false);
      // (await validatorSetHbbft.isValidatorBanned.call(accounts[62])).should.be.equal(true);
      // (await validatorSetHbbft.isValidatorBanned.call(accounts[63])).should.be.equal(true);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 9
      (await stakingHbbft.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(false);
      // (await validatorSetHbbft.isValidatorBanned.call(accounts[62])).should.be.equal(true);
      // (await validatorSetHbbft.isValidatorBanned.call(accounts[63])).should.be.equal(true);
      // (await validatorSetHbbft.bannedUntil.call(accounts[62])).should.be.bignumber.equal(bannedUntil62.add(new BN(STAKING_EPOCH_DURATION)));
      // (await validatorSetHbbft.bannedUntil.call(accounts[63])).should.be.bignumber.equal(bannedUntil63.add(new BN(STAKING_EPOCH_DURATION)));
      // (await validatorSetHbbft.bannedDelegatorsUntil.call(accounts[62])).should.be.bignumber.equal(bannedDelegatorsUntil62);
      // (await validatorSetHbbft.bannedDelegatorsUntil.call(accounts[63])).should.be.bignumber.equal(bannedDelegatorsUntil63);

      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardHbbft.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        epochPoolTokenReward.should.be.bignumber.equal(new BN(0));
      }
      tokenRewardUndistributed.should.be.bignumber.equal(await blockRewardHbbft.tokenRewardUndistributed.call());

      const blockRewardBalanceAfterReward = await erc677Token.balanceOf.call(blockRewardHbbft.address);

      blockRewardBalanceAfterReward.should.be.bignumber.equal(blockRewardBalanceBeforeReward);
      (await blockRewardHbbft.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardHbbft.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetHbbft.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[121],
        accounts[122],
        accounts[123],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[61],
        accounts[62],
        accounts[63],
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake.add(delegatorMinStake.mul(new BN(3)))
        );
      }

      const validatorsToBeFinalized = (await validatorSetHbbft.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.sortedEqual([
        accounts[91],
        accounts[92],
        accounts[93]
      ]);
      for (let i = 0; i < validatorsToBeFinalized.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validatorsToBeFinalized[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validatorsToBeFinalized[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }
    });

    it('staking epoch #9 started', async () => {
      const stakingEpochStartBlock = await stakingHbbft.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 9));
      let currentBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION / 4));
      await setCurrentBlockNumber(currentBlock);

      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      await callFinalizeChange();
      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(currentBlock);
      let validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[91],
        accounts[92],
        accounts[93]
      ]);

      currentBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION / 2));
      await setCurrentBlockNumber(currentBlock);

      const {logs} = await validatorSetHbbft.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.be.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal([
        accounts[121],
        accounts[122],
        accounts[123]
      ]);

      await callFinalizeChange();

      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(currentBlock);
      validators = await validatorSetHbbft.getValidators.call();
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
      const validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[121],
        accounts[122],
        accounts[123],
      ]);
      for (let i = 0; i < validators.length; i++) {
        const stakingAddress = await validatorSetHbbft.stakingByMiningAddress.call(validators[i]);
        await stakingHbbft.removeMyPool({from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('  three other candidates are added during the epoch #9', async () => {
      const candidatesMiningAddresses = accounts.slice(131, 133 + 1); // accounts[131...133]
      const candidatesStakingAddresses = accounts.slice(134, 136 + 1); // accounts[134...136]

      for (let i = 0; i < candidatesMiningAddresses.length; i++) {
        // Mint some balance for each candidate (imagine that each candidate got the tokens from a bridge)
        const miningAddress = candidatesMiningAddresses[i];
        const stakingAddress = candidatesStakingAddresses[i];
        await erc677Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc677Token.balanceOf.call(stakingAddress));

        // Candidate places stake on themselves
        await stakingHbbft.addPool(candidateMinStake, miningAddress, '0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
        '0x00000000000000000000000000000000', {from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('staking epoch #9 finished', async () => {
      const stakingEpoch = await stakingHbbft.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(9));

      const stakingEpochStartBlock = await stakingHbbft.stakingEpochStartBlock.call();
      const stakingEpochEndBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[121],
        accounts[122],
        accounts[123]
      ]);
      const blocksCreated = stakingEpochEndBlock.sub(await validatorSetHbbft.validatorSetApplyBlock.call()).div(new BN(validators.length));
      blocksCreated.should.be.bignumber.above(new BN(0));
      for (let i = 0; i < validators.length; i++) {
        await blockRewardHbbft.setBlocksCreated(stakingEpoch, validators[i], blocksCreated).should.be.fulfilled;
      }

      const blockRewardBalanceBeforeReward = await erc677Token.balanceOf.call(blockRewardHbbft.address);

      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 10
      (await stakingHbbft.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(true);

      let rewardDistributed = new BN(0);
      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardHbbft.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        epochPoolTokenReward.should.be.bignumber.above(new BN(0));
        rewardDistributed = rewardDistributed.add(epochPoolTokenReward);
      }
      rewardDistributed.toString().substring(0, 3).should.be.equal(tokenRewardUndistributed.div(new BN(2)).toString().substring(0, 3));
      tokenRewardUndistributed = tokenRewardUndistributed.sub(rewardDistributed);
      tokenRewardUndistributed.should.be.bignumber.equal(await blockRewardHbbft.tokenRewardUndistributed.call());

      const blockRewardBalanceAfterReward = await erc677Token.balanceOf.call(blockRewardHbbft.address);

      blockRewardBalanceAfterReward.should.be.bignumber.equal(blockRewardBalanceBeforeReward.add(rewardDistributed));
      (await blockRewardHbbft.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardHbbft.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetHbbft.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[131],
        accounts[132],
        accounts[133],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[121],
        accounts[122],
        accounts[123],
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      const validatorsToBeFinalized = (await validatorSetHbbft.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.length.should.be.equal(0);
    });

    it('staking epoch #10 started', async () => {
      const stakingEpochStartBlock = await stakingHbbft.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 10));
      await setCurrentBlockNumber(stakingEpochStartBlock);

      const {logs} = await validatorSetHbbft.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.be.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal([
        accounts[131],
        accounts[132],
        accounts[133]
      ]);

      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      await callFinalizeChange();
      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(stakingEpochStartBlock);
      let validators = await validatorSetHbbft.getValidators.call();
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
      const validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[131],
        accounts[132],
        accounts[133],
      ]);
      for (let i = 0; i < validators.length; i++) {
        const stakingAddress = await validatorSetHbbft.stakingByMiningAddress.call(validators[i]);
        await stakingHbbft.removeMyPool({from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('  three other candidates are added during the epoch #10', async () => {
      const candidatesMiningAddresses = accounts.slice(141, 143 + 1); // accounts[141...143]
      const candidatesStakingAddresses = accounts.slice(144, 146 + 1); // accounts[144...146]

      for (let i = 0; i < candidatesMiningAddresses.length; i++) {
        // Mint some balance for each candidate (imagine that each candidate got the tokens from a bridge)
        const miningAddress = candidatesMiningAddresses[i];
        const stakingAddress = candidatesStakingAddresses[i];
        await erc677Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc677Token.balanceOf.call(stakingAddress));

        // Candidate places stake on themselves
        await stakingHbbft.addPool(candidateMinStake, miningAddress, '0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
        '0x00000000000000000000000000000000', {from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('  the last validator is removed as malicious', async () => {
      const stakingEpochStartBlock = await stakingHbbft.stakingEpochStartBlock.call();
      const currentBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION - 10));
      await setCurrentBlockNumber(currentBlock);

      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(false);

      let result = await validatorSetHbbft.reportMalicious(accounts[133], currentBlock.sub(new BN(1)), [], {from: accounts[131]}).should.be.fulfilled;
      result.logs[0].event.should.be.equal("ReportedMalicious");
      result.logs[0].args.reportingValidator.should.be.equal(accounts[131]);
      result = await validatorSetHbbft.reportMalicious(accounts[133], currentBlock.sub(new BN(1)), [], {from: accounts[132]}).should.be.fulfilled;
      result.logs[0].event.should.be.equal("ReportedMalicious");
      result.logs[0].args.reportingValidator.should.be.equal(accounts[132]);

      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(true);
      result = await validatorSetHbbft.emitInitiateChange().should.be.fulfilled;
      result.logs[0].event.should.be.equal("InitiateChange");
      result.logs[0].args.newSet.should.be.deep.equal([
        accounts[131],
        accounts[132]
      ]);

      // (await validatorSetHbbft.isValidatorBanned.call(accounts[133])).should.be.equal(true);
    });

    it('staking epoch #10 finished', async () => {
      const stakingEpoch = await stakingHbbft.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(10));

      const stakingEpochStartBlock = await stakingHbbft.stakingEpochStartBlock.call();
      const stakingEpochEndBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[131],
        accounts[132],
        accounts[133]
      ]);
      const blocksCreated = stakingEpochEndBlock.sub(await validatorSetHbbft.validatorSetApplyBlock.call()).div(new BN(validators.length));
      blocksCreated.should.be.bignumber.above(new BN(0));
      for (let i = 0; i < validators.length; i++) {
        await blockRewardHbbft.setBlocksCreated(stakingEpoch, validators[i], blocksCreated).should.be.fulfilled;
      }

      const blockRewardBalanceBeforeReward = await erc677Token.balanceOf.call(blockRewardHbbft.address);

      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 11
      (await stakingHbbft.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(false);

      let rewardDistributed = new BN(0);
      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardHbbft.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        if (validators[i] == accounts[131] || validators[i] == accounts[132]) {
          epochPoolTokenReward.should.be.bignumber.above(new BN(0));
        } else {
          epochPoolTokenReward.should.be.bignumber.equal(new BN(0));
        }
        rewardDistributed = rewardDistributed.add(epochPoolTokenReward);
      }
      tokenRewardUndistributed = tokenRewardUndistributed.sub(rewardDistributed);
      tokenRewardUndistributed.should.be.bignumber.equal(await blockRewardHbbft.tokenRewardUndistributed.call());

      const blockRewardBalanceAfterReward = await erc677Token.balanceOf.call(blockRewardHbbft.address);

      blockRewardBalanceAfterReward.should.be.bignumber.equal(blockRewardBalanceBeforeReward.add(rewardDistributed));
      (await blockRewardHbbft.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardHbbft.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetHbbft.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[141],
        accounts[142],
        accounts[143],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[131],
        accounts[132],
        accounts[133],
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      const validatorsToBeFinalized = (await validatorSetHbbft.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.sortedEqual([
        accounts[131],
        accounts[132]
      ]);
    });

    it('staking epoch #11 started', async () => {
      const stakingEpochStartBlock = await stakingHbbft.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 11));
      await setCurrentBlockNumber(stakingEpochStartBlock);

      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      await callFinalizeChange();
      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));

      const validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[131],
        accounts[132]
      ]);

      const {logs} = await validatorSetHbbft.emitInitiateChange().should.be.fulfilled;
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
      const pendingValidators = await validatorSetHbbft.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[141],
        accounts[142],
        accounts[143],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        const stakingAddress = await validatorSetHbbft.stakingByMiningAddress.call(pendingValidators[i]);
        await stakingHbbft.removeMyPool({from: stakingAddress}).should.be.fulfilled;
      }
    });

    it('  three other candidates are added during the epoch #11', async () => {
      const candidatesMiningAddresses = accounts.slice(151, 153 + 1); // accounts[151...153]
      const candidatesStakingAddresses = accounts.slice(154, 156 + 1); // accounts[154...156]

      for (let i = 0; i < candidatesMiningAddresses.length; i++) {
        // Mint some balance for each candidate (imagine that each candidate got the tokens from a bridge)
        const miningAddress = candidatesMiningAddresses[i];
        const stakingAddress = candidatesStakingAddresses[i];
        await erc677Token.mint(stakingAddress, candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc677Token.balanceOf.call(stakingAddress));

        // Candidate places stake on themselves
        await stakingHbbft.addPool(candidateMinStake, miningAddress, '0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
        '0x00000000000000000000000000000000', {from: stakingAddress}).should.be.fulfilled;

      }
    });

    it('staking epoch #11 finished', async () => {
      const stakingEpoch = await stakingHbbft.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(11));

      const stakingEpochStartBlock = await stakingHbbft.stakingEpochStartBlock.call();
      const stakingEpochEndBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[131],
        accounts[132]
      ]);
      for (let i = 0; i < validators.length; i++) {
        await blockRewardHbbft.setBlocksCreated(stakingEpoch, validators[i], new BN(0)).should.be.fulfilled;
      }
      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));

      const blockRewardBalanceBeforeReward = await erc677Token.balanceOf.call(blockRewardHbbft.address);

      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 12
      (await stakingHbbft.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(false);

      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardHbbft.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        epochPoolTokenReward.should.be.bignumber.equal(new BN(0));
      }
      tokenRewardUndistributed.should.be.bignumber.equal(await blockRewardHbbft.tokenRewardUndistributed.call());

      const blockRewardBalanceAfterReward = await erc677Token.balanceOf.call(blockRewardHbbft.address);

      blockRewardBalanceAfterReward.should.be.bignumber.equal(blockRewardBalanceBeforeReward);
      (await blockRewardHbbft.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardHbbft.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetHbbft.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[151],
        accounts[152],
        accounts[153],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[131],
        accounts[132]
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      const validatorsToBeFinalized = (await validatorSetHbbft.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.sortedEqual([
        accounts[141],
        accounts[142],
        accounts[143]
      ]);
      for (let i = 0; i < validatorsToBeFinalized.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validatorsToBeFinalized[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validatorsToBeFinalized[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }
    });

    it('staking epoch #12 started', async () => {
      const stakingEpochStartBlock = await stakingHbbft.stakingEpochStartBlock.call();
      stakingEpochStartBlock.should.be.bignumber.equal(new BN(STAKING_EPOCH_START_BLOCK + STAKING_EPOCH_DURATION * 12));
      await setCurrentBlockNumber(stakingEpochStartBlock);

      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      await callFinalizeChange();
      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(stakingEpochStartBlock);
      let validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[141],
        accounts[142],
        accounts[143]
      ]);

      const {logs} = await validatorSetHbbft.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.be.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal([
        accounts[151],
        accounts[152],
        accounts[153]
      ]);

      const currentBlock = stakingEpochStartBlock.add(new BN(10));
      await setCurrentBlockNumber(currentBlock);

      await callFinalizeChange();
      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(currentBlock);
      validators = await validatorSetHbbft.getValidators.call();
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
      const stakingEpoch = await stakingHbbft.stakingEpoch.call();
      stakingEpoch.should.be.bignumber.equal(new BN(12));

      const stakingEpochStartBlock = await stakingHbbft.stakingEpochStartBlock.call();
      const stakingEpochEndBlock = stakingEpochStartBlock.add(new BN(STAKING_EPOCH_DURATION)).sub(new BN(1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      let validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[151],
        accounts[152],
        accounts[153]
      ]);
      const blocksCreated = stakingEpochEndBlock.sub(await validatorSetHbbft.validatorSetApplyBlock.call()).div(new BN(validators.length));
      blocksCreated.should.be.bignumber.above(new BN(0));
      for (let i = 0; i < validators.length; i++) {
        await blockRewardHbbft.setBlocksCreated(stakingEpoch, validators[i], blocksCreated).should.be.fulfilled;
      }

      const blockRewardBalanceBeforeReward = await erc677Token.balanceOf.call(blockRewardHbbft.address);

      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(false);
      await callReward();
      const nextStakingEpoch = stakingEpoch.add(new BN(1)); // 13
      (await stakingHbbft.stakingEpoch.call()).should.be.bignumber.equal(nextStakingEpoch);
      (await validatorSetHbbft.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      (await validatorSetHbbft.emitInitiateChangeCallable.call()).should.be.equal(true);

      let rewardDistributed = new BN(0);
      for (let i = 0; i < validators.length; i++) {
        const epochPoolTokenReward = await blockRewardHbbft.epochPoolTokenReward.call(stakingEpoch, validators[i]);
        epochPoolTokenReward.should.be.bignumber.above(new BN(0));
        rewardDistributed = rewardDistributed.add(epochPoolTokenReward);
      }
      tokenRewardUndistributed = tokenRewardUndistributed.sub(rewardDistributed);
      tokenRewardUndistributed.should.be.bignumber.equal(await blockRewardHbbft.tokenRewardUndistributed.call());

      const blockRewardBalanceAfterReward = await erc677Token.balanceOf.call(blockRewardHbbft.address);

      blockRewardBalanceAfterReward.should.be.bignumber.equal(blockRewardBalanceBeforeReward.add(rewardDistributed));
      (await blockRewardHbbft.bridgeTokenFee.call()).should.be.bignumber.equal(new BN(0));
      (await blockRewardHbbft.bridgeNativeFee.call()).should.be.bignumber.equal(new BN(0));

      const pendingValidators = await validatorSetHbbft.getPendingValidators.call();
      pendingValidators.sortedEqual([
        accounts[151],
        accounts[152],
        accounts[153],
      ]);
      for (let i = 0; i < pendingValidators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, pendingValidators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      validators = await validatorSetHbbft.getValidators.call();
      validators.sortedEqual([
        accounts[151],
        accounts[152],
        accounts[153],
      ]);
      for (let i = 0; i < validators.length; i++) {
        (await blockRewardHbbft.snapshotPoolValidatorStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
        (await blockRewardHbbft.snapshotPoolTotalStakeAmount.call(nextStakingEpoch, validators[i])).should.be.bignumber.equal(
          candidateMinStake
        );
      }

      const validatorsToBeFinalized = (await validatorSetHbbft.validatorsToBeFinalized.call()).miningAddresses;
      validatorsToBeFinalized.length.should.be.equal(0);
    });
  });

  Array.prototype.sortedEqual = function(arr) {
    [...this].sort().should.be.deep.equal([...arr].sort());
  }

  async function accrueBridgeFees() {
    const fee = web3.utils.toWei('1');
    await blockRewardHbbft.setNativeToErcBridgesAllowed([owner], {from: owner}).should.be.fulfilled;
    await blockRewardHbbft.setErcToNativeBridgesAllowed([owner], {from: owner}).should.be.fulfilled;
    await blockRewardHbbft.addBridgeTokenFeeReceivers(fee, {from: owner}).should.be.fulfilled;
    await blockRewardHbbft.addBridgeNativeFeeReceivers(fee, {from: owner}).should.be.fulfilled;
    (await blockRewardHbbft.bridgeTokenFee.call()).should.be.bignumber.equal(fee);
    (await blockRewardHbbft.bridgeNativeFee.call()).should.be.bignumber.equal(fee);
    return new BN(fee);
  }

  async function callFinalizeChange() {
    await validatorSetHbbft.setSystemAddress(owner).should.be.fulfilled;
    await validatorSetHbbft.finalizeChange({from: owner}).should.be.fulfilled;
    await validatorSetHbbft.setSystemAddress('0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE').should.be.fulfilled;
  }

  async function callReward() {
    const validators = await validatorSetHbbft.getValidators.call();
    await blockRewardHbbft.setSystemAddress(owner).should.be.fulfilled;
    await blockRewardHbbft.reward([validators[0]], [0], {from: owner}).should.be.fulfilled;
    await blockRewardHbbft.setSystemAddress('0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE').should.be.fulfilled;
  }

  async function setCurrentBlockNumber(blockNumber) {
    await blockRewardHbbft.setCurrentBlockNumber(blockNumber).should.be.fulfilled;
    await randomHbbft.setCurrentBlockNumber(blockNumber).should.be.fulfilled;
    await stakingHbbft.setCurrentBlockNumber(blockNumber).should.be.fulfilled;
    await validatorSetHbbft.setCurrentBlockNumber(blockNumber).should.be.fulfilled;
  }

  // TODO: ...add other tests...
});
