const assert = require('assert');
const fetch = require('node-fetch');
const fs = require('fs');
const path = require('path');
const Web3 = require('web3');
const chain = 'dai';
const web3 = new Web3(new Web3.providers.HttpProvider(`https://${chain}.poa.network`));
const BN = web3.utils.BN;

web3.eth.transactionBlockTimeout = 20;
web3.eth.transactionConfirmationBlocks = 1;
web3.eth.transactionPollingTimeout = 300;

const privateKey = '0x' + fs.readFileSync(`${__dirname}/key`, 'utf8').trim();
const account = web3.eth.accounts.privateKeyToAccount(privateKey);
const owner = account.address;

var abis = {};
var implementations = {};

main();

async function main() {
  // Fetch the current spec.json
  let spec = await getSpec();

  // Deploy STAKE token contract
  const tokenContract = await deploy('ERC677BridgeTokenRewardable', ['STAKE', 'STAKE', 18]);

  // Deploy POSDAO contracts
  const validatorSetContract = await deploy('ValidatorSetAuRa');
  const stakingContract = await deploy('StakingAuRa');
  const blockRewardContract = await deploy('BlockRewardAuRa');
  const randomContract = await deploy('RandomAuRa');
  const txPermissionContract = await deploy('TxPermission');
  const certifierContract = await deploy('Certifier');
  const registryContract = await deploy('Registry', [
    certifierContract.options.address,
    owner
  ]);

  // Initialization parameters
  const miningAddresses = [
    '0x9233042B8E9E03D5DC6454BBBe5aee83818fF103', // POA Network
    '0x6dC0c0be4c8B2dFE750156dc7d59FaABFb5B923D', // Giveth
    '0x9e41BA620FebA8198369c26351063B26eC5b7C9E', // MakerDAO
    '0xA13D45301207711B7C0328c6b2b64862abFe9b7a', // Protofire
    '0x657eA4A9572DfdBFd95899eAdA0f6197211527BE', // Burner Wallet
    '0xb76756f95A9fB6ff9ad3E6cb41b734c1bd805103', // Portis
    '0xDb1c683758F493Cef2E7089A3640502AB306322a', // Anyblock Analytics GmbH
    '0x657E832b1a67CDEF9e117aFd2F419387259Fa93e', // Syncnode S.R.L
    '0x10AaE121b3c62F3DAfec9cC46C27b4c1dfe4A835', // Lab10 collective
    '0x1438087186FdbFd4c256Fa2DF446921E30E54Df8', // Gnosis
    '0x0000999dc55126CA626c20377F0045946db69b6E', // Galt Project
    '0x1A740616e96E07d86203707C1619d9871614922A', // Nethermind
  ];

  const stakingAddresses = [
    '0x6A3154a1f55a8fAF96DFdE75D25eFf0C06eB6784', // POA Network
    '0x99c72Eb5c22c38137541ef4B9a2FD0316C42b510', // Giveth
    '0x2FFEA37B7ab0977dac61f980d6c633946407627B', // MakerDAO
    '0xCb253E1Fd995cb1E2b33A9c64be9D09Dc4dF0336', // Protofire
    '0x5DCeE6BC39F327F9317530B61fA75ffe0AF46C62', // Burner Wallet
    '0xeb43574E8f4FDdF11FBAf65A8632CA92262A1266', // Portis
    '0x751F0Bf3Ddec2e6677C90E869D8154C6622f31b2', // Anyblock Analytics GmbH
    '0x29CF39dE6d963D092c177a60ce67879EeA9910BB', // Syncnode S.R.L
    '0x10Bb52d950B0d472d989A4D220Fa73bC0Cc7e62d', // Lab10 collective
    '0xd3537bD39480C91271825a862180551037fddA99', // Gnosis
    '0xE868BE4d8C7A212a41a288A409658Ed3F4750495', // Galt Project
    '0x915E73d969a1e8B718D225B929dAf96E963e56DE', // Nethermind
  ];

  assert(miningAddresses.length == stakingAddresses.length);

  const certifiedAddresses = [
    owner,
    '0xcdb858ce72a31735bff85579603bbdcf85e5e081',
    '0x2adbad71c0b84922686e27952c3f506bb7b2ac0a',
    '0x9ad83402c19af24f76afa1930a2b2eec2f47a8c5',
    '0x03aae629c20affbb905b353904328c1c7274d9f2',
    '0xfa1e477c23b576d9aabc041b189ec34f263f4c71',
    '0x5ab9c640e314c8e9d0b6cfc9a8e12759dc5ab608',
    '0x7b122778b6547c340f3ea310caaf7c80a037ecf8',
    '0xcc78f946a0668632129880440df123086bd34398',
    '0xf956b2c04db59d91efa1778e35f48be48c5441e2',
    '0x77d57ddaded3f0861429bebd537fe9d81ad2aada',
    '0x4d1c96b9a49c4469a0b720a22b74b034eddfe051',
    '0xc08025c00cb9131d4b25ba1a8791adaa7deb1892',
    '0xa4d668bef19d34d45515333a3264d28a3bd787ae',
    '0x491fc792e78cdadd7d31446bb7bddef876a69ad6',
    '0x6a3154a1f55a8faf96dfde75d25eff0c06eb6784',
    '0x65459effa7a32357205c9174b55c05882b8e3ad5',
    '0x0fa4e86f3125ce226d56cd920cc0f5b145e2b1c9',
    '0xc073c8e5ed9aa11cf6776c69b3e13b259ba9f506',
    '0xcace5b3c29211740e595850e80478416ee77ca21',
    '0x5db043a62893831e89b990aa6490eb26e0fc00ee',
    '0x10dd75875a2a8a284529ae7223b1ace410d606bd',
  ];

  const firstValidatorIsUnremovable = true;
  const punishForUnreveal = false;
  const stakingEpochStartBlock = (chain == 'sokol') ? 15000000 : 9160509; // 30 March 14:00 MSK (11:00 UTC) = Unix timestamp 1585566000
  const delegatorMinStake = '1000000000000000000000'; // 1000 STAKE tokens
  const candidateMinStake = '20000000000000000000000'; // 20000 STAKE tokens
  const stakingEpochDuration = 120992; // in blocks, ~1 week for 5-second blocks
  const stakeWithdrawDisallowPeriod = 4332; // in blocks, ~6 hours for 5-second blocks
  const collectRoundLength = 76; // in blocks
  const oldBlockRewardContractAddress = '0x867305D19606aadBa405Ce534E303D0e225f9556';
  const bridgeHomeAddress = '0x7301CFA0e1756B71869E93d4e4Dca5c7d0eb0AA6';

  console.log('Initialize ValidatorSet contract...');
  await signAndSend(validatorSetContract.methods.initialize(
    blockRewardContract.options.address,
    randomContract.options.address,
    stakingContract.options.address,
    miningAddresses,
    stakingAddresses,
    firstValidatorIsUnremovable
  ), validatorSetContract.options.address);
  assert(await validatorSetContract.methods.isInitialized().call());
  assert(await validatorSetContract.methods.blockRewardContract().call() == blockRewardContract.options.address);
  assert(await validatorSetContract.methods.randomContract().call() == randomContract.options.address);
  assert(await validatorSetContract.methods.stakingContract().call() == stakingContract.options.address);
  assert((await validatorSetContract.methods.getValidators().call()).equalsIgnoreCase(miningAddresses));
  assert((await validatorSetContract.methods.getPendingValidators().call()).equalsIgnoreCase(miningAddresses));
  if (firstValidatorIsUnremovable) {
    assert((await validatorSetContract.methods.unremovableValidator().call()).equalsIgnoreCase(stakingAddresses[0]));
  } else {
    assert((await validatorSetContract.methods.unremovableValidator().call()).equalsIgnoreCase('0x0000000000000000000000000000000000000000'));
  }
  for (let i = 0; i < miningAddresses.length; i++) {
    assert(await validatorSetContract.methods.isValidator(miningAddresses[i]).call());
    assert((await validatorSetContract.methods.stakingByMiningAddress(miningAddresses[i]).call()).equalsIgnoreCase(stakingAddresses[i]));
  }

  console.log('Initialize Staking contract...');
  await signAndSend(stakingContract.methods.initialize(
    validatorSetContract.options.address,
    stakingAddresses,
    delegatorMinStake,
    candidateMinStake,
    stakingEpochDuration,
    stakingEpochStartBlock,
    stakeWithdrawDisallowPeriod
  ), stakingContract.options.address);
  await signAndSend(stakingContract.methods.setErc677TokenContract(
    tokenContract.options.address
  ), stakingContract.options.address);
  await signAndSend(tokenContract.methods.setStakingContract(
    stakingContract.options.address
  ), tokenContract.options.address);
  assert(await stakingContract.methods.isInitialized().call());
  assert(await stakingContract.methods.validatorSetContract().call() == validatorSetContract.options.address);
  assert(await stakingContract.methods.delegatorMinStake().call() == delegatorMinStake);
  assert(await stakingContract.methods.candidateMinStake().call() == candidateMinStake);
  assert(await stakingContract.methods.stakingEpochDuration().call() == stakingEpochDuration);
  assert(await stakingContract.methods.stakingEpochStartBlock().call() == stakingEpochStartBlock);
  assert(await stakingContract.methods.stakeWithdrawDisallowPeriod().call() == stakeWithdrawDisallowPeriod);
  assert((await stakingContract.methods.getPools().call()).equalsIgnoreCase(stakingAddresses));
  assert(await stakingContract.methods.erc677TokenContract().call() == tokenContract.options.address);
  assert(await tokenContract.methods.stakingContract().call() == stakingContract.options.address);

  console.log('Initialize BlockReward contract...');
  await signAndSend(blockRewardContract.methods.initialize(
    validatorSetContract.options.address,
    oldBlockRewardContractAddress
  ), blockRewardContract.options.address);
  await signAndSend(blockRewardContract.methods.setErcToNativeBridgesAllowed(
    [bridgeHomeAddress]
  ), blockRewardContract.options.address);
  await signAndSend(tokenContract.methods.setBlockRewardContract(
    blockRewardContract.options.address
  ), tokenContract.options.address);
  assert(await blockRewardContract.methods.isInitialized().call());
  assert(await blockRewardContract.methods.validatorSetContract().call() == validatorSetContract.options.address);
  assert((await blockRewardContract.methods.ercToNativeBridgesAllowed().call()).equalsIgnoreCase([bridgeHomeAddress]));
  assert(await tokenContract.methods.blockRewardContract().call() == blockRewardContract.options.address);

  console.log('Initialize Random contract...');
  await signAndSend(randomContract.methods.initialize(
    collectRoundLength,
    validatorSetContract.options.address,
    punishForUnreveal
  ), randomContract.options.address);
  assert(await randomContract.methods.isInitialized().call());
  assert(await randomContract.methods.validatorSetContract().call() == validatorSetContract.options.address);
  assert(await randomContract.methods.collectRoundLength().call() == collectRoundLength);
  assert(await randomContract.methods.punishForUnreveal().call() == punishForUnreveal);

  console.log('Initialize TxPermission contract...');
  await signAndSend(txPermissionContract.methods.initialize(
    [owner],
    certifierContract.options.address,
    validatorSetContract.options.address
  ), txPermissionContract.options.address);
  assert(await txPermissionContract.methods.isInitialized().call());
  assert(await txPermissionContract.methods.certifierContract().call() == certifierContract.options.address);
  assert(await txPermissionContract.methods.validatorSetContract().call() == validatorSetContract.options.address);
  assert(await txPermissionContract.methods.isSenderAllowed(owner).call());
  assert((await txPermissionContract.methods.allowedSenders().call()).equalsIgnoreCase([owner]));

  console.log('Initialize Certifier contract...');
  await signAndSend(certifierContract.methods.initialize(
    certifiedAddresses,
    validatorSetContract.options.address
  ), certifierContract.options.address);
  assert(await certifierContract.methods.isInitialized().call());
  assert(await certifierContract.methods.validatorSetContract().call() == validatorSetContract.options.address);
  for (let i = 0; i < certifiedAddresses.length; i++) {
    assert(await certifierContract.methods.certifiedExplicitly(certifiedAddresses[i]).call());
  }

  console.log('Mint and stake initial tokens...');
  const mintAmount = (new BN(candidateMinStake)).mul(new BN(stakingAddresses.length));
  await signAndSend(tokenContract.methods.mint(
    stakingContract.options.address,
    mintAmount.toString(10)
  ), tokenContract.options.address);
  assert((new BN(await tokenContract.methods.totalSupply().call())).eq(mintAmount));
  assert((new BN(await tokenContract.methods.balanceOf(stakingContract.options.address).call())).eq(mintAmount));
  await signAndSend(stakingContract.methods.initialValidatorStake(
    mintAmount.toString(10)
  ), stakingContract.options.address);
  for (let i = 0; i < stakingAddresses.length; i++) {
    assert((new BN(await stakingContract.methods.stakeAmount(stakingAddresses[i], stakingAddresses[i]).call())).eq(new BN(candidateMinStake)));
  }

  console.log('Change spec.json...');
  spec.engine.authorityRound.params.validators.multi[stakingEpochStartBlock] = { "contract" : validatorSetContract.options.address };
  spec.engine.authorityRound.params.blockRewardContractTransitions = {};
  spec.engine.authorityRound.params.blockRewardContractTransitions[stakingEpochStartBlock] = blockRewardContract.options.address;
  spec.engine.authorityRound.params.randomnessContractAddress = {};
  spec.engine.authorityRound.params.randomnessContractAddress[stakingEpochStartBlock] = randomContract.options.address;
  spec.engine.authorityRound.params.posdaoTransition = stakingEpochStartBlock;
  //spec.engine.authorityRound.params.blockGasLimitContractTransitions = {};
  //spec.engine.authorityRound.params.blockGasLimitContractTransitions[stakingEpochStartBlock] = txPermissionContract.options.address;
  spec.params.registrar = registryContract.options.address;
  spec.params.transactionPermissionContract = txPermissionContract.options.address;
  spec.params.transactionPermissionContractTransition = stakingEpochStartBlock;

  console.log('Save spec.json file...');
  fs.writeFileSync(path.join(__dirname, '..', 'spec.json'), JSON.stringify(spec, null, '  '), 'UTF-8');

  console.log('Save contracts.json file...');
  const contracts = {
    "ERC677BridgeTokenRewardable": tokenContract.options.address,
    "ValidatorSetAuRaCode": implementations['ValidatorSetAuRa'],
    "ValidatorSetAuRaProxy": validatorSetContract.options.address,
    "StakingAuRaCode": implementations['StakingAuRa'],
    "StakingAuRaProxy": stakingContract.options.address,
    "BlockRewardAuRaCode": implementations['BlockRewardAuRa'],
    "BlockRewardAuRaProxy": blockRewardContract.options.address,
    "RandomAuRaCode": implementations['RandomAuRa'],
    "RandomAuRaProxy": randomContract.options.address,
    "TxPermissionCode": implementations['TxPermission'],
    "TxPermissionProxy": txPermissionContract.options.address,
    "CertifierCode": implementations['Certifier'],
    "CertifierProxy": certifierContract.options.address,
    "Registry": registryContract.options.address,
    "owner": owner
  };
  fs.writeFileSync(path.join(__dirname, '..', 'contracts.json'), JSON.stringify(contracts, null, '  '), 'UTF-8');

  console.log('Save ABIs...');
  const abisPath = path.join(__dirname, '..', 'abis');
  clearDir(abisPath);
  try {
    fs.mkdirSync(abisPath);
  } catch(e) {}
  for (const contractName in abis) {
    fs.writeFileSync(path.join(abisPath, `${contractName}.abi.json`), JSON.stringify(abis[contractName], null, '  '), 'UTF-8');
  }

  console.log('Done');
}




function clearDir(dirPath) {
  let files;
  try {
    files = fs.readdirSync(dirPath);
  } catch(e) {
    return;
  }
  for (let i = 0; i < files.length; i++) {
    const filePath = dirPath + '/' + files[i];
    if (fs.statSync(filePath).isFile()) {
      fs.unlinkSync(filePath);
    }
  }
};

async function deploy(contractName, constructorArguments = null) {
  const upgradable = constructorArguments === null;

  console.log(`Deploying ${contractName} contract...`);
  const implementation = await signAndDeploy(
    contractName,
    constructorArguments
  );

  abis[contractName] = implementation.options.jsonInterface;

  if (!upgradable) {
    console.log(`  address: ${implementation.options.address}`);
    return implementation;
  } else {
    implementations[contractName] = implementation.options.address;
  }

  console.log(`  implementation address: ${implementation.options.address}`);

  const proxyContractName = 'AdminUpgradeabilityProxy';

  const proxy = await signAndDeploy(proxyContractName, [
    implementation.options.address, // implementation address
    owner, // admin (owner)
    []
  ]);
  assert(await proxy.methods.admin().call() == owner);
  assert(await proxy.methods.implementation().call() == implementation.options.address);

  if (!(proxyContractName in abis)) {
    abis[proxyContractName] = proxy.options.jsonInterface;
  }

  console.log(`  proxy address: ${proxy.options.address}`);

  return new web3.eth.Contract(
    implementation.options.jsonInterface,
    proxy.options.address
  );
}

function getSpec() {
  return fetch('https://raw.githubusercontent.com/poanetwork/poa-chain-spec/dai/spec.json').then((response) => {
    return response.json();
  })
}

async function signAndDeploy(contractName, constructorArguments) {
  const contractJSON = require(__dirname + '/../build/contracts/' + contractName);
  const contract = new web3.eth.Contract(contractJSON.abi);

  const deployObj = contract.deploy({
    data: contractJSON.bytecode,
    arguments: constructorArguments
  });

  const receipt = await signAndSend(deployObj);

  return new web3.eth.Contract(contractJSON.abi, receipt.contractAddress);
}

async function signAndSend(method, to) {
  const estimateGas = await method.estimateGas({
    from: owner
  });

  const signedTxData = await account.signTransaction({
    to,
    data: method.encodeABI(),
    gasPrice: '1000000000',
    gas: Math.trunc(estimateGas * 1.2)
  });

  const receipt = await web3.eth.sendSignedTransaction(
    signedTxData.rawTransaction
  );

  assert(receipt.status === true || receipt.status === '0x1');

  return receipt;
}

Array.prototype.equalsIgnoreCase = function(array) {
  return this.length == array.length && this.every((this_v, i) => { return this_v.equalsIgnoreCase(array[i]) });
}

String.prototype.equalsIgnoreCase = function(compareString) {
  return this.toLowerCase() === compareString.toLowerCase(); 
};

// npm run compile && node scripts/deploy_for_xdai.js
