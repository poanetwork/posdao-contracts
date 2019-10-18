# prints the number of the current block of the RPC node on localhost:8545
# requires node, curl and jq to be installed and in PATH

node <<< "console.log(parseInt($(curl --silent --data '{"method":"eth_blockNumber","params":[],"id":1,"jsonrpc":"2.0"}' -H "Content-Type: application/json" -X POST http://localhost:8545 | jq ".result"), 16))"
