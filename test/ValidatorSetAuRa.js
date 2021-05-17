const BlockRewardAuRa = artifacts.require('BlockRewardAuRaTokensMock');
const ERC677BridgeTokenRewardable = artifacts.require('ERC677BridgeTokenRewardable');
const AdminUpgradeabilityProxy = artifacts.require('AdminUpgradeabilityProxy');
const RandomAuRa = artifacts.require('RandomAuRaMock');
const StakingAuRa = artifacts.require('StakingAuRaTokensMock');
const ValidatorSetAuRa = artifacts.require('ValidatorSetAuRaMock');

const ERROR_MSG = 'VM Exception while processing transaction: revert';
const BN = web3.utils.BN;

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bn')(BN))
  .should();

/*
contract('ValidatorSetAuRa', async accounts => {
  let owner;
  let blockRewardAuRa;
  let stakingAuRa;
  let validatorSetAuRa;

  beforeEach(async () => {
    owner = accounts[0];
    // Deploy BlockReward contract
    blockRewardAuRa = await BlockRewardAuRa.new();
    blockRewardAuRa = await AdminUpgradeabilityProxy.new(blockRewardAuRa.address, owner);
    blockRewardAuRa = await BlockRewardAuRa.at(blockRewardAuRa.address);
    // Deploy Staking contract
    stakingAuRa = await StakingAuRa.new();
    stakingAuRa = await AdminUpgradeabilityProxy.new(stakingAuRa.address, owner);
    stakingAuRa = await StakingAuRa.at(stakingAuRa.address);
    // Deploy ValidatorSet contract
    validatorSetAuRa = await ValidatorSetAuRa.new();
    validatorSetAuRa = await AdminUpgradeabilityProxy.new(validatorSetAuRa.address, owner);
    validatorSetAuRa = await ValidatorSetAuRa.at(validatorSetAuRa.address);
  });

  describe('changeMetadata()', async () => {
    let initialValidators;
    let initialStakingAddresses;
    let initialPoolIds;

    beforeEach(async () => {
      initialValidators = accounts.slice(1, 3 + 1); // accounts[1...3]
      initialStakingAddresses = accounts.slice(4, 6 + 1); // accounts[4...6]
      await validatorSetAuRa.setCurrentBlockNumber(0);
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        true // _firstValidatorIsUnremovable
      ).should.be.fulfilled;
      initialPoolIds = [];
      for (let i = 0; i < initialValidators.length; i++) {
        initialPoolIds.push(await validatorSetAuRa.idByMiningAddress.call(initialValidators[i]));
      }
      await stakingAuRa.setValidatorSetAddress(validatorSetAuRa.address).should.be.fulfilled;
      (await validatorSetAuRa.unremovableValidator.call()).should.be.bignumber.equal(initialPoolIds[0]);
      initialStakingAddresses[0].should.not.be.equal('0x0000000000000000000000000000000000000000');
      await validatorSetAuRa.setCurrentBlockNumber(100);
    });
    it('should set a new metadata for an existing pool', async () => {
      const poolId = initialPoolIds[0];
      const name = 'Grüße';
      const description = 'Grüße Grüße Grüße Grüße Grüße';
      (await validatorSetAuRa.poolName.call(poolId)).should.not.be.equal(name);
      (await validatorSetAuRa.poolDescription.call(poolId)).should.not.be.equal(description);
      (await validatorSetAuRa.lastChangeBlock.call()).should.not.be.bignumber.equal(new BN(120));
      await validatorSetAuRa.setCurrentBlockNumber(120);
      const {logs} = await validatorSetAuRa.changeMetadata(name, description, {from: initialStakingAddresses[0]}).should.be.fulfilled;
      logs[0].event.should.be.equal('SetPoolMetadata');
      logs[0].args.poolId.should.be.bignumber.equal(poolId);
      logs[0].args.name.should.be.equal(name);
      logs[0].args.description.should.be.equal(description);
      (await validatorSetAuRa.poolName.call(poolId)).should.be.equal(name);
      (await validatorSetAuRa.poolDescription.call(poolId)).should.be.equal(description);
      (await validatorSetAuRa.lastChangeBlock.call()).should.be.bignumber.equal(new BN(120));
    });
    it('should only allow setting a metadata for an existing pool by its staking address', async () => {
      const name = 'Grüße';
      const description = 'Grüße Grüße Grüße Grüße Grüße';
      await validatorSetAuRa.changeMetadata(name, description, {from: initialValidators[0]}).should.be.rejectedWith(ERROR_MSG);
      await validatorSetAuRa.changeMetadata(name, description, {from: accounts[10]}).should.be.rejectedWith(ERROR_MSG);
    });
    it('should not set too long metadata', async () => {
      const name = 'Grüße';
      const longDescription = 'd'.repeat(1025);
      await validatorSetAuRa.changeMetadata(name, longDescription, {from: initialStakingAddresses[0]}).should.be.rejectedWith(ERROR_MSG);
      const normalDescription = 'd'.repeat(1024);
      await validatorSetAuRa.changeMetadata(name, normalDescription, {from: initialStakingAddresses[0]}).should.be.fulfilled;
    });
  });

  describe('clearUnremovableValidator()', async () => {
    let initialStakingAddresses;
    let initialPoolIds;

    beforeEach(async () => {
      const initialValidators = accounts.slice(1, 3 + 1); // accounts[1...3]
      initialStakingAddresses = accounts.slice(4, 6 + 1); // accounts[4...6]
      await validatorSetAuRa.setCurrentBlockNumber(0);
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        true // _firstValidatorIsUnremovable
      ).should.be.fulfilled;
      initialPoolIds = [];
      for (let i = 0; i < initialValidators.length; i++) {
        initialPoolIds.push(await validatorSetAuRa.idByMiningAddress.call(initialValidators[i]));
      }
      await stakingAuRa.setValidatorSetAddress(validatorSetAuRa.address).should.be.fulfilled;
      (await validatorSetAuRa.unremovableValidator.call()).should.be.bignumber.equal(initialPoolIds[0]);
      initialStakingAddresses[0].should.not.be.equal('0x0000000000000000000000000000000000000000');
      await validatorSetAuRa.setCurrentBlockNumber(100);
    });
    it('should make a non-removable validator removable', async () => {
      await validatorSetAuRa.clearUnremovableValidator({from: initialStakingAddresses[0]}).should.be.fulfilled;
      (await validatorSetAuRa.unremovableValidator.call()).should.be.bignumber.equal('0');
    });
    it('cannot be called more than once', async () => {
      await validatorSetAuRa.clearUnremovableValidator({from: initialStakingAddresses[0]}).should.be.fulfilled;
      (await validatorSetAuRa.unremovableValidator.call()).should.be.bignumber.equal('0');
      await validatorSetAuRa.clearUnremovableValidator({from: initialStakingAddresses[0]}).should.be.rejectedWith(ERROR_MSG);
    });
    it('can be called by an owner', async () => {
      await validatorSetAuRa.clearUnremovableValidator({from: owner}).should.be.fulfilled;
    });
    it('can only be called by an owner or non-removable validator', async () => {
      await validatorSetAuRa.clearUnremovableValidator({from: accounts[7]}).should.be.rejectedWith(ERROR_MSG);
    });
    it('should add validator pool to the poolsToBeElected list', async () => {
      await stakingAuRa.setValidatorSetAddress('0x0000000000000000000000000000000000000000').should.be.fulfilled;
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        initialPoolIds, // _initialIds
        web3.utils.toWei('1', 'ether'), // _delegatorMinStake
        web3.utils.toWei('1', 'ether'), // _candidateMinStake
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.fulfilled;

      // Deploy ERC677 contract
      const erc677Token = await ERC677BridgeTokenRewardable.new("STAKE", "STAKE", 18, 100, {from: owner});

      // Mint some balance for the non-removable validator (imagine that the validator got 2 STAKE_UNITs from a bridge)
      const stakeUnit = new BN(web3.utils.toWei('1', 'ether'));
      const mintAmount = stakeUnit.mul(new BN(2));
      await erc677Token.mint(initialStakingAddresses[0], mintAmount, {from: owner}).should.be.fulfilled;
      mintAmount.should.be.bignumber.equal(await erc677Token.balanceOf.call(initialStakingAddresses[0]));

      // Pass Staking contract address to ERC677 contract
      await erc677Token.setStakingContract(stakingAuRa.address, {from: owner}).should.be.fulfilled;
      stakingAuRa.address.should.be.equal(await erc677Token.stakingContract.call());

      // Pass ERC677 contract address to Staking contract
      await stakingAuRa.setErc677TokenContract(erc677Token.address, {from: owner}).should.be.fulfilled;
      erc677Token.address.should.be.equal(await stakingAuRa.erc677TokenContract.call());

      // Emulate block number
      await stakingAuRa.setCurrentBlockNumber(100).should.be.fulfilled;

      // Place a stake for itself
      await stakingAuRa.stake(initialStakingAddresses[0], stakeUnit.mul(new BN(1)), {from: initialStakingAddresses[0]}).should.be.fulfilled;

      (await stakingAuRa.getPoolsToBeElected.call()).length.should.be.equal(0);

      await validatorSetAuRa.clearUnremovableValidator({from: initialStakingAddresses[0]}).should.be.fulfilled;

      (await stakingAuRa.getPoolsToBeElected.call()).should.be.deep.equal([
        initialPoolIds[0]
      ]);
    });
    it('should add validator pool to the poolsToBeRemoved list', async () => {
      await stakingAuRa.setValidatorSetAddress('0x0000000000000000000000000000000000000000').should.be.fulfilled;
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        initialPoolIds, // _initialIds
        web3.utils.toWei('1', 'ether'), // _delegatorMinStake
        web3.utils.toWei('1', 'ether'), // _candidateMinStake
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.fulfilled;
      (await stakingAuRa.getPoolsToBeRemoved.call()).should.be.deep.equal([
        initialPoolIds[1],
        initialPoolIds[2]
      ]);
      await validatorSetAuRa.clearUnremovableValidator({from: initialStakingAddresses[0]}).should.be.fulfilled;
      (await stakingAuRa.getPoolsToBeRemoved.call()).should.be.deep.equal([
        initialPoolIds[1],
        initialPoolIds[2],
        initialPoolIds[0]
      ]);
    });
  });

  describe('emitInitiateChange()', async () => {
    let initialValidators;
    let initialStakingAddresses;
    let initialPoolIds;
    let randomAuRa;

    beforeEach(async () => {
      initialValidators = accounts.slice(1, 3 + 1); // accounts[1...3]
      initialStakingAddresses = accounts.slice(4, 6 + 1); // accounts[4...6]

      randomAuRa = await RandomAuRa.new();
      randomAuRa = await AdminUpgradeabilityProxy.new(randomAuRa.address, owner);
      randomAuRa = await RandomAuRa.at(randomAuRa.address);

      await validatorSetAuRa.setCurrentBlockNumber(0).should.be.fulfilled;
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
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
      await stakingAuRa.setCurrentBlockNumber(0).should.be.fulfilled;
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        initialPoolIds, // _initialIds
        web3.utils.toWei('1', 'ether'), // _delegatorMinStake
        web3.utils.toWei('1', 'ether'), // _candidateMinStake
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.fulfilled;

      // Set `initiateChangeAllowed` boolean flag to `true`
      await validatorSetAuRa.setCurrentBlockNumber(1).should.be.fulfilled;
      await validatorSetAuRa.setSystemAddress(owner).should.be.fulfilled;
      await validatorSetAuRa.finalizeChange({from: owner}).should.be.fulfilled;

      // Enqueue pending validators
      await stakingAuRa.setCurrentBlockNumber(120954).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120954).should.be.fulfilled;
      await validatorSetAuRa.setBlockRewardContract(accounts[4]).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: accounts[4]}).should.be.fulfilled;
      await validatorSetAuRa.setBlockRewardContract(blockRewardAuRa.address).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120970).should.be.fulfilled;
    });

    it('should emit InitiateChange event successfully', async () => {
      let queueValidators = await validatorSetAuRa.validatorsToBeFinalized.call();
      queueValidators.miningAddresses.length.should.be.equal(0);
      queueValidators.forNewEpoch.should.be.equal(false);

      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(true);
      (await validatorSetAuRa.initiateChangeAllowed.call()).should.be.equal(true);

      await validatorSetAuRa.setCurrentBlockNumber(2).should.be.fulfilled;
      const result = await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120970).should.be.fulfilled;

      result.logs[0].event.should.be.equal("InitiateChange");
      result.logs[0].args.parentHash.should.be.equal((await web3.eth.getBlock(1)).hash);
      result.logs[0].args.newSet.should.be.deep.equal(initialValidators);
      (await validatorSetAuRa.initiateChangeAllowed.call()).should.be.equal(false);

      queueValidators = await validatorSetAuRa.validatorsToBeFinalized.call();
      queueValidators.miningAddresses.should.be.deep.equal(initialValidators);
      queueValidators.forNewEpoch.should.be.equal(true);
    });
    it('should fail if the `emitInitiateChangeCallable` returns `false`', async () => {
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(true);
      const result = await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
      result.logs[0].event.should.be.equal("InitiateChange");
      result.logs[0].args.newSet.should.be.deep.equal(initialValidators);
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      await validatorSetAuRa.emitInitiateChange().should.be.rejectedWith(ERROR_MSG);
    });
    it('shouldn\'t emit InitiateChange event if an empty pending validators array was queued', async () => {
      await blockRewardAuRa.initialize(validatorSetAuRa.address, '0x0000000000000000000000000000000000000000').should.be.fulfilled;
      await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120980).should.be.fulfilled;
      await validatorSetAuRa.finalizeChange({from: owner}).should.be.fulfilled;

      await validatorSetAuRa.setCurrentBlockNumber(121000).should.be.fulfilled;
      await validatorSetAuRa.clearPendingValidators().should.be.fulfilled;
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(true);

      const {logs} = await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
      logs.length.should.be.equal(0);
      (await validatorSetAuRa.initiateChangeAllowed.call()).should.be.equal(true);
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
    });
  });

  describe('initialize()', async () => {
    let initialValidators;
    let initialStakingAddresses;

    beforeEach(async () => {
      initialValidators = accounts.slice(1, 3 + 1); // accounts[1...3]
      initialStakingAddresses = accounts.slice(4, 6 + 1); // accounts[4...6]
      initialValidators.length.should.be.equal(3);
      initialValidators[0].should.not.be.equal('0x0000000000000000000000000000000000000000');
      initialValidators[1].should.not.be.equal('0x0000000000000000000000000000000000000000');
      initialValidators[2].should.not.be.equal('0x0000000000000000000000000000000000000000');
      await validatorSetAuRa.setCurrentBlockNumber(0);
    });
    it('should initialize successfully', async () => {
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false // _firstValidatorIsUnremovable
      ).should.be.fulfilled;
      blockRewardAuRa.address.should.be.equal(
        await validatorSetAuRa.blockRewardContract.call()
      );
      '0x3000000000000000000000000000000000000001'.should.be.equal(
        await validatorSetAuRa.randomContract.call()
      );
      stakingAuRa.address.should.be.equal(
        await validatorSetAuRa.stakingContract.call()
      );
      (await validatorSetAuRa.getValidators.call()).should.be.deep.equal(initialValidators);
      (await validatorSetAuRa.getPendingValidators.call()).should.be.deep.equal(initialValidators);
      for (let i = 0; i < initialValidators.length; i++) {
        true.should.be.equal(
          await validatorSetAuRa.isValidator.call(initialValidators[i])
        );
        (await validatorSetAuRa.miningByStakingAddress.call(initialStakingAddresses[i])).should.be.equal(initialValidators[i]);
        (await validatorSetAuRa.stakingByMiningAddress.call(initialValidators[i])).should.be.equal(initialStakingAddresses[i]);
      }
      false.should.be.equal(
        await validatorSetAuRa.isValidator.call('0x0000000000000000000000000000000000000000')
      );
      (await validatorSetAuRa.unremovableValidator.call()).should.be.bignumber.equal('0');
      new BN(0).should.be.bignumber.equal(
        await validatorSetAuRa.validatorSetApplyBlock.call()
      );
    });
    it('should set unremovable validator to the first staking address', async () => {
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        true // _firstValidatorIsUnremovable
      ).should.be.fulfilled;
      const poolId = await validatorSetAuRa.idByStakingAddress.call(initialStakingAddresses[0]);
      poolId.should.be.bignumber.equal(
        await validatorSetAuRa.unremovableValidator.call()
      );
    });
    it('should fail if BlockRewardAuRa contract address is zero', async () => {
      await validatorSetAuRa.initialize(
        '0x0000000000000000000000000000000000000000', // _blockRewardContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false // _firstValidatorIsUnremovable
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if RandomAuRa contract address is zero', async () => {
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        '0x0000000000000000000000000000000000000000', // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false // _firstValidatorIsUnremovable
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if StakingAuRa contract address is zero', async () => {
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false // _firstValidatorIsUnremovable
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if initial mining addresses are empty', async () => {
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        stakingAuRa.address, // _stakingContract
        [], // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false // _firstValidatorIsUnremovable
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if already initialized', async () => {
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false // _firstValidatorIsUnremovable
      ).should.be.fulfilled;
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false // _firstValidatorIsUnremovable
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if the number of mining addresses is not the same as the number of staking ones', async () => {
      const initialStakingAddressesShort = accounts.slice(4, 5 + 1); // accounts[4...5]
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddressesShort, // _initialStakingAddresses
        false // _firstValidatorIsUnremovable
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if the mining addresses are the same as the staking ones', async () => {
      const initialStakingAddressesShort = accounts.slice(4, 5 + 1); // accounts[4...5]
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialValidators, // _initialStakingAddresses
        false // _firstValidatorIsUnremovable
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if some mining address is 0', async () => {
      initialValidators[0] = '0x0000000000000000000000000000000000000000';
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false // _firstValidatorIsUnremovable
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if some staking address is 0', async () => {
      initialStakingAddresses[0] = '0x0000000000000000000000000000000000000000';
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false // _firstValidatorIsUnremovable
      ).should.be.rejectedWith(ERROR_MSG);
    });
  });

  describe('newValidatorSet()', async () => {
    let initialValidators;
    let initialStakingAddresses;
    let initialPoolIds;
    let randomAuRa;

    beforeEach(async () => {
      initialValidators = accounts.slice(1, 3 + 1); // accounts[1...3]
      initialStakingAddresses = accounts.slice(4, 6 + 1); // accounts[4...6]

      randomAuRa = await RandomAuRa.new();
      randomAuRa = await AdminUpgradeabilityProxy.new(randomAuRa.address, owner);
      randomAuRa = await RandomAuRa.at(randomAuRa.address);

      await validatorSetAuRa.setCurrentBlockNumber(0).should.be.fulfilled;
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
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
      await stakingAuRa.setCurrentBlockNumber(0).should.be.fulfilled;
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        initialPoolIds, // _initialIds
        web3.utils.toWei('1', 'ether'), // _delegatorMinStake
        web3.utils.toWei('1', 'ether'), // _candidateMinStake
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.fulfilled;
      await stakingAuRa.setCurrentBlockNumber(120954).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120954).should.be.fulfilled;
    });
    it('can only be called by BlockReward contract', async () => {
      await validatorSetAuRa.newValidatorSet({from: owner}).should.be.rejectedWith(ERROR_MSG);
      await validatorSetAuRa.setBlockRewardContract(accounts[4]).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: accounts[4]}).should.be.fulfilled;
    });
    it('should increment the number of staking epoch', async () => {
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(new BN(0));
      await validatorSetAuRa.setBlockRewardContract(accounts[4]).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: accounts[4]}).should.be.fulfilled;
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(new BN(1));
    });
    it('should set staking epoch start block', async () => {
      (await stakingAuRa.stakingEpochStartBlock.call()).should.be.bignumber.equal(new BN(0));
      await validatorSetAuRa.setBlockRewardContract(accounts[4]).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: accounts[4]}).should.be.fulfilled;
      (await stakingAuRa.stakingEpochStartBlock.call()).should.be.bignumber.equal(new BN(120955));
    });
    it('should reset validatorSetApplyBlock', async () => {
      await validatorSetAuRa.setValidatorSetApplyBlock(new BN(1)).should.be.fulfilled;
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(1));
      await validatorSetAuRa.setBlockRewardContract(accounts[4]).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: accounts[4]}).should.be.fulfilled;
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
    });
    it('should enqueue initial validators', async () => {
      // Emulate calling `finalizeChange()` at network startup
      await validatorSetAuRa.setCurrentBlockNumber(1).should.be.fulfilled;
      (await validatorSetAuRa.initiateChangeAllowed.call()).should.be.equal(true);
      await validatorSetAuRa.setSystemAddress(owner).should.be.fulfilled;
      await validatorSetAuRa.finalizeChange({from: owner}).should.be.fulfilled;
      (await validatorSetAuRa.initiateChangeAllowed.call()).should.be.equal(true);

      // Emulate calling `newValidatorSet()` at the last block of staking epoch
      await stakingAuRa.setCurrentBlockNumber(120954).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120954).should.be.fulfilled;
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      await validatorSetAuRa.setBlockRewardContract(accounts[4]).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: accounts[4]}).should.be.fulfilled;
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(true);

      // Emulate calling `emitInitiateChange()` at the beginning of the next staking epoch
      await stakingAuRa.setCurrentBlockNumber(120955).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120955).should.be.fulfilled;
      const {logs} = await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal(initialValidators);
      (await validatorSetAuRa.initiateChangeAllowed.call()).should.be.equal(false);
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);

      // Check the returned value of `validatorsToBeFinalized()`
      const queueResult = await validatorSetAuRa.validatorsToBeFinalized.call();
      queueResult[0].should.be.deep.equal(initialValidators);
      queueResult[1].should.be.equal(true);
    });
    it('should enqueue only one validator which has non-empty pool', async () => {
      const stakeUnit = new BN(web3.utils.toWei('1', 'ether'));
      const mintAmount = stakeUnit.mul(new BN(2));

      await validatorSetAuRa.setValidatorSetApplyBlock(1).should.be.fulfilled;
      await stakingAuRa.setCurrentBlockNumber(10).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(10).should.be.fulfilled;

      // Deploy token contract and mint some tokens for the first initial validator
      const erc677Token = await ERC677BridgeTokenRewardable.new("STAKE", "STAKE", 18, 100, {from: owner});
      await erc677Token.mint(initialStakingAddresses[0], mintAmount, {from: owner}).should.be.fulfilled;
      mintAmount.should.be.bignumber.equal(await erc677Token.balanceOf.call(initialStakingAddresses[0]));

      // Pass Staking contract address to ERC677 contract
      await erc677Token.setStakingContract(stakingAuRa.address, {from: owner}).should.be.fulfilled;
      stakingAuRa.address.should.be.equal(await erc677Token.stakingContract.call());

      // Pass ERC677 contract address to Staking contract
      await stakingAuRa.setErc677TokenContract(erc677Token.address, {from: owner}).should.be.fulfilled;
      erc677Token.address.should.be.equal(await stakingAuRa.erc677TokenContract.call());

      // Emulate staking by the first validator into their own pool
      const stakeAmount = stakeUnit.mul(new BN(1));
      await stakingAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[0], stakeAmount, {from: initialStakingAddresses[0]}).should.be.fulfilled;
      stakeAmount.should.be.bignumber.equal(await stakingAuRa.stakeAmount.call(initialPoolIds[0], '0x0000000000000000000000000000000000000000'));

      // Emulate calling `newValidatorSet()` at the last block of staking epoch
      await stakingAuRa.setCurrentBlockNumber(120954).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120954).should.be.fulfilled;
      await validatorSetAuRa.setBlockRewardContract(accounts[4]).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: accounts[4]}).should.be.fulfilled;

      // Check the returned value of `getPendingValidators()`
      (await validatorSetAuRa.getPendingValidators.call()).should.be.deep.equal([initialValidators[0]]);
    });
    it('should enqueue unremovable validator anyway', async () => {
      validatorSetAuRa = await ValidatorSetAuRa.new();
      validatorSetAuRa = await AdminUpgradeabilityProxy.new(validatorSetAuRa.address, owner);
      validatorSetAuRa = await ValidatorSetAuRa.at(validatorSetAuRa.address);

      stakingAuRa = await StakingAuRa.new();
      stakingAuRa = await AdminUpgradeabilityProxy.new(stakingAuRa.address, owner);
      stakingAuRa = await StakingAuRa.at(stakingAuRa.address);

      await validatorSetAuRa.setCurrentBlockNumber(0).should.be.fulfilled;
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        randomAuRa.address, // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        true // _firstValidatorIsUnremovable
      ).should.be.fulfilled;
      initialPoolIds = [];
      for (let i = 0; i < initialValidators.length; i++) {
        initialPoolIds.push(await validatorSetAuRa.idByMiningAddress.call(initialValidators[i]));
      }
      await stakingAuRa.setCurrentBlockNumber(0).should.be.fulfilled;
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        initialPoolIds, // _initialIds
        web3.utils.toWei('1', 'ether'), // _delegatorMinStake
        web3.utils.toWei('1', 'ether'), // _candidateMinStake
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.fulfilled;
      await stakingAuRa.setValidatorSetAddress(validatorSetAuRa.address).should.be.fulfilled;

      const stakeUnit = new BN(web3.utils.toWei('1', 'ether'));
      const mintAmount = stakeUnit.mul(new BN(2));

      await validatorSetAuRa.setValidatorSetApplyBlock(1).should.be.fulfilled;
      await stakingAuRa.setCurrentBlockNumber(10).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(10).should.be.fulfilled;

      // Deploy token contract and mint some tokens for the second initial validator
      const erc677Token = await ERC677BridgeTokenRewardable.new("STAKE", "STAKE", 18, 100, {from: owner});
      await erc677Token.mint(initialStakingAddresses[1], mintAmount, {from: owner}).should.be.fulfilled;
      mintAmount.should.be.bignumber.equal(await erc677Token.balanceOf.call(initialStakingAddresses[1]));

      // Pass Staking contract address to ERC677 contract
      await erc677Token.setStakingContract(stakingAuRa.address, {from: owner}).should.be.fulfilled;
      stakingAuRa.address.should.be.equal(await erc677Token.stakingContract.call());

      // Pass ERC677 contract address to Staking contract
      await stakingAuRa.setErc677TokenContract(erc677Token.address, {from: owner}).should.be.fulfilled;
      erc677Token.address.should.be.equal(await stakingAuRa.erc677TokenContract.call());

      // Emulate staking by the second validator into their own pool
      const stakeAmount = stakeUnit.mul(new BN(1));
      await stakingAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[1], stakeAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      stakeAmount.should.be.bignumber.equal(await stakingAuRa.stakeAmount.call(initialPoolIds[1], '0x0000000000000000000000000000000000000000'));

      // Emulate calling `newValidatorSet()` at the last block of staking epoch
      await stakingAuRa.setCurrentBlockNumber(120954).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120954).should.be.fulfilled;
      await validatorSetAuRa.setBlockRewardContract(accounts[4]).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: accounts[4]}).should.be.fulfilled;

      // Check the returned value of `getPendingValidators()`
      const unremovablePoolId = await validatorSetAuRa.unremovableValidator.call();
      const unremovableMiningAddress = await validatorSetAuRa.miningAddressById.call(unremovablePoolId);
      (await validatorSetAuRa.getPendingValidators.call()).should.be.deep.equal([
        unremovableMiningAddress,
        initialValidators[1]
      ]);

      // Check the current active pools
      (await stakingAuRa.getPools.call()).should.be.deep.equal([
        unremovablePoolId,
        initialPoolIds[1]
      ]);
    });
    it('should choose validators randomly', async () => {
      const stakingAddresses = accounts.slice(7, 29 + 1); // accounts[7...29]
      let miningAddresses = [];

      for (let i = 0; i < stakingAddresses.length; i++) {
        // Generate new candidate mining address
        let candidateMiningAddress = '0x';
        for (let i = 0; i < 20; i++) {
          let randomByte = random(0, 255).toString(16);
          if (randomByte.length % 2) {
            randomByte = '0' + randomByte;
          }
          candidateMiningAddress += randomByte;
        }
        miningAddresses.push(candidateMiningAddress.toLowerCase());
      }

      const stakeUnit = new BN(web3.utils.toWei('1', 'ether'));
      const mintAmount = stakeUnit.mul(new BN(100));

      await validatorSetAuRa.setValidatorSetApplyBlock(1).should.be.fulfilled;
      await stakingAuRa.setCurrentBlockNumber(20).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(20).should.be.fulfilled;

      // Deploy token contract and mint tokens for the candidates
      const erc677Token = await ERC677BridgeTokenRewardable.new("STAKE", "STAKE", 18, 100, {from: owner});
      for (let i = 0; i < stakingAddresses.length; i++) {
        await erc677Token.mint(stakingAddresses[i], mintAmount, {from: owner}).should.be.fulfilled;
        mintAmount.should.be.bignumber.equal(await erc677Token.balanceOf.call(stakingAddresses[i]));
      }

      // Pass Staking contract address to ERC677 contract
      await erc677Token.setStakingContract(stakingAuRa.address, {from: owner}).should.be.fulfilled;
      stakingAuRa.address.should.be.equal(await erc677Token.stakingContract.call());

      // Pass ERC677 contract address to Staking contract
      await stakingAuRa.setErc677TokenContract(erc677Token.address, {from: owner}).should.be.fulfilled;
      erc677Token.address.should.be.equal(await stakingAuRa.erc677TokenContract.call());

      // Emulate staking by the candidates into their own pool
      await stakingAuRa.setCurrentBlockNumber(30).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(30).should.be.fulfilled;
      const poolIds = [];
      for (let i = 0; i < stakingAddresses.length; i++) {
        const stakeAmount = stakeUnit.mul(new BN(i + 1));
        const poolName = `Pool name for ${stakingAddresses[i]}`;
        const poolDescription = `Pool description for ${stakingAddresses[i]}`;
        await stakingAuRa.addPool(stakeAmount, miningAddresses[i], poolName, poolDescription, {from: stakingAddresses[i]}).should.be.fulfilled;
        const poolId = await validatorSetAuRa.idByStakingAddress.call(stakingAddresses[i]);
        stakeAmount.should.be.bignumber.equal(await stakingAuRa.stakeAmount.call(poolId, '0x0000000000000000000000000000000000000000'));
        poolIds.push(poolId);
      }

      // Check pools of the new candidates
      (await stakingAuRa.getPoolsToBeElected.call()).should.be.deep.equal(poolIds);
      const poolsLikelihood = await stakingAuRa.getPoolsLikelihood.call();
      let likelihoodSum = new BN(0);
      for (let i = 0; i < stakingAddresses.length; i++) {
        const poolLikelihood = stakeUnit.mul(new BN(i + 1));
        poolsLikelihood[0][i].should.be.bignumber.equal(new BN(poolLikelihood));
        likelihoodSum = likelihoodSum.add(poolLikelihood);
      }
      poolsLikelihood[1].should.be.bignumber.equal(new BN(likelihoodSum));

      // Generate a random seed
      (await randomAuRa.currentSeed.call()).should.be.bignumber.equal(new BN(0));
      await randomAuRa.setCurrentBlockNumber(0).should.be.fulfilled;
      await randomAuRa.initialize(114, validatorSetAuRa.address, true).should.be.fulfilled;
      let secretNumbers = [];
      let seed = 0;
      for (let i = 0; i < initialValidators.length; i++) {
        const secretNumber = random(1000000, 2000000);
        await randomAuRa.setCurrentBlockNumber(40 + i).should.be.fulfilled;
        await randomAuRa.setCoinbase(initialValidators[i]).should.be.fulfilled;
        const secretNumberHash = web3.utils.soliditySha3(new BN(secretNumber));
        await randomAuRa.commitHash(secretNumberHash, [1 + i, 2 + i, 3 + i], {from: initialValidators[i]}).should.be.fulfilled;
        secretNumbers.push(secretNumber);
        seed ^= secretNumber;
      }
      for (let i = 0; i < initialValidators.length; i++) {
        const secretNumber = secretNumbers[i];
        await randomAuRa.setCurrentBlockNumber(60 + i).should.be.fulfilled;
        await randomAuRa.setCoinbase(initialValidators[i]).should.be.fulfilled;
        await randomAuRa.revealNumber(new BN(secretNumber), {from: initialValidators[i]}).should.be.fulfilled;
      }
      (await randomAuRa.currentSeed.call()).should.be.bignumber.equal(new BN(seed));

      // Emulate calling `newValidatorSet()` at the last block of staking epoch
      await stakingAuRa.setCurrentBlockNumber(120954).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120954).should.be.fulfilled;
      await randomAuRa.setCurrentBlockNumber(120954).should.be.fulfilled;
      await validatorSetAuRa.setBlockRewardContract(accounts[4]).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: accounts[4]}).should.be.fulfilled;

      const newValidators = await validatorSetAuRa.getPendingValidators.call();

      newValidators.length.should.be.equal((await validatorSetAuRa.MAX_VALIDATORS.call()).toNumber());

      for (let i = 0; i < newValidators.length; i++) {
        miningAddresses.indexOf(newValidators[i].toLowerCase()).should.be.gte(0);
      }
    });
    it('should choose validators randomly but leave an unremovable validator', async () => {
      validatorSetAuRa = await ValidatorSetAuRa.new();
      validatorSetAuRa = await AdminUpgradeabilityProxy.new(validatorSetAuRa.address, owner);
      validatorSetAuRa = await ValidatorSetAuRa.at(validatorSetAuRa.address);

      stakingAuRa = await StakingAuRa.new();
      stakingAuRa = await AdminUpgradeabilityProxy.new(stakingAuRa.address, owner);
      stakingAuRa = await StakingAuRa.at(stakingAuRa.address);

      await validatorSetAuRa.setCurrentBlockNumber(0).should.be.fulfilled;
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        randomAuRa.address, // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        true // _firstValidatorIsUnremovable
      ).should.be.fulfilled;
      initialPoolIds = [];
      for (let i = 0; i < initialValidators.length; i++) {
        initialPoolIds.push(await validatorSetAuRa.idByMiningAddress.call(initialValidators[i]));
      }
      await stakingAuRa.setCurrentBlockNumber(0).should.be.fulfilled;
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        '0x0000000000000000000000000000000000000000', // _governanceContract
        initialPoolIds, // _initialIds
        web3.utils.toWei('1', 'ether'), // _delegatorMinStake
        web3.utils.toWei('1', 'ether'), // _candidateMinStake
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.fulfilled;
      await stakingAuRa.setValidatorSetAddress(validatorSetAuRa.address).should.be.fulfilled;

      const stakingAddresses = accounts.slice(7, 25 + 1); // accounts[7...25]
      let miningAddresses = [];

      for (let i = 0; i < stakingAddresses.length; i++) {
        // Generate new candidate mining address
        let candidateMiningAddress = '0x';
        for (let i = 0; i < 20; i++) {
          let randomByte = random(0, 255).toString(16);
          if (randomByte.length % 2) {
            randomByte = '0' + randomByte;
          }
          candidateMiningAddress += randomByte;
        }
        miningAddresses.push(candidateMiningAddress.toLowerCase());
      }

      const stakeUnit = new BN(web3.utils.toWei('1', 'ether'));
      const mintAmount = stakeUnit.mul(new BN(100));

      await validatorSetAuRa.setValidatorSetApplyBlock(1).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(20).should.be.fulfilled;
      await stakingAuRa.setCurrentBlockNumber(20).should.be.fulfilled;

      // Deploy token contract and mint tokens for the candidates
      const erc677Token = await ERC677BridgeTokenRewardable.new("STAKE", "STAKE", 18, 100, {from: owner});
      for (let i = 0; i < stakingAddresses.length; i++) {
        await erc677Token.mint(stakingAddresses[i], mintAmount, {from: owner}).should.be.fulfilled;
        mintAmount.should.be.bignumber.equal(await erc677Token.balanceOf.call(stakingAddresses[i]));
      }

      // Pass Staking contract address to ERC677 contract
      await erc677Token.setStakingContract(stakingAuRa.address, {from: owner}).should.be.fulfilled;
      stakingAuRa.address.should.be.equal(await erc677Token.stakingContract.call());

      // Pass ERC677 contract address to Staking contract
      await stakingAuRa.setErc677TokenContract(erc677Token.address, {from: owner}).should.be.fulfilled;
      erc677Token.address.should.be.equal(await stakingAuRa.erc677TokenContract.call());

      // Emulate staking by the candidates into their own pool
      (await stakingAuRa.getPoolsToBeElected.call()).length.should.be.equal(0);
      await stakingAuRa.setCurrentBlockNumber(30).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(30).should.be.fulfilled;
      const poolIds = [];
      for (let i = 0; i < stakingAddresses.length; i++) {
        const stakeAmount = stakeUnit.mul(new BN(i + 1));
        const poolName = `Pool name for ${stakingAddresses[i]}`;
        const poolDescription = `Pool description for ${stakingAddresses[i]}`;
        await stakingAuRa.addPool(stakeAmount, miningAddresses[i], poolName, poolDescription, {from: stakingAddresses[i]}).should.be.fulfilled;
        const poolId = await validatorSetAuRa.idByStakingAddress.call(stakingAddresses[i]);
        stakeAmount.should.be.bignumber.equal(await stakingAuRa.stakeAmount.call(poolId, '0x0000000000000000000000000000000000000000'));
        poolIds.push(poolId);
      }

      // Check pools of the new candidates
      (await stakingAuRa.getPoolsToBeElected.call()).should.be.deep.equal(poolIds);
      const poolsLikelihood = await stakingAuRa.getPoolsLikelihood.call();
      let likelihoodSum = new BN(0);
      for (let i = 0; i < stakingAddresses.length; i++) {
        const poolLikelihood = stakeUnit.mul(new BN(i + 1));
        poolsLikelihood[0][i].should.be.bignumber.equal(new BN(poolLikelihood));
        likelihoodSum = likelihoodSum.add(poolLikelihood);
      }
      poolsLikelihood[1].should.be.bignumber.equal(new BN(likelihoodSum));

      // Generate a random seed
      (await randomAuRa.currentSeed.call()).should.be.bignumber.equal(new BN(0));
      await randomAuRa.setCurrentBlockNumber(0).should.be.fulfilled;
      await randomAuRa.initialize(114, validatorSetAuRa.address, true).should.be.fulfilled;
      let secretNumbers = [];
      let seed = 0;
      for (let i = 0; i < initialValidators.length; i++) {
        const secretNumber = random(1000000, 2000000);
        await randomAuRa.setCurrentBlockNumber(40 + i).should.be.fulfilled;
        await randomAuRa.setCoinbase(initialValidators[i]).should.be.fulfilled;
        const secretNumberHash = web3.utils.soliditySha3(new BN(secretNumber));
        await randomAuRa.commitHash(secretNumberHash, [1 + i, 2 + i, 3 + i], {from: initialValidators[i]}).should.be.fulfilled;
        secretNumbers.push(secretNumber);
        seed ^= secretNumber;
      }
      for (let i = 0; i < initialValidators.length; i++) {
        const secretNumber = secretNumbers[i];
        await randomAuRa.setCurrentBlockNumber(60 + i).should.be.fulfilled;
        await randomAuRa.setCoinbase(initialValidators[i]).should.be.fulfilled;
        await randomAuRa.revealNumber(new BN(secretNumber), {from: initialValidators[i]}).should.be.fulfilled;
      }
      (await randomAuRa.currentSeed.call()).should.be.bignumber.equal(new BN(seed));

      // Emulate calling `newValidatorSet()` at the last block of staking epoch
      await stakingAuRa.setCurrentBlockNumber(120954).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120954).should.be.fulfilled;
      await randomAuRa.setCurrentBlockNumber(120954).should.be.fulfilled;
      await validatorSetAuRa.setBlockRewardContract(accounts[4]).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: accounts[4]}).should.be.fulfilled;

      const newValidators = await validatorSetAuRa.getPendingValidators.call();

      newValidators.length.should.be.equal((await validatorSetAuRa.MAX_VALIDATORS.call()).toNumber());

      newValidators[0].toLowerCase().should.be.equal(initialValidators[0].toLowerCase());
      for (let i = 1; i < newValidators.length; i++) {
        miningAddresses.indexOf(newValidators[i].toLowerCase()).should.be.gte(0);
      }
    });
  });

  describe('_getRandomIndex()', async () => {
    it('should return an adjusted index for defined inputs', async () => {
      const likelihood = [100, 200, 300, 400, 500, 600, 700];
      const likelihoodSum = 2800;

      const randomNumbers = [
        '102295698372522486450340395642197401505767984240419462599162533279732332782651',
        '88025212233336166694158733213902358522896299602970367772879732461395027846748',
        '3523742620359620556816465264713466573401040793358132246666974190393877305106',
        '114287137201841041676259866712650409340573048931079410295991941812580890362241',
        '56538372295469756217105752313834104791610579310176881601739166767736723828094',
        '68894736484717464620468052267132544577303666765971723802696502263332160676293',
        '2687897135972768982863977619384943065126168850144103674632415860805119241205',
        '24156724137176021809787734003047081984697808114992466341401603861146655392651',
        '25832498784249909278064625550198896956883678749506959657822549797979716953904',
        '83427681337508775305223983109488324606217343189389013271254642438269351755393',
        '89240493523877502173991078619437290376114395569336992401719662797476983687349',
        '32853052436845401068458327441561229850088309385635363390209017592145381901382',
        '92757373761302092632106569748694156597982600321652929951701742642022538783264',
        '67100691778885672569176318615234924603932468421815258024949536088416049543990',
        '39719159917163831412538990465342603972769478329347733852265531421865718849185',
        '11999966582708588347446743916419096256885726657832588083780562629766444127924',
        '3010033826674280221348240369209662207451628800231593904185251036266265501228',
        '104413946901985991618369747356151891708096310010480784960228664399399331870677',
        '46702964557713889464151228598162726133335720586871289696077799307058716500554',
        '33559859380160476336881942583444222658690349088979267802639562440185523997062',
        '88164666426323367273712257076795707964138351637743196085165838265474516578736',
        '65103249564951811056118667152373579848051986877071782497698315108889906670108',
        '72821055933320812937250747090735048382600804178995301517010109398983401788049',
        '99208478519263809245343193866271416846250644213811563487317845411846195381743',
        '43244103797891865076724512787658122057625989128787310921522570707520428148373',
        '52593213271200799069017680398601742889781965771702477275560701649706236275690',
        '108328978994570005091822140894920607469753367145808907051759972778893235527605',
        '106243412807859477512275680165822018408062239633748780895951018757528890023894',
        '100523913914531030393977247260355055750370476166866773273692522317156719075854',
        '77022898496333694502068353640750783584648231690398908206984568236564244491382',
        '41979375344302562213493428021758696472517069655026004024762400804791650208434',
        '43628854778068621724043940318620457362856035361685143045720331752230463022095',
        '82285705897178482139228255154026207979788495615016066666460634531254361700322',
        '103033773949537101659963963063505003708388612890360333986921649759562312839480',
        '90770865318369187790230484859485855456585867208388117002983261502339419006204',
        '26815346888796872071397186407189158071870764013785636988299203117345299034401',
        '109773710075222485244630344395494360152079130725134468924787713882051145672746',
        '39403951878453528586564883635284384469843277424612617097230872271502436953145',
        '39389791094920594224321489203186955206743847893381281919090308687926471241472',
        '93046390131440905160726040276266392159114510166775585212343442741436904797202',
        '54170062802343058895719474837092940503100946361183675631561437940603180035660',
        '47885497876255822026761249333701662294944183779830405146054765546172721805412',
        '85784108075793984715971258928372040611210416723184976507035355612383079708374',
        '975231504725199172058136797192737545453371688771241516140759234478419802859',
        '11221695937635509523634019528204860046172097301950632766664824992008610905586',
        '107436738580825641164015325500403818249158286517547805162070908854567423888257',
        '95131259382133028521920698684605162235171126887687165345810768990116888018363',
        '32093301002413573589394148587673090493082958864884746627245068789892859808298',
        '88877363243051860109462313934196367092545400665058685614791669873785662729846',
        '93303263974274844888269460050007671790319652816365815159843581987373074921653',
        '2838589525588108250288537685649588904049605284200358625857231445075798244256',
        '103440835631677484504289133413857661716343392137124352829588867199056428014608',
        '14834897586325978641677634740309984613791219233942292334268919899179999089427',
        '90592739484283286958273216485369225962659619600146792320515852466657598765134',
        '90009074497738073685802439049113289828004402439066889514902444182938602209126',
        '85446725415529547155742409866805383130577708568559028346751611699611011965692',
        '65338189934805816499720020632343445443773750636821931638972192112064593536084',
        '68894736484717464620468052267132544577303666765971723802696502263332160676293',
        '97038415570065070631636413689846636057583460394114803408406438433553572855219',
        '37174481483698717274508692458943206319646761313668452904666599193190263829226',
        '83293654371769887530231273428029838254071141275752836966434884009154334272471',
        '61550675608757547480427728231220369062183692943133553616606393063245090570238',
        '106310422063868805710005503758389364559077338757562463680315994157927102319153',
        '92316372422720713132834387635796571697148072536922335291921606080588893618074',
        '38851776122105484438816516456270700216579032737823857667223570744638236996564',
        '91931610975789749530771289631457740460089882038525235577892199819123862300768',
        '12584022001269166953738601736475241704543867143251821698991913500991013184565',
        '93838766957989869741843637162267026686800430761690851182846725406625910762822',
        '37527235859951512630084295239070248050772227070293275276310077413880965859648',
        '10029852584219766552202521629257119585310608286735288902896374319246007520547',
        '100531592418921996440959660218081004075084077325762235445092461282455443776592',
        '70360301780279317294526696738122950206853248320606760459000212639207738599755',
        '42615335097200622363427787014986340987435795544127844838513465698022325549070',
        '97179166642841831901710211011434773821974291088367923187565757087014715556023',
        '35700707592987123768295375654492959504360595047325542190366022889869127210877',
        '61466192968763487567230878115575886253903086088440811010550926385451886494782',
        '21081112160100882571933565571444206767966165752831043953100274757688624040309',
        '43600512080977603081232319401589971747578355235034101951568657558733599985311',
        '93046390131440905160726040276266392159114510166775585212343442741436904797202',
        '78166256786997532299895132208906760280082009588209678686600716400062852428405',
        '13222897386810906888619556934369590110383618401108006840064914837471049962790',
        '1578602856830276566247637536764056525646602601434018088262687436606906368471',
        '71251492413200829753765707207416712328940017555460320629775672005788805406038',
        '49473946423701235119114128891150684565057594399210078568622426111576160796776',
        '2795241924893775962338639421462660396880272895841450532860602370352763967428',
        '1368176909817681289535734912268540340083367565311628960255594700153503166951',
        '102261823055652808807641282805776330377598366626091044675628029769297795448573',
        '98333942429624994334088114537313280633768758375747170937650280702106049631163',
        '101084934713827664963652249459825932313523258148511708462071053005419555774093',
        '100436038107430274336090680869036994691021844216896199595301884506738559689882',
        '21029750837416702025158549833474322060763342167147939813379699113300579329884',
        '41747798356210327951828864606739475704670278732672411923226952550562810994269',
        '48797956882581040238328998452706637312526017192747728857965049344578930185689',
        '84075528317472161332110783338824603002333331699958015220146204384887016317460',
        '109137764198542875397010922573213806461038404637611535658969502477953977062158',
        '80035044963460208738839148866504952156311667250384896327472835098317653499856',
        '17617865953480899987668249746368539050669466120508322054265245207241748794585',
        '85801402425178001324027499648440415057772242639989974198794870373495420146359',
        '54552824519765246569647140014258846853726582476686673581485232345599309803850',
        '50071681440615794591592854304870967989140492470769568917917087979516067576429'
      ];

      const sampleIndexes = [
        3, 6, 6, 2, 2, 6, 1, 4, 5, 3, 3, 6, 2, 6, 0, 2, 6, 3, 6, 0, 2, 3, 5, 6, 5,
        4, 4, 5, 4, 6, 6, 4, 6, 2, 5, 4, 3, 3, 3, 5, 5, 4, 3, 0, 6, 2, 3, 6, 6, 2,
        4, 2, 6, 6, 0, 5, 6, 6, 6, 6, 6, 4, 6, 4, 5, 2, 6, 5, 3, 5, 3, 6, 3, 6, 2,
        1, 5, 4, 5, 5, 5, 1, 4, 6, 6, 6, 3, 4, 1, 3, 5, 4, 4, 4, 6, 4, 4, 2, 5, 6
      ];

      let results = [];
      for (let i = 0; i < randomNumbers.length; i++) {
        const index = await validatorSetAuRa.getRandomIndex.call(
          likelihood,
          likelihoodSum,
          randomNumbers[i]
        );
        results.push(index.toNumber());
      }

      results.should.be.deep.equal(sampleIndexes);
    });

    it('should always return an index within the input array size', async () => {
      for (let i = 0; i < 100; i++) {
        const size = random(19, 100);

        let likelihood = [];
        let likelihoodSum = 0;
        for (let j = 0; j < size; j++) {
          const randomLikelihood = random(100, 1000);
          likelihood.push(randomLikelihood);
          likelihoodSum += randomLikelihood;
        }

        let currentSize = size;
        let randomNumber = random(0, Number.MAX_SAFE_INTEGER);
        for (let j = 0; j < size; j++) {
          const index = await validatorSetAuRa.getRandomIndex.call(
            likelihood,
            likelihoodSum,
            randomNumber
          );
          (index < currentSize).should.be.equal(true);
          likelihoodSum -= likelihood[index];
          likelihood[index] = likelihood[currentSize - 1];
          currentSize--;
          randomNumber = new BN(web3.utils.soliditySha3(randomNumber).slice(2), 16);
        }
      }
    });

    it('should return indexes according to given likelihood', async () => {
      const repeats = 2000;
      const maxFluctuation = 2; // percents, +/-

      const stakeAmounts = [
        170000, // 17%
        130000, // 13%
        10000,  // 1%
        210000, // 21%
        90000,  // 9%
        60000,  // 6%
        0,      // 0%
        100000, // 10%
        40000,  // 4%
        140000, // 14%
        30000,  // 3%
        0,      // 0%
        20000   // 2%
      ];

      const stakeAmountsTotal = stakeAmounts.reduce((accumulator, value) => accumulator + value);
      const stakeAmountsExpectedShares = stakeAmounts.map((value) => parseInt(value / stakeAmountsTotal * 100));
      let indexesStats = stakeAmounts.map(() => 0);

      for (let i = 0; i < repeats; i++) {
        const index = await validatorSetAuRa.getRandomIndex.call(
          stakeAmounts,
          stakeAmountsTotal,
          random(0, Number.MAX_SAFE_INTEGER)
        );
        indexesStats[index.toNumber()]++;
      }

      const stakeAmountsRandomShares = indexesStats.map((value) => Math.round(value / repeats * 100));

      //console.log(stakeAmountsExpectedShares);
      //console.log(stakeAmountsRandomShares);

      stakeAmountsRandomShares.forEach((value, index) => {
        if (stakeAmountsExpectedShares[index] == 0) {
          value.should.be.equal(0);
        } else {
          Math.abs(stakeAmountsExpectedShares[index] - value).should.be.most(maxFluctuation);
        }
      });
    });
  });

  // TODO: ...add other tests...
});

function random(low, high) {
  return Math.floor(Math.random() * (high - low) + low);
}
*/
