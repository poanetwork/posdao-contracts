const fs = require('fs');
const Web3 = require('web3');
const web3 = new Web3(new Web3.providers.HttpProvider("https://dai.poa.network"));
const utils = require('./utils/utils');

main();

async function main() {
  let dir = './contracts/';

  if (!fs.existsSync(dir)) {
    dir = '.' + dir;
  }

  const filenames = fs.readdirSync(dir);
  let contracts = [];
  let maxContractNameLength = 0;

  for (let i = 0; i < filenames.length; i++) {
    const filename = filenames[i];

    if (!filename.endsWith('.sol')) {
      continue;
    }

    const stats = fs.statSync(dir + filename);

    if (stats.isFile()) {
      const contractName = filename.replace('.sol', '');

      if (
        contractName.startsWith('Initializer') ||
        contractName.startsWith('Migrations') ||
        contractName.startsWith('Registry')
      ) {
        continue;
      }

      contracts.push(contractName);

      if (contractName.length > maxContractNameLength) {
        maxContractNameLength = contractName.length;
      }
    }
  }

  for (let i = 0; i < contracts.length; i++) {
    const contractName = contracts[i];

    const compiled = await compile(dir, contractName);
    const gas = await estimateGas(compiled, []) / 1000000;
    const dotsCount = maxContractNameLength - contractName.length;
    const dots = '.'.repeat(dotsCount);
    
    console.log(contractName + ' ' + dots + ' ' + gas + ' Mgas');
  }
}

async function estimateGas(compiled, arguments) {
  const contract = new web3.eth.Contract(compiled.abi);
  const deploy = await contract.deploy({data: '0x' + compiled.bytecode, arguments: arguments});
  return await deploy.estimateGas();
}

async function compile(dir, contractName) {
  const compiled = await utils.compile(dir, contractName);
  return {abi: compiled.abi, bytecode: compiled.evm.bytecode.object};
}

// node scripts/get_deploy_estimate_gas.js
