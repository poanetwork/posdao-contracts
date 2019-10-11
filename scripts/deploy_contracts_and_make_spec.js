// this is a copy of make_spec.js, modified such that contracts aren't deployed in the genesis block,
// but on a running chain - as is needed for upgrading an existing chain to POSDAO.
// Requires an unlocked and funded account provided by the connected RPC node.

const fs = require('fs');
const path = require('path');
const Web3 = require('web3');
const utils = require('./utils/utils');

const MIN_DEPLOYER_BALANCE_WEI = '1000000000000000000'; // wild guess: 1 native token
const GAS_PRICE = process.env.GAS_PRICE || 100000000000; // 100 Gwei
const GAS_LIMIT = process.env.GAS_LIMIT || 6000000; // 6 MGas

main();

async function main() {
  const rpcUrl = process.env.RPC_URL || "http://localhost:8545";
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

  // additional vars for supporting the forking case
  const templateSpecFile = process.env.TEMPLATE_SPEC_FILE || 'spec.json';
  const forkBlock = process.env.FORK_BLOCK || 0;

  const contracts = {
    ValidatorSetAuRa: { withProxy: true},
    StakingAuRa: { withProxy: true},
    BlockRewardAuRa: { withProxy: true},
    RandomAuRa: { withProxy: true},
    TxPermission: { withProxy: true},
    Certifier: { withProxy: true},
    Registry: { withProxy: false, getDeployArgs: () => [contracts.Certifier.proxyAddress, owner] },

    AdminUpgradeabilityProxy: { skipDeploy: true},
    InitializerAuRa: { skipDeploy: true},
  };

  const web3 = new Web3(rpcUrl);

  // preliminary checks: can connect, networkID matches, primary account set, unlocked and funded
  const connectedNetworkId = await web3.eth.net.getId();
  if (connectedNetworkId !== parseInt(networkID)) {
    console.error(`networkId mismatch: configured for ${networkID}, connected rpc node reports ${connectedNetworkId}. Aborting.`);
    process.exit(1);
  }
  const nodeAccs = await web3.eth.getAccounts();
  if (nodeAccs === undefined || nodeAccs.length === 0) {
    console.error('no account found on connected node');
    process.exit(2);
  }
  const deployerAddr = nodeAccs[0];
  const deployerBalanceWei = await web3.eth.getBalance(deployerAddr);
  const deployerBalanceEth = web3.utils.fromWei(deployerBalanceWei);
  if (parseInt(deployerBalanceWei) < parseInt(MIN_DEPLOYER_BALANCE_WEI)) {
    console.log(`deployer account ${deployerAddr} has insufficient balance ${deployerBalanceEth} ETH - minimum is ${web3.utils.fromWei(MIN_DEPLOYER_BALANCE_WEI)} ETH`);
    process.exit(3);
  }

  console.log(`testing if deployer account ${deployerAddr} is unlocked.\nIf it gets stuck here, it probably is not!`);
  // didn't find a more reasonable way to test this :-(
  await web3.eth.sign('testmsg', deployerAddr);

  let spec = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'templates', templateSpecFile), 'UTF-8'));

  spec.name = networkName;
  spec.params.networkID = networkID;

  // compile contracts...
  for (let i = 0; i < Object.keys(contracts).length; i++) {
    const name = Object.keys(contracts)[i];
    let realContractName = name;
    let dir = 'contracts/';

    if (name == 'AdminUpgradeabilityProxy') {
      dir = 'contracts/upgradeability/';
    } else if (name == 'StakingAuRa' && erc20Restricted) {
      realContractName = 'StakingAuRaCoins';
      dir = 'contracts/base/';
    } else if (name == 'BlockRewardAuRa' && erc20Restricted) {
      realContractName = 'BlockRewardAuRaCoins';
      dir = 'contracts/base/';
    }

    console.log(`Compiling ${name}...`);
    const compiled = await compile(
      path.join(__dirname, '..', dir),
      realContractName
    );
    contracts[name].compiled = compiled;
  }

  // deploy contracts...
  for (let i = 0; i < Object.keys(contracts).length; i++) {
    const name = Object.keys(contracts)[i];

    if (contracts[name].skipDeploy) {
      continue;
    }

    console.log(`Deploying ${name}...`);
    const compiled = contracts[name].compiled;
    const contract = new web3.eth.Contract(compiled.abi);
    const deploy = await contract.deploy({
      data: '0x' + compiled.bytecode,
      arguments: contracts[name].getDeployArgs ? contracts[name].getDeployArgs() : []
    });
    const deployed = await deploy.send({
      from: deployerAddr,
      gasPrice: GAS_PRICE,
      gas: GAS_LIMIT
    });

    contracts[name].implementationAddress = deployed.options.address;

    if (contracts[name].withProxy) {
      console.log(`Deploying Storage Proxy for ${name}...`);
      const compiled = contracts.AdminUpgradeabilityProxy.compiled;
      const contract = new web3.eth.Contract(compiled.abi);
      const deploy = await contract.deploy({
        data: '0x' + compiled.bytecode,
        arguments: [
          contracts[name].implementationAddress, // logic address
          owner, // admin
          [] // no data
        ]
      });
      const deployed = await deploy.send({
        from: deployerAddr,
        gasPrice: GAS_PRICE,
        gas: GAS_LIMIT
      });

      contracts[name].proxyAddress = deployed.options.address;
    }
  }

  // complement chain spec
  spec.engine.authorityRound.params.validators.multi[forkBlock] = {
    "contract": contracts['ValidatorSetAuRa'].proxyAddress
  };
  spec.engine.authorityRound.params.blockRewardContractTransitions[forkBlock] = contracts['BlockRewardAuRa'].proxyAddress;
  spec.engine.authorityRound.params.randomnessContractAddress = contracts['RandomAuRa'].proxyAddress;
  spec.params.transactionPermissionContract = contracts['TxPermission'].proxyAddress;
  spec.params.registrar = contracts['Registry'].proxyAddress;

  // Build InitializerAuRa contract
  const initContract = new web3.eth.Contract(contracts['InitializerAuRa'].compiled.abi);
  const initDeploy = await initContract.deploy({data: '0x' + contracts['InitializerAuRa'].compiled.bytecode, arguments: [
      [ // _contracts
        contracts.ValidatorSetAuRa.proxyAddress,
        contracts.BlockRewardAuRa.proxyAddress,
        contracts.RandomAuRa.proxyAddress,
        contracts.StakingAuRa.proxyAddress,
        contracts.TxPermission.proxyAddress,
        contracts.Certifier.proxyAddress
      ],
      owner, // _owner
      initialValidators, // _miningAddresses
      stakingAddresses, // _stakingAddresses
      firstValidatorIsUnremovable, // _firstValidatorIsUnremovable
      web3.utils.toWei('1', 'ether'), // _delegatorMinStake
      web3.utils.toWei('1', 'ether'), // _candidateMinStake
      stakingEpochDuration, // _stakingEpochDuration
      0, // _stakingEpochStartBlock
      stakeWithdrawDisallowPeriod, // _stakeWithdrawDisallowPeriod
      collectRoundLength // _collectRoundLength
    ]});

  console.log(`init deploy code: ${initDeploy.encodeABI()}`);

  initDeploy.send({
    from: deployerAddr,
    gasPrice: GAS_PRICE,
    gas: GAS_LIMIT
  });

  console.log('Saving spec.json file ...');
  fs.writeFileSync(path.join(__dirname, '..', 'spec.json'), JSON.stringify(spec, null, '  '), 'UTF-8');
  console.log('Done');
}

async function compile(dir, contractName) {
  const compiled = await utils.compile(dir, contractName);
  return {abi: compiled.abi, bytecode: compiled.evm.bytecode.object};
}

// source tau1.env
// FORK_BLOCK=$((`tau1_current_block.sh`+100)) node scripts/deploy_contracts_and_make_spec.js
