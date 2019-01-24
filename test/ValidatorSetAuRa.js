const EternalStorageProxy = artifacts.require('EternalStorageProxy');
const ValidatorSetAuRa = artifacts.require('ValidatorSetAuRaMock');

const ERROR_MSG = 'VM Exception while processing transaction: revert';
const BN = web3.utils.BN;

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bn')(BN))
  .should();

contract('ValidatorSetAuRa', async accounts => {
  describe('initialize()', async () => {
    let validatorSetAuRa;

    const initialValidators = [
      '0xeE385a1df869A468883107B0C06fA8791b28A04f',
      '0x71385ae87C4b93DB96f02F952Be1F7A63F6057a6',
      '0x190EC582090aE24284989aF812F6B2c93F768ECd'
    ];

    beforeEach(async () => {
      validatorSetAuRa = await ValidatorSetAuRa.new();
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
        200 // _stakingEpochDuration
      ).should.be.fulfilled;
      new BN(200).should.be.bignumber.equal(
        await validatorSetAuRa.stakingEpochDuration.call()
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
        200 // _stakingEpochDuration
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
        200 // _stakingEpochDuration
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
        200 // _stakingEpochDuration
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
        200 // _stakingEpochDuration
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
        200 // _stakingEpochDuration
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
        200 // _stakingEpochDuration
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
        200 // _stakingEpochDuration
      ).should.be.fulfilled;
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialValidators
        1, // _delegatorMinStake
        1, // _candidateMinStake
        200 // _stakingEpochDuration
      ).should.be.rejectedWith(ERROR_MSG);
    });
    it('should fail if stakingEpochDuration is less than 28', async () => {
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialValidators
        1, // _delegatorMinStake
        1, // _candidateMinStake
        27 // _stakingEpochDuration
      ).should.be.rejectedWith(ERROR_MSG);
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        initialValidators, // _initialValidators
        1, // _delegatorMinStake
        1, // _candidateMinStake
        28 // _stakingEpochDuration
      ).should.be.fulfilled;
    });
  });
});
