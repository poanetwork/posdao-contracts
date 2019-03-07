# POSDAO Smart Contracts

Implementation of POSDAO consensus algorithm in Solidity language.

## About

POSDAO, a Proof-of-Stake (POS) algorithm implemented as a decentralized autonomous organization (DAO). It is designed to provide a decentralized, fair and energy efficient consensus for public chains. The algorithm works as a set of smart contracts written in Solidity. The POSDAO is implemented with a general purpose BFT consensus protocol such as AuthorityRound with a leader and probabilistic finality, or Honeybadger BFT, leaderless and with instant finality. It incentivizes actors to behave in the best interests of a network. The algorithm provides a Sybil control mechanism for reporting malicious validators and adjusting their stake, distributing a block reward, and managing a set of validators. The authors implement the POSDAO for a sidechain based on Ethereum 1.0 protocol.

## Other POSDAO Repositories and Resources

- Modified Parity-Ethereum client with changes related to POSDAO https://github.com/poanetwork/parity-ethereum/tree/aura-pos
- Integration tests setup for a POSDAO network https://github.com/poanetwork/posdao-test-setup
- Forum to ask questions and discuss https://forum.poa.network/c/posdao

## Contracts brief description

- `BlockReward` contract generates and distributes rewards by the logic and formulas described in Whitepaper. It has different implementations for Aura and HBBFT.
- `Certifier` allows validators using zero gas price for service transactions (see https://wiki.parity.io/Permissioning.html#gas-price for more info).
- `Initializer` is used once on network startup and then destroyed on genesis block, has different implementations for Aura and HBBFT.
- `KeyGenHistory` is used to store validators public keys needed for HBBFT engine.
- `Random` contract generates and stores random numbers in RANDAO manner (and controls their revealing by validators for Aura) which are used when forming new validator set at the beginning of each staking epoch. The contract has different implementations for Aura and HBBFT.
- `Registry` stores human-readable keys associated with addresses, like DNS (see https://wiki.parity.io/Parity-name-registry.html for more info).
- `Staking` contract contains staking logic: it allows staking tokens, withdrawal tokens, creating and removing pools. It has different implementations for Aura and HBBFT.
- `TxPermission` controls the use of zero gas price by validators in service transactions and protects the network against transactions spamming by malicious validators that way.
- `ValidatorSet` stores the current validator set and contains the logic for choosing new validators at the beginning of each staking epoch. Also, this contract along with [modified Parity client](https://github.com/poanetwork/parity-ethereum) is responsible for discovering and removing malicious validators. It has different implementations for Aura and HBBFT.

Note that HBBFT implementations are not fully finished.

## Whitepaper and License

Work in progress. Will be published later.
