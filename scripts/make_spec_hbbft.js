const fs = require('fs');
const path = require('path');
const Web3 = require('web3');
const web3 = new Web3(new Web3.providers.HttpProvider("https://dai.poa.network"));
const utils = require('./utils/utils');
const fp = require('lodash/fp');

const VALIDATOR_SET_CONTRACT = '0x1000000000000000000000000000000000000001';
const BLOCK_REWARD_CONTRACT = '0x2000000000000000000000000000000000000001';
const RANDOM_CONTRACT = '0x3000000000000000000000000000000000000001';
const STAKING_CONTRACT = '0x1100000000000000000000000000000000000001';
const PERMISSION_CONTRACT = '0x4000000000000000000000000000000000000001';
const CERTIFIER_CONTRACT = '0x5000000000000000000000000000000000000001';

main();

async function main() {
  const networkName = process.env.NETWORK_NAME;
  const networkID = process.env.NETWORK_ID;
  const owner = process.env.OWNER.trim();
  let initialValidators = process.env.INITIAL_VALIDATORS.split(',');
  for (let i = 0; i < initialValidators.length; i++) {
    initialValidators[i] = initialValidators[i].trim();
  }
  let stakingAddresses = process.env.STAKING_ADDRESSES.split(',');
  for (let i = 0; i < stakingAddresses.length; i++) {
    stakingAddresses[i] = stakingAddresses[i].trim();
  }
  const firstValidatorIsUnremovable = process.env.FIRST_VALIDATOR_IS_UNREMOVABLE === 'true';
  const stakingEpochDuration = process.env.STAKING_EPOCH_DURATION;
  const stakeWithdrawDisallowPeriod = process.env.STAKE_WITHDRAW_DISALLOW_PERIOD;
  const collectRoundLength = process.env.COLLECT_ROUND_LENGTH;
  const erc20Restricted = process.env.ERC20_RESTRICTED === 'true';

  const ethToWei = web3.utils.toWei('1', 'ether');
  //stakingParams = [_delegatorMinStake, _candidateMinStake, _stakingEpochDuration, _stakingEpochStartBlock, _stakeWithdrawDisallowPeriod
  let stakingParams = [ethToWei, ethToWei, stakingEpochDuration, 0, stakeWithdrawDisallowPeriod];

  let publicKeys = process.env.PUBLIC_KEYS.split(',');
  for (let i = 0; i < publicKeys.length; i++) {
    publicKeys[i] = publicKeys[i].trim();
  }
  let publicKeysSplit = fp.flatMap(x => [x.substring(0, 34), '0x' + x.substring(34, 66)])(publicKeys);

  let internetAddresses = process.env.IP_ADDRESSES.split(',');;
  for (let i = 0; i < internetAddresses.length; i++) {
    internetAddresses[i] = internetAddresses[i].trim();
  }

  const contracts = [
    'AdminUpgradeabilityProxy',
    'BlockRewardHbbft',
    'CertifierHbbft',
    'InitializerHbbft',
    'RandomHbbft',
    'Registry',
    'StakingHbbft',
    'TxPermissionHbbft',
    'ValidatorSetHbbft',
    'KeyGenHistory'
  ];

  let spec = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'templates', 'spec_hbbft.json'), 'UTF-8'));

  spec.name = networkName;
  spec.params.networkID = networkID;

  let contractsCompiled = {};
  for (let i = 0; i < contracts.length; i++) {
    const contractName = contracts[i];
    let realContractName = contractName;
    let dir = 'contracts/';

    if (contractName == 'AdminUpgradeabilityProxy') {
      dir = 'contracts/upgradeability/';
    } else if (contractName == 'StakingHbbft' && erc20Restricted) {
      realContractName = 'StakingHbbftCoins';
      dir = 'contracts/base/';
    } else if (contractName == 'BlockRewardHbbft' && erc20Restricted) {
      realContractName = 'BlockRewardHbbftCoins';
      dir = 'contracts/base/';
    }

    console.log(`Compiling ${contractName}...`);
    const compiled = await compile(
      path.join(__dirname, '..', dir),
      realContractName
    );
    contractsCompiled[contractName] = compiled;
  }

  const storageProxyCompiled = contractsCompiled['AdminUpgradeabilityProxy'];
  let contract = new web3.eth.Contract(storageProxyCompiled.abi);
  let deploy;

  // Build ValidatorSetHbbft contract
  deploy = await contract.deploy({data: '0x' + storageProxyCompiled.bytecode, arguments: [
      '0x1000000000000000000000000000000000000000', // implementation address
      owner,
      []
    ]});
  spec.engine.hbbft.params.validators.multi = {
    "0": {
      "contract": VALIDATOR_SET_CONTRACT
    }
  };
  spec.accounts[VALIDATOR_SET_CONTRACT] = {
    balance: '0',
    constructor: await deploy.encodeABI()
  };
  spec.accounts['0x1000000000000000000000000000000000000000'] = {
    balance: '0',
    constructor: '0x' + contractsCompiled['ValidatorSetHbbft'].bytecode
  };

  // Build StakingHbbft contract
  deploy = await contract.deploy({data: '0x' + storageProxyCompiled.bytecode, arguments: [
      '0x1100000000000000000000000000000000000000', // implementation address
      owner,
      []
    ]});
  spec.accounts[STAKING_CONTRACT] = {
    balance: '0',
    constructor: await deploy.encodeABI()
  };
  spec.accounts['0x1100000000000000000000000000000000000000'] = {
    balance: '0',
    constructor: '0x' + contractsCompiled['StakingHbbft'].bytecode
  };

  // Build BlockRewardHbbft contract
  deploy = await contract.deploy({data: '0x' + storageProxyCompiled.bytecode, arguments: [
      '0x2000000000000000000000000000000000000000', // implementation address
      owner,
      []
    ]});
  spec.accounts[BLOCK_REWARD_CONTRACT] = {
    balance: '0',
    constructor: await deploy.encodeABI()
  };
  spec.engine.hbbft.params.blockRewardContractAddress = BLOCK_REWARD_CONTRACT;
  spec.engine.hbbft.params.blockRewardContractTransition = 0;
  spec.accounts['0x2000000000000000000000000000000000000000'] = {
    balance: '0',
    constructor: '0x' + contractsCompiled['BlockRewardHbbft'].bytecode
  };

  // Build RandomHbbft contract
  deploy = await contract.deploy({data: '0x' + storageProxyCompiled.bytecode, arguments: [
      '0x3000000000000000000000000000000000000000', // implementation address
      owner,
      []
    ]});
  spec.accounts[RANDOM_CONTRACT] = {
    balance: '0',
    constructor: await deploy.encodeABI()
  };
  spec.accounts['0x3000000000000000000000000000000000000000'] = {
    balance: '0',
    constructor: '0x' + contractsCompiled['RandomHbbft'].bytecode
  };
  spec.engine.hbbft.params.randomnessContractAddress = RANDOM_CONTRACT;

  // Build TxPermission contract
  deploy = await contract.deploy({data: '0x' + storageProxyCompiled.bytecode, arguments: [
      '0x4000000000000000000000000000000000000000', // implementation address
      owner,
      []
    ]});
  spec.accounts[PERMISSION_CONTRACT] = {
    balance: '0',
    constructor: await deploy.encodeABI()
  };
  spec.params.transactionPermissionContract = PERMISSION_CONTRACT;
  spec.accounts['0x4000000000000000000000000000000000000000'] = {
    balance: '0',
    constructor: '0x' + contractsCompiled['TxPermissionHbbft'].bytecode
  };

  // Build Certifier contract
  deploy = await contract.deploy({data: '0x' + storageProxyCompiled.bytecode, arguments: [
      '0x5000000000000000000000000000000000000000', // implementation address
      owner,
      []
    ]});
  spec.accounts[CERTIFIER_CONTRACT] = {
    balance: '0',
    constructor: await deploy.encodeABI()
  };
  spec.accounts['0x5000000000000000000000000000000000000000'] = {
    balance: '0',
    constructor: '0x' + contractsCompiled['CertifierHbbft'].bytecode
  };

  // Build Registry contract
  contract = new web3.eth.Contract(contractsCompiled['Registry'].abi);
  deploy = await contract.deploy({data: '0x' + contractsCompiled['Registry'].bytecode, arguments: [
      CERTIFIER_CONTRACT,
      owner
    ]});
  spec.accounts['0x6000000000000000000000000000000000000000'] = {
    balance: '0',
    constructor: await deploy.encodeABI()
  };
  spec.params.registrar = '0x6000000000000000000000000000000000000000';

  // Build KeyGenHistory contract
  contract = new web3.eth.Contract(contractsCompiled['KeyGenHistory'].abi);
  deploy = await contract.deploy({data: '0x' + contractsCompiled['KeyGenHistory'].bytecode, arguments: [
      [],
      [],
      []
    ]});
  spec.accounts['0x7000000000000000000000000000000000000000'] = {
    balance: '0',
    constructor: await deploy.encodeABI()
  };

  // Build InitializerHbbft contract
  contract = new web3.eth.Contract(contractsCompiled['InitializerHbbft'].abi);
  deploy = await contract.deploy({data: '0x' + contractsCompiled['InitializerHbbft'].bytecode, arguments: [
      [ // _contracts
        VALIDATOR_SET_CONTRACT,
        BLOCK_REWARD_CONTRACT,
        RANDOM_CONTRACT,
        STAKING_CONTRACT,
        PERMISSION_CONTRACT,
        CERTIFIER_CONTRACT
      ],
      owner, // _owner
      initialValidators, // _miningAddresses
      stakingAddresses, // _stakingAddresses
      firstValidatorIsUnremovable, // _firstValidatorIsUnremovable
      stakingParams,
      publicKeysSplit,
      internetAddresses,
    ]});
  spec.accounts['0x7000000000000000000000000000000000000000'] = {
    balance: '0',
    constructor: await deploy.encodeABI()
  };

  console.log('Saving spec_hbbft.json file ...');
  fs.writeFileSync(path.join(__dirname, '..', 'spec_hbbft.json'), JSON.stringify(spec, null, '  '), 'UTF-8');
  console.log('Done');
}

async function compile(dir, contractName) {
  const compiled = await utils.compile(dir, contractName);
  const abiFile = `abis/${contractName}.json`;
  console.log(`saving abi to ${abiFile}`);
  fs.writeFileSync(abiFile, JSON.stringify(compiled.abi, null, 2), 'UTF-8');
  return {abi: compiled.abi, bytecode: compiled.evm.bytecode.object};
}

// NETWORK_NAME=DPoSChain NETWORK_ID=101 OWNER=0x1092a1E3A3F2FB2024830Dd12064a4B33fF8EbAe INITIAL_VALIDATORS=0xeE385a1df869A468883107B0C06fA8791b28A04f,0x71385ae87c4b93db96f02f952be1f7a63f6057a6,0x190ec582090ae24284989af812f6b2c93f768ecd STAKING_ADDRESSES=0xe5aa2949ac94896bb2c5c75d9d5a88eb9f7c6b59,0x63a9344ae66c1f26d400b3ea4750a709c3aa6cfa,0xa5f6858d6254329a67cddab2dc04d795c5257709 STAKING_EPOCH_DURATION=120954 STAKE_WITHDRAW_DISALLOW_PERIOD=4320 COLLECT_ROUND_LENGTH=114 FIRST_VALIDATOR_IS_UNREMOVABLE=true ERC20_RESTRICTED=false PUBLIC_KEYS=0x52be8f332b0404dff35dd0b2ba44993a9d3dc8e770b9ce19a849dff948f1e14c57e7c8219d522c1a4cce775adbee5330f222520f0afdabfdb4a4501ceeb8dcee,0x99edf3f524a6f73e7f5d561d0030fc6bcc3e4bd33971715617de7791e12d9bdf6258fa65b74e7161bbbf7ab36161260f56f68336a6f65599dc37e7f2e397f845,0xa255fd7ad199f0ee814ee00cce44ef2b1fa1b52eead5d8013ed85eade03034ae4c246658946c2e1d7ded96394a1247fb4d093c32474317ae388e8d25692a0f56 IP_ADDRESSES=0x11111111111111111111111111111111,0x22222222222222222222222222222222,0x33333333333333333333333333333333 node scripts/make_spec_hbbft.js
