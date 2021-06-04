const EmptyContract = artifacts.require('EmptyContract');
const ERC677BridgeTokenRewardable = artifacts.require('ERC677BridgeTokenRewardableMock');
const RecipientMock = artifacts.require('RecipientMock');

const REVERT_MSG = 'VM Exception while processing transaction: revert';
const INVALID_OPCODE_MSG = 'VM Exception while processing transaction: invalid opcode';
const { BN, toWei } = web3.utils;

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bn')(BN))
  .should();

const ethUtil = require('ethereumjs-util');
const permitSign = require('./utils/eip712.sign.permit');

contract('ERC677BridgeTokenRewardable', async accounts => {
  let owner;

  beforeEach(async () => {
    owner = accounts[0];
  });
  describe('constructor', () => {
    it('should be created', async () => {
      const token = await ERC677BridgeTokenRewardable.new(
        'STAKE',
        'STAKE',
        18,
        100
      ).should.be.fulfilled;

      (await token.name.call()).should.be.equal('STAKE');
      (await token.symbol.call()).should.be.equal('STAKE');
      (await token.decimals.call()).toNumber().should.be.equal(18);
    });
    it('should fail if empty chain ID', async () => {
      await ERC677BridgeTokenRewardable.new(
        'STAKE',
        'STAKE',
        18,
        0
      ).should.be.rejectedWith(REVERT_MSG);
    });
  });
  describe('addBridge', () => {
    let bridge;
    let token;
    beforeEach(async () => {
      bridge = await EmptyContract.new();
      token = await ERC677BridgeTokenRewardable.new(
        'STAKE',
        'STAKE',
        18,
        100
      ).should.be.fulfilled;
    });
    it('should add', async () => {
      await token.addBridge(bridge.address).should.be.fulfilled;
      (await token.bridgeList.call()).should.be.deep.equal([bridge.address]);
    });
    it('should fail if invalid or wrong address', async () => {
      await token.addBridge('0x0000000000000000000000000000000000000000').should.be.rejectedWith(REVERT_MSG);
      await token.addBridge(accounts[2]).should.be.rejectedWith(REVERT_MSG);
    });
    it('should fail if not an owner', async () => {
      await token.addBridge(
          bridge.address,
          { from: accounts[1] }
      ).should.be.rejectedWith(REVERT_MSG);
    });
  });
  describe('transferAndCall', () => {
    const value = new BN(toWei('1'));
    let token;
    let recipient;

    beforeEach(async () => {
      token = await ERC677BridgeTokenRewardable.new(
        'STAKE',
        'STAKE',
        18,
        100
      ).should.be.fulfilled;
      recipient = await RecipientMock.new();
      await token.mint(accounts[1], value);
    });
    it('should transfer and call', async () => {
      const customString = 'Hello';
      const data = web3.eth.abi.encodeParameters(['string'], [customString]);
      await token.transferAndCall(recipient.address, value, data, { from: accounts[1] }).should.be.fulfilled;
      (await token.balanceOf.call(recipient.address)).should.be.bignumber.equal(value);
      (await recipient.from.call()).should.be.equal(accounts[1]);
      (await recipient.value.call()).should.be.bignumber.equal(value);
      (await recipient.customString.call()).should.be.equal(customString);
    });
    it('should fail if wrong custom data', async () => {
      const data = web3.eth.abi.encodeParameters(['uint256'], ['123']);
      await token.transferAndCall(
        recipient.address,
        value,
        data,
        { from: accounts[1] }
      ).should.be.rejectedWith(REVERT_MSG);
    });
    it('should fail if recipient is empty contract', async () => {
      const customString = 'Hello';
      const data = web3.eth.abi.encodeParameters(['string'], [customString]);
      bridge = await EmptyContract.new();
      await token.addBridge(bridge.address).should.be.fulfilled;
      await token.transferAndCall(
        bridge.address,
        value,
        data,
        { from: accounts[1] }
      ).should.be.rejectedWith(REVERT_MSG);
    });
  });
  describe('transfer', () => {
    const value = new BN(toWei('1'));
    let token;
    let recipient;

    beforeEach(async () => {
      token = await ERC677BridgeTokenRewardable.new(
        'STAKE',
        'STAKE',
        18,
        100
      ).should.be.fulfilled;
      recipient = await RecipientMock.new();
      await token.mint(accounts[1], value);
    });
    it('should transfer', async () => {
      await token.transfer(accounts[2], value, { from: accounts[1] }).should.be.fulfilled;
      (await token.balanceOf.call(accounts[2])).should.be.bignumber.equal(value);
    });
    it('should fail if recipient is bridge, BlockReward, or Staking contract', async () => {
      const bridge = await EmptyContract.new();
      await token.addBridge(bridge.address).should.be.fulfilled;
      await token.transfer(
        bridge.address,
        value,
        { from: accounts[1] }
      ).should.be.rejectedWith(REVERT_MSG);
      
      const blockReward = await EmptyContract.new();
      await token.setBlockRewardContract(blockReward.address).should.be.fulfilled;;
      await token.transfer(
        blockReward.address,
        value,
        { from: accounts[1] }
      ).should.be.rejectedWith(REVERT_MSG);

      const staking = await EmptyContract.new();
      await token.setStakingContract(staking.address).should.be.fulfilled;;
      await token.transfer(
        staking.address,
        value,
        { from: accounts[1] }
      ).should.be.rejectedWith(REVERT_MSG);
    });
  });
  describe('transferFrom', () => {
    const value = new BN(toWei('1'));
    let token;
    let recipient;

    beforeEach(async () => {
      token = await ERC677BridgeTokenRewardable.new(
        'STAKE',
        'STAKE',
        18,
        100
      ).should.be.fulfilled;
      recipient = await RecipientMock.new();
      await token.mint(accounts[1], value);
    });
    it('should transfer', async () => {
      await token.approve(owner, value, { from: accounts[1] }).should.be.fulfilled;
      await token.transferFrom(accounts[1], accounts[2], value).should.be.fulfilled;
      (await token.balanceOf.call(accounts[2])).should.be.bignumber.equal(value);
    });
    it('should fail if recipient is bridge, BlockReward, or Staking contract', async () => {
      await token.approve(owner, value, { from: accounts[1] }).should.be.fulfilled;

      const bridge = await EmptyContract.new();
      await token.addBridge(bridge.address).should.be.fulfilled;
      await token.transferFrom(
        accounts[1],
        bridge.address,
        value
      ).should.be.rejectedWith(REVERT_MSG);

      const blockReward = await EmptyContract.new();
      await token.setBlockRewardContract(blockReward.address).should.be.fulfilled;;
      await token.transferFrom(
        accounts[1],
        blockReward.address,
        value
      ).should.be.rejectedWith(REVERT_MSG);

      const staking = await EmptyContract.new();
      await token.setStakingContract(staking.address).should.be.fulfilled;;
      await token.transferFrom(
        accounts[1],
        staking.address,
        value
      ).should.be.rejectedWith(REVERT_MSG);
    });
  });
  describe('move', () => {
    const value = new BN(toWei('1'));
    let token;
    let recipient;

    beforeEach(async () => {
      token = await ERC677BridgeTokenRewardable.new(
        'STAKE',
        'STAKE',
        18,
        100
      ).should.be.fulfilled;
      recipient = await RecipientMock.new();
      await token.mint(accounts[1], value);
    });
    it('should transfer', async () => {
      await token.approve(owner, value, { from: accounts[1] }).should.be.fulfilled;
      await token.move(accounts[1], accounts[2], value).should.be.fulfilled;
      (await token.balanceOf.call(accounts[2])).should.be.bignumber.equal(value);
    });
    it('should fail if recipient is bridge, BlockReward, or Staking contract', async () => {
      await token.approve(owner, value, { from: accounts[1] }).should.be.fulfilled;

      const bridge = await EmptyContract.new();
      await token.addBridge(bridge.address).should.be.fulfilled;
      await token.move(
        accounts[1],
        bridge.address,
        value
      ).should.be.rejectedWith(REVERT_MSG);

      const blockReward = await EmptyContract.new();
      await token.setBlockRewardContract(blockReward.address).should.be.fulfilled;;
      await token.move(
        accounts[1],
        blockReward.address,
        value
      ).should.be.rejectedWith(REVERT_MSG);

      const staking = await EmptyContract.new();
      await token.setStakingContract(staking.address).should.be.fulfilled;;
      await token.move(
        accounts[1],
        staking.address,
        value
      ).should.be.rejectedWith(REVERT_MSG);
    });
  });
  describe('permit', () => {
    const privateKey = '0x2bdd21761a483f71054e14f5b827213567971c676928d9a1808cbfa4b7501210';
    const infinite = new BN('ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff', 16);
    let holder;
    let spender;
    let nonce;
    let expiry;
    let allowed;

    beforeEach(async () => {
      token = await ERC677BridgeTokenRewardable.new(
        'STAKE',
        'STAKE',
        18,
        100
      ).should.be.fulfilled;

      holder = '0x040b798028e9abded00Bfc65e7CF01484013db17';
      spender = accounts[11];
      nonce = await token.nonces.call(holder);
      expiry = 0;
      allowed = true;

      holder.toLowerCase().should.be.equal(
        ethUtil.bufferToHex(ethUtil.privateToAddress(privateKey)).toLowerCase()
      ); // make sure privateKey is holder's key

      // Mint some extra tokens for the `holder`
      await token.mint(holder, '10000');
      (await token.balanceOf.call(holder)).should.be.bignumber.equal(new BN('10000'));
    });
    it('should permit', async () => {
      // Holder signs the `permit` params with their privateKey
      const signature = permitSign({
        name: await token.name.call(),
        version: await token.version.call(),
        chainId: "100",
        verifyingContract: token.address
      }, {
        holder,
        spender,
        nonce,
        expiry,
        allowed
      }, privateKey);

      (await token.allowance.call(holder, spender)).should.be.bignumber.equal(new BN('0'));

      // An arbitrary address calls the `permit` function
      const { logs } = await token.permit(
        holder,
        spender,
        nonce,
        expiry,
        allowed,
        signature.v,
        signature.r,
        signature.s
      ).should.be.fulfilled;

      logs[0].event.should.be.equal('Approval');
      logs[0].args.owner.should.be.equal(holder);
      logs[0].args.spender.should.be.equal(spender);
      logs[0].args.value.should.be.bignumber.equal(infinite);

      // Now allowance is infinite
      (await token.allowance.call(holder, spender)).should.be.bignumber.equal(infinite);

      // The caller of `permit` can't spend holder's funds
      await token.transferFrom(holder, accounts[12], '10000').should.be.rejectedWith(INVALID_OPCODE_MSG);
      (await token.balanceOf.call(holder)).should.be.bignumber.equal(new BN('10000'));

      // Spender can transfer all holder's funds
      await token.transferFrom(holder, accounts[12], '10000', { from: spender }).should.be.fulfilled;
      (await token.balanceOf.call(holder)).should.be.bignumber.equal(new BN('0'));
      (await token.balanceOf.call(accounts[12])).should.be.bignumber.equal(new BN('10000'));
      (await token.nonces.call(holder)).should.be.bignumber.equal(nonce.add(new BN('1')));

      // The allowance is still infinite after transfer
      (await token.allowance.call(holder, spender)).should.be.bignumber.equal(infinite);
    });
    it('should fail when invalid expiry', async () => {
      expiry = 900;

      const signature = permitSign({
        name: await token.name.call(),
        version: await token.version.call(),
        chainId: "100",
        verifyingContract: token.address
      }, {
        holder,
        spender,
        nonce,
        expiry,
        allowed
      }, privateKey);

      await token.setNow(1000).should.be.fulfilled;
      await token.permit(
        holder,
        spender,
        nonce,
        expiry,
        allowed,
        signature.v,
        signature.r,
        signature.s
      ).should.be.rejectedWith(REVERT_MSG);

      await token.setNow(800).should.be.fulfilled;
      await token.permit(
        holder,
        spender,
        nonce,
        expiry,
        allowed,
        signature.v,
        signature.r,
        signature.s
      ).should.be.fulfilled;
    });
    it('should consider expiry', async () => {
      expiry = 900;

      const signature = permitSign({
        name: await token.name.call(),
        version: await token.version.call(),
        chainId: "100",
        verifyingContract: token.address
      }, {
        holder,
        spender,
        nonce,
        expiry,
        allowed
      }, privateKey);

      await token.setNow(800).should.be.fulfilled;
      await token.permit(
        holder,
        spender,
        nonce,
        expiry,
        allowed,
        signature.v,
        signature.r,
        signature.s
      ).should.be.fulfilled;
      (await token.expirations.call(holder, spender)).should.be.bignumber.equal(new BN(expiry));

      // Spender can transfer holder's funds
      await token.setNow(899).should.be.fulfilled;
      await token.transferFrom(holder, accounts[12], '6000', { from: spender }).should.be.fulfilled;
      (await token.balanceOf.call(holder)).should.be.bignumber.equal(new BN('4000'));
      (await token.balanceOf.call(accounts[12])).should.be.bignumber.equal(new BN('6000'));

      // Spender can't transfer the remaining holder's funds because of expiry
      await token.setNow(901).should.be.fulfilled;
      await token.transferFrom(holder, accounts[12], '4000', { from: spender }).should.be.rejectedWith(REVERT_MSG);
    });
    it('should disallow unlimited allowance', async () => {
      expiry = 900;
      await token.setNow(800).should.be.fulfilled;

      let signature = permitSign({
        name: await token.name.call(),
        version: await token.version.call(),
        chainId: "100",
        verifyingContract: token.address
      }, {
        holder,
        spender,
        nonce,
        expiry,
        allowed
      }, privateKey);

      await token.permit(
        holder,
        spender,
        nonce,
        expiry,
        allowed,
        signature.v,
        signature.r,
        signature.s
      ).should.be.fulfilled;

      (await token.allowance.call(holder, spender)).should.be.bignumber.equal(infinite);
      (await token.expirations.call(holder, spender)).should.be.bignumber.equal(new BN(expiry));

      // Spender can transfer holder's funds
      await token.transferFrom(holder, accounts[12], '6000', { from: spender }).should.be.fulfilled;
      (await token.balanceOf.call(holder)).should.be.bignumber.equal(new BN('4000'));
      (await token.balanceOf.call(accounts[12])).should.be.bignumber.equal(new BN('6000'));

      nonce = nonce - 0 + 1;
      allowed = false;

      signature = permitSign({
        name: await token.name.call(),
        version: await token.version.call(),
        chainId: "100",
        verifyingContract: token.address
      }, {
        holder,
        spender,
        nonce,
        expiry,
        allowed
      }, privateKey);

      await token.permit(
        holder,
        spender,
        nonce,
        expiry,
        allowed,
        signature.v,
        signature.r,
        signature.s
      ).should.be.fulfilled;

      (await token.allowance.call(holder, spender)).should.be.bignumber.equal(new BN('0'));
      (await token.expirations.call(holder, spender)).should.be.bignumber.equal(new BN('0'));

      // Spender can't transfer the remaining holder's funds because of zero allowance
      await token.transferFrom(holder, accounts[12], '4000', { from: spender }).should.be.rejectedWith(INVALID_OPCODE_MSG);
    });
    it('should fail when invalid signature or parameters', async () => {
      let signature = permitSign({
        name: await token.name.call(),
        version: await token.version.call(),
        chainId: "100",
        verifyingContract: token.address
      }, {
        holder,
        spender,
        nonce,
        expiry,
        allowed
      }, privateKey);

      allowed = !allowed;

      await token.permit(
        holder,
        spender,
        nonce,
        expiry,
        allowed,
        signature.v,
        signature.r,
        signature.s
      ).should.be.rejectedWith(REVERT_MSG);

      allowed = !allowed;

      await token.permit(
        holder,
        spender,
        nonce,
        expiry,
        allowed,
        signature.v,
        signature.s, // here should be `signature.r` in a correct case
        signature.r  // here should be `signature.s` in a correct case
      ).should.be.rejectedWith(REVERT_MSG);

      signature = permitSign({
        name: await token.name.call(),
        version: await token.version.call(),
        chainId: "100",
        verifyingContract: token.address
      }, {
        holder,
        spender,
        nonce: nonce - 0 + 1,
        expiry,
        allowed
      }, privateKey);

      await token.permit(
        holder,
        spender,
        nonce - 0 + 1,
        expiry,
        allowed,
        signature.v,
        signature.r,
        signature.s
      ).should.be.rejectedWith(REVERT_MSG);

      signature = permitSign({
        name: await token.name.call(),
        version: await token.version.call(),
        chainId: "100",
        verifyingContract: token.address
      }, {
        holder,
        spender,
        nonce,
        expiry,
        allowed
      }, privateKey);

      await token.permit(
        holder,
        spender,
        nonce,
        expiry,
        allowed,
        signature.v,
        signature.r,
        signature.s
      ).should.be.fulfilled;
    });
  });
  describe('claimTokens', () => {
    const value = new BN(toWei('1'));
    let token;
    let anotherToken;

    beforeEach(async () => {
      token = await ERC677BridgeTokenRewardable.new(
        'STAKE',
        'STAKE',
        18,
        100
      ).should.be.fulfilled;
      anotherToken = await ERC677BridgeTokenRewardable.new(
        'ANOTHER',
        'ANOTHER',
        18,
        100
      ).should.be.fulfilled;

      await anotherToken.mint(accounts[2], value).should.be.fulfilled;
      await anotherToken.transfer(token.address, value, { from: accounts[2] }).should.be.fulfilled;
      (await anotherToken.balanceOf.call(token.address)).should.be.bignumber.equal(value);
    });
    it('should claim tokens', async () => {
      await token.claimTokens(anotherToken.address, accounts[3]).should.be.fulfilled;
      (await anotherToken.balanceOf.call(accounts[3])).should.be.bignumber.equal(value);
    });
    it('should fail if invalid recipient', async () => {
      await token.claimTokens(
        anotherToken.address,
        '0x0000000000000000000000000000000000000000'
      ).should.be.rejectedWith(REVERT_MSG);
    });
    it('should fail if not an owner', async () => {
      await token.claimTokens(
        anotherToken.address,
        accounts[3],
        { from: accounts[1] }
      ).should.be.rejectedWith(REVERT_MSG);
    });
    async function claimNativeCoins(to) {
      const token = await ERC677BridgeTokenRewardable.new(
        'STAKE',
        'STAKE',
        18,
        100
      ).should.be.fulfilled;
      const balanceBefore = new BN(await web3.eth.getBalance(to));

      await web3.eth.sendTransaction({ from: owner, to: token.address, value });
      await token.claimTokens('0x0000000000000000000000000000000000000000', to).should.be.fulfilled;

      const balanceAfter = new BN(await web3.eth.getBalance(to));
      balanceAfter.should.be.bignumber.equal(balanceBefore.add(value));
    }
    it('should claim native coins', async () => {
      await claimNativeCoins(accounts[3]);
    });
    it('should claim native coins to non-payable contract', async () => {
      const nonPayableContract = await EmptyContract.new();
      await claimNativeCoins(nonPayableContract.address);
    });
  });
});
