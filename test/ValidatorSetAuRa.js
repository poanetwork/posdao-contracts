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

    beforeEach(async () => {
      validatorSetAuRa = await ValidatorSetAuRa.new();
    });
    it('should initialize successfully', async () => {
      await validatorSetAuRa.setCurrentBlockNumber(0);
      await validatorSetAuRa.initialize(
        '0x2000000000000000000000000000000000000001', // _blockRewardContract
        '0x3000000000000000000000000000000000000001', // _randomContract
        '0x0000000000000000000000000000000000000000', // _erc20TokenContract
        [ // _initialValidators
          '0xeE385a1df869A468883107B0C06fA8791b28A04f',
          '0x71385ae87C4b93DB96f02F952Be1F7A63F6057a6',
          '0x190EC582090aE24284989aF812F6B2c93F768ECd'
        ],
        1, // _delegatorMinStake
        1, // _validatorMinStake
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
      (await validatorSetAuRa.getValidators.call()).should.be.deep.equal([
        '0xeE385a1df869A468883107B0C06fA8791b28A04f',
        '0x71385ae87C4b93DB96f02F952Be1F7A63F6057a6',
        '0x190EC582090aE24284989aF812F6B2c93F768ECd'
      ]);
      (await validatorSetAuRa.getValidators.call()).should.be.deep.equal(
        await validatorSetAuRa.getPendingValidators.call()
      );
      new BN(0).should.be.bignumber.equal(
        await validatorSetAuRa.validatorIndex.call('0xeE385a1df869A468883107B0C06fA8791b28A04f')
      );
      new BN(1).should.be.bignumber.equal(
        await validatorSetAuRa.validatorIndex.call('0x71385ae87C4b93DB96f02F952Be1F7A63F6057a6')
      );
      new BN(2).should.be.bignumber.equal(
        await validatorSetAuRa.validatorIndex.call('0x190EC582090aE24284989aF812F6B2c93F768ECd')
      );
      true.should.be.equal(
        await validatorSetAuRa.isValidator.call('0xeE385a1df869A468883107B0C06fA8791b28A04f')
      );
      true.should.be.equal(
        await validatorSetAuRa.isValidator.call('0x71385ae87C4b93DB96f02F952Be1F7A63F6057a6')
      );
      true.should.be.equal(
        await validatorSetAuRa.isValidator.call('0x190EC582090aE24284989aF812F6B2c93F768ECd')
      );
      false.should.be.equal(
        await validatorSetAuRa.isValidator.call('0x0000000000000000000000000000000000000000')
      );
      (await validatorSetAuRa.getValidators.call()).should.be.deep.equal(
        await validatorSetAuRa.getPools.call()
      );
      new BN(0).should.be.bignumber.equal(
        await validatorSetAuRa.poolIndex.call('0xeE385a1df869A468883107B0C06fA8791b28A04f')
      );
      new BN(1).should.be.bignumber.equal(
        await validatorSetAuRa.poolIndex.call('0x71385ae87C4b93DB96f02F952Be1F7A63F6057a6')
      );
      new BN(2).should.be.bignumber.equal(
        await validatorSetAuRa.poolIndex.call('0x190EC582090aE24284989aF812F6B2c93F768ECd')
      );
      true.should.be.equal(
        await validatorSetAuRa.isPoolActive.call('0xeE385a1df869A468883107B0C06fA8791b28A04f')
      );
      true.should.be.equal(
        await validatorSetAuRa.isPoolActive.call('0x71385ae87C4b93DB96f02F952Be1F7A63F6057a6')
      );
      true.should.be.equal(
        await validatorSetAuRa.isPoolActive.call('0x190EC582090aE24284989aF812F6B2c93F768ECd')
      );
      new BN(web3.utils.toWei('1', 'ether')).should.be.bignumber.equal(
        await validatorSetAuRa.getDelegatorMinStake.call()
      );
      new BN(web3.utils.toWei('1', 'ether')).should.be.bignumber.equal(
        await validatorSetAuRa.getValidatorMinStake.call()
      );
      new BN(1).should.be.bignumber.equal(
        await validatorSetAuRa.validatorSetApplyBlock.call()
      );
    });
  });
});
