// This script checks the functions of contracts for clashing.
// See https://medium.com/nomic-labs-blog/malicious-backdoors-in-ethereum-proxies-62629adf3357
// for details.

const fs = require('fs');
const utils = require('./utils/utils');

main();

async function main() {
  console.log('Checking the contracts\' functions for a clashing...');

  let dir = './contracts/';

  if (!fs.existsSync(dir)) {
    dir = '.' + dir;
  }

  const eternalStorageProxyHashes = await getHashes(
    `${dir}eternal-storage/`,
    'EternalStorageProxy'
  );

  const filenames = fs.readdirSync(dir);
  let contracts = [];
  let success = true;

  for (let i = 0; i < filenames.length; i++) {
    const filename = filenames[i];

    if (!filename.endsWith('.sol')) {
      continue;
    }

    const stats = fs.statSync(dir + filename);

    if (stats.isFile()) {
      const contractName = filename.replace('.sol', '');

      if (contractName == 'Migrations') {
        continue;
      }

      contracts.push(contractName);
    }
  }

  for (let i = 0; i < contracts.length; i++) {
    const contractName = contracts[i];
    const contractHashes = await getHashes(dir, contractName);

    for (const fnSignature in contractHashes) {
      const fnHash = contractHashes[fnSignature];

      for (const eternalFnSignature in eternalStorageProxyHashes) {
        const eternalFnHash = eternalStorageProxyHashes[eternalFnSignature];

        if (fnHash == eternalFnHash) {
          console.error('');
          console.error(`Error: the hash for ${contractName}.${fnSignature} is the same as for EternalStorageProxy.${eternalFnSignature}`);
          success = false;
        }
      }
    }
  }

  if (success) {
    console.log('Success');
    console.log('');
  } else {
    console.error('');
    process.exit(1);
  }
}

async function getHashes(dir, contractName) {
  const compiled = await utils.compile(dir, contractName);
  return compiled.evm.methodIdentifiers;
}

// node scripts/check_for_clashing.js
