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
    // Initialize Governance
    await governance.initialize(validatorSetAuRa.address);
    await governance.setCurrentBlockNumber(currentBlockNumber).should.be.fulfilled;
  });

  describe('create()', async () => {
    it('should create a new ballot', async () => {
      const targetPoolId = initialPoolIds[initialValidators.length - 1];
      const reason = web3.utils.toHex("unrevealed");
      await governance.create(targetPoolId, 17280, reason, 0, { from: initialStakingAddresses[0] }).should.be.fulfilled;
      const ballot = await governance.getBallot(1);
      ballot._poolId.should.be.bignumber.equal(targetPoolId);
      ballot._creatorPoolId.should.be.bignumber.equal(initialPoolIds[0]);
      ballot._reason.should.be.equal(web3.utils.padRight(reason, 64));
      ballot._status.should.be.bignumber.equal(new BN(1));
    });
  });
});
