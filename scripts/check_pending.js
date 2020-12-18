const RPC = process.argv[2] || 'https://rpc.xdaichain.com';

const Web3 = require('web3');
const web3 = new Web3(new Web3.providers.HttpProvider(RPC));
const BN = web3.utils.BN;

main();

async function main() {
  console.log(`Retrieving pending transactions from ${RPC} ...`);
  const pending = await getPendingList(RPC);

  console.log(`Totally found ${pending.result.length} pending transactions`);
  console.log(`Searching for correct transactions...`);

  let addresses = {};

  for (let i = 0; i < pending.result.length; i++) {
    const from = pending.result[i].from.toLowerCase();
    addresses[from] = { balance: new BN(0), nonce: new BN(0) };
  }

  const addressArray = Object.keys(addresses);

  // Retrieve nonces from RPC
  let promises = [];
  let batch = new web3.BatchRequest();
  for (let i = 0; i < addressArray.length; i++) {
    const address = addressArray[i];
    promises.push(new Promise((resolve, reject) => {
      batch.add(web3.eth.getTransactionCount.request(address, 'latest', (err, nonce) => {
        if (err) reject(err);
        else resolve(nonce);
      }));
    }));
  }
  await batch.execute();
  const nonces = await Promise.all(promises);

  // Retrieve balances from RPC
  promises = [];
  batch = new web3.BatchRequest();
  for (let i = 0; i < addressArray.length; i++) {
    const address = addressArray[i];
    promises.push(new Promise((resolve, reject) => {
      batch.add(web3.eth.getBalance.request(address, 'latest', (err, balance) => {
        if (err) reject(err);
        else resolve(balance);
      }));
    }));
  }
  await batch.execute();
  const balances = await Promise.all(promises);
  
  for (let i = 0; i < addressArray.length; i++) {
    const address = addressArray[i];
    addresses[address].balance = new BN(balances[i]);
    addresses[address].nonce = new BN(nonces[i]);
  }

  let correctTXsFound = 0;
  const gasLimit = new BN('9000000');
  for (let i = 0; i < pending.result.length; i++) {
    const tx = pending.result[i];
    const from = tx.from.toLowerCase();
    const txNonce = new BN(web3.utils.hexToNumberString(tx.nonce));
    const txGas = new BN(web3.utils.hexToNumberString(tx.gas));
    const txGasPrice = new BN(web3.utils.hexToNumberString(tx.gasPrice));
    const txValue = new BN(web3.utils.hexToNumberString(tx.value));
    const txValuePlusGas = txGas.mul(txGasPrice).add(txValue);

    let minGasLimit = new BN('21000');
    if (tx.input != '0x' && tx.input) {
      minGasLimit = new BN('21064');
    }

    if (txNonce.eq(addresses[from].nonce) && txGas.lt(gasLimit) && txGas.gte(minGasLimit) && txValuePlusGas.lte(addresses[from].balance)) {
      console.log(`Correct TX:`);
      console.log(tx);
      correctTXsFound++;
    }
  }

  console.log(`Found ${correctTXsFound} correct transaction(s) - ${Math.round(correctTXsFound / pending.result.length * 10000) / 100}% of ${pending.result.length} pending txs`);
}

function getPendingList(rpc) {
  const cmd = `curl --data '{"method":"parity_pendingTransactions","params":[],"id":1,"jsonrpc":"2.0"}' -H "Content-Type: application/json" -X POST ${rpc}`;
  return new Promise((resolve, reject) => {
    var exec = require('child_process').exec;
    exec(cmd, { maxBuffer: 1024*1024*10 }, function (error, stdout, stderr) {
      if (error !== null) {
        reject(error);
      }
      let resp;
      try {
        resp = JSON.parse(stdout);
      } catch(e) {
        reject(e);
      }
      resolve(resp);
    });
  })
}
