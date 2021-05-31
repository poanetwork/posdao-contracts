const AdminUpgradeabilityProxy = artifacts.require('AdminUpgradeabilityProxy');
const BlockRewardAuRa = artifacts.require('BlockRewardAuRaTokensMock');
const Governance = artifacts.require('GovernanceMock');
const RandomAuRa = artifacts.require('RandomAuRaMock');
const StakingAuRa = artifacts.require('StakingAuRaTokensMock');
const ValidatorSetAuRa = artifacts.require('ValidatorSetAuRaMock');

const ERROR_MSG = 'VM Exception while processing transaction: revert';
const BN = web3.utils.BN;

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bn')(BN))
  .should();

contract('Governance', async accounts => {
  let owner;
  let initialValidators;
  let initialStakingAddresses;
  let initialPoolIds;
  let blockRewardAuRa;
  let governance;
  let randomAuRa;
  let stakingAuRa;
  let validatorSetAuRa;

  beforeEach(async () => {
    owner = accounts[0];
    initialValidators = accounts.slice(1, 10 + 1); // accounts[1...10]
    initialStakingAddresses = accounts.slice(11, 20 + 1); // accounts[11...20]
    initialStakingAddresses.length.should.be.equal(10);
    for (let i = 0; i < initialStakingAddresses.length; i++) {
      initialStakingAddresses[i].should.not.be.equal('0x0000000000000000000000000000000000000000');
    }
    // Deploy BlockReward contract
    blockRewardAuRa = await BlockRewardAuRa.new();
    blockRewardAuRa = await AdminUpgradeabilityProxy.new(blockRewardAuRa.address, owner);
    blockRewardAuRa = await BlockRewardAuRa.at(blockRewardAuRa.address);
    // Deploy Governance contract
    governance = await Governance.new();
    governance = await AdminUpgradeabilityProxy.new(governance.address, owner);
    governance = await Governance.at(governance.address);
    // Deploy Random contract
    randomAuRa = await RandomAuRa.new();
    randomAuRa = await AdminUpgradeabilityProxy.new(randomAuRa.address, owner);
    randomAuRa = await RandomAuRa.at(randomAuRa.address);
    // Deploy Staking contract
    stakingAuRa = await StakingAuRa.new();
    stakingAuRa = await AdminUpgradeabilityProxy.new(stakingAuRa.address, owner);
    stakingAuRa = await StakingAuRa.at(stakingAuRa.address);
    // Deploy ValidatorSet contract
    validatorSetAuRa = await ValidatorSetAuRa.new();
    validatorSetAuRa = await AdminUpgradeabilityProxy.new(validatorSetAuRa.address, owner);
    validatorSetAuRa = await ValidatorSetAuRa.at(validatorSetAuRa.address);
    const currentBlockNumber = 9307427;
    // Initialize ValidatorSet
    await validatorSetAuRa.initialize(
      blockRewardAuRa.address, // _blockRewardContract
      governance.address, // _governanceContract
      randomAuRa.address, // _randomContract
      stakingAuRa.address, // _stakingContract
      initialValidators, // _initialMiningAddresses
      initialStakingAddresses, // _initialStakingAddresses
      false // _firstValidatorIsUnremovable
    ).should.be.fulfilled;
    initialPoolIds = [];
    for (let i = 0; i < initialValidators.length; i++) {
      initialPoolIds.push(await validatorSetAuRa.idByMiningAddress.call(initialValidators[i]));
    }
    await validatorSetAuRa.setCurrentBlockNumber(currentBlockNumber).should.be.fulfilled;
    // Initialize StakingAuRa
    await stakingAuRa.initialize(
      validatorSetAuRa.address, // _validatorSetContract
      governance.address, // _governanceContract
      initialPoolIds, // _initialIds
      web3.utils.toWei('1', 'ether'), // _delegatorMinStake
      web3.utils.toWei('1', 'ether'), // _candidateMinStake
      120992, // _stakingEpochDuration
      9186425, // _stakingEpochStartBlock
      4332 // _stakeWithdrawDisallowPeriod
    ).should.be.fulfilled;
    await stakingAuRa.setCurrentBlockNumber(currentBlockNumber).should.be.fulfilled;
    await stakingAuRa.setStakingEpoch(1).should.be.fulfilled;
    await stakingAuRa.setValidatorSetAddress(owner).should.be.fulfilled;
    await stakingAuRa.setStakingEpochStartBlock(9186425+120992).should.be.fulfilled;
    await stakingAuRa.setValidatorSetAddress(validatorSetAuRa.address).should.be.fulfilled;
    // Initialize Governance
    await governance.initialize(validatorSetAuRa.address);
    await governance.setCurrentBlockNumber(currentBlockNumber).should.be.fulfilled;
  });

  describe('create()', async () => {
    const reason = web3.utils.toHex("unrevealed");

    it('should create a new ballot', async () => {
      const targetPoolId = initialPoolIds[initialValidators.length - 1];
      const {logs} = await governance.create(targetPoolId, 17280, reason, 0, { from: initialStakingAddresses[0] }).should.be.fulfilled;
      const ballot = await governance.getBallot.call(1);
      logs[0].event.should.be.equal('Created');
      logs[0].args.ballotId.should.be.bignumber.equal(new BN(1));
      ballot._poolId.should.be.bignumber.equal(targetPoolId);
      ballot._creatorPoolId.should.be.bignumber.equal(initialPoolIds[0]);
      ballot._reason.should.be.equal(web3.utils.padRight(reason, 64));
      ballot._status.should.be.bignumber.equal(new BN(1));
    });
    it('should not create a ballot for a non-validator pool', async () => {
      let targetPoolId = web3.utils.sha3(Math.random().toString());
      await governance.create(targetPoolId, 17280, reason, 0, { from: initialStakingAddresses[0] }).should.be.rejectedWith(ERROR_MSG);
      targetPoolId = initialPoolIds[initialValidators.length - 1];
      await governance.create(targetPoolId, 17280, reason, 0, { from: initialStakingAddresses[0] }).should.be.fulfilled;
    });
    it('cannot be called by a non-validator pool', async () => {
      const targetPoolId = initialPoolIds[initialValidators.length - 1];
      await governance.create(targetPoolId, 17280, reason, 0, { from: owner }).should.be.rejectedWith(ERROR_MSG);
      await governance.create(targetPoolId, 17280, reason, 0, { from: initialStakingAddresses[0] }).should.be.fulfilled;
    });
    it('should not create a ballot for the caller pool', async () => {
      const targetPoolId = initialPoolIds[initialValidators.length - 1];
      await governance.create(targetPoolId, 17280, reason, 0, { from: initialStakingAddresses[initialValidators.length - 1] }).should.be.rejectedWith(ERROR_MSG);
      await governance.create(targetPoolId, 17280, reason, 0, { from: initialStakingAddresses[initialValidators.length - 2] }).should.be.fulfilled;
    });
    it('should not create a ballot for the pool which is already under unfinalized ballot', async () => {
      const targetPoolId = initialPoolIds[initialValidators.length - 1];
      await governance.create(targetPoolId, 17280, reason, 0, { from: initialStakingAddresses[0] }).should.be.fulfilled;
      await governance.create(targetPoolId, 17280, reason, 0, { from: initialStakingAddresses[1] }).should.be.rejectedWith(ERROR_MSG);
      const ballotExpirationBlock = await governance.ballotExpirationBlock.call(1);
      await governance.setCurrentBlockNumber(ballotExpirationBlock);
      await governance.finalize(1).should.be.fulfilled;
      await governance.create(targetPoolId, 17280, reason, 0, { from: initialStakingAddresses[2] }).should.be.fulfilled;
    });
    it('cannot create too many parallel ballots by the same creator', async () => {
      const maxParallelBallotsAllowed = Math.floor(initialValidators.length / 3);
      for (let i = 1; i <= maxParallelBallotsAllowed; i++) {
        await governance.create(initialPoolIds[i], 17280, reason, 0, { from: initialStakingAddresses[0] }).should.be.fulfilled;
      }
      await governance.create(initialPoolIds[maxParallelBallotsAllowed + 1], 17280, reason, 0, { from: initialStakingAddresses[0] }).should.be.rejectedWith(ERROR_MSG);
      await governance.cancel(1, { from: initialStakingAddresses[0] }).should.be.fulfilled;
      await governance.create(initialPoolIds[maxParallelBallotsAllowed + 1], 17280, reason, 0, { from: initialStakingAddresses[0] }).should.be.fulfilled;
      await governance.create(initialPoolIds[maxParallelBallotsAllowed + 2], 17280, reason, 0, { from: initialStakingAddresses[0] }).should.be.rejectedWith(ERROR_MSG);
      const ballotExpirationBlock = await governance.ballotExpirationBlock.call(2);
      await governance.setCurrentBlockNumber(ballotExpirationBlock);
      await governance.finalize(2, { from: owner }).should.be.fulfilled;
      await governance.create(initialPoolIds[maxParallelBallotsAllowed + 2], 17280, reason, 0, { from: initialStakingAddresses[0] }).should.be.fulfilled;
      await governance.create(initialPoolIds[maxParallelBallotsAllowed + 3], 17280, reason, 0, { from: initialStakingAddresses[0] }).should.be.rejectedWith(ERROR_MSG);
    });
    it('should not create a ballot with an invalid duration', async () => {
      const minDuration = await governance.MIN_DURATION.call();
      const maxDuration = await governance.MAX_DURATION.call();
      minDuration.should.be.bignumber.lt(maxDuration);
      await governance.create(initialPoolIds[1], minDuration - 1, reason, 0, { from: initialStakingAddresses[0] }).should.be.rejectedWith(ERROR_MSG);
      await governance.create(initialPoolIds[1], minDuration, reason, 0, { from: initialStakingAddresses[0] }).should.be.fulfilled;
      await governance.create(initialPoolIds[3], maxDuration - 0 + 1, reason, 0, { from: initialStakingAddresses[2] }).should.be.rejectedWith(ERROR_MSG);
      await governance.create(initialPoolIds[3], maxDuration, reason, 0, { from: initialStakingAddresses[2] }).should.be.fulfilled;
      await governance.create(initialPoolIds[5], minDuration.add(maxDuration).div(new BN(2)), reason, 0, { from: initialStakingAddresses[4] }).should.be.fulfilled;
    });
    it('should not create a ballot with an invalid reason', async () => {
      await governance.create(initialPoolIds[9], 17280, web3.utils.toHex("other reason"), 0, { from: initialStakingAddresses[8] }).should.be.rejectedWith(ERROR_MSG);
      await governance.create(initialPoolIds[7], 17280, web3.utils.toHex("unrevealed"), 0, { from: initialStakingAddresses[6] }).should.be.fulfilled;
      await governance.create(initialPoolIds[5], 17280, web3.utils.toHex("often reveal skips"), 0, { from: initialStakingAddresses[4] }).should.be.fulfilled;
      await governance.create(initialPoolIds[3], 17280, web3.utils.toHex("often block skips"), 0, { from: initialStakingAddresses[2] }).should.be.fulfilled;
      await governance.create(initialPoolIds[1], 17280, web3.utils.toHex("often block delays"), 0, { from: initialStakingAddresses[0] }).should.be.fulfilled;
    });
    it('should increase openCountPerPoolId getter value for the sender pool', async () => {
      const sender = initialStakingAddresses[0];
      const senderPoolId = await validatorSetAuRa.idByStakingAddress.call(sender);
      const openCountPerPoolId = await governance.openCountPerPoolId.call(senderPoolId);
      await governance.create(initialPoolIds[1], 17280, reason, 0, { from: sender }).should.be.fulfilled;
      openCountPerPoolId.add(new BN(1)).should.be.bignumber.equal(await governance.openCountPerPoolId.call(senderPoolId));
    });
    it('should increase latestBallotId getter value', async () => {
      const latestBallotId = await governance.latestBallotId.call();
      await governance.create(initialPoolIds[1], 17280, reason, 0, { from: initialStakingAddresses[0] }).should.be.fulfilled;
      latestBallotId.add(new BN(1)).should.be.bignumber.equal(await governance.latestBallotId.call());
    });
    it('should set correct data for getters', async () => {
      const targetPoolId = initialPoolIds[initialValidators.length - 1];
      const ballotId = (new BN(await governance.latestBallotId.call())).add(new BN(1));
      const currentBlockNumber = await governance.getCurrentBlockNumber.call();

      (await governance.ballotPoolId.call(ballotId)).should.be.bignumber.equal(new BN(0));
      (await governance.ballotCreator.call(ballotId)).should.be.bignumber.equal(new BN(0));
      (await governance.ballotExpirationBlock.call(ballotId)).should.be.bignumber.equal(new BN(0));
      (await governance.ballotLongBanUntilBlock.call(ballotId)).should.be.bignumber.equal(new BN(0));
      (await governance.ballotShortBanUntilBlock.call(ballotId)).should.be.bignumber.equal(new BN(0));
      (await governance.ballotStakingEpoch.call(ballotId)).should.be.bignumber.equal(new BN(0));
      (await governance.ballotReason.call(ballotId)).should.be.equal('0x0000000000000000000000000000000000000000000000000000000000000000');
      (await governance.ballotStatus.call(ballotId)).should.be.bignumber.equal(new BN(0));
      (await governance.ballotThreshold.call(ballotId)).should.be.bignumber.equal(new BN(0));
      (await governance.ballotIdByPoolId.call(targetPoolId)).should.be.bignumber.equal(new BN(0));

      const {logs} = await governance.create(targetPoolId, 17280, reason, 0, { from: initialStakingAddresses[0] }).should.be.fulfilled;
      logs[0].event.should.be.equal('Created');
      logs[0].args.ballotId.should.be.bignumber.equal(ballotId);

      const expirationBlock = currentBlockNumber.add(new BN(17280));
      const stakingEpochDuration = await stakingAuRa.stakingEpochDuration.call();
      const stakingEpochEndBlock = await stakingAuRa.stakingEpochEndBlock.call();

      (await governance.ballotPoolId.call(ballotId)).should.be.bignumber.equal(targetPoolId);
      (await governance.ballotCreator.call(ballotId)).should.be.bignumber.equal(initialPoolIds[0]);
      (await governance.ballotExpirationBlock.call(ballotId)).should.be.bignumber.equal(expirationBlock);

      let fullStakingEpochs = new BN(12);
      if (expirationBlock.gt(stakingEpochEndBlock)) {
        fullStakingEpochs = expirationBlock.sub(stakingEpochEndBlock).div(stakingEpochDuration).add(fullStakingEpochs).add(new BN(1));
      }
      const ballotLongBanUntilBlockExpected = fullStakingEpochs.mul(stakingEpochDuration).add(stakingEpochEndBlock);
      const ballotShortBanUntilBlockExpected = fullStakingEpochs.sub(new BN(12)).mul(stakingEpochDuration).add(stakingEpochEndBlock);
      (await governance.ballotLongBanUntilBlock.call(ballotId)).should.be.bignumber.equal(ballotLongBanUntilBlockExpected);
      (await governance.ballotShortBanUntilBlock.call(ballotId)).should.be.bignumber.equal(ballotShortBanUntilBlockExpected);
      (await governance.ballotStakingEpoch.call(ballotId)).should.be.bignumber.equal(new BN(1));
      (await governance.ballotReason.call(ballotId)).should.be.equal(web3.utils.padRight(reason, 64));
      (await governance.ballotStatus.call(ballotId)).should.be.bignumber.equal(new BN(1));
      (await governance.ballotThreshold.call(ballotId)).should.be.bignumber.equal((new BN(initialValidators.length)).div(new BN(2)).add(new BN(1)));
      (await governance.ballotIdByPoolId.call(targetPoolId)).should.be.bignumber.equal(ballotId);
    });
  });
});
