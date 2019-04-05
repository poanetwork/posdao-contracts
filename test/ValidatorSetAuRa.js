const BlockRewardAuRa = artifacts.require('BlockRewardAuRa');
const ERC677BridgeTokenRewardable = artifacts.require('ERC677BridgeTokenRewardableMock');
const EternalStorageProxy = artifacts.require('EternalStorageProxy');
const RandomAuRa = artifacts.require('RandomAuRa');
const StakingAuRa = artifacts.require('StakingAuRaMock');
const ValidatorSetAuRa = artifacts.require('ValidatorSetAuRaMock');

const ERROR_MSG = 'VM Exception while processing transaction: revert';
const BN = web3.utils.BN;

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bn')(BN))
  .should();

contract('ValidatorSetAuRa', async accounts => {
  let owner;
  let stakingAuRa;
  let validatorSetAuRa;

  beforeEach(async () => {
    owner = accounts[0];
    // Deploy BlockReward contract
    blockRewardAuRa = await BlockRewardAuRa.new();
    blockRewardAuRa = await EternalStorageProxy.new(blockRewardAuRa.address, owner);
    blockRewardAuRa = await BlockRewardAuRa.at(blockRewardAuRa.address);
    // Deploy Staking contract
    stakingAuRa = await StakingAuRa.new();
    stakingAuRa = await EternalStorageProxy.new(stakingAuRa.address, owner);
    stakingAuRa = await StakingAuRa.at(stakingAuRa.address);
    // Deploy ValidatorSet contract
    validatorSetAuRa = await ValidatorSetAuRa.new();
    validatorSetAuRa = await EternalStorageProxy.new(validatorSetAuRa.address, owner);
    validatorSetAuRa = await ValidatorSetAuRa.at(validatorSetAuRa.address);
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
        new BN(i).should.be.bignumber.equal(
          await validatorSetAuRa.validatorIndex.call(initialValidators[i])
        );
        true.should.be.equal(
          await validatorSetAuRa.isValidator.call(initialValidators[i])
        );
        (await validatorSetAuRa.miningByStakingAddress.call(initialStakingAddresses[i])).should.be.equal(initialValidators[i]);
        (await validatorSetAuRa.stakingByMiningAddress.call(initialValidators[i])).should.be.equal(initialStakingAddresses[i]);
      }
      false.should.be.equal(
        await validatorSetAuRa.isValidator.call('0x0000000000000000000000000000000000000000')
      );
      (await validatorSetAuRa.unremovableValidator.call()).should.be.equal(
        '0x0000000000000000000000000000000000000000'
      );
      new BN(1).should.be.bignumber.equal(
        await validatorSetAuRa.validatorSetApplyBlock.call()
      );
    });
    it('should set unremovable validator to the first staking address', async () => {
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        true // _firstValidatorIsUnremovable
      ).should.be.fulfilled;
      initialStakingAddresses[0].should.be.equal(
        await validatorSetAuRa.unremovableValidator.call()
      );
    });
    it('should fail if the current block number is not zero', async () => {
      await validatorSetAuRa.setCurrentBlockNumber(1);
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false // _firstValidatorIsUnremovable
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if BlockRewardAuRa contract address is zero', async () => {
      await validatorSetAuRa.initialize(
        '0x0000000000000000000000000000000000000000', // _blockRewardContract
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
        '0x3000000000000000000000000000000000000001', // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false // _firstValidatorIsUnremovable
      ).should.be.fulfilled;
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
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
    let randomAuRa;

    beforeEach(async () => {
      initialValidators = accounts.slice(1, 3 + 1); // accounts[1...3]
      initialStakingAddresses = accounts.slice(4, 6 + 1); // accounts[4...6]

      randomAuRa = await RandomAuRa.new();
      randomAuRa = await EternalStorageProxy.new(randomAuRa.address, owner);
      randomAuRa = await RandomAuRa.at(randomAuRa.address);

      await validatorSetAuRa.setCurrentBlockNumber(0).should.be.fulfilled;
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        randomAuRa.address, // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false // _firstValidatorIsUnremovable
      ).should.be.fulfilled;
      await stakingAuRa.setCurrentBlockNumber(0).should.be.fulfilled;
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.fulfilled;
      await stakingAuRa.setValidatorSetAddress(validatorSetAuRa.address).should.be.fulfilled;
      await stakingAuRa.setCurrentBlockNumber(120960).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120960).should.be.fulfilled;
    });
    it('can only be called by BlockReward contract', async () => {
      await validatorSetAuRa.newValidatorSet({from: owner}).should.be.rejectedWith(ERROR_MSG);
      await validatorSetAuRa.setBlockRewardContract(accounts[4]).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: accounts[4]}).should.be.fulfilled;
    });
    it('should only work at the latest block of current staking epoch', async () => {
      await stakingAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      (await stakingAuRa.stakingEpochEndBlock.call()).should.be.bignumber.equal(new BN(120960));
      await validatorSetAuRa.setBlockRewardContract(accounts[4]).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: accounts[4]}).should.be.fulfilled;
      (await stakingAuRa.stakingEpochStartBlock.call()).should.be.bignumber.equal(new BN(0));
      await stakingAuRa.setCurrentBlockNumber(120960).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120960).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: accounts[4]}).should.be.fulfilled;
      (await stakingAuRa.stakingEpochStartBlock.call()).should.be.bignumber.equal(new BN(120961));
    });
    it('should increment the number of staking epoch', async () => {
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(new BN(0));
      await validatorSetAuRa.setBlockRewardContract(accounts[4]).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: accounts[4]}).should.be.fulfilled;
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(new BN(1));
    });
    it('should reset validatorSetApplyBlock', async () => {
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(1));
      await validatorSetAuRa.setBlockRewardContract(accounts[4]).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: accounts[4]}).should.be.fulfilled;
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
    });
    it('should enqueue initial validators', async () => {
      // Emulate calling `finalizeChange()` at network startup
      await validatorSetAuRa.setCurrentBlockNumber(1).should.be.fulfilled;
      (await validatorSetAuRa.initiateChangeAllowed.call()).should.be.equal(false);
      await validatorSetAuRa.setSystemAddress(owner).should.be.fulfilled;
      await validatorSetAuRa.finalizeChange({from: owner}).should.be.fulfilled;
      (await validatorSetAuRa.initiateChangeAllowed.call()).should.be.equal(true);

      // Emulate calling `newValidatorSet()` at the last block of staking epoch
      await stakingAuRa.setCurrentBlockNumber(120960).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120960).should.be.fulfilled;
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      await validatorSetAuRa.setBlockRewardContract(accounts[4]).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: accounts[4]}).should.be.fulfilled;
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(true);

      // Emulate calling `emitInitiateChange()` at the beginning of the next staking epoch
      await stakingAuRa.setCurrentBlockNumber(120961).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120961).should.be.fulfilled;
      const {logs} = await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
      logs[0].event.should.equal("InitiateChange");
      logs[0].args.newSet.should.be.deep.equal(initialValidators);
      (await validatorSetAuRa.initiateChangeAllowed.call()).should.be.equal(false);
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);

      // Check the returned value of `getQueueValidators()`
      const queueResult = await validatorSetAuRa.getQueueValidators.call();
      queueResult[0].should.be.deep.equal(initialValidators);
      queueResult[1].should.be.equal(true);
    });
    it('should enqueue only one validator which has non-empty pool', async () => {
      const stakeUnit = await stakingAuRa.STAKE_UNIT.call();
      const mintAmount = stakeUnit.mul(new BN(2));

      await stakingAuRa.setCurrentBlockNumber(10).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(10).should.be.fulfilled;

      // Deploy token contract and mint some tokens for the first initial validator
      const erc20Token = await ERC677BridgeTokenRewardable.new("POSDAO20", "POSDAO20", 18, {from: owner});
      await erc20Token.mint(initialStakingAddresses[0], mintAmount, {from: owner}).should.be.fulfilled;
      mintAmount.should.be.bignumber.equal(await erc20Token.balanceOf.call(initialStakingAddresses[0]));

      // Pass Staking contract address to ERC20 contract
      await erc20Token.setStakingContract(stakingAuRa.address, {from: owner}).should.be.fulfilled;
      stakingAuRa.address.should.be.equal(await erc20Token.stakingContract.call());

      // Pass ERC20 contract address to Staking contract
      await stakingAuRa.setErc20TokenContract(erc20Token.address, {from: owner}).should.be.fulfilled;
      erc20Token.address.should.be.equal(await stakingAuRa.erc20TokenContract.call());

      // Emulate staking by the first validator into their own pool
      const stakeAmount = stakeUnit.mul(new BN(1));
      await stakingAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[0], stakeAmount, {from: initialStakingAddresses[0]}).should.be.fulfilled;
      stakeAmount.should.be.bignumber.equal(await stakingAuRa.stakeAmount.call(initialStakingAddresses[0], initialStakingAddresses[0]));

      // Emulate calling `newValidatorSet()` at the last block of staking epoch
      await stakingAuRa.setCurrentBlockNumber(120960).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120960).should.be.fulfilled;
      await validatorSetAuRa.setBlockRewardContract(accounts[4]).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: accounts[4]}).should.be.fulfilled;

      // Check the returned value of `getPendingValidators()`
      (await validatorSetAuRa.getPendingValidators.call()).should.be.deep.equal([initialValidators[0]]);
    });
    it('should enqueue unremovable validator anyway', async () => {
      validatorSetAuRa = await ValidatorSetAuRa.new();
      validatorSetAuRa = await EternalStorageProxy.new(validatorSetAuRa.address, owner);
      validatorSetAuRa = await ValidatorSetAuRa.at(validatorSetAuRa.address);

      stakingAuRa = await StakingAuRa.new();
      stakingAuRa = await EternalStorageProxy.new(stakingAuRa.address, owner);
      stakingAuRa = await StakingAuRa.at(stakingAuRa.address);

      await validatorSetAuRa.setCurrentBlockNumber(0).should.be.fulfilled;
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        randomAuRa.address, // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        true // _firstValidatorIsUnremovable
      ).should.be.fulfilled;

      await stakingAuRa.setCurrentBlockNumber(0).should.be.fulfilled;
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.fulfilled;
      await stakingAuRa.setValidatorSetAddress(validatorSetAuRa.address).should.be.fulfilled;

      const stakeUnit = await stakingAuRa.STAKE_UNIT.call();
      const mintAmount = stakeUnit.mul(new BN(2));

      await stakingAuRa.setCurrentBlockNumber(10).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(10).should.be.fulfilled;

      // Deploy token contract and mint some tokens for the second initial validator
      const erc20Token = await ERC677BridgeTokenRewardable.new("POSDAO20", "POSDAO20", 18, {from: owner});
      await erc20Token.mint(initialStakingAddresses[1], mintAmount, {from: owner}).should.be.fulfilled;
      mintAmount.should.be.bignumber.equal(await erc20Token.balanceOf.call(initialStakingAddresses[1]));

      // Pass Staking contract address to ERC20 contract
      await erc20Token.setStakingContract(stakingAuRa.address, {from: owner}).should.be.fulfilled;
      stakingAuRa.address.should.be.equal(await erc20Token.stakingContract.call());

      // Pass ERC20 contract address to Staking contract
      await stakingAuRa.setErc20TokenContract(erc20Token.address, {from: owner}).should.be.fulfilled;
      erc20Token.address.should.be.equal(await stakingAuRa.erc20TokenContract.call());

      // Emulate staking by the second validator into their own pool
      const stakeAmount = stakeUnit.mul(new BN(1));
      await stakingAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[1], stakeAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      stakeAmount.should.be.bignumber.equal(await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], initialStakingAddresses[1]));

      // Emulate calling `newValidatorSet()` at the last block of staking epoch
      await stakingAuRa.setCurrentBlockNumber(120960).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120960).should.be.fulfilled;
      await validatorSetAuRa.setBlockRewardContract(accounts[4]).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: accounts[4]}).should.be.fulfilled;

      // Check the returned value of `getPendingValidators()`
      const unremovableStakingAddress = await validatorSetAuRa.unremovableValidator.call();
      const unremovableMiningAddress = await validatorSetAuRa.miningByStakingAddress.call(unremovableStakingAddress);
      (await validatorSetAuRa.getPendingValidators.call()).should.be.deep.equal([
        unremovableMiningAddress,
        initialValidators[1]
      ]);

      // Check the current active pools
      (await stakingAuRa.getPools.call()).should.be.deep.equal([
        unremovableStakingAddress,
        initialStakingAddresses[1]
      ]);
    });
    it('should choose validators randomly', async () => {
      // TODO: to be implemented
    });
  });

  describe('_getRandomIndex()', async () => {
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
