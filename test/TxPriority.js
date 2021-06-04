const TxPriorityMock = artifacts.require('TxPriorityMock');

const ERROR_MSG = 'VM Exception while processing transaction: revert';
const BN = web3.utils.BN;

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bn')(BN))
  .should();

contract('TxPriority', async accounts => {
  let owner;
  let txPriority;

  beforeEach(async () => {
    owner = accounts[0];
    txPriority = await TxPriorityMock.new(owner, false);
  });

  describe('setPriority()', async () => {
  	it('should add a destination', async () => {
      const target = accounts[1];
      const fnSignature = '0x12345678';
      const weight = '1000';
      let weights = await txPriority.getPriorities.call();
      weights.length.should.be.equal(0);
      (await txPriority.weightExistsInTree.call(weight)).should.be.equal(false);
      const { logs } = await txPriority.setPriority(target, fnSignature, weight).should.be.fulfilled;
      logs[0].event.should.be.equal('PrioritySet');
      logs[0].args.target.should.be.equal(target);
      logs[0].args.fnSignature.should.be.equal(web3.utils.padRight(fnSignature, 64));
      logs[0].args.weight.should.be.bignumber.equal(new BN(weight));
      weights = await txPriority.getPriorities.call();
      weights.length.should.be.equal(1);
      (await txPriority.weightsCount.call()).should.be.bignumber.equal(new BN(1));
      weights[0].target.should.be.equal(target);
      weights[0].fnSignature.should.be.equal(fnSignature);
      weights[0].value.should.be.equal(weight);
      (await txPriority.weightExistsInTree.call(weight)).should.be.equal(true);
      (await txPriority.firstWeightInTree.call()).should.be.bignumber.equal(new BN(weight));
      (await txPriority.lastWeightInTree.call()).should.be.bignumber.equal(new BN(weight));
      (await txPriority.nextWeightInTree.call(weight)).should.be.bignumber.equal(new BN(0));
      (await txPriority.prevWeightInTree.call(weight)).should.be.bignumber.equal(new BN(0));
    });
    it('should fail when target address is zero', async () => {
      const target = '0x0000000000000000000000000000000000000000';
      const fnSignature = '0x12345678';
      const weight = '1000';
      await txPriority.setPriority(target, fnSignature, weight).should.be.rejectedWith('target cannot be 0');
    });
    it('should fail when weight is zero', async () => {
      const target = accounts[1];
      const fnSignature = '0x12345678';
      const weight = '0';
      await txPriority.setPriority(target, fnSignature, weight).should.be.rejectedWith('weight cannot be 0');
    });
    it('shouldn`t change anything if destination with the same weight already exists', async () => {
      const target = accounts[1];
      const fnSignature = '0x12345678';
      const weight = '1000';
      await txPriority.setPriority(target, fnSignature, weight).should.be.fulfilled;

      let destinationByWeight = await txPriority.destinationByWeight.call(weight);
      destinationByWeight.target.should.be.equal(target);
      destinationByWeight.fnSignature.should.be.equal(fnSignature);
      destinationByWeight.value.should.be.bignumber.equal(new BN(weight));
      weight.should.be.equal((await txPriority.weightByDestination.call(target, fnSignature)).toString());
      let weights = await txPriority.getPriorities.call();
      weights.length.should.be.equal(1);
      weights[0].target.should.be.equal(target);
      weights[0].fnSignature.should.be.equal(fnSignature);
      weights[0].value.should.be.equal(weight);

      const { logs } = await txPriority.setPriority(target, fnSignature, weight).should.be.fulfilled;
      logs[0].event.should.be.equal('PrioritySet');
      logs[0].args.target.should.be.equal(target);
      logs[0].args.fnSignature.should.be.equal(web3.utils.padRight(fnSignature, 64));
      logs[0].args.weight.should.be.bignumber.equal(new BN(weight));

      destinationByWeight = await txPriority.destinationByWeight.call(weight);
      destinationByWeight.target.should.be.equal(target);
      destinationByWeight.fnSignature.should.be.equal(fnSignature);
      destinationByWeight.value.should.be.bignumber.equal(new BN(weight));
      weight.should.be.equal((await txPriority.weightByDestination.call(target, fnSignature)).toString());
      weights = await txPriority.getPriorities.call();
      weights.length.should.be.equal(1);
      weights[0].target.should.be.equal(target);
      weights[0].fnSignature.should.be.equal(fnSignature);
      weights[0].value.should.be.equal(weight);

      (await txPriority.weightExistsInTree.call(weight)).should.be.equal(true);
      (await txPriority.firstWeightInTree.call()).should.be.bignumber.equal(new BN(weight));
      (await txPriority.lastWeightInTree.call()).should.be.bignumber.equal(new BN(weight));
      (await txPriority.nextWeightInTree.call(weight)).should.be.bignumber.equal(new BN(0));
      (await txPriority.prevWeightInTree.call(weight)).should.be.bignumber.equal(new BN(0));
    });
    it('should update existing destination weight', async () => {
      const target = accounts[1];
      const fnSignature = '0x12345678';
      const weight = '1000';
      const newWeight = '2000';
      
      await txPriority.setPriority(target, fnSignature, weight).should.be.fulfilled;
      
      let destinationByWeight = await txPriority.destinationByWeight.call(weight);
      destinationByWeight.target.should.be.equal(target);
      destinationByWeight.fnSignature.should.be.equal(fnSignature);
      destinationByWeight.value.should.be.bignumber.equal(new BN(weight));
      destinationByWeight = await txPriority.destinationByWeight.call(newWeight);
      destinationByWeight.target.should.be.equal('0x0000000000000000000000000000000000000000');
      destinationByWeight.fnSignature.should.be.equal('0x00000000');
      destinationByWeight.value.should.be.bignumber.equal(new BN(0));
      weight.should.be.equal((await txPriority.weightByDestination.call(target, fnSignature)).toString());
      
      await txPriority.setPriority(target, fnSignature, newWeight).should.be.fulfilled;

      destinationByWeight = await txPriority.destinationByWeight.call(newWeight);
      destinationByWeight.target.should.be.equal(target);
      destinationByWeight.fnSignature.should.be.equal(fnSignature);
      destinationByWeight.value.should.be.bignumber.equal(new BN(newWeight));
      destinationByWeight = await txPriority.destinationByWeight.call(weight);
      destinationByWeight.target.should.be.equal('0x0000000000000000000000000000000000000000');
      destinationByWeight.fnSignature.should.be.equal('0x00000000');
      destinationByWeight.value.should.be.bignumber.equal(new BN(0));
      newWeight.should.be.equal((await txPriority.weightByDestination.call(target, fnSignature)).toString());

      const weights = await txPriority.getPriorities.call();
      weights.length.should.be.equal(1);
      (await txPriority.weightsCount.call()).should.be.bignumber.equal(new BN(1));

      (await txPriority.weightExistsInTree.call(weight)).should.be.equal(false);
      (await txPriority.weightExistsInTree.call(newWeight)).should.be.equal(true);
      (await txPriority.firstWeightInTree.call()).should.be.bignumber.equal(new BN(newWeight));
      (await txPriority.lastWeightInTree.call()).should.be.bignumber.equal(new BN(newWeight));
      (await txPriority.nextWeightInTree.call(newWeight)).should.be.bignumber.equal(new BN(0));
      (await txPriority.prevWeightInTree.call(newWeight)).should.be.bignumber.equal(new BN(0));
    });
    it('should add a new destination with a unique weight', async () => {
      const target = accounts[1];
      const fnSignature1 = '0x12345678';
      const fnSignature2 = '0x12345679';
      const weight1 = '1000';
      const weight2 = '1001';
      
      await txPriority.setPriority(target, fnSignature1, weight1).should.be.fulfilled;
      await txPriority.setPriority(target, fnSignature2, weight1).should.be.rejectedWith(ERROR_MSG)
      await txPriority.setPriority(target, fnSignature2, weight2).should.be.fulfilled;

      const weights = await txPriority.getPriorities.call();
      weights.length.should.be.equal(2);
      weights[0].target.should.be.equal(target);
      weights[0].fnSignature.should.be.equal(fnSignature2);
      weights[0].value.should.be.equal(weight2);
      weights[1].target.should.be.equal(target);
      weights[1].fnSignature.should.be.equal(fnSignature1);
      weights[1].value.should.be.equal(weight1);
      (await txPriority.weightsCount.call()).should.be.bignumber.equal(new BN(2));

      let destinationByWeight = await txPriority.destinationByWeight.call(weight1);
      destinationByWeight.target.should.be.equal(target);
      destinationByWeight.fnSignature.should.be.equal(fnSignature1);
      destinationByWeight.value.should.be.bignumber.equal(new BN(weight1));
      weight1.should.be.equal((await txPriority.weightByDestination.call(target, fnSignature1)).toString());

      destinationByWeight = await txPriority.destinationByWeight.call(weight2);
      destinationByWeight.target.should.be.equal(target);
      destinationByWeight.fnSignature.should.be.equal(fnSignature2);
      destinationByWeight.value.should.be.bignumber.equal(new BN(weight2));
      weight2.should.be.equal((await txPriority.weightByDestination.call(target, fnSignature2)).toString());

      (await txPriority.weightExistsInTree.call(weight1)).should.be.equal(true);
      (await txPriority.weightExistsInTree.call(weight2)).should.be.equal(true);
      (await txPriority.firstWeightInTree.call()).should.be.bignumber.equal(new BN(weight1));
      (await txPriority.lastWeightInTree.call()).should.be.bignumber.equal(new BN(weight2));
      (await txPriority.nextWeightInTree.call(weight1)).should.be.bignumber.equal(new BN(weight2));
      (await txPriority.prevWeightInTree.call(weight1)).should.be.bignumber.equal(new BN(0));
      (await txPriority.nextWeightInTree.call(weight2)).should.be.bignumber.equal(new BN(0));
      (await txPriority.prevWeightInTree.call(weight2)).should.be.bignumber.equal(new BN(weight1));
    });
    it('can only be called by an owner', async () => {
      const target = accounts[1];
      const fnSignature = '0x12345678';
      const weight = '1000';
      await txPriority.setPriority(target, fnSignature, weight, { from: accounts[2] }).should.be.rejectedWith('caller is not the owner');
      await txPriority.setPriority(target, fnSignature, weight, { from: owner }).should.be.fulfilled;
    });
  });

  describe('removePriority()', async () => {
    it('should remove a destination', async () => {
      const target = accounts[1];
      const fnSignature = '0x12345678';
      const weight = '1000';
      
      await txPriority.setPriority(target, fnSignature, weight).should.be.fulfilled;

      let weights = await txPriority.getPriorities.call();
      weights.length.should.be.equal(1);
      (await txPriority.weightsCount.call()).should.be.bignumber.equal(new BN(1));
      weights[0].target.should.be.equal(target);
      weights[0].fnSignature.should.be.equal(fnSignature);
      weights[0].value.should.be.equal(weight);
      (await txPriority.weightExistsInTree.call(weight)).should.be.equal(true);
      (await txPriority.firstWeightInTree.call()).should.be.bignumber.equal(new BN(weight));
      (await txPriority.lastWeightInTree.call()).should.be.bignumber.equal(new BN(weight));
      (await txPriority.nextWeightInTree.call(weight)).should.be.bignumber.equal(new BN(0));
      (await txPriority.prevWeightInTree.call(weight)).should.be.bignumber.equal(new BN(0));
      let destinationByWeight = await txPriority.destinationByWeight.call(weight);
      destinationByWeight.target.should.be.equal(target);
      destinationByWeight.fnSignature.should.be.equal(fnSignature);
      destinationByWeight.value.should.be.bignumber.equal(new BN(weight));
      weight.should.be.equal((await txPriority.weightByDestination.call(target, fnSignature)).toString());
      
      const { logs } = await txPriority.removePriority(target, fnSignature).should.be.fulfilled;
      logs[0].event.should.be.equal('PrioritySet');
      logs[0].args.target.should.be.equal(target);
      logs[0].args.fnSignature.should.be.equal(web3.utils.padRight(fnSignature, 64));
      logs[0].args.weight.should.be.bignumber.equal(new BN(0));

      weights = await txPriority.getPriorities.call();
      weights.length.should.be.equal(0);
      (await txPriority.weightsCount.call()).should.be.bignumber.equal(new BN(0));
      (await txPriority.weightExistsInTree.call(weight)).should.be.equal(false);
      (await txPriority.firstWeightInTree.call()).should.be.bignumber.equal(new BN(0));
      (await txPriority.lastWeightInTree.call()).should.be.bignumber.equal(new BN(0));
      destinationByWeight = await txPriority.destinationByWeight.call(weight);
      destinationByWeight.target.should.be.equal('0x0000000000000000000000000000000000000000');
      destinationByWeight.fnSignature.should.be.equal('0x00000000');
      destinationByWeight.value.should.be.bignumber.equal(new BN(0));
      (await txPriority.weightByDestination.call(target, fnSignature)).toString().should.be.equal('0');
    });
    it('should remove a specified destination', async () => {
      const target1 = accounts[1];
      const target2 = accounts[2];
      const target3 = accounts[3];
      const fnSignature1 = '0x12345671';
      const fnSignature2 = '0x12345672';
      const fnSignature3 = '0x12345673';
      const weight1 = '1001';
      const weight2 = '1002';
      const weight3 = '1003';

      await txPriority.setPriority(target1, fnSignature1, weight1).should.be.fulfilled;
      await txPriority.setPriority(target2, fnSignature2, weight2).should.be.fulfilled;
      await txPriority.setPriority(target3, fnSignature3, weight3).should.be.fulfilled;

      let weights = await txPriority.getPriorities.call();
      weights.length.should.be.equal(3);
      (await txPriority.weightsCount.call()).should.be.bignumber.equal(new BN(3));
      weights[0].target.should.be.equal(target3);
      weights[0].fnSignature.should.be.equal(fnSignature3);
      weights[0].value.should.be.equal(weight3);
      weights[1].target.should.be.equal(target2);
      weights[1].fnSignature.should.be.equal(fnSignature2);
      weights[1].value.should.be.equal(weight2);
      weights[2].target.should.be.equal(target1);
      weights[2].fnSignature.should.be.equal(fnSignature1);
      weights[2].value.should.be.equal(weight1);
      (await txPriority.weightExistsInTree.call(weight1)).should.be.equal(true);
      (await txPriority.weightExistsInTree.call(weight2)).should.be.equal(true);
      (await txPriority.weightExistsInTree.call(weight3)).should.be.equal(true);
      (await txPriority.firstWeightInTree.call()).should.be.bignumber.equal(new BN(weight1));
      (await txPriority.lastWeightInTree.call()).should.be.bignumber.equal(new BN(weight3));
      (await txPriority.nextWeightInTree.call(weight1)).should.be.bignumber.equal(new BN(weight2));
      (await txPriority.prevWeightInTree.call(weight1)).should.be.bignumber.equal(new BN(0));
      (await txPriority.nextWeightInTree.call(weight2)).should.be.bignumber.equal(new BN(weight3));
      (await txPriority.prevWeightInTree.call(weight2)).should.be.bignumber.equal(new BN(weight1));
      (await txPriority.nextWeightInTree.call(weight3)).should.be.bignumber.equal(new BN(0));
      (await txPriority.prevWeightInTree.call(weight3)).should.be.bignumber.equal(new BN(weight2));

      await txPriority.removePriority(target2, fnSignature2).should.be.fulfilled;

      weights = await txPriority.getPriorities.call();
      weights.length.should.be.equal(2);
      (await txPriority.weightsCount.call()).should.be.bignumber.equal(new BN(2));
      weights[0].target.should.be.equal(target3);
      weights[0].fnSignature.should.be.equal(fnSignature3);
      weights[0].value.should.be.equal(weight3);
      weights[1].target.should.be.equal(target1);
      weights[1].fnSignature.should.be.equal(fnSignature1);
      weights[1].value.should.be.equal(weight1);
      (await txPriority.weightExistsInTree.call(weight1)).should.be.equal(true);
      (await txPriority.weightExistsInTree.call(weight2)).should.be.equal(false);
      (await txPriority.weightExistsInTree.call(weight3)).should.be.equal(true);
      (await txPriority.firstWeightInTree.call()).should.be.bignumber.equal(new BN(weight1));
      (await txPriority.lastWeightInTree.call()).should.be.bignumber.equal(new BN(weight3));
      (await txPriority.nextWeightInTree.call(weight1)).should.be.bignumber.equal(new BN(weight3));
      (await txPriority.prevWeightInTree.call(weight1)).should.be.bignumber.equal(new BN(0));
      (await txPriority.nextWeightInTree.call(weight3)).should.be.bignumber.equal(new BN(0));
      (await txPriority.prevWeightInTree.call(weight3)).should.be.bignumber.equal(new BN(weight1));

      await txPriority.removePriority(target1, fnSignature1).should.be.fulfilled;

      weights = await txPriority.getPriorities.call();
      weights.length.should.be.equal(1);
      (await txPriority.weightsCount.call()).should.be.bignumber.equal(new BN(1));
      weights[0].target.should.be.equal(target3);
      weights[0].fnSignature.should.be.equal(fnSignature3);
      weights[0].value.should.be.equal(weight3);
      (await txPriority.weightExistsInTree.call(weight1)).should.be.equal(false);
      (await txPriority.weightExistsInTree.call(weight2)).should.be.equal(false);
      (await txPriority.weightExistsInTree.call(weight3)).should.be.equal(true);
      (await txPriority.firstWeightInTree.call()).should.be.bignumber.equal(new BN(weight3));
      (await txPriority.lastWeightInTree.call()).should.be.bignumber.equal(new BN(weight3));
      (await txPriority.nextWeightInTree.call(weight3)).should.be.bignumber.equal(new BN(0));
      (await txPriority.prevWeightInTree.call(weight3)).should.be.bignumber.equal(new BN(0));

      await txPriority.removePriority(target3, fnSignature3).should.be.fulfilled;

      weights = await txPriority.getPriorities.call();
      weights.length.should.be.equal(0);
      (await txPriority.weightsCount.call()).should.be.bignumber.equal(new BN(0));
      (await txPriority.weightExistsInTree.call(weight1)).should.be.equal(false);
      (await txPriority.weightExistsInTree.call(weight2)).should.be.equal(false);
      (await txPriority.weightExistsInTree.call(weight3)).should.be.equal(false);
      (await txPriority.firstWeightInTree.call()).should.be.bignumber.equal(new BN(0));
      (await txPriority.lastWeightInTree.call()).should.be.bignumber.equal(new BN(0));
    });
    it('cannot remove non-existent destination', async () => {
      const target = accounts[1];
      const fnSignature = '0x12345678';
      const weight = '1000';
      await txPriority.removePriority(target, fnSignature).should.be.rejectedWith('destination does not exist');
      await txPriority.setPriority(target, fnSignature, weight).should.be.fulfilled;
      await txPriority.removePriority(target, fnSignature).should.be.fulfilled;
    });
    it('can only be called by an owner', async () => {
      const target = accounts[1];
      const fnSignature = '0x12345678';
      const weight = '1000';
      await txPriority.setPriority(target, fnSignature, weight).should.be.fulfilled;
      await txPriority.removePriority(target, fnSignature, { from: accounts[2] }).should.be.rejectedWith('caller is not the owner');
      await txPriority.removePriority(target, fnSignature, { from: owner }).should.be.fulfilled;
    });
  });

  describe('getPriorities()', async () => {
    it('should return weights in descending order', async () => {
      const target = accounts[1];
      const fnSignature1 = '0x12345671';
      const fnSignature2 = '0x12345672';
      const fnSignature3 = '0x12345673';
      const weight1 = '1001';
      const weight2 = '1002';
      const weight3 = '1003';
      
      await txPriority.setPriority(target, fnSignature2, weight2).should.be.fulfilled;
      await txPriority.setPriority(target, fnSignature3, weight3).should.be.fulfilled;
      await txPriority.setPriority(target, fnSignature1, weight1).should.be.fulfilled;

      const weights = await txPriority.getPriorities.call();
      weights.length.should.be.equal(3);
      weights[0].target.should.be.equal(target);
      weights[0].fnSignature.should.be.equal(fnSignature3);
      weights[0].value.should.be.equal(weight3);
      weights[1].target.should.be.equal(target);
      weights[1].fnSignature.should.be.equal(fnSignature2);
      weights[1].value.should.be.equal(weight2);
      weights[2].target.should.be.equal(target);
      weights[2].fnSignature.should.be.equal(fnSignature1);
      weights[2].value.should.be.equal(weight1);
    });
  });

  describe('setSendersWhitelist()', async () => {
    it('should set a whitelist', async () => {
      const whitelist = accounts.slice(1, 10);
      const { logs } = await txPriority.setSendersWhitelist(whitelist).should.be.fulfilled;
      logs[0].event.should.be.equal('SendersWhitelistSet');
      logs[0].args.whitelist.should.be.deep.equal(whitelist);
      (await txPriority.getSendersWhitelist.call()).should.be.deep.equal(whitelist);
    });
    it('should clear a whitelist', async () => {
      const { logs } = await txPriority.setSendersWhitelist([]).should.be.fulfilled;
      logs[0].event.should.be.equal('SendersWhitelistSet');
      logs[0].args.whitelist.should.be.deep.equal([]);
      (await txPriority.getSendersWhitelist.call()).should.be.deep.equal([]);
    });
    it('can only be called by an owner', async () => {
      const whitelist = accounts.slice(1, 10);
      await txPriority.setSendersWhitelist(whitelist, { from: accounts[11] }).should.be.rejectedWith('caller is not the owner');
      await txPriority.setSendersWhitelist(whitelist, { from: owner }).should.be.fulfilled;
    });
  });

  describe('setMinGasPrice()', async () => {
    it('should add a destination', async () => {
      const target = accounts[1];
      const fnSignature = '0x12345678';
      const minGasPrice = '20000000000';
      let prices = await txPriority.getMinGasPrices.call();
      prices.length.should.be.equal(0);
      const { logs } = await txPriority.setMinGasPrice(target, fnSignature, minGasPrice).should.be.fulfilled;
      logs[0].event.should.be.equal('MinGasPriceSet');
      logs[0].args.target.should.be.equal(target);
      logs[0].args.fnSignature.should.be.equal(web3.utils.padRight(fnSignature, 64));
      logs[0].args.minGasPrice.should.be.bignumber.equal(new BN(minGasPrice));
      prices = await txPriority.getMinGasPrices.call();
      prices.length.should.be.equal(1);
      prices[0].target.should.be.equal(target);
      prices[0].fnSignature.should.be.equal(fnSignature);
      prices[0].value.should.be.equal(minGasPrice);
    });
    it('should fail when target address is zero', async () => {
      const target = '0x0000000000000000000000000000000000000000';
      const fnSignature = '0x12345678';
      const minGasPrice = '20000000000';
      await txPriority.setMinGasPrice(target, fnSignature, minGasPrice).should.be.rejectedWith('target cannot be 0');
    });
    it('should fail when minGasPrice is zero', async () => {
      const target = accounts[1];
      const fnSignature = '0x12345678';
      const minGasPrice = '0';
      await txPriority.setMinGasPrice(target, fnSignature, minGasPrice).should.be.rejectedWith('minGasPrice cannot be 0');
    });
    it('shouldn`t change anything if destination with the same minGasPrice already exists', async () => {
      const target = accounts[1];
      const fnSignature = '0x12345678';
      const minGasPrice = '20000000000';
      await txPriority.setMinGasPrice(target, fnSignature, minGasPrice).should.be.fulfilled;

      let prices = await txPriority.getMinGasPrices.call();
      prices.length.should.be.equal(1);
      prices[0].target.should.be.equal(target);
      prices[0].fnSignature.should.be.equal(fnSignature);
      prices[0].value.should.be.equal(minGasPrice);

      const { logs } = await txPriority.setMinGasPrice(target, fnSignature, minGasPrice).should.be.fulfilled;
      logs[0].event.should.be.equal('MinGasPriceSet');
      logs[0].args.target.should.be.equal(target);
      logs[0].args.fnSignature.should.be.equal(web3.utils.padRight(fnSignature, 64));
      logs[0].args.minGasPrice.should.be.bignumber.equal(new BN(minGasPrice));

      prices = await txPriority.getMinGasPrices.call();
      prices.length.should.be.equal(1);
      prices[0].target.should.be.equal(target);
      prices[0].fnSignature.should.be.equal(fnSignature);
      prices[0].value.should.be.equal(minGasPrice);
    });
    it('should update existing destination minGasPrice', async () => {
      const target = accounts[1];
      const fnSignature = '0x12345678';
      const minGasPrice = '20000000000';
      const newMinGasPrice = '30000000000';
      
      await txPriority.setMinGasPrice(target, fnSignature, minGasPrice).should.be.fulfilled;

      let prices = await txPriority.getMinGasPrices.call();
      prices.length.should.be.equal(1);
      prices[0].target.should.be.equal(target);
      prices[0].fnSignature.should.be.equal(fnSignature);
      prices[0].value.should.be.equal(minGasPrice);
      
      await txPriority.setMinGasPrice(target, fnSignature, newMinGasPrice).should.be.fulfilled;

      prices = await txPriority.getMinGasPrices.call();
      prices.length.should.be.equal(1);
      prices[0].target.should.be.equal(target);
      prices[0].fnSignature.should.be.equal(fnSignature);
      prices[0].value.should.be.equal(newMinGasPrice);
    });
    it('should add a new destination', async () => {
      const target = accounts[1];
      const fnSignature1 = '0x12345678';
      const fnSignature2 = '0x12345679';
      const minGasPrice = '20000000000';

      await txPriority.setMinGasPrice(target, fnSignature1, minGasPrice).should.be.fulfilled;
      await txPriority.setMinGasPrice(target, fnSignature2, minGasPrice).should.be.fulfilled;

      const prices = await txPriority.getMinGasPrices.call();
      prices.length.should.be.equal(2);
      prices[0].target.should.be.equal(target);
      prices[0].fnSignature.should.be.equal(fnSignature1);
      prices[0].value.should.be.equal(minGasPrice);
      prices[1].target.should.be.equal(target);
      prices[1].fnSignature.should.be.equal(fnSignature2);
      prices[1].value.should.be.equal(minGasPrice);
    });
    it('can only be called by an owner', async () => {
      const target = accounts[1];
      const fnSignature = '0x12345678';
      const minGasPrice = '20000000000';
      await txPriority.setMinGasPrice(target, fnSignature, minGasPrice, { from: accounts[2] }).should.be.rejectedWith('caller is not the owner');
      await txPriority.setMinGasPrice(target, fnSignature, minGasPrice, { from: owner }).should.be.fulfilled;
    });
  });

  describe('removeMinGasPrice()', async () => {
    it('should remove a destination', async () => {
      const target = accounts[1];
      const fnSignature = '0x12345678';
      const minGasPrice = '20000000000';
      
      await txPriority.setMinGasPrice(target, fnSignature, minGasPrice).should.be.fulfilled;

      let prices = await txPriority.getMinGasPrices.call();
      prices.length.should.be.equal(1);
      prices[0].target.should.be.equal(target);
      prices[0].fnSignature.should.be.equal(fnSignature);
      prices[0].value.should.be.equal(minGasPrice);
      
      const { logs } = await txPriority.removeMinGasPrice(target, fnSignature).should.be.fulfilled;
      logs[0].event.should.be.equal('MinGasPriceSet');
      logs[0].args.target.should.be.equal(target);
      logs[0].args.fnSignature.should.be.equal(web3.utils.padRight(fnSignature, 64));
      logs[0].args.minGasPrice.should.be.bignumber.equal(new BN(0));

      prices = await txPriority.getMinGasPrices.call();
      prices.length.should.be.equal(0);

      await txPriority.removeMinGasPrice(target, fnSignature).should.be.rejectedWith('not found');
    });
    it('should remove a specified destination', async () => {
      const target1 = accounts[1];
      const target2 = accounts[2];
      const target3 = accounts[3];
      const target4 = accounts[4];
      const fnSignature1 = '0x12345671';
      const fnSignature2 = '0x12345672';
      const fnSignature3 = '0x12345673';
      const fnSignature4 = '0x12345674';
      const minGasPrice1 = '10000000000';
      const minGasPrice2 = '20000000000';
      const minGasPrice3 = '30000000000';
      const minGasPrice4 = '40000000000';

      await txPriority.setMinGasPrice(target1, fnSignature1, minGasPrice1).should.be.fulfilled;
      await txPriority.setMinGasPrice(target2, fnSignature2, minGasPrice2).should.be.fulfilled;
      await txPriority.setMinGasPrice(target3, fnSignature3, minGasPrice3).should.be.fulfilled;

      let prices = await txPriority.getMinGasPrices.call();
      prices.length.should.be.equal(3);
      prices[0].target.should.be.equal(target1);
      prices[0].fnSignature.should.be.equal(fnSignature1);
      prices[0].value.should.be.equal(minGasPrice1);
      prices[1].target.should.be.equal(target2);
      prices[1].fnSignature.should.be.equal(fnSignature2);
      prices[1].value.should.be.equal(minGasPrice2);
      prices[2].target.should.be.equal(target3);
      prices[2].fnSignature.should.be.equal(fnSignature3);
      prices[2].value.should.be.equal(minGasPrice3);

      await txPriority.removeMinGasPrice(target1, fnSignature1).should.be.fulfilled;

      prices = await txPriority.getMinGasPrices.call();
      prices.length.should.be.equal(2);
      prices[0].target.should.be.equal(target3);
      prices[0].fnSignature.should.be.equal(fnSignature3);
      prices[0].value.should.be.equal(minGasPrice3);
      prices[1].target.should.be.equal(target2);
      prices[1].fnSignature.should.be.equal(fnSignature2);
      prices[1].value.should.be.equal(minGasPrice2);

      await txPriority.setMinGasPrice(target4, fnSignature4, minGasPrice4).should.be.fulfilled;

      prices = await txPriority.getMinGasPrices.call();
      prices.length.should.be.equal(3);
      prices[0].target.should.be.equal(target3);
      prices[0].fnSignature.should.be.equal(fnSignature3);
      prices[0].value.should.be.equal(minGasPrice3);
      prices[1].target.should.be.equal(target2);
      prices[1].fnSignature.should.be.equal(fnSignature2);
      prices[1].value.should.be.equal(minGasPrice2);
      prices[2].target.should.be.equal(target4);
      prices[2].fnSignature.should.be.equal(fnSignature4);
      prices[2].value.should.be.equal(minGasPrice4);

      await txPriority.removeMinGasPrice(target2, fnSignature2).should.be.fulfilled;

      prices = await txPriority.getMinGasPrices.call();
      prices.length.should.be.equal(2);
      prices[0].target.should.be.equal(target3);
      prices[0].fnSignature.should.be.equal(fnSignature3);
      prices[0].value.should.be.equal(minGasPrice3);
      prices[1].target.should.be.equal(target4);
      prices[1].fnSignature.should.be.equal(fnSignature4);
      prices[1].value.should.be.equal(minGasPrice4);

      await txPriority.removeMinGasPrice(target3, fnSignature3).should.be.fulfilled;

      prices = await txPriority.getMinGasPrices.call();
      prices.length.should.be.equal(1);
      prices[0].target.should.be.equal(target4);
      prices[0].fnSignature.should.be.equal(fnSignature4);
      prices[0].value.should.be.equal(minGasPrice4);

      await txPriority.removeMinGasPrice(target4, fnSignature4).should.be.fulfilled;

      prices = await txPriority.getMinGasPrices.call();
      prices.length.should.be.equal(0);
    });
    it('cannot remove non-existent destination', async () => {
      const target = accounts[1];
      const fnSignature = '0x12345678';
      const minGasPrice = '20000000000';
      await txPriority.removeMinGasPrice(target, fnSignature).should.be.rejectedWith('not found');
      await txPriority.setMinGasPrice(target, fnSignature, minGasPrice).should.be.fulfilled;
      await txPriority.removeMinGasPrice(target, fnSignature).should.be.fulfilled;
    });
    it('can only be called by an owner', async () => {
      const target = accounts[1];
      const fnSignature = '0x12345678';
      const minGasPrice = '20000000000';
      await txPriority.setMinGasPrice(target, fnSignature, minGasPrice).should.be.fulfilled;
      await txPriority.removeMinGasPrice(target, fnSignature, { from: accounts[2] }).should.be.rejectedWith('caller is not the owner');
      await txPriority.removeMinGasPrice(target, fnSignature, { from: owner }).should.be.fulfilled;
    });
  });
});
