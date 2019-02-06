# POSDAO Smart Contracts

Implementation of POSDAO consensus algorithm in Solidity language.

## About

POSDAO, a Proof-of-Stake (POS) algorithm implemented as a decentralized autonomous organization (DAO). It is designed to provide a decentralized, fair and energy efficient consensus for public chains. The algorithm works as a set of smart contracts written in Solidity. The POSDAO is implemented with a general purpose BFT consensus protocol such as AuthorityRound with a leader and probabilistic finality, or Honeybadger BFT, leaderless and with instant finality. It incentivizes actors to behave in the best interests of a network. The algorithm provides a Sybil control mechanism for reporting malicious validators and adjusting their stake, distributing a block reward, and managing a set of validators. The authors implement the POSDAO for a sidechain based on Ethereum 1.0 protocol.

## Other POSDAO Repositories and Resources

- Modified Parity-Ethereum client with changes related to POSDAO https://github.com/poanetwork/parity-ethereum/tree/aura-pos
- Integration tests setup for a POSDAO network https://github.com/poanetwork/posdao-test-setup
- Forum to ask questions and discuss https://forum.poa.network/c/posdao

## Whitepaper and License

Work in progress. Will be published later.
