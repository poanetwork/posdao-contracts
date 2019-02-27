const ERC677BridgeTokenRewardable = artifacts.require('ERC677BridgeTokenRewardableMock');
const EternalStorageProxy = artifacts.require('EternalStorageProxy');
const RandomAuRa = artifacts.require('RandomAuRa');
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
    let candidateMiningAddress;
    let candidateStakingAddress;
    let erc20Token;
    let stakeUnit;
    let initialValidators;
    let initialStakingAddresses;

    beforeEach(async () => {
      candidateMiningAddress = accounts[7];
      candidateStakingAddress = accounts[8];
      initialValidators = accounts.slice(1, 3 + 1); // accounts[1...3]
      initialStakingAddresses = accounts.slice(4, 6 + 1); // accounts[4...6]

      // Initialize ValidatorSet
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false, // _firstValidatorIsUnremovable
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
      await erc20Token.mint(candidateStakingAddress, mintAmount, {from: owner}).should.be.fulfilled;
      mintAmount.should.be.bignumber.equal(await erc20Token.balanceOf.call(candidateStakingAddress));

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
      false.should.be.equal(await validatorSetAuRa.doesPoolExist.call(candidateStakingAddress));
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.fulfilled;
      true.should.be.equal(await validatorSetAuRa.doesPoolExist.call(candidateStakingAddress));
    });
    it('should fail if mining address is 0', async () => {
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), '0x0000000000000000000000000000000000000000', {from: candidateStakingAddress}).should.be.rejectedWith(ERROR_MSG);
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.fulfilled;
    });
    it('should fail if mining address is equal to staking', async () => {
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateStakingAddress, {from: candidateStakingAddress}).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if the pool with the same mining/staking address is already existed', async () => {
      const candidateMiningAddress2 = accounts[9];
      const candidateStakingAddress2 = accounts[10];
      
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.fulfilled;
      
      await erc20Token.mint(candidateMiningAddress, stakeUnit.mul(new BN(2)), {from: owner}).should.be.fulfilled;
      await erc20Token.mint(candidateMiningAddress2, stakeUnit.mul(new BN(2)), {from: owner}).should.be.fulfilled;
      await erc20Token.mint(candidateStakingAddress2, stakeUnit.mul(new BN(2)), {from: owner}).should.be.fulfilled;

      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress2}).should.be.rejectedWith(ERROR_MSG);
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress2, {from: candidateStakingAddress}).should.be.rejectedWith(ERROR_MSG);
      
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateStakingAddress, {from: candidateMiningAddress2}).should.be.rejectedWith(ERROR_MSG);
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateStakingAddress2, {from: candidateMiningAddress}).should.be.rejectedWith(ERROR_MSG);

      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateMiningAddress2}).should.be.rejectedWith(ERROR_MSG);
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress2, {from: candidateMiningAddress}).should.be.rejectedWith(ERROR_MSG);

      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateStakingAddress, {from: candidateStakingAddress2}).should.be.rejectedWith(ERROR_MSG);
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateStakingAddress2, {from: candidateStakingAddress}).should.be.rejectedWith(ERROR_MSG);
      
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress2, {from: candidateStakingAddress2}).should.be.fulfilled;
    });
    it('should fail if gasPrice is 0', async () => {
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress, gasPrice: 0}).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if ERC contract is not specified', async () => {
      // Set ERC20 contract address to zero
      await validatorSetAuRa.resetErc20TokenContract().should.be.fulfilled;

      // Try to add a new pool
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.rejectedWith(ERROR_MSG);
      false.should.be.equal(await validatorSetAuRa.doesPoolExist.call(candidateStakingAddress));

      // Pass ERC20 contract address to ValidatorSet contract
      await validatorSetAuRa.setErc20TokenContract(erc20Token.address, {from: owner}).should.be.fulfilled;

      // Add a new pool
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.fulfilled;
      true.should.be.equal(await validatorSetAuRa.doesPoolExist.call(candidateStakingAddress));
    });
    it('should fail if staking amount is 0', async () => {
      await validatorSetAuRa.addPool(new BN(0), candidateMiningAddress, {from: candidateStakingAddress}).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if block.number is inside disallowed range', async () => {
      await validatorSetAuRa.setCurrentBlockNumber(119960).should.be.fulfilled;
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.rejectedWith(ERROR_MSG);
      await validatorSetAuRa.setCurrentBlockNumber(116560).should.be.fulfilled;
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.fulfilled;
    });
    it('should fail if staking amount is less than CANDIDATE_MIN_STAKE', async () => {
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)).div(new BN(2)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.rejectedWith(ERROR_MSG);
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.fulfilled;
    });
    it('should fail if candidate doesn\'t have enough funds', async () => {
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(3)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.rejectedWith(ERROR_MSG);
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(2)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.fulfilled;
    });
    it('stake amount should be increased', async () => {
      const amount = stakeUnit.mul(new BN(2));
      await validatorSetAuRa.addPool(amount, candidateMiningAddress, {from: candidateStakingAddress}).should.be.fulfilled;
      amount.should.be.bignumber.equal(await validatorSetAuRa.stakeAmount.call(candidateStakingAddress, candidateStakingAddress));
      amount.should.be.bignumber.equal(await validatorSetAuRa.stakeAmountByCurrentEpoch.call(candidateStakingAddress, candidateStakingAddress));
      amount.should.be.bignumber.equal(await validatorSetAuRa.stakeAmountTotal.call(candidateStakingAddress));
    });
    it('should be able to add more than one pool', async () => {
      const candidate1MiningAddress = candidateMiningAddress;
      const candidate1StakingAddress = candidateStakingAddress;
      const candidate2MiningAddress = accounts[9];
      const candidate2StakingAddress = accounts[10];
      const amount1 = stakeUnit.mul(new BN(2));
      const amount2 = stakeUnit.mul(new BN(3));

      // Emulate having necessary amount for the candidate #2
      await erc20Token.mint(candidate2StakingAddress, amount2, {from: owner}).should.be.fulfilled;
      amount2.should.be.bignumber.equal(await erc20Token.balanceOf.call(candidate2StakingAddress));

      // Add two new pools
      (await validatorSetAuRa.isPoolActive.call(candidate1StakingAddress)).should.be.equal(false);
      (await validatorSetAuRa.isPoolActive.call(candidate2StakingAddress)).should.be.equal(false);
      await validatorSetAuRa.addPool(amount1, candidate1MiningAddress, {from: candidate1StakingAddress}).should.be.fulfilled;
      await validatorSetAuRa.addPool(amount2, candidate2MiningAddress, {from: candidate2StakingAddress}).should.be.fulfilled;
      (await validatorSetAuRa.isPoolActive.call(candidate1StakingAddress)).should.be.equal(true);
      (await validatorSetAuRa.isPoolActive.call(candidate2StakingAddress)).should.be.equal(true);

      // Check indexes (0...2 are busy by initial validators)
      new BN(3).should.be.bignumber.equal(await validatorSetAuRa.poolIndex.call(candidate1StakingAddress));
      new BN(4).should.be.bignumber.equal(await validatorSetAuRa.poolIndex.call(candidate2StakingAddress));

      // Check pools' existence
      const validators = await validatorSetAuRa.getValidators.call();

      (await validatorSetAuRa.getPools.call()).should.be.deep.equal([
        await validatorSetAuRa.stakingByMiningAddress.call(validators[0]),
        await validatorSetAuRa.stakingByMiningAddress.call(validators[1]),
        await validatorSetAuRa.stakingByMiningAddress.call(validators[2]),
        candidate1StakingAddress,
        candidate2StakingAddress
      ]);
    });
    it('shouldn\'t allow adding more than MAX_CANDIDATES pools', async () => {
      for (let p = initialValidators.length; p < 100; p++) {
        // Generate new candidate staking address
        let candidateStakingAddress = '0x';
        for (let i = 0; i < 20; i++) {
          let randomByte = random(0, 255).toString(16);
          if (randomByte.length % 2) {
            randomByte = '0' + randomByte;
          }
          candidateStakingAddress += randomByte;
        }

        // Add a new pool
        await validatorSetAuRa.addToPoolsMock(candidateStakingAddress).should.be.fulfilled;
        new BN(p).should.be.bignumber.equal(await validatorSetAuRa.poolIndex.call(candidateStakingAddress));
      }

      // Try to add a new pool outside of max limit
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.rejectedWith(ERROR_MSG);
      false.should.be.equal(await validatorSetAuRa.doesPoolExist.call(candidateStakingAddress));
    });
    it('should remove added pool from the list of inactive pools', async () => {
      await validatorSetAuRa.addToPoolsInactiveMock(candidateStakingAddress).should.be.fulfilled;
      (await validatorSetAuRa.getPoolsInactive.call()).should.be.deep.equal([candidateStakingAddress]);
      await validatorSetAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.fulfilled;
      true.should.be.equal(await validatorSetAuRa.doesPoolExist.call(candidateStakingAddress));
      (await validatorSetAuRa.getPoolsInactive.call()).length.should.be.equal(0);
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
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false, // _firstValidatorIsUnremovable
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
          await validatorSetAuRa.poolIndex.call(initialStakingAddresses[i])
        );
        true.should.be.equal(
          await validatorSetAuRa.isPoolActive.call(initialStakingAddresses[i])
        );
        (await validatorSetAuRa.miningByStakingAddress.call(initialStakingAddresses[i])).should.be.equal(initialValidators[i]);
        (await validatorSetAuRa.stakingByMiningAddress.call(initialValidators[i])).should.be.equal(initialStakingAddresses[i]);
      }
      false.should.be.equal(
        await validatorSetAuRa.isValidator.call('0x0000000000000000000000000000000000000000')
      );
      (await validatorSetAuRa.getPools.call()).should.be.deep.equal(initialStakingAddresses);
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
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false, // _firstValidatorIsUnremovable
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
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false, // _firstValidatorIsUnremovable
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
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false, // _firstValidatorIsUnremovable
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if initial mining addresses are empty', async () => {
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        [], // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false, // _firstValidatorIsUnremovable
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
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false, // _firstValidatorIsUnremovable
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
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false, // _firstValidatorIsUnremovable
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
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false, // _firstValidatorIsUnremovable
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.fulfilled;
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false, // _firstValidatorIsUnremovable
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
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false, // _firstValidatorIsUnremovable
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
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false, // _firstValidatorIsUnremovable
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
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false, // _firstValidatorIsUnremovable
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        120960 // _stakeWithdrawDisallowPeriod
      ).should.be.rejectedWith(ERROR_MSG);
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false, // _firstValidatorIsUnremovable
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.fulfilled;
    });
    it('should fail if the number of mining addresses is not the same as the number of staking ones', async () => {
      const initialStakingAddressesShort = accounts.slice(4, 5 + 1); // accounts[4...5]
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddressesShort, // _initialStakingAddresses
        false, // _firstValidatorIsUnremovable
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if the mining addresses are the same as the staking ones', async () => {
      const initialStakingAddressesShort = accounts.slice(4, 5 + 1); // accounts[4...5]
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialMiningAddresses
        initialValidators, // _initialStakingAddresses
        false, // _firstValidatorIsUnremovable
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if some mining address is 0', async () => {
      initialValidators[0] = '0x0000000000000000000000000000000000000000';
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false, // _firstValidatorIsUnremovable
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if some staking address is 0', async () => {
      initialStakingAddresses[0] = '0x0000000000000000000000000000000000000000';
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false, // _firstValidatorIsUnremovable
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.rejectedWith(ERROR_MSG);
    });
  });

  describe('newValidatorSet()', async () => {
    let initialValidators;
    let initialStakingAddresses;
    let blockRewardAuRa;

    beforeEach(async () => {
      initialValidators = accounts.slice(1, 3 + 1); // accounts[1...3]
      initialStakingAddresses = accounts.slice(4, 6 + 1); // accounts[4...6]
      blockRewardAuRa = accounts[4]; // emulate BlockRewardAuRa contract

      let randomAuRa = await RandomAuRa.new();
      randomAuRa = await EternalStorageProxy.new(randomAuRa.address, owner);
      randomAuRa = await ValidatorSetAuRa.at(randomAuRa.address);

      await validatorSetAuRa.setCurrentBlockNumber(0).should.be.fulfilled;
      await validatorSetAuRa.initialize(
        blockRewardAuRa, // _blockRewardContract
        randomAuRa.address, // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        false, // _firstValidatorIsUnremovable
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320 // _stakeWithdrawDisallowPeriod
      ).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120960).should.be.fulfilled;
    });
    it('can only be called by BlockReward contract', async () => {
      await validatorSetAuRa.newValidatorSet({from: owner}).should.be.rejectedWith(ERROR_MSG);
      await validatorSetAuRa.newValidatorSet({from: blockRewardAuRa}).should.be.fulfilled;
    });
    it('should only work at the latest block of current staking epoch', async () => {
      await validatorSetAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      (await validatorSetAuRa.stakingEpochEndBlock.call()).should.be.bignumber.equal(new BN(120960));
      await validatorSetAuRa.newValidatorSet({from: blockRewardAuRa}).should.be.fulfilled;
      (await validatorSetAuRa.stakingEpochStartBlock.call()).should.be.bignumber.equal(new BN(0));
      await validatorSetAuRa.setCurrentBlockNumber(120960).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: blockRewardAuRa}).should.be.fulfilled;
      (await validatorSetAuRa.stakingEpochStartBlock.call()).should.be.bignumber.equal(new BN(120961));
    });
    it('should increment the number of staking epoch', async () => {
      (await validatorSetAuRa.stakingEpoch.call()).should.be.bignumber.equal(new BN(0));
      await validatorSetAuRa.newValidatorSet({from: blockRewardAuRa}).should.be.fulfilled;
      (await validatorSetAuRa.stakingEpoch.call()).should.be.bignumber.equal(new BN(1));
    });
    it('should increment changeRequestCount', async () => {
      (await validatorSetAuRa.changeRequestCount.call()).should.be.bignumber.equal(new BN(0));
      await validatorSetAuRa.newValidatorSet({from: blockRewardAuRa}).should.be.fulfilled;
      (await validatorSetAuRa.changeRequestCount.call()).should.be.bignumber.equal(new BN(1));
    });
    it('should reset validatorSetApplyBlock', async () => {
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(1));
      await validatorSetAuRa.newValidatorSet({from: blockRewardAuRa}).should.be.fulfilled;
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
      await validatorSetAuRa.setCurrentBlockNumber(120960).should.be.fulfilled;
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(false);
      await validatorSetAuRa.newValidatorSet({from: blockRewardAuRa}).should.be.fulfilled;
      (await validatorSetAuRa.emitInitiateChangeCallable.call()).should.be.equal(true);

      // Emulate calling `emitInitiateChange()` at the beginning of the next staking epoch
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
      const stakeUnit = await validatorSetAuRa.STAKE_UNIT.call();
      const mintAmount = stakeUnit.mul(new BN(2));

      await validatorSetAuRa.setCurrentBlockNumber(10).should.be.fulfilled;

      // Deploy token contract and mint some tokens for the first initial validator
      const erc20Token = await ERC677BridgeTokenRewardable.new("POA20", "POA20", 18, {from: owner});
      await erc20Token.mint(initialStakingAddresses[0], mintAmount, {from: owner}).should.be.fulfilled;
      mintAmount.should.be.bignumber.equal(await erc20Token.balanceOf.call(initialStakingAddresses[0]));

      // Pass ValidatorSet contract address to ERC20 contract
      await erc20Token.setValidatorSetContract(validatorSetAuRa.address, {from: owner}).should.be.fulfilled;
      validatorSetAuRa.address.should.be.equal(await erc20Token.validatorSetContract.call());

      // Pass ERC20 contract address to ValidatorSet contract
      await validatorSetAuRa.setErc20TokenContract(erc20Token.address, {from: owner}).should.be.fulfilled;
      erc20Token.address.should.be.equal(await validatorSetAuRa.erc20TokenContract.call());

      // Emulate staking by the first validator into his own pool
      const stakeAmount = stakeUnit.mul(new BN(1));
      await validatorSetAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      await validatorSetAuRa.stake(initialStakingAddresses[0], stakeAmount, {from: initialStakingAddresses[0]}).should.be.fulfilled;
      stakeAmount.should.be.bignumber.equal(await validatorSetAuRa.stakeAmount.call(initialStakingAddresses[0], initialStakingAddresses[0]));

      // Emulate calling `newValidatorSet()` at the last block of staking epoch
      await validatorSetAuRa.setCurrentBlockNumber(120960).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: blockRewardAuRa}).should.be.fulfilled;

      // Check the returned value of `getPendingValidators()`
      (await validatorSetAuRa.getPendingValidators.call()).should.be.deep.equal([initialValidators[0]]);
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
});

function random(low, high) {
  return Math.floor(Math.random() * (high - low) + low);
}
