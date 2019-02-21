const fs = require('fs');
const solc = require('solc');

async function compile(dir, contractName) {
  const input = {
    language: 'Solidity',
    sources: {
      '': {
        content: fs.readFileSync(dir + contractName + '.sol').toString()
      }
    },
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      evmVersion: "constantinople",
      outputSelection: {
        '*': {
          '*': [ 'abi', 'evm.bytecode.object', 'evm.methodIdentifiers' ]
        }
      }
    }
  }

  const compiled = JSON.parse(solc.compile(JSON.stringify(input), function(path) {
    let content;
    try {
      content = fs.readFileSync(dir + path);
    } catch (e) {
      if (e.code == 'ENOENT') {
        content = fs.readFileSync(dir + '../' + path);
      }
    }
    return {
      contents: content.toString()
    }
  }));

  return compiled.contracts[''][contractName];
}

module.exports = {
  compile
}
