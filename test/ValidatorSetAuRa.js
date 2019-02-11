const ERC677BridgeTokenRewardable = artifacts.require('ERC677BridgeTokenRewardableMock');
const EternalStorageProxy = artifacts.require('EternalStorageProxy');
const ValidatorSetAuRa = artifacts.require('ValidatorSetAuRaMock');

const ERROR_MSG = 'VM Exception while processing transaction: revert';
const BN = web3.utils.BN;

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bn')(BN))
  .should();

contract('ValidatorSetAuRa', async accounts => {
  let owner;
  let validatorSetAuRa;

  beforeEach(async () => {
    owner = accounts[0];
    // Deploy ValidatorSet contract
    validatorSetAuRa = await ValidatorSetAuRa.new();
    validatorSetAuRa = await EternalStorageProxy.new(validatorSetAuRa.address, owner);
    validatorSetAuRa = await ValidatorSetAuRa.at(validatorSetAuRa.address);
  });

  describe('addPool()', async () => {
    let candidate;
    let erc20Token;
    let stakeUnit;
    let initialValidators;

    beforeEach(async () => {
      candidate = accounts[4];
      initialValidators = accounts.slice(1, 3 + 1); // accounts[1...3]

      // Initialize ValidatorSet
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialValidators
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.fulfilled;

      // Deploy ERC20 contract
      erc20Token = await ERC677BridgeTokenRewardable.new("POA20", "POA20", 18, {from: owner});

      // Mint some balance for candidate (imagine that the candidate got 2 STAKE_UNITs from a bridge)
      stakeUnit = await validatorSetAuRa.STAKE_UNIT.call();
      const mintAmount = stakeUnit.mul(new BN(2));
      await erc20Token.mint(candidate, mintAmount, {from: owner}).should.be.fulfilled;
      mintAmount.should.be.bignumber.equal(await erc20Token.balanceOf(candidate));

      // Pass ValidatorSet contract address to ERC20 contract
      await erc20Token.setValidatorSetContract(validatorSetAuRa.address, {from: owner}).should.be.fulfilled;
      validatorSetAuRa.address.should.be.equal(
        await erc20Token.validatorSetContract.call()
      );

      // Pass ERC20 contract address to ValidatorSet contract
      '0x0000000000000000000000000000000000000000'.should.be.equal(
        await validatorSetAuRa.erc20TokenContract.call()
      );
      await validatorSetAuRa.setErc20TokenContract(erc20Token.address, {from: owner}).should.be.fulfilled;
      erc20Token.address.should.be.equal(
        await validatorSetAuRa.erc20TokenContract.call()
      );

      // Emulate block number
      await validatorSetAuRa.setCurrentBlockNumber(2).should.be.fulfilled;
    });
    it('should create a new pool', async () => {
      false.should.be.equal(await validatorSetAuRa.doesPoolExist.call(candidate));
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), {from: candidate}).should.be.fulfilled;
      true.should.be.equal(await validatorSetAuRa.doesPoolExist.call(candidate));
    });
    it('should fail if gasPrice is 0', async () => {
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), {from: candidate, gasPrice: 0}).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if ERC contract is not specified', async () => {
      // Set ERC20 contract address to zero
      await validatorSetAuRa.resetErc20TokenContract().should.be.fulfilled;

      // Try to add a new pool
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), {from: candidate}).should.be.rejectedWith(ERROR_MSG);
      false.should.be.equal(await validatorSetAuRa.doesPoolExist.call(candidate));

      // Pass ERC20 contract address to ValidatorSet contract
      await validatorSetAuRa.setErc20TokenContract(erc20Token.address, {from: owner}).should.be.fulfilled;

      // Add a new pool
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), {from: candidate}).should.be.fulfilled;
      true.should.be.equal(await validatorSetAuRa.doesPoolExist.call(candidate));
    });
    it('should fail if staking amount is 0', async () => {
      await validatorSetAuRa.addPool(new BN(0), {from: candidate}).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if block.number is inside disallowed range', async () => {
      await validatorSetAuRa.setCurrentBlockNumber(119960).should.be.fulfilled;
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), {from: candidate}).should.be.rejectedWith(ERROR_MSG);
      await validatorSetAuRa.setCurrentBlockNumber(116560).should.be.fulfilled;
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), {from: candidate}).should.be.fulfilled;
    });
    it('should fail if staking amount is less than CANDIDATE_MIN_STAKE', async () => {
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)).div(new BN(2)), {from: candidate}).should.be.rejectedWith(ERROR_MSG);
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), {from: candidate}).should.be.fulfilled;
    });
    it('should fail if candidate doesn\'t have enough funds', async () => {
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(3)), {from: candidate}).should.be.rejectedWith(ERROR_MSG);
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(2)), {from: candidate}).should.be.fulfilled;
    });
    it('stake amount should be increased', async () => {
      const amount = stakeUnit.mul(new BN(2));
      await validatorSetAuRa.addPool(amount, {from: candidate}).should.be.fulfilled;
      amount.should.be.bignumber.equal(await validatorSetAuRa.stakeAmount.call(candidate, candidate));
      amount.should.be.bignumber.equal(await validatorSetAuRa.stakeAmountByEpoch.call(candidate, candidate, 0));
      amount.should.be.bignumber.equal(await validatorSetAuRa.stakeAmountTotal.call(candidate));
    });
    it('should be able to add more than one pool', async () => {
      const candidate1 = candidate;
      const candidate2 = accounts[5];
      const amount1 = stakeUnit.mul(new BN(2));
      const amount2 = stakeUnit.mul(new BN(3));

      // Emulate having necessary amount for the candidate #2
      await erc20Token.mint(candidate2, amount2, {from: owner}).should.be.fulfilled;
      amount2.should.be.bignumber.equal(await erc20Token.balanceOf(candidate2));

      // Add two new pools
      (await validatorSetAuRa.isPoolActive.call(candidate1)).should.be.equal(false);
      (await validatorSetAuRa.isPoolActive.call(candidate2)).should.be.equal(false);
      await validatorSetAuRa.addPool(amount1, {from: candidate1}).should.be.fulfilled;
      await validatorSetAuRa.addPool(amount2, {from: candidate2}).should.be.fulfilled;
      (await validatorSetAuRa.isPoolActive.call(candidate1)).should.be.equal(true);
      (await validatorSetAuRa.isPoolActive.call(candidate2)).should.be.equal(true);

      // Check indexes (0...2 are busy by initial validators)
      new BN(3).should.be.bignumber.equal(await validatorSetAuRa.poolIndex.call(candidate1));
      new BN(4).should.be.bignumber.equal(await validatorSetAuRa.poolIndex.call(candidate2));

      // Check pools' existence
      const validators = await validatorSetAuRa.getValidators.call();

      (await validatorSetAuRa.getPools.call()).should.be.deep.equal([
        validators[0],
        validators[1],
        validators[2],
        candidate1,
        candidate2
      ]);
    });
    it('shouldn\'t allow adding more than MAX_CANDIDATES pools', async () => {
      for (let p = initialValidators.length; p < 100; p++) {
        // Generate new candidate address
        let candidateAddress = '0x';
        for (let i = 0; i < 20; i++) {
          let randomByte = random(0, 255).toString(16);
          if (randomByte.length % 2) {
            randomByte = '0' + randomByte;
          }
          candidateAddress += randomByte;
        }

        // Add a new pool
        await validatorSetAuRa.addToPoolsMock(candidateAddress).should.be.fulfilled;
        new BN(p).should.be.bignumber.equal(await validatorSetAuRa.poolIndex.call(candidateAddress));
      }

      // Try to add a new pool outside of max limit
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), {from: candidate}).should.be.rejectedWith(ERROR_MSG);
      false.should.be.equal(await validatorSetAuRa.doesPoolExist.call(candidate));
    });
    it('should remove added pool from the list of inactive pools', async () => {
      await validatorSetAuRa.addToPoolsInactiveMock(candidate).should.be.fulfilled;
      (await validatorSetAuRa.getPoolsInactive.call()).should.be.deep.equal([candidate]);
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), {from: candidate}).should.be.fulfilled;
      true.should.be.equal(await validatorSetAuRa.doesPoolExist.call(candidate));
      (await validatorSetAuRa.getPoolsInactive.call()).length.should.be.equal(0);
    });
  });

  describe('initialize()', async () => {
    const initialValidators = accounts.slice(1, 4); // get three addresses

    beforeEach(async () => {
      initialValidators.length.should.be.equal(3);
      initialValidators[0].should.not.be.equal('0x0000000000000000000000000000000000000000');
      initialValidators[1].should.not.be.equal('0x0000000000000000000000000000000000000000');
      initialValidators[2].should.not.be.equal('0x0000000000000000000000000000000000000000');
      await validatorSetAuRa.setCurrentBlockNumber(0);
    });
    it('should initialize successfully', async () => {
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialValidators
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.fulfilled;
      new BN(120960).should.be.bignumber.equal(
        await validatorSetAuRa.stakingEpochDuration.call()
      );
      new BN(4320).should.be.bignumber.equal(
        await validatorSetAuRa.stakeWithdrawDisallowPeriod.call()
      );
      new BN(0).should.be.bignumber.equal(
        await validatorSetAuRa.stakingEpochStartBlock.call()
      );
      '0x2000000000000000000000000000000000000001'.should.be.equal(
        await validatorSetAuRa.blockRewardContract.call()
      );
      '0x3000000000000000000000000000000000000001'.should.be.equal(
        await validatorSetAuRa.randomContract.call()
      );
      '0x0000000000000000000000000000000000000000'.should.be.equal(
        await validatorSetAuRa.erc20TokenContract.call()
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
        new BN(i).should.be.bignumber.equal(
          await validatorSetAuRa.poolIndex.call(initialValidators[i])
        );
        true.should.be.equal(
          await validatorSetAuRa.isPoolActive.call(initialValidators[i])
        );
      }
      false.should.be.equal(
        await validatorSetAuRa.isValidator.call('0x0000000000000000000000000000000000000000')
      );
      (await validatorSetAuRa.getValidators.call()).should.be.deep.equal(
        await validatorSetAuRa.getPools.call()
      );
      new BN(web3.utils.toWei('1', 'ether')).should.be.bignumber.equal(
        await validatorSetAuRa.getDelegatorMinStake.call()
      );
      new BN(web3.utils.toWei('1', 'ether')).should.be.bignumber.equal(
        await validatorSetAuRa.getCandidateMinStake.call()
      );
      new BN(1).should.be.bignumber.equal(
        await validatorSetAuRa.validatorSetApplyBlock.call()
      );
    });
    it('should fail if the current block number is not zero', async () => {
      await validatorSetAuRa.setCurrentBlockNumber(1);
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialValidators
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if BlockRewardAuRa contract address is zero', async () => {
      await validatorSetAuRa.initialize(
        '0x0000000000000000000000000000000000000000', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialValidators
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if RandomAuRa contract address is zero', async () => {
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x0000000000000000000000000000000000000000', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialValidators
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if initial validators array is empty', async () => {
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        [], // _initialValidators
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if delegatorMinStake is zero', async () => {
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialValidators
        0, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if candidateMinStake is zero', async () => {
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialValidators
        1, // _delegatorMinStake
        0, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if already initialized', async () => {
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialValidators
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.fulfilled;
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialValidators
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if stakingEpochDuration is 0', async () => {
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialValidators
        1, // _delegatorMinStake
        1, // _candidateMinStake
        0, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if stakeWithdrawDisallowPeriod is 0', async () => {
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialValidators
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        0 // _stakeWithdrawDisallowPeriod
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if stakeWithdrawDisallowPeriod >= stakingEpochDuration', async () => {
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialValidators
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        120960 // _stakeWithdrawDisallowPeriod
      ).should.be.rejectedWith(ERROR_MSG);
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialValidators
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.fulfilled;
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
});

function random(low, high) {
  return Math.floor(Math.random() * (high - low) + low);
}
