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
    blockRewardAuRa = await AdminUpgradeabilityProxy.new(blockRewardAuRa.address, owner, []);
    blockRewardAuRa = await BlockRewardAuRa.at(blockRewardAuRa.address);
    // Deploy Random contract
    randomAuRa = await RandomAuRa.new();
    randomAuRa = await AdminUpgradeabilityProxy.new(randomAuRa.address, owner, []);
    randomAuRa = await RandomAuRa.at(randomAuRa.address);
    // Deploy Staking contract
    stakingAuRa = await StakingAuRa.new();
    stakingAuRa = await AdminUpgradeabilityProxy.new(stakingAuRa.address, owner, []);
    stakingAuRa = await StakingAuRa.at(stakingAuRa.address);
    // Deploy ValidatorSet contract
    validatorSetAuRa = await ValidatorSetAuRa.new();
    validatorSetAuRa = await AdminUpgradeabilityProxy.new(validatorSetAuRa.address, owner, []);
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
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
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
      await stakingAuRa.setErc20TokenContractMock('0x0000000000000000000000000000000000000000').should.be.fulfilled;

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

  describe('balance', async () => {
    let erc20Token;
    let mintAmount;

    beforeEach(async () => {
      // Deploy ERC20 contract
      erc20Token = await ERC677BridgeTokenRewardable.new("POSDAO20", "POSDAO20", 18, {from: owner});

      // Mint some balance for an arbitrary address
      const stakeUnit = await stakingAuRa.STAKE_UNIT.call();
      mintAmount = stakeUnit.mul(new BN(2));
      await erc20Token.mint(accounts[10], mintAmount, {from: owner}).should.be.fulfilled;
      mintAmount.should.be.bignumber.equal(await erc20Token.balanceOf.call(accounts[10]));

      // Pass Staking contract address to ERC20 contract
      await erc20Token.setStakingContract(stakingAuRa.address, {from: owner}).should.be.fulfilled;
      stakingAuRa.address.should.be.equal(
        await erc20Token.stakingContract.call()
      );
    });

    it('cannot be increased by token.transfer function', async () => {
      await erc20Token.transfer(stakingAuRa.address, mintAmount, {from: accounts[10]}).should.be.rejectedWith(ERROR_MSG);
      await erc20Token.transfer(accounts[11], mintAmount, {from: accounts[10]}).should.be.fulfilled;
    });
    it('cannot be increased by token.transferFrom function', async () => {
      await erc20Token.approve(accounts[9], mintAmount, {from: accounts[10]}).should.be.fulfilled;
      await erc20Token.transferFrom(accounts[10], stakingAuRa.address, mintAmount, {from: accounts[9]}).should.be.rejectedWith(ERROR_MSG);
      await erc20Token.transferFrom(accounts[10], accounts[11], mintAmount, {from: accounts[9]}).should.be.fulfilled;
    });
    it('cannot be increased by token.transferAndCall function', async () => {
      await erc20Token.transferAndCall(stakingAuRa.address, mintAmount, [], {from: accounts[10]}).should.be.rejectedWith(ERROR_MSG);
      await erc20Token.transferAndCall(accounts[11], mintAmount, [], {from: accounts[10]}).should.be.fulfilled;
    });
    it('cannot be increased by sending native coins', async () => {
      await web3.eth.sendTransaction({from: owner, to: stakingAuRa.address, value: 1}).should.be.rejectedWith(ERROR_MSG);
      await web3.eth.sendTransaction({from: owner, to: accounts[1], value: 1}).should.be.fulfilled;
    });
  });

  describe('claimReward()', async () => {
    let delegator;
    let erc20Token;

    beforeEach(async () => {
      // Initialize BlockRewardAuRa
      await blockRewardAuRa.initialize(
        validatorSetAuRa.address
      ).should.be.fulfilled;

      // Initialize RandomAuRa
      await randomAuRa.initialize(
        114, // _collectRoundLength
        validatorSetAuRa.address
      ).should.be.fulfilled;

      // Initialize StakingAuRa
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.fulfilled;

      // Start the network
      await setCurrentBlockNumber(1);
      await callFinalizeChange();
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(1));

      // Deploy ERC20 contract
      erc20Token = await ERC677BridgeTokenRewardable.new("POSDAO20", "POSDAO20", 18, {from: owner});
      await stakingAuRa.setErc20TokenContract(erc20Token.address, {from: owner}).should.be.fulfilled;
      await erc20Token.setBlockRewardContract(blockRewardAuRa.address).should.be.fulfilled;
      await erc20Token.setStakingContract(stakingAuRa.address).should.be.fulfilled;

      // Validators place stakes during the epoch #0
      const candidateMinStake = await stakingAuRa.candidateMinStake.call();
      for (let i = 0; i < initialStakingAddresses.length; i++) {
        // Mint some balance for each validator (imagine that each validator got the tokens from a bridge)
        await erc20Token.mint(initialStakingAddresses[i], candidateMinStake, {from: owner}).should.be.fulfilled;
        candidateMinStake.should.be.bignumber.equal(await erc20Token.balanceOf.call(initialStakingAddresses[i]));

        // Validator places stake on themselves
        await stakingAuRa.stake(initialStakingAddresses[i], candidateMinStake, {from: initialStakingAddresses[i]}).should.be.fulfilled;
      }

      // Mint some balance for a delegator (imagine that the delegator got the tokens from a bridge)
      delegator = accounts[10];
      const delegatorMinStake = await stakingAuRa.delegatorMinStake.call();
      await erc20Token.mint(delegator, delegatorMinStake, {from: owner}).should.be.fulfilled;
      delegatorMinStake.should.be.bignumber.equal(await erc20Token.balanceOf.call(delegator));

      // The delegator places stake on the first validator
      await stakingAuRa.stake(initialStakingAddresses[0], delegatorMinStake, {from: delegator}).should.be.fulfilled;

      // Staking epoch #0 finishes
      const stakingEpochEndBlock = (await stakingAuRa.stakingEpochStartBlock.call()).add(new BN(120954));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      const blocksCreated = stakingEpochEndBlock.sub(await validatorSetAuRa.validatorSetApplyBlock.call()).div(new BN(initialValidators.length));
      blocksCreated.should.be.bignumber.above(new BN(0));
      for (let i = 0; i < initialValidators.length; i++) {
        await blockRewardAuRa.setBlocksCreated(new BN(0), initialValidators[i], blocksCreated).should.be.fulfilled;
        await randomAuRa.setSentReveal(initialValidators[i]).should.be.fulfilled;
      }

      await callReward();
    });

    it('gas consumption for one staking epoch is OK', async () => {
      const stakingEpoch = 2600;

      for (let i = 0; i < initialValidators.length; i++) {
        await blockRewardAuRa.snapshotPoolStakeAmounts(stakingAuRa.address, stakingEpoch, initialValidators[i]);
      }

      await stakingAuRa.setStakingEpoch(stakingEpoch).should.be.fulfilled;
      const stakingEpochStartBlock = new BN(120954 * stakingEpoch + 1);
      await stakingAuRa.setValidatorSetAddress(owner).should.be.fulfilled;
      await stakingAuRa.setStakingEpochStartBlock(stakingEpochStartBlock).should.be.fulfilled;
      await stakingAuRa.setValidatorSetAddress(validatorSetAuRa.address).should.be.fulfilled;
      await setCurrentBlockNumber(stakingEpochStartBlock);

      let result = await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
      result.logs[0].event.should.be.equal("InitiateChange");
      result.logs[0].args.newSet.should.be.deep.equal(initialValidators);

      const currentBlock = stakingEpochStartBlock.add(new BN(Math.floor(initialValidators.length / 2) + 1));
      await setCurrentBlockNumber(currentBlock);

      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      await callFinalizeChange();
      const validatorSetApplyBlock = await validatorSetAuRa.validatorSetApplyBlock.call();
      validatorSetApplyBlock.should.be.bignumber.equal(currentBlock);
      (await validatorSetAuRa.getValidators.call()).should.be.deep.equal(initialValidators);

      await accrueBridgeFees();

      const stakingEpochEndBlock = stakingEpochStartBlock.add(new BN(120954 - 1));
      await setCurrentBlockNumber(stakingEpochEndBlock);

      const blocksCreated = stakingEpochEndBlock.sub(validatorSetApplyBlock).div(new BN(initialValidators.length));
      blocksCreated.should.be.bignumber.above(new BN(0));
      for (let i = 0; i < initialValidators.length; i++) {
        await blockRewardAuRa.setBlocksCreated(new BN(stakingEpoch), initialValidators[i], blocksCreated).should.be.fulfilled;
        await randomAuRa.setSentReveal(initialValidators[i]).should.be.fulfilled;
      }

      let blockRewardTokensBalanceBefore = await erc20Token.balanceOf.call(blockRewardAuRa.address);
      let blockRewardCoinsBalanceBefore = new BN(await web3.eth.getBalance(blockRewardAuRa.address));
      for (let i = 0; i < initialValidators.length; i++) {
        (await blockRewardAuRa.epochPoolTokenReward.call(stakingEpoch, initialValidators[i])).should.be.bignumber.equal(new BN(0));
        (await blockRewardAuRa.epochPoolNativeReward.call(stakingEpoch, initialValidators[i])).should.be.bignumber.equal(new BN(0));
      }
      await callReward();
      (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
      let distributedTokensAmount = new BN(0);
      let distributedCoinsAmount = new BN(0);
      for (let i = 0; i < initialValidators.length; i++) {
        const epochPoolTokenReward = await blockRewardAuRa.epochPoolTokenReward.call(stakingEpoch, initialValidators[i]);
        const epochPoolNativeReward = await blockRewardAuRa.epochPoolNativeReward.call(stakingEpoch, initialValidators[i]);
        epochPoolTokenReward.should.be.bignumber.above(new BN(0));
        epochPoolNativeReward.should.be.bignumber.above(new BN(0));
        distributedTokensAmount = distributedTokensAmount.add(epochPoolTokenReward);
        distributedCoinsAmount = distributedCoinsAmount.add(epochPoolNativeReward);
      }
      let blockRewardTokensBalanceAfter = await erc20Token.balanceOf.call(blockRewardAuRa.address);
      let blockRewardCoinsBalanceAfter = new BN(await web3.eth.getBalance(blockRewardAuRa.address));
      blockRewardTokensBalanceAfter.should.be.bignumber.equal(blockRewardTokensBalanceBefore.add(distributedTokensAmount));
      blockRewardCoinsBalanceAfter.should.be.bignumber.equal(blockRewardCoinsBalanceBefore.add(distributedCoinsAmount));

      // The delegator claims their rewards
      const delegatorTokensBalanceBefore = await erc20Token.balanceOf.call(delegator);
      const delegatorCoinsBalanceBefore = new BN(await web3.eth.getBalance(delegator));

      blockRewardTokensBalanceBefore = await erc20Token.balanceOf.call(blockRewardAuRa.address);
      blockRewardCoinsBalanceBefore = new BN(await web3.eth.getBalance(blockRewardAuRa.address));

      result = await stakingAuRa.claimReward(initialStakingAddresses[0], [stakingEpoch], {from: delegator}).should.be.fulfilled;

      result.logs[0].event.should.be.equal("ClaimedReward");
      result.logs[0].args.fromPoolStakingAddress.should.be.equal(initialStakingAddresses[0]);
      result.logs[0].args.staker.should.be.equal(delegator);
      result.logs[0].args.stakingEpoch.should.be.bignumber.equal(new BN(stakingEpoch));

      const claimedTokensAmount = result.logs[0].args.tokensAmount;
      const claimedCoinsAmount = result.logs[0].args.nativeCoinsAmount;

      const tx = await web3.eth.getTransaction(result.tx);
      const weiSpent = (new BN(result.receipt.gasUsed)).mul(new BN(tx.gasPrice));

      result.receipt.gasUsed.should.be.below(1700000);

      const delegatorTokensBalanceAfter = await erc20Token.balanceOf.call(delegator);
      const delegatorCoinsBalanceAfter = new BN(await web3.eth.getBalance(delegator));

      blockRewardTokensBalanceAfter = await erc20Token.balanceOf.call(blockRewardAuRa.address);
      blockRewardCoinsBalanceAfter = new BN(await web3.eth.getBalance(blockRewardAuRa.address));

      delegatorTokensBalanceAfter.should.be.bignumber.equal(delegatorTokensBalanceBefore.add(claimedTokensAmount));
      delegatorCoinsBalanceAfter.should.be.bignumber.equal(delegatorCoinsBalanceBefore.add(claimedCoinsAmount).sub(weiSpent));

      blockRewardTokensBalanceAfter.should.be.bignumber.equal(blockRewardTokensBalanceBefore.sub(claimedTokensAmount));
      blockRewardCoinsBalanceAfter.should.be.bignumber.equal(blockRewardCoinsBalanceBefore.sub(claimedCoinsAmount));
    });

    it('gas consumption for one staking epoch is OK', async () => {
      const maxStakingEpoch = 20;

      maxStakingEpoch.should.be.above(2);

      // Loop of staking epochs
      for (let stakingEpoch = 1; stakingEpoch <= maxStakingEpoch; stakingEpoch++) {
        (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(new BN(stakingEpoch));

        const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
        stakingEpochStartBlock.should.be.bignumber.equal(new BN(120954 * stakingEpoch + 1));
        await setCurrentBlockNumber(stakingEpochStartBlock);

        const result = await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
        result.logs[0].event.should.be.equal("InitiateChange");
        result.logs[0].args.newSet.should.be.deep.equal(initialValidators);

        const currentBlock = stakingEpochStartBlock.add(new BN(Math.floor(initialValidators.length / 2) + 1));
        await setCurrentBlockNumber(currentBlock);

        (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
        await callFinalizeChange();
        const validatorSetApplyBlock = await validatorSetAuRa.validatorSetApplyBlock.call();
        validatorSetApplyBlock.should.be.bignumber.equal(currentBlock);
        (await validatorSetAuRa.getValidators.call()).should.be.deep.equal(initialValidators);

        await accrueBridgeFees();

        const stakingEpochEndBlock = stakingEpochStartBlock.add(new BN(120954 - 1));
        await setCurrentBlockNumber(stakingEpochEndBlock);

        const blocksCreated = stakingEpochEndBlock.sub(validatorSetApplyBlock).div(new BN(initialValidators.length));
        blocksCreated.should.be.bignumber.above(new BN(0));
        for (let i = 0; i < initialValidators.length; i++) {
          await blockRewardAuRa.setBlocksCreated(new BN(stakingEpoch), initialValidators[i], blocksCreated).should.be.fulfilled;
          await randomAuRa.setSentReveal(initialValidators[i]).should.be.fulfilled;
        }

        const blockRewardTokensBalanceBefore = await erc20Token.balanceOf.call(blockRewardAuRa.address);
        const blockRewardCoinsBalanceBefore = new BN(await web3.eth.getBalance(blockRewardAuRa.address));
        for (let i = 0; i < initialValidators.length; i++) {
          (await blockRewardAuRa.epochPoolTokenReward.call(stakingEpoch, initialValidators[i])).should.be.bignumber.equal(new BN(0));
          (await blockRewardAuRa.epochPoolNativeReward.call(stakingEpoch, initialValidators[i])).should.be.bignumber.equal(new BN(0));
        }
        await callReward();
        let distributedTokensAmount = new BN(0);
        let distributedCoinsAmount = new BN(0);
        for (let i = 0; i < initialValidators.length; i++) {
          const epochPoolTokenReward = await blockRewardAuRa.epochPoolTokenReward.call(stakingEpoch, initialValidators[i]);
          const epochPoolNativeReward = await blockRewardAuRa.epochPoolNativeReward.call(stakingEpoch, initialValidators[i]);
          epochPoolTokenReward.should.be.bignumber.above(new BN(0));
          epochPoolNativeReward.should.be.bignumber.above(new BN(0));
          distributedTokensAmount = distributedTokensAmount.add(epochPoolTokenReward);
          distributedCoinsAmount = distributedCoinsAmount.add(epochPoolNativeReward);
        }
        const blockRewardTokensBalanceAfter = await erc20Token.balanceOf.call(blockRewardAuRa.address);
        const blockRewardCoinsBalanceAfter = new BN(await web3.eth.getBalance(blockRewardAuRa.address));
        blockRewardTokensBalanceAfter.should.be.bignumber.equal(blockRewardTokensBalanceBefore.add(distributedTokensAmount));
        blockRewardCoinsBalanceAfter.should.be.bignumber.equal(blockRewardCoinsBalanceBefore.add(distributedCoinsAmount));
      }

      // The delegator claims their rewards
      let initialGasConsumption = new BN(0);
      let startGasConsumption = new BN(0);
      let endGasConsumption = new BN(0);
      let blockRewardTokensBalanceTotalBefore = await erc20Token.balanceOf.call(blockRewardAuRa.address);
      let blockRewardCoinsBalanceTotalBefore = new BN(await web3.eth.getBalance(blockRewardAuRa.address));

      let tokensDelegatorGotForAllEpochs = new BN(0);
      let coinsDelegatorGotForAllEpochs = new BN(0);
      for (let stakingEpoch = 1; stakingEpoch <= maxStakingEpoch; stakingEpoch++) {
        const delegatorTokensBalanceBefore = await erc20Token.balanceOf.call(delegator);
        const delegatorCoinsBalanceBefore = new BN(await web3.eth.getBalance(delegator));

        const blockRewardTokensBalanceBefore = await erc20Token.balanceOf.call(blockRewardAuRa.address);
        const blockRewardCoinsBalanceBefore = new BN(await web3.eth.getBalance(blockRewardAuRa.address));

        let result = await stakingAuRa.claimReward(initialStakingAddresses[0], [stakingEpoch], {from: delegator}).should.be.fulfilled;
        result.logs[0].event.should.be.equal("ClaimedReward");
        result.logs[0].args.fromPoolStakingAddress.should.be.equal(initialStakingAddresses[0]);
        result.logs[0].args.staker.should.be.equal(delegator);
        result.logs[0].args.stakingEpoch.should.be.bignumber.equal(new BN(stakingEpoch));

        const claimedTokensAmount = result.logs[0].args.tokensAmount;
        const claimedCoinsAmount = result.logs[0].args.nativeCoinsAmount;

        const tx = await web3.eth.getTransaction(result.tx);
        const weiSpent = (new BN(result.receipt.gasUsed)).mul(new BN(tx.gasPrice));

        if (stakingEpoch == 1) {
          initialGasConsumption = new BN(result.receipt.gasUsed);
        } else if (stakingEpoch == 2) {
          startGasConsumption = new BN(result.receipt.gasUsed);
        } else if (stakingEpoch == maxStakingEpoch) {
          endGasConsumption = new BN(result.receipt.gasUsed);
        }

        const delegatorTokensBalanceAfter = await erc20Token.balanceOf.call(delegator);
        const delegatorCoinsBalanceAfter = new BN(await web3.eth.getBalance(delegator));

        const blockRewardTokensBalanceAfter = await erc20Token.balanceOf.call(blockRewardAuRa.address);
        const blockRewardCoinsBalanceAfter = new BN(await web3.eth.getBalance(blockRewardAuRa.address));

        delegatorTokensBalanceAfter.should.be.bignumber.equal(delegatorTokensBalanceBefore.add(claimedTokensAmount));
        delegatorCoinsBalanceAfter.should.be.bignumber.equal(delegatorCoinsBalanceBefore.add(claimedCoinsAmount).sub(weiSpent));

        blockRewardTokensBalanceAfter.should.be.bignumber.equal(blockRewardTokensBalanceBefore.sub(claimedTokensAmount));
        blockRewardCoinsBalanceAfter.should.be.bignumber.equal(blockRewardCoinsBalanceBefore.sub(claimedCoinsAmount));

        tokensDelegatorGotForAllEpochs = tokensDelegatorGotForAllEpochs.add(claimedTokensAmount);
        coinsDelegatorGotForAllEpochs = coinsDelegatorGotForAllEpochs.add(claimedCoinsAmount);

        // console.log(`stakingEpoch = ${stakingEpoch}, gasUsed = ${result.receipt.gasUsed}, cumulativeGasUsed = ${result.receipt.cumulativeGasUsed}`);
      }

      const perEpochGasConsumption = endGasConsumption.sub(startGasConsumption).div(new BN(maxStakingEpoch - 2));
      perEpochGasConsumption.should.be.bignumber.equal(new BN(584));

      // Check gas consumption for the case when the delegator didn't touch their
      // stake for 50 years (2600 staking epochs)
      const maxGasConsumption = initialGasConsumption.sub(perEpochGasConsumption).add(perEpochGasConsumption.mul(new BN(2600)));
      maxGasConsumption.should.be.bignumber.below(new BN(1700000));

      let blockRewardTokensBalanceTotalAfter = await erc20Token.balanceOf.call(blockRewardAuRa.address);
      let blockRewardCoinsBalanceTotalAfter = new BN(await web3.eth.getBalance(blockRewardAuRa.address));

      blockRewardTokensBalanceTotalAfter.should.be.bignumber.equal(blockRewardTokensBalanceTotalBefore.sub(tokensDelegatorGotForAllEpochs));
      blockRewardCoinsBalanceTotalAfter.should.be.bignumber.equal(blockRewardCoinsBalanceTotalBefore.sub(coinsDelegatorGotForAllEpochs));

      // The validators claim their rewards
      let tokensValidatorsGotForAllEpochs = new BN(0);
      let coinsValidatorsGotForAllEpochs = new BN(0);
      for (let v = 0; v < initialStakingAddresses.length; v++) {
        for (let stakingEpoch = 1; stakingEpoch <= maxStakingEpoch; stakingEpoch++) {
          const validator = initialStakingAddresses[v];
          const validatorTokensBalanceBefore = await erc20Token.balanceOf.call(validator);
          const validatorCoinsBalanceBefore = new BN(await web3.eth.getBalance(validator));

          const blockRewardTokensBalanceBefore = await erc20Token.balanceOf.call(blockRewardAuRa.address);
          const blockRewardCoinsBalanceBefore = new BN(await web3.eth.getBalance(blockRewardAuRa.address));

          let result = await stakingAuRa.claimReward(validator, [stakingEpoch], {from: validator}).should.be.fulfilled;
          result.logs[0].event.should.be.equal("ClaimedReward");
          result.logs[0].args.fromPoolStakingAddress.should.be.equal(validator);
          result.logs[0].args.staker.should.be.equal(validator);
          result.logs[0].args.stakingEpoch.should.be.bignumber.equal(new BN(stakingEpoch));

          const claimedTokensAmount = result.logs[0].args.tokensAmount;
          const claimedCoinsAmount = result.logs[0].args.nativeCoinsAmount;

          const tx = await web3.eth.getTransaction(result.tx);
          const weiSpent = (new BN(result.receipt.gasUsed)).mul(new BN(tx.gasPrice));

          const validatorTokensBalanceAfter = await erc20Token.balanceOf.call(validator);
          const validatorCoinsBalanceAfter = new BN(await web3.eth.getBalance(validator));

          const blockRewardTokensBalanceAfter = await erc20Token.balanceOf.call(blockRewardAuRa.address);
          const blockRewardCoinsBalanceAfter = new BN(await web3.eth.getBalance(blockRewardAuRa.address));

          validatorTokensBalanceAfter.should.be.bignumber.equal(validatorTokensBalanceBefore.add(claimedTokensAmount));
          validatorCoinsBalanceAfter.should.be.bignumber.equal(validatorCoinsBalanceBefore.add(claimedCoinsAmount).sub(weiSpent));

          blockRewardTokensBalanceAfter.should.be.bignumber.equal(blockRewardTokensBalanceBefore.sub(claimedTokensAmount));
          blockRewardCoinsBalanceAfter.should.be.bignumber.equal(blockRewardCoinsBalanceBefore.sub(claimedCoinsAmount));

          tokensValidatorsGotForAllEpochs = tokensValidatorsGotForAllEpochs.add(claimedTokensAmount);
          coinsValidatorsGotForAllEpochs = coinsValidatorsGotForAllEpochs.add(claimedCoinsAmount);
        }
      }

      blockRewardTokensBalanceTotalAfter = await erc20Token.balanceOf.call(blockRewardAuRa.address);
      blockRewardCoinsBalanceTotalAfter = new BN(await web3.eth.getBalance(blockRewardAuRa.address));

      blockRewardTokensBalanceTotalAfter.should.be.bignumber.equal(blockRewardTokensBalanceTotalBefore.sub(tokensDelegatorGotForAllEpochs).sub(tokensValidatorsGotForAllEpochs));
      blockRewardCoinsBalanceTotalAfter.should.be.bignumber.equal(blockRewardCoinsBalanceTotalBefore.sub(coinsDelegatorGotForAllEpochs).sub(coinsValidatorsGotForAllEpochs));

      blockRewardTokensBalanceTotalAfter.should.be.bignumber.gte(new BN(0));
      blockRewardCoinsBalanceTotalAfter.should.be.bignumber.gte(new BN(0));
    });

    it('gas consumption for 52 staking epochs (1 continuous year) is OK', async () => {
      const maxStakingEpoch = 52;

      // Loop of staking epochs
      for (let stakingEpoch = 1; stakingEpoch <= maxStakingEpoch; stakingEpoch++) {
        (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(new BN(stakingEpoch));

        const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
        stakingEpochStartBlock.should.be.bignumber.equal(new BN(120954 * stakingEpoch + 1));
        await setCurrentBlockNumber(stakingEpochStartBlock);

        const result = await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
        result.logs[0].event.should.be.equal("InitiateChange");
        result.logs[0].args.newSet.should.be.deep.equal(initialValidators);

        const currentBlock = stakingEpochStartBlock.add(new BN(Math.floor(initialValidators.length / 2) + 1));
        await setCurrentBlockNumber(currentBlock);

        (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
        await callFinalizeChange();
        const validatorSetApplyBlock = await validatorSetAuRa.validatorSetApplyBlock.call();
        validatorSetApplyBlock.should.be.bignumber.equal(currentBlock);
        (await validatorSetAuRa.getValidators.call()).should.be.deep.equal(initialValidators);

        await accrueBridgeFees();

        const stakingEpochEndBlock = stakingEpochStartBlock.add(new BN(120954 - 1));
        await setCurrentBlockNumber(stakingEpochEndBlock);

        const blocksCreated = stakingEpochEndBlock.sub(validatorSetApplyBlock).div(new BN(initialValidators.length));
        blocksCreated.should.be.bignumber.above(new BN(0));
        for (let i = 0; i < initialValidators.length; i++) {
          await blockRewardAuRa.setBlocksCreated(new BN(stakingEpoch), initialValidators[i], blocksCreated).should.be.fulfilled;
          await randomAuRa.setSentReveal(initialValidators[i]).should.be.fulfilled;
        }

        const blockRewardTokensBalanceBefore = await erc20Token.balanceOf.call(blockRewardAuRa.address);
        const blockRewardCoinsBalanceBefore = new BN(await web3.eth.getBalance(blockRewardAuRa.address));
        for (let i = 0; i < initialValidators.length; i++) {
          (await blockRewardAuRa.epochPoolTokenReward.call(stakingEpoch, initialValidators[i])).should.be.bignumber.equal(new BN(0));
          (await blockRewardAuRa.epochPoolNativeReward.call(stakingEpoch, initialValidators[i])).should.be.bignumber.equal(new BN(0));
        }
        await callReward();
        let distributedTokensAmount = new BN(0);
        let distributedCoinsAmount = new BN(0);
        for (let i = 0; i < initialValidators.length; i++) {
          const epochPoolTokenReward = await blockRewardAuRa.epochPoolTokenReward.call(stakingEpoch, initialValidators[i]);
          const epochPoolNativeReward = await blockRewardAuRa.epochPoolNativeReward.call(stakingEpoch, initialValidators[i]);
          epochPoolTokenReward.should.be.bignumber.above(new BN(0));
          epochPoolNativeReward.should.be.bignumber.above(new BN(0));
          distributedTokensAmount = distributedTokensAmount.add(epochPoolTokenReward);
          distributedCoinsAmount = distributedCoinsAmount.add(epochPoolNativeReward);
        }
        const blockRewardTokensBalanceAfter = await erc20Token.balanceOf.call(blockRewardAuRa.address);
        const blockRewardCoinsBalanceAfter = new BN(await web3.eth.getBalance(blockRewardAuRa.address));
        blockRewardTokensBalanceAfter.should.be.bignumber.equal(blockRewardTokensBalanceBefore.add(distributedTokensAmount));
        blockRewardCoinsBalanceAfter.should.be.bignumber.equal(blockRewardCoinsBalanceBefore.add(distributedCoinsAmount));
      }

      // The delegator claims their rewards
      const delegatorTokensBalanceBefore = await erc20Token.balanceOf.call(delegator);
      const delegatorCoinsBalanceBefore = new BN(await web3.eth.getBalance(delegator));

      const blockRewardTokensBalanceBefore = await erc20Token.balanceOf.call(blockRewardAuRa.address);
      const blockRewardCoinsBalanceBefore = new BN(await web3.eth.getBalance(blockRewardAuRa.address));
      const blockRewardTokensBalanceTotalBefore = blockRewardTokensBalanceBefore;
      const blockRewardCoinsBalanceTotalBefore = blockRewardCoinsBalanceBefore;

      const result = await stakingAuRa.claimReward(initialStakingAddresses[0], [], {from: delegator}).should.be.fulfilled;

      let tokensDelegatorGotForAllEpochs = new BN(0);
      let coinsDelegatorGotForAllEpochs = new BN(0);
      for (let i = 0; i < maxStakingEpoch; i++) {
        result.logs[i].event.should.be.equal("ClaimedReward");
        result.logs[i].args.fromPoolStakingAddress.should.be.equal(initialStakingAddresses[0]);
        result.logs[i].args.staker.should.be.equal(delegator);
        result.logs[i].args.stakingEpoch.should.be.bignumber.equal(new BN(i + 1));
        tokensDelegatorGotForAllEpochs = tokensDelegatorGotForAllEpochs.add(result.logs[i].args.tokensAmount);
        coinsDelegatorGotForAllEpochs = coinsDelegatorGotForAllEpochs.add(result.logs[i].args.nativeCoinsAmount);
      }

      const tx = await web3.eth.getTransaction(result.tx);
      const weiSpent = (new BN(result.receipt.gasUsed)).mul(new BN(tx.gasPrice));

      // console.log(`gasUsed = ${result.receipt.gasUsed}, cumulativeGasUsed = ${result.receipt.cumulativeGasUsed}`);
      result.receipt.gasUsed.should.be.below(1700000);

      const delegatorTokensBalanceAfter = await erc20Token.balanceOf.call(delegator);
      const delegatorCoinsBalanceAfter = new BN(await web3.eth.getBalance(delegator));

      const blockRewardTokensBalanceAfter = await erc20Token.balanceOf.call(blockRewardAuRa.address);
      const blockRewardCoinsBalanceAfter = new BN(await web3.eth.getBalance(blockRewardAuRa.address));

      tokensDelegatorGotForAllEpochs.should.be.bignumber.gte(new BN(0));
      coinsDelegatorGotForAllEpochs.should.be.bignumber.gte(new BN(0));

      delegatorTokensBalanceAfter.should.be.bignumber.equal(delegatorTokensBalanceBefore.add(tokensDelegatorGotForAllEpochs));
      delegatorCoinsBalanceAfter.should.be.bignumber.equal(delegatorCoinsBalanceBefore.add(coinsDelegatorGotForAllEpochs).sub(weiSpent));

      blockRewardTokensBalanceAfter.should.be.bignumber.equal(blockRewardTokensBalanceBefore.sub(tokensDelegatorGotForAllEpochs));
      blockRewardCoinsBalanceAfter.should.be.bignumber.equal(blockRewardCoinsBalanceBefore.sub(coinsDelegatorGotForAllEpochs));

      // The validators claim their rewards
      let tokensValidatorsGotForAllEpochs = new BN(0);
      let coinsValidatorsGotForAllEpochs = new BN(0);
      for (let v = 0; v < initialStakingAddresses.length; v++) {
        const validator = initialStakingAddresses[v];
        const validatorTokensBalanceBefore = await erc20Token.balanceOf.call(validator);
        const validatorCoinsBalanceBefore = new BN(await web3.eth.getBalance(validator));

        const blockRewardTokensBalanceBefore = await erc20Token.balanceOf.call(blockRewardAuRa.address);
        const blockRewardCoinsBalanceBefore = new BN(await web3.eth.getBalance(blockRewardAuRa.address));

        const result = await stakingAuRa.claimReward(validator, [], {from: validator}).should.be.fulfilled;

        let claimedTokensAmount = new BN(0);
        let claimedCoinsAmount = new BN(0);
        for (let i = 0; i < maxStakingEpoch; i++) {
          result.logs[i].event.should.be.equal("ClaimedReward");
          result.logs[i].args.fromPoolStakingAddress.should.be.equal(validator);
          result.logs[i].args.staker.should.be.equal(validator);
          result.logs[i].args.stakingEpoch.should.be.bignumber.equal(new BN(i + 1));
          claimedTokensAmount = claimedTokensAmount.add(result.logs[i].args.tokensAmount);
          claimedCoinsAmount = claimedCoinsAmount.add(result.logs[i].args.nativeCoinsAmount);
        }

        const tx = await web3.eth.getTransaction(result.tx);
        const weiSpent = (new BN(result.receipt.gasUsed)).mul(new BN(tx.gasPrice));

        const validatorTokensBalanceAfter = await erc20Token.balanceOf.call(validator);
        const validatorCoinsBalanceAfter = new BN(await web3.eth.getBalance(validator));

        const blockRewardTokensBalanceAfter = await erc20Token.balanceOf.call(blockRewardAuRa.address);
        const blockRewardCoinsBalanceAfter = new BN(await web3.eth.getBalance(blockRewardAuRa.address));

        claimedTokensAmount.should.be.bignumber.gte(new BN(0));
        claimedCoinsAmount.should.be.bignumber.gte(new BN(0));

        validatorTokensBalanceAfter.should.be.bignumber.equal(validatorTokensBalanceBefore.add(claimedTokensAmount));
        validatorCoinsBalanceAfter.should.be.bignumber.equal(validatorCoinsBalanceBefore.add(claimedCoinsAmount).sub(weiSpent));

        blockRewardTokensBalanceAfter.should.be.bignumber.equal(blockRewardTokensBalanceBefore.sub(claimedTokensAmount));
        blockRewardCoinsBalanceAfter.should.be.bignumber.equal(blockRewardCoinsBalanceBefore.sub(claimedCoinsAmount));

        tokensValidatorsGotForAllEpochs = tokensValidatorsGotForAllEpochs.add(claimedTokensAmount);
        coinsValidatorsGotForAllEpochs = coinsValidatorsGotForAllEpochs.add(claimedCoinsAmount);
      }

      const blockRewardTokensBalanceTotalAfter = await erc20Token.balanceOf.call(blockRewardAuRa.address);
      const blockRewardCoinsBalanceTotalAfter = new BN(await web3.eth.getBalance(blockRewardAuRa.address));

      blockRewardTokensBalanceTotalAfter.should.be.bignumber.equal(blockRewardTokensBalanceTotalBefore.sub(tokensDelegatorGotForAllEpochs).sub(tokensValidatorsGotForAllEpochs));
      blockRewardCoinsBalanceTotalAfter.should.be.bignumber.equal(blockRewardCoinsBalanceTotalBefore.sub(coinsDelegatorGotForAllEpochs).sub(coinsValidatorsGotForAllEpochs));

      blockRewardTokensBalanceTotalAfter.should.be.bignumber.gte(new BN(0));
      blockRewardCoinsBalanceTotalAfter.should.be.bignumber.gte(new BN(0));
    });

    it('gas consumption for 52 staking epochs (10 years including gaps) is OK', async () => {
      const maxStakingEpochs = 52;
      const gapSize = 10;

      // Loop of staking epochs
      for (let s = 0; s < maxStakingEpochs; s++) {
        const stakingEpoch = (await stakingAuRa.stakingEpoch.call()).toNumber();

        const stakingEpochStartBlock = await stakingAuRa.stakingEpochStartBlock.call();
        stakingEpochStartBlock.should.be.bignumber.equal(new BN(120954 * stakingEpoch + 1));
        await setCurrentBlockNumber(stakingEpochStartBlock);

        const result = await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
        result.logs[0].event.should.be.equal("InitiateChange");
        result.logs[0].args.newSet.should.be.deep.equal(initialValidators);

        const currentBlock = stakingEpochStartBlock.add(new BN(Math.floor(initialValidators.length / 2) + 1));
        await setCurrentBlockNumber(currentBlock);

        (await validatorSetAuRa.validatorSetApplyBlock.call()).should.be.bignumber.equal(new BN(0));
        await callFinalizeChange();
        const validatorSetApplyBlock = await validatorSetAuRa.validatorSetApplyBlock.call();
        validatorSetApplyBlock.should.be.bignumber.equal(currentBlock);
        (await validatorSetAuRa.getValidators.call()).should.be.deep.equal(initialValidators);

        await accrueBridgeFees();

        const stakingEpochEndBlock = stakingEpochStartBlock.add(new BN(120954 - 1));
        await setCurrentBlockNumber(stakingEpochEndBlock);

        const blocksCreated = stakingEpochEndBlock.sub(validatorSetApplyBlock).div(new BN(initialValidators.length));
        blocksCreated.should.be.bignumber.above(new BN(0));
        for (let i = 0; i < initialValidators.length; i++) {
          await blockRewardAuRa.setBlocksCreated(new BN(stakingEpoch), initialValidators[i], blocksCreated).should.be.fulfilled;
          await randomAuRa.setSentReveal(initialValidators[i]).should.be.fulfilled;
        }

        const blockRewardTokensBalanceBefore = await erc20Token.balanceOf.call(blockRewardAuRa.address);
        const blockRewardCoinsBalanceBefore = new BN(await web3.eth.getBalance(blockRewardAuRa.address));
        for (let i = 0; i < initialValidators.length; i++) {
          (await blockRewardAuRa.epochPoolTokenReward.call(stakingEpoch, initialValidators[i])).should.be.bignumber.equal(new BN(0));
          (await blockRewardAuRa.epochPoolNativeReward.call(stakingEpoch, initialValidators[i])).should.be.bignumber.equal(new BN(0));
        }
        await callReward();
        let distributedTokensAmount = new BN(0);
        let distributedCoinsAmount = new BN(0);
        for (let i = 0; i < initialValidators.length; i++) {
          const epochPoolTokenReward = await blockRewardAuRa.epochPoolTokenReward.call(stakingEpoch, initialValidators[i]);
          const epochPoolNativeReward = await blockRewardAuRa.epochPoolNativeReward.call(stakingEpoch, initialValidators[i]);
          epochPoolTokenReward.should.be.bignumber.above(new BN(0));
          epochPoolNativeReward.should.be.bignumber.above(new BN(0));
          distributedTokensAmount = distributedTokensAmount.add(epochPoolTokenReward);
          distributedCoinsAmount = distributedCoinsAmount.add(epochPoolNativeReward);
        }
        const blockRewardTokensBalanceAfter = await erc20Token.balanceOf.call(blockRewardAuRa.address);
        const blockRewardCoinsBalanceAfter = new BN(await web3.eth.getBalance(blockRewardAuRa.address));
        blockRewardTokensBalanceAfter.should.be.bignumber.equal(blockRewardTokensBalanceBefore.add(distributedTokensAmount));
        blockRewardCoinsBalanceAfter.should.be.bignumber.equal(blockRewardCoinsBalanceBefore.add(distributedCoinsAmount));

        const nextStakingEpoch = stakingEpoch + gapSize; // jump through a few epochs
        await stakingAuRa.setStakingEpoch(nextStakingEpoch).should.be.fulfilled;
        await stakingAuRa.setValidatorSetAddress(owner).should.be.fulfilled;
        await stakingAuRa.setStakingEpochStartBlock(120954 * nextStakingEpoch + 1).should.be.fulfilled;
        await stakingAuRa.setValidatorSetAddress(validatorSetAuRa.address).should.be.fulfilled;
        for (let i = 0; i < initialValidators.length; i++) {
          await blockRewardAuRa.snapshotPoolStakeAmounts(stakingAuRa.address, nextStakingEpoch, initialValidators[i]);
        }
      }

      const epochsPoolGotRewardFor = await blockRewardAuRa.epochsPoolGotRewardFor.call(initialValidators[0]);

      // The delegator claims their rewards
      const delegatorTokensBalanceBefore = await erc20Token.balanceOf.call(delegator);
      const delegatorCoinsBalanceBefore = new BN(await web3.eth.getBalance(delegator));

      const blockRewardTokensBalanceBefore = await erc20Token.balanceOf.call(blockRewardAuRa.address);
      const blockRewardCoinsBalanceBefore = new BN(await web3.eth.getBalance(blockRewardAuRa.address));
      const blockRewardTokensBalanceTotalBefore = blockRewardTokensBalanceBefore;
      const blockRewardCoinsBalanceTotalBefore = blockRewardCoinsBalanceBefore;

      const result = await stakingAuRa.claimReward(initialStakingAddresses[0], [], {from: delegator}).should.be.fulfilled;

      let tokensDelegatorGotForAllEpochs = new BN(0);
      let coinsDelegatorGotForAllEpochs = new BN(0);
      for (let i = 0; i < maxStakingEpochs; i++) {
        result.logs[i].event.should.be.equal("ClaimedReward");
        result.logs[i].args.fromPoolStakingAddress.should.be.equal(initialStakingAddresses[0]);
        result.logs[i].args.staker.should.be.equal(delegator);
        result.logs[i].args.stakingEpoch.should.be.bignumber.equal(epochsPoolGotRewardFor[i]);
        tokensDelegatorGotForAllEpochs = tokensDelegatorGotForAllEpochs.add(result.logs[i].args.tokensAmount);
        coinsDelegatorGotForAllEpochs = coinsDelegatorGotForAllEpochs.add(result.logs[i].args.nativeCoinsAmount);
      }

      const tx = await web3.eth.getTransaction(result.tx);
      const weiSpent = (new BN(result.receipt.gasUsed)).mul(new BN(tx.gasPrice));

      // console.log(`gasUsed = ${result.receipt.gasUsed}, cumulativeGasUsed = ${result.receipt.cumulativeGasUsed}`);
      result.receipt.gasUsed.should.be.below(2000000);

      const delegatorTokensBalanceAfter = await erc20Token.balanceOf.call(delegator);
      const delegatorCoinsBalanceAfter = new BN(await web3.eth.getBalance(delegator));

      const blockRewardTokensBalanceAfter = await erc20Token.balanceOf.call(blockRewardAuRa.address);
      const blockRewardCoinsBalanceAfter = new BN(await web3.eth.getBalance(blockRewardAuRa.address));

      tokensDelegatorGotForAllEpochs.should.be.bignumber.gte(new BN(0));
      coinsDelegatorGotForAllEpochs.should.be.bignumber.gte(new BN(0));

      delegatorTokensBalanceAfter.should.be.bignumber.equal(delegatorTokensBalanceBefore.add(tokensDelegatorGotForAllEpochs));
      delegatorCoinsBalanceAfter.should.be.bignumber.equal(delegatorCoinsBalanceBefore.add(coinsDelegatorGotForAllEpochs).sub(weiSpent));

      blockRewardTokensBalanceAfter.should.be.bignumber.equal(blockRewardTokensBalanceBefore.sub(tokensDelegatorGotForAllEpochs));
      blockRewardCoinsBalanceAfter.should.be.bignumber.equal(blockRewardCoinsBalanceBefore.sub(coinsDelegatorGotForAllEpochs));

      // The validators claim their rewards
      let tokensValidatorsGotForAllEpochs = new BN(0);
      let coinsValidatorsGotForAllEpochs = new BN(0);
      for (let v = 0; v < initialStakingAddresses.length; v++) {
        const validator = initialStakingAddresses[v];
        const validatorTokensBalanceBefore = await erc20Token.balanceOf.call(validator);
        const validatorCoinsBalanceBefore = new BN(await web3.eth.getBalance(validator));

        const blockRewardTokensBalanceBefore = await erc20Token.balanceOf.call(blockRewardAuRa.address);
        const blockRewardCoinsBalanceBefore = new BN(await web3.eth.getBalance(blockRewardAuRa.address));

        const result = await stakingAuRa.claimReward(validator, [], {from: validator}).should.be.fulfilled;

        let claimedTokensAmount = new BN(0);
        let claimedCoinsAmount = new BN(0);
        for (let i = 0; i < maxStakingEpochs; i++) {
          result.logs[i].event.should.be.equal("ClaimedReward");
          result.logs[i].args.fromPoolStakingAddress.should.be.equal(validator);
          result.logs[i].args.staker.should.be.equal(validator);
          result.logs[i].args.stakingEpoch.should.be.bignumber.equal(epochsPoolGotRewardFor[i]);
          claimedTokensAmount = claimedTokensAmount.add(result.logs[i].args.tokensAmount);
          claimedCoinsAmount = claimedCoinsAmount.add(result.logs[i].args.nativeCoinsAmount);
        }

        const tx = await web3.eth.getTransaction(result.tx);
        const weiSpent = (new BN(result.receipt.gasUsed)).mul(new BN(tx.gasPrice));

        const validatorTokensBalanceAfter = await erc20Token.balanceOf.call(validator);
        const validatorCoinsBalanceAfter = new BN(await web3.eth.getBalance(validator));

        const blockRewardTokensBalanceAfter = await erc20Token.balanceOf.call(blockRewardAuRa.address);
        const blockRewardCoinsBalanceAfter = new BN(await web3.eth.getBalance(blockRewardAuRa.address));

        claimedTokensAmount.should.be.bignumber.gte(new BN(0));
        claimedCoinsAmount.should.be.bignumber.gte(new BN(0));

        validatorTokensBalanceAfter.should.be.bignumber.equal(validatorTokensBalanceBefore.add(claimedTokensAmount));
        validatorCoinsBalanceAfter.should.be.bignumber.equal(validatorCoinsBalanceBefore.add(claimedCoinsAmount).sub(weiSpent));

        blockRewardTokensBalanceAfter.should.be.bignumber.equal(blockRewardTokensBalanceBefore.sub(claimedTokensAmount));
        blockRewardCoinsBalanceAfter.should.be.bignumber.equal(blockRewardCoinsBalanceBefore.sub(claimedCoinsAmount));

        tokensValidatorsGotForAllEpochs = tokensValidatorsGotForAllEpochs.add(claimedTokensAmount);
        coinsValidatorsGotForAllEpochs = coinsValidatorsGotForAllEpochs.add(claimedCoinsAmount);
      }

      const blockRewardTokensBalanceTotalAfter = await erc20Token.balanceOf.call(blockRewardAuRa.address);
      const blockRewardCoinsBalanceTotalAfter = new BN(await web3.eth.getBalance(blockRewardAuRa.address));

      blockRewardTokensBalanceTotalAfter.should.be.bignumber.equal(blockRewardTokensBalanceTotalBefore.sub(tokensDelegatorGotForAllEpochs).sub(tokensValidatorsGotForAllEpochs));
      blockRewardCoinsBalanceTotalAfter.should.be.bignumber.equal(blockRewardCoinsBalanceTotalBefore.sub(coinsDelegatorGotForAllEpochs).sub(coinsValidatorsGotForAllEpochs));

      blockRewardTokensBalanceTotalAfter.should.be.bignumber.gte(new BN(0));
      blockRewardCoinsBalanceTotalAfter.should.be.bignumber.gte(new BN(0));
    });
  });

  describe('clearUnremovableValidator()', async () => {
    beforeEach(async () => {
      // Deploy ValidatorSet contract
      validatorSetAuRa = await ValidatorSetAuRa.new();
      validatorSetAuRa = await AdminUpgradeabilityProxy.new(validatorSetAuRa.address, owner, []);
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
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
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
      await validatorSetAuRa.setCurrentBlockNumber(100).should.be.fulfilled;

      // Place a stake for itself
      await stakingAuRa.stake(initialStakingAddresses[0], stakeUnit.mul(new BN(1)), {from: initialStakingAddresses[0]}).should.be.fulfilled;

      (await stakingAuRa.getPoolsToBeElected.call()).length.should.be.equal(0);

      await stakingAuRa.setValidatorSetAddress(accounts[7]).should.be.fulfilled;
      await stakingAuRa.clearUnremovableValidator(initialStakingAddresses[0], {from: accounts[7]}).should.be.fulfilled;

      (await stakingAuRa.getPoolsToBeElected.call()).should.be.deep.equal([
        initialStakingAddresses[0]
      ]);

      const likelihoodInfo = await stakingAuRa.getPoolsLikelihood.call();
      likelihoodInfo.likelihoods[0].should.be.bignumber.equal(stakeUnit);
      likelihoodInfo.sum.should.be.bignumber.equal(stakeUnit);
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
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.fulfilled;
      new BN(120954).should.be.bignumber.equal(
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
        await stakingAuRa.delegatorMinStake.call()
      );
      new BN(web3.utils.toWei('1', 'ether')).should.be.bignumber.equal(
        await stakingAuRa.candidateMinStake.call()
      );
    });
    it('should fail if ValidatorSet contract address is zero', async () => {
      await stakingAuRa.initialize(
        '0x0000000000000000000000000000000000000000', // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
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
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
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
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
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
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.fulfilled;
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
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
        0, // _stakingEpochStartBlock
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
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
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
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
        120954, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
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
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
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
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
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
    it('should move part of the stake', async () => {
      await erc20Token.mint(delegatorAddress, mintAmount, {from: owner}).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: delegatorAddress}).should.be.fulfilled;

      const sourcePool = initialStakingAddresses[0];
      const targetPool = initialStakingAddresses[1];

      (await stakingAuRa.stakeAmount.call(sourcePool, delegatorAddress)).should.be.bignumber.equal(mintAmount);
      (await stakingAuRa.stakeAmount.call(targetPool, delegatorAddress)).should.be.bignumber.equal(mintAmount);
      
      const moveAmount = stakeUnit.div(new BN(2));
      moveAmount.should.be.bignumber.below(await stakingAuRa.delegatorMinStake.call());
      
      await stakingAuRa.moveStake(sourcePool, targetPool, moveAmount, {from: delegatorAddress}).should.be.fulfilled;
      (await stakingAuRa.stakeAmount.call(sourcePool, delegatorAddress)).should.be.bignumber.equal(mintAmount.sub(moveAmount));
      (await stakingAuRa.stakeAmount.call(targetPool, delegatorAddress)).should.be.bignumber.equal(mintAmount.add(moveAmount));
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
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.fulfilled;

      candidateMinStake = await stakingAuRa.candidateMinStake.call();
      delegatorMinStake = await stakingAuRa.delegatorMinStake.call();

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
      await stakingAuRa.setErc20TokenContractMock('0x0000000000000000000000000000000000000000').should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.setErc20TokenContract(erc20Token.address, {from: owner}).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
    });
    it('should fail if erc20TokenContract address is defined but msg.value is not zero', async () => {
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1], value: 1}).should.be.rejectedWith(ERROR_MSG);
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
      await validatorSetAuRa.removeMaliciousValidators([initialValidators[1]], {from: accounts[8]}).should.be.fulfilled;
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
      likelihoodInfo.likelihoods[0].should.be.bignumber.equal(candidateMinStake);
      likelihoodInfo.sum.should.be.bignumber.equal(candidateMinStake);
      await stakingAuRa.stake(initialStakingAddresses[1], delegatorMinStake, {from: delegatorAddress}).should.be.fulfilled;
      likelihoodInfo = await stakingAuRa.getPoolsLikelihood.call();
      likelihoodInfo.likelihoods[0].should.be.bignumber.equal(candidateMinStake.add(delegatorMinStake));
      likelihoodInfo.sum.should.be.bignumber.equal(candidateMinStake.add(delegatorMinStake));
      await stakingAuRa.stake(initialStakingAddresses[1], delegatorMinStake, {from: delegatorAddress}).should.be.fulfilled;
      likelihoodInfo = await stakingAuRa.getPoolsLikelihood.call();
      likelihoodInfo.likelihoods[0].should.be.bignumber.equal(candidateMinStake.add(delegatorMinStake.mul(new BN(2))));
      likelihoodInfo.sum.should.be.bignumber.equal(candidateMinStake.add(delegatorMinStake.mul(new BN(2))));
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

  describe('stakeNative()', async () => {
    let delegatorAddress;
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
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
        4320, // _stakeWithdrawDisallowPeriod
        true // _erc20Restricted
      ).should.be.fulfilled;

      candidateMinStake = await stakingAuRa.candidateMinStake.call();
      delegatorMinStake = await stakingAuRa.delegatorMinStake.call();

      await stakingAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
    });
    it('should place a stake', async () => {
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], initialStakingAddresses[1])).should.be.bignumber.equal(new BN(0));
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(new BN(0));
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: candidateMinStake}).should.be.fulfilled;
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], initialStakingAddresses[1])).should.be.bignumber.equal(candidateMinStake);
      const result = await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: delegatorAddress, value: delegatorMinStake}).should.be.fulfilled;
      result.logs[0].event.should.be.equal("Staked");
      result.logs[0].args.toPoolStakingAddress.should.be.equal(initialStakingAddresses[1]);
      result.logs[0].args.staker.should.be.equal(delegatorAddress);
      result.logs[0].args.stakingEpoch.should.be.bignumber.equal(new BN(0));
      result.logs[0].args.amount.should.be.bignumber.equal(delegatorMinStake);
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(delegatorMinStake);
      (await stakingAuRa.stakeAmountTotal.call(initialStakingAddresses[1])).should.be.bignumber.equal(candidateMinStake.add(delegatorMinStake));
    });
    it('should fail for zero gas price', async () => {
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: candidateMinStake, gasPrice: 0}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: candidateMinStake}).should.be.fulfilled;
    });
    it('should fail if erc20TokenContract address is defined', async () => {
      const erc20Token = await ERC677BridgeTokenRewardable.new("POSDAO20", "POSDAO20", 18, {from: owner});
      await stakingAuRa.setErc20TokenContractMock(erc20Token.address).should.be.fulfilled;
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: candidateMinStake}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.setErc20TokenContractMock('0x0000000000000000000000000000000000000000').should.be.fulfilled;
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: candidateMinStake}).should.be.fulfilled;
    });
    it('should fail if erc20TokenContract address is not defined and erc20 is not restricted', async () => {
      (await stakingAuRa.erc20TokenContract.call()).should.be.equal('0x0000000000000000000000000000000000000000');
      await stakingAuRa.setErc20Restricted(false).should.be.fulfilled;
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: candidateMinStake}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.setErc20Restricted(true).should.be.fulfilled;
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: candidateMinStake}).should.be.fulfilled;
    });
    it('should fail for a non-existing pool', async () => {
      await stakingAuRa.stakeNative(accounts[10], {from: delegatorAddress, value: delegatorMinStake}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.stakeNative('0x0000000000000000000000000000000000000000', {from: delegatorAddress, value: delegatorMinStake}).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail for a zero amount', async () => {
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: candidateMinStake}).should.be.fulfilled;
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: delegatorAddress, value: 0}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: delegatorAddress, value: delegatorMinStake}).should.be.fulfilled;
    });
    it('should fail for a banned validator', async () => {
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: candidateMinStake}).should.be.fulfilled;
      await validatorSetAuRa.setRandomContract(accounts[8]).should.be.fulfilled;
      await validatorSetAuRa.removeMaliciousValidators([initialValidators[1]], {from: accounts[8]}).should.be.fulfilled;
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: delegatorAddress, value: delegatorMinStake}).should.be.rejectedWith(ERROR_MSG);
    });
    it('should only success in the allowed staking window', async () => {
      await stakingAuRa.setCurrentBlockNumber(117000).should.be.fulfilled;
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: candidateMinStake}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: candidateMinStake}).should.be.fulfilled;
    });
    it('should fail if a candidate stakes less than CANDIDATE_MIN_STAKE', async () => {
      const halfOfCandidateMinStake = candidateMinStake.div(new BN(2));
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: halfOfCandidateMinStake}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: candidateMinStake}).should.be.fulfilled;
    });
    it('should fail if a delegator stakes less than DELEGATOR_MIN_STAKE', async () => {
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: candidateMinStake}).should.be.fulfilled;
      const halfOfDelegatorMinStake = delegatorMinStake.div(new BN(2));
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: delegatorAddress, value: halfOfDelegatorMinStake}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: delegatorAddress, value: delegatorMinStake}).should.be.fulfilled;
    });
    it('should fail if a delegator stakes into an empty pool', async () => {
      (await stakingAuRa.stakeAmountMinusOrderedWithdraw.call(initialStakingAddresses[1], initialStakingAddresses[1])).should.be.bignumber.equal(new BN(0));
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: delegatorAddress, value: delegatorMinStake}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: candidateMinStake}).should.be.fulfilled;
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: delegatorAddress, value: delegatorMinStake}).should.be.fulfilled;
    });
    it('should increase a stake amount', async () => {
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: candidateMinStake}).should.be.fulfilled;
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(new BN(0));
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: delegatorAddress, value: delegatorMinStake}).should.be.fulfilled;
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(delegatorMinStake);
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: delegatorAddress, value: delegatorMinStake}).should.be.fulfilled;
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(delegatorMinStake.mul(new BN(2)));
    });
    it('should increase the stakeAmountByCurrentEpoch', async () => {
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: candidateMinStake}).should.be.fulfilled;
      (await stakingAuRa.stakeAmountByCurrentEpoch.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(new BN(0));
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: delegatorAddress, value: delegatorMinStake}).should.be.fulfilled;
      (await stakingAuRa.stakeAmountByCurrentEpoch.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(delegatorMinStake);
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: delegatorAddress, value: delegatorMinStake}).should.be.fulfilled;
      (await stakingAuRa.stakeAmountByCurrentEpoch.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(delegatorMinStake.mul(new BN(2)));
    });
    it('should increase a total stake amount', async () => {
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: candidateMinStake}).should.be.fulfilled;
      (await stakingAuRa.stakeAmountTotal.call(initialStakingAddresses[1])).should.be.bignumber.equal(candidateMinStake);
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: delegatorAddress, value: delegatorMinStake}).should.be.fulfilled;
      (await stakingAuRa.stakeAmountTotal.call(initialStakingAddresses[1])).should.be.bignumber.equal(candidateMinStake.add(delegatorMinStake));
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: delegatorAddress, value: delegatorMinStake}).should.be.fulfilled;
      (await stakingAuRa.stakeAmountTotal.call(initialStakingAddresses[1])).should.be.bignumber.equal(candidateMinStake.add(delegatorMinStake.mul(new BN(2))));
    });
    it('should add a delegator to the pool', async () => {
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: candidateMinStake}).should.be.fulfilled;
      (await stakingAuRa.poolDelegators.call(initialStakingAddresses[1])).length.should.be.equal(0);
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: delegatorAddress, value: delegatorMinStake}).should.be.fulfilled;
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: delegatorAddress, value: delegatorMinStake}).should.be.fulfilled;
      (await stakingAuRa.poolDelegators.call(initialStakingAddresses[1])).should.be.deep.equal([delegatorAddress]);
    });
    it('should update pool\'s likelihood', async () => {
      let likelihoodInfo = await stakingAuRa.getPoolsLikelihood.call();
      likelihoodInfo.likelihoods.length.should.be.equal(0);
      likelihoodInfo.sum.should.be.bignumber.equal(new BN(0));
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: candidateMinStake}).should.be.fulfilled;
      likelihoodInfo = await stakingAuRa.getPoolsLikelihood.call();
      likelihoodInfo.likelihoods[0].should.be.bignumber.equal(candidateMinStake);
      likelihoodInfo.sum.should.be.bignumber.equal(candidateMinStake);
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: delegatorAddress, value: delegatorMinStake}).should.be.fulfilled;
      likelihoodInfo = await stakingAuRa.getPoolsLikelihood.call();
      likelihoodInfo.likelihoods[0].should.be.bignumber.equal(candidateMinStake.add(delegatorMinStake));
      likelihoodInfo.sum.should.be.bignumber.equal(candidateMinStake.add(delegatorMinStake));
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: delegatorAddress, value: delegatorMinStake}).should.be.fulfilled;
      likelihoodInfo = await stakingAuRa.getPoolsLikelihood.call();
      likelihoodInfo.likelihoods[0].should.be.bignumber.equal(candidateMinStake.add(delegatorMinStake.mul(new BN(2))));
      likelihoodInfo.sum.should.be.bignumber.equal(candidateMinStake.add(delegatorMinStake.mul(new BN(2))));
    });
    it('should decrease the balance of the staker and increase the balance of the Staking contract', async () => {
      (await web3.eth.getBalance(stakingAuRa.address)).should.be.equal('0');
      const initialBalance = new BN(await web3.eth.getBalance(initialStakingAddresses[1]));
      await stakingAuRa.stakeNative(initialStakingAddresses[1], {from: initialStakingAddresses[1], value: candidateMinStake}).should.be.fulfilled;
      (new BN(await web3.eth.getBalance(initialStakingAddresses[1]))).should.be.bignumber.below(initialBalance.sub(candidateMinStake));
      (new BN(await web3.eth.getBalance(stakingAuRa.address))).should.be.bignumber.equal(candidateMinStake);
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
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.fulfilled;
      await stakingAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
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
  });

  describe('removeMyPool()', async () => {
    beforeEach(async () => {
      // Initialize Staking
      await stakingAuRa.initialize(
        validatorSetAuRa.address, // _validatorSetContract
        initialStakingAddresses, // _initialStakingAddresses
        1, // _delegatorMinStake
        1, // _candidateMinStake
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.fulfilled;
      await stakingAuRa.setCurrentBlockNumber(100).should.be.fulfilled;
    });

    it('should fail for zero gas price', async () => {
      await stakingAuRa.setValidatorSetAddress(accounts[7]).should.be.fulfilled;
      await stakingAuRa.incrementStakingEpoch({from: accounts[7]}).should.be.fulfilled;
      await stakingAuRa.setValidatorSetAddress(validatorSetAuRa.address).should.be.fulfilled;
      await stakingAuRa.removeMyPool({from: initialStakingAddresses[0], gasPrice: 0}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.removeMyPool({from: initialStakingAddresses[0]}).should.be.fulfilled;
    });
    it('should fail if Staking contract is not initialized', async () => {
      await stakingAuRa.setValidatorSetAddress(accounts[7]).should.be.fulfilled;
      await stakingAuRa.incrementStakingEpoch({from: accounts[7]}).should.be.fulfilled;
      await stakingAuRa.setValidatorSetAddress('0x0000000000000000000000000000000000000000').should.be.fulfilled;
      await stakingAuRa.removeMyPool({from: initialStakingAddresses[0]}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.setValidatorSetAddress(validatorSetAuRa.address).should.be.fulfilled;
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
      stakingAuRa = await AdminUpgradeabilityProxy.new(stakingAuRa.address, owner, []);
      stakingAuRa = await StakingAuRa.at(stakingAuRa.address);

      // Deploy ValidatorSet contract
      validatorSetAuRa = await ValidatorSetAuRa.new();
      validatorSetAuRa = await AdminUpgradeabilityProxy.new(validatorSetAuRa.address, owner, []);
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
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
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

  describe('withdraw()', async () => {
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
        120954, // _stakingEpochDuration
        0, // _stakingEpochStartBlock
        4320, // _stakeWithdrawDisallowPeriod
        false // _erc20Restricted
      ).should.be.fulfilled;

      candidateMinStake = await stakingAuRa.candidateMinStake.call();
      delegatorMinStake = await stakingAuRa.delegatorMinStake.call();

      // Deploy ERC20 contract
      erc20Token = await ERC677BridgeTokenRewardable.new("POSDAO20", "POSDAO20", 18, {from: owner});

      // Mint some balance for delegator and candidates (imagine that they got some STAKE_UNITs from a bridge)
      const stakeUnit = await stakingAuRa.STAKE_UNIT.call();
      mintAmount = stakeUnit.mul(new BN(2));
      await erc20Token.mint(initialStakingAddresses[0], mintAmount, {from: owner}).should.be.fulfilled;
      await erc20Token.mint(initialStakingAddresses[1], mintAmount, {from: owner}).should.be.fulfilled;
      await erc20Token.mint(initialStakingAddresses[2], mintAmount, {from: owner}).should.be.fulfilled;
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

    it('should withdraw a stake', async () => {
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], initialStakingAddresses[1])).should.be.bignumber.equal(new BN(0));
      (await stakingAuRa.stakeAmountByCurrentEpoch.call(initialStakingAddresses[1], initialStakingAddresses[1])).should.be.bignumber.equal(new BN(0));
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(new BN(0));
      (await stakingAuRa.stakeAmountByCurrentEpoch.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(new BN(0));
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], initialStakingAddresses[1])).should.be.bignumber.equal(mintAmount);
      (await stakingAuRa.stakeAmountByCurrentEpoch.call(initialStakingAddresses[1], initialStakingAddresses[1])).should.be.bignumber.equal(mintAmount);
      (await erc20Token.balanceOf.call(initialStakingAddresses[1])).should.be.bignumber.equal(new BN(0));

      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: delegatorAddress}).should.be.fulfilled;
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(mintAmount);
      (await stakingAuRa.stakeAmountByCurrentEpoch.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(mintAmount);
      (await stakingAuRa.stakeAmountTotal.call(initialStakingAddresses[1])).should.be.bignumber.equal(mintAmount.mul(new BN(2)));
      (await erc20Token.balanceOf.call(delegatorAddress)).should.be.bignumber.equal(new BN(0));

      const result = await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount, {from: delegatorAddress}).should.be.fulfilled;
      result.logs[0].event.should.be.equal("Withdrawn");
      result.logs[0].args.fromPoolStakingAddress.should.be.equal(initialStakingAddresses[1]);
      result.logs[0].args.staker.should.be.equal(delegatorAddress);
      result.logs[0].args.stakingEpoch.should.be.bignumber.equal(new BN(0));
      result.logs[0].args.amount.should.be.bignumber.equal(mintAmount);
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(new BN(0));
      (await stakingAuRa.stakeAmountByCurrentEpoch.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(new BN(0));
      (await stakingAuRa.stakeAmountTotal.call(initialStakingAddresses[1])).should.be.bignumber.equal(mintAmount);
      (await erc20Token.balanceOf.call(delegatorAddress)).should.be.bignumber.equal(mintAmount);
    });
    it('should fail for zero gas price', async () => {
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1], gasPrice: 0}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
    });
    it('should fail if not initialized', async () => {
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      await stakingAuRa.setValidatorSetAddress('0x0000000000000000000000000000000000000000').should.be.fulfilled;
      await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.setValidatorSetAddress(validatorSetAuRa.address).should.be.fulfilled;
      await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
    });
    it('should fail for a zero pool address', async () => {
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      await stakingAuRa.withdraw('0x0000000000000000000000000000000000000000', mintAmount, {from: initialStakingAddresses[1]}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
    });
    it('should fail for a zero amount', async () => {
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      await stakingAuRa.withdraw(initialStakingAddresses[1], new BN(0), {from: initialStakingAddresses[1]}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
    });
    it('shouldn\'t allow withdrawing from a banned pool', async () => {
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: delegatorAddress}).should.be.fulfilled;
      await validatorSetAuRa.setBannedUntil(initialValidators[1], 100).should.be.fulfilled;
      await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount, {from: delegatorAddress}).should.be.rejectedWith(ERROR_MSG);
      await validatorSetAuRa.setBannedUntil(initialValidators[1], 0).should.be.fulfilled;
      await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount, {from: delegatorAddress}).should.be.fulfilled;
    });
    it('shouldn\'t allow withdrawing during the stakeWithdrawDisallowPeriod', async () => {
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      await stakingAuRa.setCurrentBlockNumber(117000).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(117000).should.be.fulfilled;
      await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.setCurrentBlockNumber(116000).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(116000).should.be.fulfilled;
      await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
    });
    it('should fail if non-zero residue is less than CANDIDATE_MIN_STAKE', async () => {
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount.sub(candidateMinStake).add(new BN(1)), {from: initialStakingAddresses[1]}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount.sub(candidateMinStake), {from: initialStakingAddresses[1]}).should.be.fulfilled;
      await stakingAuRa.withdraw(initialStakingAddresses[1], candidateMinStake, {from: initialStakingAddresses[1]}).should.be.fulfilled;
    });
    it('should fail if non-zero residue is less than DELEGATOR_MIN_STAKE', async () => {
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: delegatorAddress}).should.be.fulfilled;
      await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount.sub(delegatorMinStake).add(new BN(1)), {from: delegatorAddress}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount.sub(delegatorMinStake), {from: delegatorAddress}).should.be.fulfilled;
      await stakingAuRa.withdraw(initialStakingAddresses[1], delegatorMinStake, {from: delegatorAddress}).should.be.fulfilled;
    });
    it('should fail if withdraw more than staked', async () => {
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount.add(new BN(1)), {from: initialStakingAddresses[1]}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
    });
    it('should fail if withdraw already ordered amount', async () => {
      // Set `initiateChangeAllowed` boolean flag to `true`
      await validatorSetAuRa.setCurrentBlockNumber(1).should.be.fulfilled;
      await validatorSetAuRa.setSystemAddress(owner).should.be.fulfilled;
      await validatorSetAuRa.finalizeChange({from: owner}).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(100).should.be.fulfilled;

      // Place a stake during the initial staking epoch
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(new BN(0));
      await stakingAuRa.stake(initialStakingAddresses[0], mintAmount, {from: initialStakingAddresses[0]}).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[2], mintAmount, {from: initialStakingAddresses[2]}).should.be.fulfilled;
      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: delegatorAddress}).should.be.fulfilled;

      // Change staking epoch
      await stakingAuRa.setCurrentBlockNumber(120954).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120954).should.be.fulfilled;
      await validatorSetAuRa.setBlockRewardContract(accounts[7]).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: accounts[7]}).should.be.fulfilled;
      await validatorSetAuRa.setBlockRewardContract(blockRewardAuRa.address).should.be.fulfilled;
      await stakingAuRa.setCurrentBlockNumber(120970).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120970).should.be.fulfilled;
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(new BN(1));

      // Finalize a new validator set
      await blockRewardAuRa.initialize(validatorSetAuRa.address).should.be.fulfilled;
      await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
      await validatorSetAuRa.finalizeChange({from: owner}).should.be.fulfilled;

      // Order withdrawal
      const orderedAmount = mintAmount.div(new BN(4));
      await stakingAuRa.orderWithdraw(initialStakingAddresses[1], orderedAmount, {from: delegatorAddress}).should.be.fulfilled;

      // The second validator removes their pool
      (await validatorSetAuRa.isValidator.call(initialValidators[1])).should.be.equal(true);
      (await stakingAuRa.getPoolsInactive.call()).length.should.be.equal(0);
      await stakingAuRa.removeMyPool({from: initialStakingAddresses[1]}).should.be.fulfilled;
      (await stakingAuRa.getPoolsInactive.call()).should.be.deep.equal([initialStakingAddresses[1]]);

      // Change staking epoch and enqueue pending validators
      await stakingAuRa.setCurrentBlockNumber(120954*2).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120954*2).should.be.fulfilled;
      await validatorSetAuRa.setBlockRewardContract(accounts[7]).should.be.fulfilled;
      await validatorSetAuRa.newValidatorSet({from: accounts[7]}).should.be.fulfilled;
      await validatorSetAuRa.setBlockRewardContract(blockRewardAuRa.address).should.be.fulfilled;
      await stakingAuRa.setCurrentBlockNumber(120970*2).should.be.fulfilled;
      await validatorSetAuRa.setCurrentBlockNumber(120970*2).should.be.fulfilled;
      (await stakingAuRa.stakingEpoch.call()).should.be.bignumber.equal(new BN(2));

      // Finalize a new validator set
      await validatorSetAuRa.emitInitiateChange().should.be.fulfilled;
      await validatorSetAuRa.finalizeChange({from: owner}).should.be.fulfilled;
      (await validatorSetAuRa.isValidator.call(initialValidators[1])).should.be.equal(false);

      // Check withdrawal for a delegator
      const restOfAmount = mintAmount.mul(new BN(3)).div(new BN(4));
      (await stakingAuRa.poolDelegators.call(initialStakingAddresses[1])).should.be.deep.equal([delegatorAddress]);
      (await stakingAuRa.stakeAmountMinusOrderedWithdraw.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(restOfAmount);
      (await stakingAuRa.stakeAmountByCurrentEpoch.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(new BN(0));
      await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount, {from: delegatorAddress}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.withdraw(initialStakingAddresses[1], restOfAmount.add(new BN(1)), {from: delegatorAddress}).should.be.rejectedWith(ERROR_MSG);
      await stakingAuRa.withdraw(initialStakingAddresses[1], restOfAmount, {from: delegatorAddress}).should.be.fulfilled;
      (await stakingAuRa.stakeAmountByCurrentEpoch.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(new BN(0));
      (await stakingAuRa.stakeAmountMinusOrderedWithdraw.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(new BN(0));
      (await stakingAuRa.stakeAmount.call(initialStakingAddresses[1], delegatorAddress)).should.be.bignumber.equal(orderedAmount);
      (await stakingAuRa.poolDelegators.call(initialStakingAddresses[1])).length.should.be.equal(0);
      (await stakingAuRa.poolDelegatorsInactive.call(initialStakingAddresses[1])).should.be.deep.equal([delegatorAddress]);
    });
    it('should decrease likelihood', async () => {
      let likelihoodInfo = await stakingAuRa.getPoolsLikelihood.call();
      likelihoodInfo.sum.should.be.bignumber.equal(new BN(0));

      await stakingAuRa.stake(initialStakingAddresses[1], mintAmount, {from: initialStakingAddresses[1]}).should.be.fulfilled;

      likelihoodInfo = await stakingAuRa.getPoolsLikelihood.call();
      likelihoodInfo.likelihoods[0].should.be.bignumber.equal(mintAmount);
      likelihoodInfo.sum.should.be.bignumber.equal(mintAmount);

      await stakingAuRa.withdraw(initialStakingAddresses[1], mintAmount.div(new BN(2)), {from: initialStakingAddresses[1]}).should.be.fulfilled;

      likelihoodInfo = await stakingAuRa.getPoolsLikelihood.call();
      likelihoodInfo.likelihoods[0].should.be.bignumber.equal(mintAmount.div(new BN(2)));
      likelihoodInfo.sum.should.be.bignumber.equal(mintAmount.div(new BN(2)));
    });
    // TODO: add unit tests for native coin withdrawal
  });

  // TODO: ...add other tests...

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
    const {logs} = await blockRewardAuRa.reward([validators[0]], [0], {from: owner}).should.be.fulfilled;
    
    // Emulate minting native coins
    logs[0].event.should.be.equal("MintedNative");
    const receivers = logs[0].args.receivers;
    const rewards = logs[0].args.rewards;
    for (let i = 0; i < receivers.length; i++) {
      await blockRewardAuRa.sendCoins({from: owner, value: rewards[i]}).should.be.fulfilled;
    }

    await blockRewardAuRa.setSystemAddress('0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE').should.be.fulfilled;
  }

  async function setCurrentBlockNumber(blockNumber) {
    await blockRewardAuRa.setCurrentBlockNumber(blockNumber).should.be.fulfilled;
    await randomAuRa.setCurrentBlockNumber(blockNumber).should.be.fulfilled;
    await stakingAuRa.setCurrentBlockNumber(blockNumber).should.be.fulfilled;
    await validatorSetAuRa.setCurrentBlockNumber(blockNumber).should.be.fulfilled;
  }
});

function random(low, high) {
  return Math.floor(Math.random() * (high - low) + low);
}

function shuffle(a) {
  var j, x, i;
  for (i = a.length - 1; i > 0; i--) {
    j = Math.floor(Math.random() * (i + 1));
    x = a[i];
    a[i] = a[j];
    a[j] = x;
  }
  return a;
}
