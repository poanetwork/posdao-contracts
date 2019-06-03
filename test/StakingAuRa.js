const BlockRewardAuRa = artifacts.require('BlockRewardAuRa');
const ERC677BridgeTokenRewardable = artifacts.require('ERC677BridgeTokenRewardableMock');
const EternalStorageProxy = artifacts.require('EternalStorageProxy');
const RandomAuRa = artifacts.require('RandomAuRa');
const ValidatorSetAuRa = artifacts.require('ValidatorSetAuRaMock');
const StakingAuRa = artifacts.require('StakingAuRaMock');

const ERROR_MSG = 'VM Exception while processing transaction: revert';
const BN = web3.utils.BN;

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bn')(BN))
  .should();

contract('StakingAuRa', async accounts => {
  let owner;
  let initialValidators;
  let initialStakingAddresses;
  let blockRewardAuRa;
  let randomAuRa;
  let stakingAuRa;
  let validatorSetAuRa;

  beforeEach(async () => {
    owner = accounts[0];
    initialValidators = accounts.slice(1, 3 + 1); // accounts[1...3]
    initialStakingAddresses = accounts.slice(4, 6 + 1); // accounts[4...6]
    initialStakingAddresses.length.should.be.equal(3);
    initialStakingAddresses[0].should.not.be.equal('0x0000000000000000000000000000000000000000');
    initialStakingAddresses[1].should.not.be.equal('0x0000000000000000000000000000000000000000');
    initialStakingAddresses[2].should.not.be.equal('0x0000000000000000000000000000000000000000');
    // Deploy BlockReward contract
    blockRewardAuRa = await BlockRewardAuRa.new();
    blockRewardAuRa = await EternalStorageProxy.new(blockRewardAuRa.address, owner);
    blockRewardAuRa = await BlockRewardAuRa.at(blockRewardAuRa.address);
    // Deploy Random contract
    randomAuRa = await RandomAuRa.new();
    randomAuRa = await EternalStorageProxy.new(randomAuRa.address, owner);
    randomAuRa = await RandomAuRa.at(randomAuRa.address);
    // Deploy Staking contract
    stakingAuRa = await StakingAuRa.new();
    stakingAuRa = await EternalStorageProxy.new(stakingAuRa.address, owner);
    stakingAuRa = await StakingAuRa.at(stakingAuRa.address);
    // Deploy ValidatorSet contract
    validatorSetAuRa = await ValidatorSetAuRa.new();
    validatorSetAuRa = await EternalStorageProxy.new(validatorSetAuRa.address, owner);
    validatorSetAuRa = await ValidatorSetAuRa.at(validatorSetAuRa.address);
    // Initialize ValidatorSet
    await validatorSetAuRa.initialize(
      blockRewardAuRa.address, // _blockRewardContract
      randomAuRa.address, // _randomContract
      stakingAuRa.address, // _stakingContract
      initialValidators, // _initialMiningAddresses
      initialStakingAddresses, // _initialStakingAddresses
      false // _firstValidatorIsUnremovable
    ).should.be.fulfilled;
  });

  describe('addPool()', async () => {
    let candidateMiningAddress;
    let candidateStakingAddress;
    let erc20Token;
    let stakeUnit;

    beforeEach(async () => {
      candidateMiningAddress = accounts[7];
      candidateStakingAddress = accounts[8];

      // Initialize Staking
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.fulfilled;

      // Deploy ERC20 contract
      erc20Token = await ERC677BridgeTokenRewardable.new("POSDAO20", "POSDAO20", 18, {from: owner});

      // Mint some balance for candidate (imagine that the candidate got 2 STAKE_UNITs from a bridge)
      stakeUnit = await stakingAuRa.STAKE_UNIT.call();
      const mintAmount = stakeUnit.mul(new BN(2));
      await erc20Token.mint(candidateStakingAddress, mintAmount, {from: owner}).should.be.fulfilled;
      mintAmount.should.be.bignumber.equal(await erc20Token.balanceOf.call(candidateStakingAddress));

      // Pass Staking contract address to ERC20 contract
      await erc20Token.setStakingContract(stakingAuRa.address, {from: owner}).should.be.fulfilled;
      stakingAuRa.address.should.be.equal(
        await erc20Token.stakingContract.call()
      );

      // Pass ERC20 contract address to Staking contract
      '0x0000000000000000000000000000000000000000'.should.be.equal(
        await stakingAuRa.erc20TokenContract.call()
      );
      await stakingAuRa.setErc20TokenContract(erc20Token.address, {from: owner}).should.be.fulfilled;
      erc20Token.address.should.be.equal(
        await stakingAuRa.erc20TokenContract.call()
      );

      // Emulate block number
      await stakingAuRa.setCurrentBlockNumber(2).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(2).should.be.fulfilled;
    });

    it('should create a new pool', async () => {
      false.should.be.equal(await stakingAuRa.isPoolActive.call(candidateStakingAddress));
      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.fulfilled;
      true.should.be.equal(await stakingAuRa.isPoolActive.call(candidateStakingAddress));
    });
    it('should fail if mining address is 0', async () => {
      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), '0x0000000000000000000000000000000000000000', {from: candidateStakingAddress}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.fulfilled;
    });
    it('should fail if mining address is equal to staking', async () => {
      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateStakingAddress, {from: candidateStakingAddress}).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if the pool with the same mining/staking address is already existed', async () => {
      const candidateMiningAddress2 = accounts[9];
      const candidateStakingAddress2 = accounts[10];
      
      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.fulfilled;
      
      await erc20Token.mint(candidateMiningAddress, stakeUnit.mul(new BN(2)), {from: owner}).should.be.fulfilled;
      await erc20Token.mint(candidateMiningAddress2, stakeUnit.mul(new BN(2)), {from: owner}).should.be.fulfilled;
      await erc20Token.mint(candidateStakingAddress2, stakeUnit.mul(new BN(2)), {from: owner}).should.be.fulfilled;

      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress2}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress2, {from: candidateStakingAddress}).should.be.rejectedWith(ERROR_MSG);
      
      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateStakingAddress, {from: candidateMiningAddress2}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateStakingAddress2, {from: candidateMiningAddress}).should.be.rejectedWith(ERROR_MSG);

      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateMiningAddress2}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress2, {from: candidateMiningAddress}).should.be.rejectedWith(ERROR_MSG);

      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateStakingAddress, {from: candidateStakingAddress2}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateStakingAddress2, {from: candidateStakingAddress}).should.be.rejectedWith(ERROR_MSG);
      
      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress2, {from: candidateStakingAddress2}).should.be.fulfilled;
    });
    it('should fail if gasPrice is 0', async () => {
      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress, gasPrice: 0}).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if ERC contract is not specified', async () => {
      // Set ERC20 contract address to zero
      await stakingAuRa.resetErc20TokenContract().should.be.fulfilled;

      // Try to add a new pool
      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.rejectedWith(ERROR_MSG);
      false.should.be.equal(await stakingAuRa.isPoolActive.call(candidateStakingAddress));

      // Pass ERC20 contract address to ValidatorSet contract
      await stakingAuRa.setErc20TokenContract(erc20Token.address, {from: owner}).should.be.fulfilled;

      // Add a new pool
      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.fulfilled;
      true.should.be.equal(await stakingAuRa.isPoolActive.call(candidateStakingAddress));
    });
    it('should fail if staking amount is 0', async () => {
      await stakingAuRa.addPool(new BN(0), candidateMiningAddress, {from: candidateStakingAddress}).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if block.number is inside disallowed range', async () => {
      await stakingAuRa.setCurrentBlockNumber(119960).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(119960).should.be.fulfilled;
      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.setCurrentBlockNumber(116560).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(116560).should.be.fulfilled;
      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.fulfilled;
    });
    it('should fail if staking amount is less than CANDIDATE_MIN_STAKE', async () => {
      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)).div(new BN(2)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.fulfilled;
    });
    it('should fail if candidate doesn\'t have enough funds', async () => {
      await stakingAuRa.addPool(stakeUnit.mul(new BN(3)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.addPool(stakeUnit.mul(new BN(2)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.fulfilled;
    });
    it('stake amount should be increased', async () => {
      const amount = stakeUnit.mul(new BN(2));
      await stakingAuRa.addPool(amount, candidateMiningAddress, {from: candidateStakingAddress}).should.be.fulfilled;
      amount.should.be.bignumber.equal(await stakingAuRa.stakeAmount.call(candidateStakingAddress, candidateStakingAddress));
      amount.should.be.bignumber.equal(await stakingAuRa.stakeAmountByCurrentEpoch.call(candidateStakingAddress, candidateStakingAddress));
      amount.should.be.bignumber.equal(await stakingAuRa.stakeAmountTotal.call(candidateStakingAddress));
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
      (await stakingAuRa.isPoolActive.call(candidate1StakingAddress)).should.be.equal(false);
      (await stakingAuRa.isPoolActive.call(candidate2StakingAddress)).should.be.equal(false);
      await stakingAuRa.addPool(amount1, candidate1MiningAddress, {from: candidate1StakingAddress}).should.be.fulfilled;
      await stakingAuRa.addPool(amount2, candidate2MiningAddress, {from: candidate2StakingAddress}).should.be.fulfilled;
      (await stakingAuRa.isPoolActive.call(candidate1StakingAddress)).should.be.equal(true);
      (await stakingAuRa.isPoolActive.call(candidate2StakingAddress)).should.be.equal(true);

      // Check indexes (0...2 are busy by initial validators)
      new BN(3).should.be.bignumber.equal(await stakingAuRa.poolIndex.call(candidate1StakingAddress));
      new BN(4).should.be.bignumber.equal(await stakingAuRa.poolIndex.call(candidate2StakingAddress));

      // Check indexes in the `poolsToBeElected` list
      new BN(0).should.be.bignumber.equal(await stakingAuRa.poolToBeElectedIndex.call(candidate1StakingAddress));
      new BN(1).should.be.bignumber.equal(await stakingAuRa.poolToBeElectedIndex.call(candidate2StakingAddress));

      // Check pools' existence
      const validators = await validatorSetAuRa.getValidators.call();

      (await stakingAuRa.getPools.call()).should.be.deep.equal([
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
        await stakingAuRa.addPoolActiveMock(candidateStakingAddress).should.be.fulfilled;
        new BN(p).should.be.bignumber.equal(await stakingAuRa.poolIndex.call(candidateStakingAddress));
      }

      // Try to add a new pool outside of max limit
      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.rejectedWith(ERROR_MSG);
      false.should.be.equal(await stakingAuRa.isPoolActive.call(candidateStakingAddress));
    });
    it('should remove added pool from the list of inactive pools', async () => {
      await stakingAuRa.addPoolInactiveMock(candidateStakingAddress).should.be.fulfilled;
      (await stakingAuRa.getPoolsInactive.call()).should.be.deep.equal([candidateStakingAddress]);
      await stakingAuRa.addPool(stakeUnit.mul(new BN(1)), candidateMiningAddress, {from: candidateStakingAddress}).should.be.fulfilled;
      true.should.be.equal(await stakingAuRa.isPoolActive.call(candidateStakingAddress));
      (await stakingAuRa.getPoolsInactive.call()).length.should.be.equal(0);
    });
  });

  describe('clearUnremovableValidator()', async () => {
    beforeEach(async () => {
      // Deploy ValidatorSet contract
      validatorSetAuRa = await ValidatorSetAuRa.new();
      validatorSetAuRa = await EternalStorageProxy.new(validatorSetAuRa.address, owner);
      validatorSetAuRa = await ValidatorSetAuRa.at(validatorSetAuRa.address);

      // Initialize ValidatorSet
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        true // _firstValidatorIsUnremovable
      ).should.be.fulfilled;

      // Initialize Staking
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.fulfilled;
    });

    it('should add validator pool to the poolsToBeElected list', async () => {
      // Deploy ERC20 contract
      const erc20Token = await ERC677BridgeTokenRewardable.new("POSDAO20", "POSDAO20", 18, {from: owner});

      // Mint some balance for the non-removable validator (imagine that the validator got 2 STAKE_UNITs from a bridge)
      const stakeUnit = await stakingAuRa.STAKE_UNIT.call();
      const mintAmount = stakeUnit.mul(new BN(2));
      await erc20Token.mint(initialStakingAddresses[0], mintAmount, {from: owner}).should.be.fulfilled;
      mintAmount.should.be.bignumber.equal(await erc20Token.balanceOf.call(initialStakingAddresses[0]));

      // Pass Staking contract address to ERC20 contract
      await erc20Token.setStakingContract(stakingAuRa.address, {from: owner}).should.be.fulfilled;
      stakingAuRa.address.should.be.equal(await erc20Token.stakingContract.call());

      // Pass ERC20 contract address to Staking contract
      await stakingAuRa.setErc20TokenContract(erc20Token.address, {from: owner}).should.be.fulfilled;
      erc20Token.address.should.be.equal(await stakingAuRa.erc20TokenContract.call());

      // Emulate block number
      await stakingAuRa.setCurrentBlockNumber(100).should.be.fulfilled;

      // Place a stake for itself
      await stakingAuRa.stake(initialStakingAddresses[0], stakeUnit.mul(new BN(1)), {from: initialStakingAddresses[0]}).should.be.fulfilled;

      (await stakingAuRa.getPoolsToBeElected.call()).length.should.be.equal(0);

      await stakingAuRa.setValidatorSetAddress(accounts[7]).should.be.fulfilled;
      await stakingAuRa.clearUnremovableValidator(initialStakingAddresses[0], {from: accounts[7]}).should.be.fulfilled;

      (await stakingAuRa.getPoolsToBeElected.call()).should.be.deep.equal([
        initialStakingAddresses[0]
      ]);

      const likelihoodInfo = await stakingAuRa.getPoolsLikelihood.call();
      likelihoodInfo.likelihoods[0].should.be.bignumber.equal(new BN(100));
      likelihoodInfo.sum.should.be.bignumber.equal(new BN(100));
    });
    it('should add validator pool to the poolsToBeRemoved list', async () => {
      await stakingAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      (await stakingAuRa.getPoolsToBeRemoved.call()).should.be.deep.equal([
        initialStakingAddresses[1],
        initialStakingAddresses[2]
      ]);
      await stakingAuRa.setValidatorSetAddress(accounts[7]).should.be.fulfilled;
      await stakingAuRa.clearUnremovableValidator(initialStakingAddresses[0], {from: accounts[7]}).should.be.fulfilled;
      (await stakingAuRa.getPoolsToBeRemoved.call()).should.be.deep.equal([
        initialStakingAddresses[1],
        initialStakingAddresses[2],
        initialStakingAddresses[0]
      ]);
    });
    it('can only be called by the ValidatorSet contract', async () => {
      await stakingAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      await stakingAuRa.setValidatorSetAddress(accounts[7]).should.be.fulfilled;
      await stakingAuRa.clearUnremovableValidator(initialStakingAddresses[0], {from: accounts[8]}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.clearUnremovableValidator(initialStakingAddresses[0], {from: accounts[7]}).should.be.fulfilled;
    });
    it('non-removable validator address cannot be zero', async () => {
      await stakingAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      await stakingAuRa.setValidatorSetAddress(accounts[7]).should.be.fulfilled;
      await stakingAuRa.clearUnremovableValidator('0x0000000000000000000000000000000000000000', {from: accounts[7]}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.clearUnremovableValidator(initialStakingAddresses[0], {from: accounts[7]}).should.be.fulfilled;
    });
  });

  describe('incrementStakingEpoch()', async () => {
    it('should increment', async () => {
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(new BN(0));
      await stakingAuRa.setValidatorSetAddress(accounts[7]).should.be.fulfilled;
      await stakingAuRa.incrementStakingEpoch({from: accounts[7]}).should.be.fulfilled;
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(new BN(1));
    });
    it('can only be called by ValidatorSet contract', async () => {
      await stakingAuRa.setValidatorSetAddress(accounts[7]).should.be.fulfilled;
      await stakingAuRa.incrementStakingEpoch({from: accounts[8]}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.incrementStakingEpoch({from: accounts[7]}).should.be.fulfilled;
    });
  });

  describe('initialize()', async () => {
    beforeEach(async () => {
      await stakingAuRa.setCurrentBlockNumber(0);
    });
    it('should initialize successfully', async () => {
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.fulfilled;
      new BN(120960).should.be.bignumber.equal(
        await stakingAuRa.stakingEpochDuration.call()
      );
      new BN(4320).should.be.bignumber.equal(
        await stakingAuRa.stakeWithdrawDisallowPeriod.call()
      );
      new BN(0).should.be.bignumber.equal(
        await stakingAuRa.stakingEpochStartBlock.call()
      );
      validatorSetAuRa.address.should.be.equal(
        await stakingAuRa.validatorSetContract.call()
      );
      '0x0000000000000000000000000000000000000000'.should.be.equal(
        await stakingAuRa.erc20TokenContract.call()
      );
      for (let i = 0; i < initialStakingAddresses.length; i++) {
        new BN(i).should.be.bignumber.equal(
          await stakingAuRa.poolIndex.call(initialStakingAddresses[i])
        );
        true.should.be.equal(
          await stakingAuRa.isPoolActive.call(initialStakingAddresses[i])
        );
        new BN(i).should.be.bignumber.equal(
          await stakingAuRa.poolToBeRemovedIndex.call(initialStakingAddresses[i])
        );
      }
      (await stakingAuRa.getPools.call()).should.be.deep.equal(initialStakingAddresses);
      new BN(web3.utils.toWei('1', 'ether')).should.be.bignumber.equal(
        await stakingAuRa.getDelegatorMinStake.call()
      );
      new BN(web3.utils.toWei('1', 'ether')).should.be.bignumber.equal(
        await stakingAuRa.getCandidateMinStake.call()
      );
    });
    it('should fail if the current block number is not zero', async () => {
      await stakingAuRa.setCurrentBlockNumber(1);
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if ValidatorSet contract address is zero', async () => {
      await stakingAuRa.initialize(
        '0x0000000000000000000000000000000000000000', // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if delegatorMinStake is zero', async () => {
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        0, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if candidateMinStake is zero', async () => {
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        0, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if already initialized', async () => {
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.fulfilled;
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if stakingEpochDuration is 0', async () => {
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        0, // _stakingEpochDuration
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if stakeWithdrawDisallowPeriod is 0', async () => {
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        0, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if stakeWithdrawDisallowPeriod >= stakingEpochDuration', async () => {
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        120960, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.fulfilled;
    });
    it('should fail if some staking address is 0', async () => {
      initialStakingAddresses[0] = '0x0000000000000000000000000000000000000000';
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.rejectedWith(ERROR_MSG);
    });
  });

  describe('moveStake()', async () => {
    let delegatorAddress;
    let erc20Token;
    let mintAmount;
    let stakeUnit;

    beforeEach(async () => {
      delegatorAddress = accounts[7];

      // Initialize Staking
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.fulfilled;

      // Deploy ERC20 contract
      erc20Token = await ERC677BridgeTokenRewardable.new("POSDAO20", "POSDAO20", 18, {from: owner});

      // Mint some balance for delegator and candidates (imagine that they got some STAKE_UNITs from a bridge)
      stakeUnit = await stakingAuRa.STAKE_UNIT.call();
      mintAmount = stakeUnit.mul(new BN(2));
      await erc20Token.mint(initialStakingAddresses[0], mintAmount, {from: owner}).should.be.fulfilled;
      await erc20Token.mint(initialStakingAddresses[1], mintAmount, {from: owner}).should.be.fulfilled;
      await erc20Token.mint(delegatorAddress, mintAmount, {from: owner}).should.be.fulfilled;
      mintAmount.should.be.bignumber.equal(await erc20Token.balanceOf.call(initialStakingAddresses[0]));
      mintAmount.should.be.bignumber.equal(await erc20Token.balanceOf.call(initialStakingAddresses[1]));
      mintAmount.should.be.bignumber.equal(await erc20Token.balanceOf.call(delegatorAddress));

      // Pass Staking contract address to ERC20 contract
      await erc20Token.setStakingContract(stakingAuRa.address, {from: owner}).should.be.fulfilled;
      stakingAuRa.address.should.be.equal(await erc20Token.stakingContract.call());

      // Pass ERC20 contract address to Staking contract
      '0x0000000000000000000000000000000000000000'.should.be.equal(
        await stakingAuRa.erc20TokenContract.call()
      );
      await stakingAuRa.setErc20TokenContract(erc20Token.address, {from: owner}).should.be.fulfilled;
      erc20Token.address.should.be.equal(await stakingAuRa.erc20TokenContract.call());

      // Place stakes
      await stakingAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[0], mintAmount, {from: initialStakingAddresses[0]}).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[0], mintAmount, {from: delegatorAddress}).should.be.fulfilled;
    });

    it('should move entire stake', async () => {
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[0], delegatorAddress)).should.be.bignumber.equal(mintAmount);
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(new BN(0));
      await stakingAuRa.moveStake(initialStakingAddresses[0], initialStakingAddresses[1], mintAmount, {from: delegatorAddress}).should.be.fulfilled;
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[0], delegatorAddress)).should.be.bignumber.equal(new BN(0));
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(mintAmount);
    });
    it('should move part of the stake', async () => {
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[0], delegatorAddress)).should.be.bignumber.equal(mintAmount);
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(new BN(0));
      await stakingAuRa.moveStake(initialStakingAddresses[0], initialStakingAddresses[1], stakeUnit, {from: delegatorAddress}).should.be.fulfilled;
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[0], delegatorAddress)).should.be.bignumber.equal(stakeUnit);
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(stakeUnit);
    });
    it('should fail for zero gas price', async () => {
      await stakingAuRa.moveStake(initialStakingAddresses[0], initialStakingAddresses[1], mintAmount, {from: delegatorAddress, gasPrice: 0}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.moveStake(initialStakingAddresses[0], initialStakingAddresses[1], mintAmount, {from: delegatorAddress}).should.be.fulfilled;
    });
    it('should fail if the source and destination addresses are the same', async () => {
      await stakingAuRa.moveStake(initialStakingAddresses[0], initialStakingAddresses[0], mintAmount, {from: delegatorAddress}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.moveStake(initialStakingAddresses[0], initialStakingAddresses[1], mintAmount, {from: delegatorAddress}).should.be.fulfilled;
    });
    it('should fail if the staker tries to move more than they have', async () => {
      await stakingAuRa.moveStake(initialStakingAddresses[0], initialStakingAddresses[1], mintAmount.mul(new BN(2)), {from: delegatorAddress}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.moveStake(initialStakingAddresses[0], initialStakingAddresses[1], mintAmount, {from: delegatorAddress}).should.be.fulfilled;
    });
  });

  describe('stake()', async () => {
    let delegatorAddress;
    let erc20Token;
    let mintAmount;
    let candidateMinStake;
    let delegatorMinStake;

    beforeEach(async () => {
      delegatorAddress = accounts[7];

      // Initialize Staking
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.fulfilled;

      candidateMinStake = await stakingAuRa.getCandidateMinStake.call();
      delegatorMinStake = await stakingAuRa.getDelegatorMinStake.call();

      // Deploy ERC20 contract
      erc20Token = await ERC677BridgeTokenRewardable.new("POSDAO20", "POSDAO20", 18, {from: owner});

      // Mint some balance for delegator and candidates (imagine that they got some STAKE_UNITs from a bridge)
      const stakeUnit = await stakingAuRa.STAKE_UNIT.call();
      mintAmount = stakeUnit.mul(new BN(2));
      await erc20Token.mint(initialStakingAddresses[1], mintAmount, {from: owner}).should.be.fulfilled;
      await erc20Token.mint(delegatorAddress, mintAmount, {from: owner}).should.be.fulfilled;
      mintAmount.should.be.bignumber.equal(await erc20Token.balanceOf.call(initialStakingAddresses[1]));
      mintAmount.should.be.bignumber.equal(await erc20Token.balanceOf.call(delegatorAddress));

      // Pass Staking contract address to ERC20 contract
      await erc20Token.setStakingContract(stakingAuRa.address, {from: owner}).should.be.fulfilled;
      stakingAuRa.address.should.be.equal(await erc20Token.stakingContract.call());

      // Pass ERC20 contract address to Staking contract
      '0x0000000000000000000000000000000000000000'.should.be.equal(
        await stakingAuRa.erc20TokenContract.call()
      );
      await stakingAuRa.setErc20TokenContract(erc20Token.address, {from: owner}).should.be.fulfilled;
      erc20Token.address.should.be.equal(await stakingAuRa.erc20TokenContract.call());

      await stakingAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
    });

    it('should place a stake', async () => {
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], initialStakingAddresses[1])).should.be.bignumber.equal(new BN(0));
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(new BN(0));
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], initialStakingAddresses[1])).should.be.bignumber.equal(mintAmount);
      const result = await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: delegatorAddress}).should.be.fulfilled;
      result.logs[0].event.should.be.equal("Staked");
      result.logs[0].args.toPoolStakingAddress.should.be.equal(initialStakingAddresses[1]);
      result.logs[0].args.staker.should.be.equal(delegatorAddress);
      result.logs[0].args.stakingEpoch.should.be.bignumber.equal(new BN(0));
      result.logs[0].args.amount.should.be.bignumber.equal(mintAmount);
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(mintAmount);
      (await stakingAuRa.stakeAmountTotal.call(initialStakingAddresses[1])).should.be.bignumber.equal(mintAmount.mul(new BN(2)));
    });
    it('should fail for zero gas price', async () => {
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1], gasPrice: 0}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
    });
    it('should fail if erc20TokenContract address is not defined', async () => {
      await stakingAuRa.resetErc20TokenContract().should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.setErc20TokenContract(erc20Token.address, {from: owner}).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
    });
    it('should fail for a non-existing pool', async () => {
      await stakingAuRa.stake(accounts[10], mintAmount, {from: delegatorAddress}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.stake('0x0000000000000000000000000000000000000000', mintAmount, {from: delegatorAddress}).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail for a zero amount', async () => {
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[1], new BN(0), {from: delegatorAddress}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: delegatorAddress}).should.be.fulfilled;
    });
    it('should fail for a banned validator', async () => {
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      await validatorSetAuRa.setRandomContract(accounts[8]).should.be.fulfilled;
      await validatorSetAuRa.removeMaliciousValidator(initialValidators[1], {from: accounts[8]}).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: delegatorAddress}).should.be.rejectedWith(ERROR_MSG);
    });
    it('should only success in the allowed staking window', async () => {
      await stakingAuRa.setCurrentBlockNumber(117000).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
    });
    it('should fail if a candidate stakes less than CANDIDATE_MIN_STAKE', async () => {
      const halfOfCandidateMinStake = candidateMinStake.div(new BN(2));
      await stakingAuRa.stake(initialStakingAddresses[1], halfOfCandidateMinStake, {from: initialStakingAddresses[1]}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.stake(initialStakingAddresses[1], candidateMinStake, {from: initialStakingAddresses[1]}).should.be.fulfilled;
    });
    it('should fail if a delegator stakes less than DELEGATOR_MIN_STAKE', async () => {
      await stakingAuRa.stake(initialStakingAddresses[1], candidateMinStake, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      const halfOfDelegatorMinStake = delegatorMinStake.div(new BN(2));
      await stakingAuRa.stake(initialStakingAddresses[1], halfOfDelegatorMinStake, {from: delegatorAddress}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.stake(initialStakingAddresses[1], delegatorMinStake, {from: delegatorAddress}).should.be.fulfilled;
    });
    it('should fail if a delegator stakes into an empty pool', async () => {
      (await stakingAuRa.stakeAmountMinusOrderedWithdraw.call(initialStakingAddresses[1], initialStakingAddresses[1])).should.be.bignumber.equal(new BN(0));
      await stakingAuRa.stake(initialStakingAddresses[1], delegatorMinStake, {from: delegatorAddress}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.stake(initialStakingAddresses[1], candidateMinStake, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[1], delegatorMinStake, {from: delegatorAddress}).should.be.fulfilled;
    });
    it('should increase a stake amount', async () => {
      await stakingAuRa.stake(initialStakingAddresses[1], candidateMinStake, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(new BN(0));
      await stakingAuRa.stake(initialStakingAddresses[1], delegatorMinStake, {from: delegatorAddress}).should.be.fulfilled;
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(delegatorMinStake);
      await stakingAuRa.stake(initialStakingAddresses[1], delegatorMinStake, {from: delegatorAddress}).should.be.fulfilled;
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(delegatorMinStake.mul(new BN(2)));
    });
    it('should increase the stakeAmountByCurrentEpoch', async () => {
      await stakingAuRa.stake(initialStakingAddresses[1], candidateMinStake, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      (await stakingAuRa.stakeAmountByCurrentEpoch.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(new BN(0));
      await stakingAuRa.stake(initialStakingAddresses[1], delegatorMinStake, {from: delegatorAddress}).should.be.fulfilled;
      (await stakingAuRa.stakeAmountByCurrentEpoch.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(delegatorMinStake);
      await stakingAuRa.stake(initialStakingAddresses[1], delegatorMinStake, {from: delegatorAddress}).should.be.fulfilled;
      (await stakingAuRa.stakeAmountByCurrentEpoch.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(delegatorMinStake.mul(new BN(2)));
    });
    it('should increase a total stake amount', async () => {
      await stakingAuRa.stake(initialStakingAddresses[1], candidateMinStake, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      (await stakingAuRa.stakeAmountTotal.call(initialStakingAddresses[1])).should.be.bignumber.equal(candidateMinStake);
      await stakingAuRa.stake(initialStakingAddresses[1], delegatorMinStake, {from: delegatorAddress}).should.be.fulfilled;
      (await stakingAuRa.stakeAmountTotal.call(initialStakingAddresses[1])).should.be.bignumber.equal(candidateMinStake.add(delegatorMinStake));
      await stakingAuRa.stake(initialStakingAddresses[1], delegatorMinStake, {from: delegatorAddress}).should.be.fulfilled;
      (await stakingAuRa.stakeAmountTotal.call(initialStakingAddresses[1])).should.be.bignumber.equal(candidateMinStake.add(delegatorMinStake.mul(new BN(2))));
    });
    it('should add a delegator to the pool', async () => {
      await stakingAuRa.stake(initialStakingAddresses[1], candidateMinStake, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      (await stakingAuRa.poolDelegators.call(initialStakingAddresses[1])).length.should.be.equal(0);
      await stakingAuRa.stake(initialStakingAddresses[1], delegatorMinStake, {from: delegatorAddress}).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[1], delegatorMinStake, {from: delegatorAddress}).should.be.fulfilled;
      (await stakingAuRa.poolDelegators.call(initialStakingAddresses[1])).should.be.deep.equal([delegatorAddress]);
    });
    it('should update pool\'s likelihood', async () => {
      let likelihoodInfo = await stakingAuRa.getPoolsLikelihood.call();
      likelihoodInfo.likelihoods.length.should.be.equal(0);
      likelihoodInfo.sum.should.be.bignumber.equal(new BN(0));
      await stakingAuRa.stake(initialStakingAddresses[1], candidateMinStake, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      likelihoodInfo = await stakingAuRa.getPoolsLikelihood.call();
      likelihoodInfo.likelihoods[0].should.be.bignumber.equal(new BN(100));
      likelihoodInfo.sum.should.be.bignumber.equal(new BN(100));
      await stakingAuRa.stake(initialStakingAddresses[1], delegatorMinStake, {from: delegatorAddress}).should.be.fulfilled;
      likelihoodInfo = await stakingAuRa.getPoolsLikelihood.call();
      likelihoodInfo.likelihoods[0].should.be.bignumber.equal(new BN(200));
      likelihoodInfo.sum.should.be.bignumber.equal(new BN(200));
      await stakingAuRa.stake(initialStakingAddresses[1], delegatorMinStake, {from: delegatorAddress}).should.be.fulfilled;
      likelihoodInfo = await stakingAuRa.getPoolsLikelihood.call();
      likelihoodInfo.likelihoods[0].should.be.bignumber.equal(new BN(300));
      likelihoodInfo.sum.should.be.bignumber.equal(new BN(300));
    });
    it('should fail if the staker stakes more than they have', async () => {
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount.mul(new BN(2)), {from: initialStakingAddresses[1]}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.stake(initialStakingAddresses[1], candidateMinStake, {from: initialStakingAddresses[1]}).should.be.fulfilled;
    });
    it('should decrease the balance of the staker and increase the balance of the Staking contract', async () => {
      (await erc20Token.balanceOf.call(stakingAuRa.address)).should.be.bignumber.equal(new BN(0));
      await stakingAuRa.stake(initialStakingAddresses[1], candidateMinStake, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      (await erc20Token.balanceOf.call(initialStakingAddresses[1])).should.be.bignumber.equal(mintAmount.sub(candidateMinStake));
      (await erc20Token.balanceOf.call(stakingAuRa.address)).should.be.bignumber.equal(candidateMinStake);
    });
  });

  describe('removePool()', async () => {
    beforeEach(async () => {
      // Initialize Staking
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.fulfilled;
      await stakingAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
    });

    it('should remove a pool', async () => {
      (await stakingAuRa.getPools.call()).should.be.deep.equal(initialStakingAddresses);
      await stakingAuRa.setValidatorSetAddress(accounts[7]).should.be.fulfilled;
      await stakingAuRa.removePool(initialStakingAddresses[0], {from: accounts[7]}).should.be.fulfilled;
      (await stakingAuRa.getPools.call()).should.be.deep.equal([
        initialStakingAddresses[2],
        initialStakingAddresses[1]
      ]);
      (await stakingAuRa.getPoolsInactive.call()).length.should.be.equal(0);
    });
    it('can only be called by the ValidatorSetAuRa contract', async () => {
      await stakingAuRa.setValidatorSetAddress(accounts[7]).should.be.fulfilled;
      await stakingAuRa.removePool(initialStakingAddresses[0], {from: accounts[8]}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.removePool(initialStakingAddresses[0], {from: accounts[7]}).should.be.fulfilled;
    });
    it('shouldn\'t remove a nonexistent pool', async () => {
      (await stakingAuRa.getPools.call()).should.be.deep.equal(initialStakingAddresses);
      await stakingAuRa.setValidatorSetAddress(accounts[7]).should.be.fulfilled;
      await stakingAuRa.removePool(accounts[10], {from: accounts[7]}).should.be.fulfilled;
      (await stakingAuRa.getPools.call()).should.be.deep.equal(initialStakingAddresses);
    });
    it('should reset pool index', async () => {
      (await stakingAuRa.poolIndex.call(initialStakingAddresses[1])).should.be.bignumber.equal(new BN(1));
      await stakingAuRa.setValidatorSetAddress(accounts[7]).should.be.fulfilled;
      await stakingAuRa.removePool(initialStakingAddresses[1], {from: accounts[7]}).should.be.fulfilled;
      (await stakingAuRa.poolIndex.call(initialStakingAddresses[1])).should.be.bignumber.equal(new BN(0));
    });
    it('should add/remove a pool to/from the utility lists', async () => {
      // Deploy ERC20 contract
      const erc20Token = await ERC677BridgeTokenRewardable.new("POSDAO20", "POSDAO20", 18, {from: owner});

      // Mint some balance for candidate (imagine that the candidate got 2 STAKE_UNITs from a bridge)
      const stakeUnit = await stakingAuRa.STAKE_UNIT.call();
      const mintAmount = stakeUnit.mul(new BN(2));
      await erc20Token.mint(initialStakingAddresses[0], mintAmount, {from: owner}).should.be.fulfilled;
      mintAmount.should.be.bignumber.equal(await erc20Token.balanceOf.call(initialStakingAddresses[0]));

      // Pass Staking contract address to ERC20 contract
      await erc20Token.setStakingContract(stakingAuRa.address, {from: owner}).should.be.fulfilled;
      stakingAuRa.address.should.be.equal(await erc20Token.stakingContract.call());

      // Pass ERC20 contract address to Staking contract
      '0x0000000000000000000000000000000000000000'.should.be.equal(
        await stakingAuRa.erc20TokenContract.call()
      );
      await stakingAuRa.setErc20TokenContract(erc20Token.address, {from: owner}).should.be.fulfilled;
      erc20Token.address.should.be.equal(await stakingAuRa.erc20TokenContract.call());

      // The first validator places stake for themselves
      (await stakingAuRa.getPoolsToBeElected.call()).length.should.be.deep.equal(0);
      (await stakingAuRa.getPoolsToBeRemoved.call()).should.be.deep.equal(initialStakingAddresses);
      await stakingAuRa.stake(initialStakingAddresses[0], stakeUnit.mul(new BN(1)), {from: initialStakingAddresses[0]}).should.be.fulfilled;
      (await stakingAuRa.stakeAmountTotal.call(initialStakingAddresses[0])).should.be.bignumber.equal(stakeUnit);
      (await stakingAuRa.getPoolsToBeElected.call()).should.be.deep.equal([initialStakingAddresses[0]]);
      (await stakingAuRa.getPoolsToBeRemoved.call()).should.be.deep.equal([
        initialStakingAddresses[2],
        initialStakingAddresses[1]
      ]);

      // Remove the pool
      await stakingAuRa.setValidatorSetAddress(accounts[7]).should.be.fulfilled;
      (await stakingAuRa.poolInactiveIndex.call(initialStakingAddresses[0])).should.be.bignumber.equal(new BN(0));
      await stakingAuRa.removePool(initialStakingAddresses[0], {from: accounts[7]}).should.be.fulfilled;
      await stakingAuRa.removePool(initialStakingAddresses[0], {from: accounts[7]}).should.be.fulfilled;
      (await stakingAuRa.getPoolsInactive.call()).should.be.deep.equal([initialStakingAddresses[0]]);
      (await stakingAuRa.poolInactiveIndex.call(initialStakingAddresses[0])).should.be.bignumber.equal(new BN(0));

      await stakingAuRa.setStakeAmountTotal(initialStakingAddresses[0], 0);
      await stakingAuRa.removePool(initialStakingAddresses[0], {from: accounts[7]}).should.be.fulfilled;
      (await stakingAuRa.getPoolsInactive.call()).length.should.be.equal(0);
      (await stakingAuRa.getPoolsToBeElected.call()).length.should.be.deep.equal(0);

      (await stakingAuRa.poolToBeRemovedIndex.call(initialStakingAddresses[1])).should.be.bignumber.equal(new BN(1));
      await stakingAuRa.removePool(initialStakingAddresses[1], {from: accounts[7]}).should.be.fulfilled;
      (await stakingAuRa.getPoolsToBeRemoved.call()).should.be.deep.equal([initialStakingAddresses[2]]);
      (await stakingAuRa.poolToBeRemovedIndex.call(initialStakingAddresses[1])).should.be.bignumber.equal(new BN(0));
    });
    it('should fail for zero gas price', async () => {
      await stakingAuRa.setValidatorSetAddress(accounts[7]).should.be.fulfilled;
      await stakingAuRa.incrementStakingEpoch({from: accounts[7]}).should.be.fulfilled;
      await stakingAuRa.setValidatorSetAddress(validatorSetAuRa.address).should.be.fulfilled;
      await stakingAuRa.removeMyPool({from: initialStakingAddresses[0], gasPrice: 0}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.removeMyPool({from: initialStakingAddresses[0]}).should.be.fulfilled;
    });
    it('should fail for initial validator during the initial staking epoch', async () => {
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(new BN(0));
      (await validatorSetAuRa.isValidator.call(initialValidators[0])).should.be.equal(true);
      (await validatorSetAuRa.miningByStakingAddress.call(initialStakingAddresses[0])).should.be.equal(initialValidators[0]);
      await stakingAuRa.removeMyPool({from: initialStakingAddresses[0]}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.setValidatorSetAddress(accounts[7]).should.be.fulfilled;
      await stakingAuRa.incrementStakingEpoch({from: accounts[7]}).should.be.fulfilled;
      await stakingAuRa.setValidatorSetAddress(validatorSetAuRa.address).should.be.fulfilled;
      await stakingAuRa.removeMyPool({from: initialStakingAddresses[0]}).should.be.fulfilled
    });
    it('should fail for a non-removable validator', async () => {
      // Deploy Staking contract
      stakingAuRa = await StakingAuRa.new();
      stakingAuRa = await EternalStorageProxy.new(stakingAuRa.address, owner);
      stakingAuRa = await StakingAuRa.at(stakingAuRa.address);

      // Deploy ValidatorSet contract
      validatorSetAuRa = await ValidatorSetAuRa.new();
      validatorSetAuRa = await EternalStorageProxy.new(validatorSetAuRa.address, owner);
      validatorSetAuRa = await ValidatorSetAuRa.at(validatorSetAuRa.address);

      // Initialize ValidatorSet
      await validatorSetAuRa.initialize(
        blockRewardAuRa.address, // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        stakingAuRa.address, // _stakingContract
        initialValidators, // _initialMiningAddresses
        initialStakingAddresses, // _initialStakingAddresses
        true // _firstValidatorIsUnremovable
      ).should.be.fulfilled;

      // Initialize Staking
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120960, // _stakingEpochDuration
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.fulfilled;

      await stakingAuRa.setCurrentBlockNumber(100).should.be.fulfilled;

      (await stakingAuRa.getPools.call()).should.be.deep.equal(initialStakingAddresses);
      await stakingAuRa.setValidatorSetAddress(accounts[7]).should.be.fulfilled;
      await stakingAuRa.incrementStakingEpoch({from: accounts[7]}).should.be.fulfilled;
      await stakingAuRa.setValidatorSetAddress(validatorSetAuRa.address).should.be.fulfilled;
      await stakingAuRa.removeMyPool({from: initialStakingAddresses[0]}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.removeMyPool({from: initialStakingAddresses[1]}).should.be.fulfilled;
      (await stakingAuRa.getPools.call()).should.be.deep.equal([
        initialStakingAddresses[0],
        initialStakingAddresses[2]
      ]);
    });
  });

  // TODO: ...add other tests...
});

function random(low, high) {
  return Math.floor(Math.random() * (high - low) + low);
}
