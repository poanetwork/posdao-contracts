#!/usr/bin/env bash

# Exit script as soon as a command fails.
set -o errexit

# Executes cleanup function at script exit.
trap cleanup EXIT

cleanup() {
  # Kill the ganache-cli instance that we started (if we started one and if it's still running).
  if [ -n "$ganache_pid" ] && ps -p $ganache_pid > /dev/null; then
    kill -9 $ganache_pid
  fi
}

if [ "$SOLIDITY_COVERAGE" = true ]; then
  ganache_port=8555
else
  ganache_port=8544
fi

ganache_running() {
  nc -z localhost "$ganache_port"
}

start_ganache() {
  if [ "$SOLIDITY_COVERAGE" = true ]; then
    node_modules/.bin/testrpc-sc --gasLimit 0xfffffffffff --port "$ganache_port" --accounts 200 > /dev/null &
  else
    node_modules/.bin/ganache-cli --gasLimit 0xfffffffffff --port "$ganache_port" --accounts 200 > /dev/null &
  fi

  ganache_pid=$!
}

if ganache_running; then
  echo "Using existing ganache-cli instance"
else
  echo "Starting ganache-cli instance"
  start_ganache
  sleep 5
fi

if [ "$SOLIDITY_COVERAGE" = true ]; then
  node_modules/.bin/solidity-coverage

  if [ "$CONTINUOUS_INTEGRATION" = true ]; then
    cat coverage/lcov.info | node_modules/.bin/coveralls
  fi
else
  node_modules/.bin/truffle test "$@" --network test
fi
