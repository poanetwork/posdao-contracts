# POSDAO Smart Contracts

Implementation of POSDAO consensus algorithm in Solidity language.

## About

POSDAO, a Proof-of-Stake (POS) algorithm implemented as a decentralized autonomous organization (DAO). It is designed to provide a decentralized, fair and energy efficient consensus for public chains. The algorithm works as a set of smart contracts written in Solidity. The POSDAO is implemented with a general purpose BFT consensus protocol such as AuthorityRound with a leader and probabilistic finality, or Honeybadger BFT, leaderless and with instant finality. It incentivizes actors to behave in the best interests of a network. The algorithm provides a Sybil control mechanism for reporting malicious validators and adjusting their stake, distributing a block reward, and managing a set of validators. The authors implement the POSDAO for a sidechain based on Ethereum 1.0 protocol.

## Other POSDAO Repositories and Resources

- Modified Parity-Ethereum client with changes related to POSDAO https://github.com/poanetwork/parity-ethereum/tree/aura-pos
- Integration tests setup for a POSDAO network https://github.com/poanetwork/posdao-test-setup
- Forum to ask questions and discuss https://forum.poa.network/c/posdao

## Contracts brief description

- `BlockRewardAuRa` contract mainly generates and distributes rewards by the logic and formulas described in Whitepaper. The features of this contract:
  - distributes the fee from `erc-to-erc`, `native-to-erc`, and/or `erc-to-native` bridge among validators and their delegators;
  - distributes staking tokens minted by 1%/year inflation among validators and their delegators;
  - mints native coins needed for `erc-to-native` bridge;
  - makes a snapshot of the validators and their delegators at the beginning of each staking epoch and uses that snapshot during the staking epoch to accrue rewards to validators and their delegators.

- `Certifier` allows validators use zero gas price for their service transactions (see [Parity Wiki](https://wiki.parity.io/Permissioning.html#gas-price) for more info). By the service transactions the callings of the next functions are meant:
  - ValidatorSet.emitInitiateChange
  - ValidatorSet.reportMalicious
  - RandomAura.commitHash
  - RandomAura.revealSecret

- `InitializerAuRa` is used once on network startup and then destroyed on genesis block. This contract is needed for initializing upgradable contracts on genesis block since an upgradable contract can't have the constructor. The bytecode of this contract is written by `scripts/make_spec.js` into `spec.json` along with other contracts.

- `KeyGenHistory` is used for storing validators public keys needed for HBBFT engine and for storing events which can be used by HBBFT nodes.

- `RandomAuRa` contract generates and stores random numbers in [RANDAO](https://github.com/randao/randao) manner (and controls their revealing by validators for Aura) which are used when forming new validator set at the beginning of each staking epoch by `ValidatorSet` contract. The RandomAuRa contract has the next key functions:
  - `commitHash` and `revealSecret`. Can only be called by validator's node when generating and revealing their secret number by the node (see [RANDAO](https://github.com/randao/randao) to understand principle). Each validator node must call these functions once per so-called `collection round`. This logic forms random seed which is used by `ValidatorSetAuRa` contract. See Whitepaper for more details;
  - `onBlockClose`. This function is automatically called by `BlockRewardAuRa` contract at the end of each `collection round`. The function is responsible for controlling revealing secret numbers by validators nodes and for punishing the validators when they don't reveal.

- `Registry` contract stores human-readable keys associated with addresses, like DNS (see [Parity Wiki](https://wiki.parity.io/Parity-name-registry.html) for more info). This contract is mainly needed for storing the address of `TxPermission` contract (see [Parity Wiki](https://wiki.parity.io/Permissioning.html#transaction-type) to get how it works).

- `StakingAuRa` contains staking logic and includes the next features:
  - creating, storing, and removing pools by candidates and validators;
  - staking tokens by participants (delegators, candidates, or validators) into the pools;
  - storing stakes made by participants;
  - withdrawal tokens by participants from the pools;
  - moving tokens between pools by participant;
  - performing automatic tokens withdrawals at the end of staking epoch ordered by participants.

- `TxPermission` controls the use of zero gas price by validators in service transactions and that way protects the network against transactions spamming by malicious validators. The protection logic is written in `allowedTxTypes` function.

- `ValidatorSetAuRa` stores the current validator set and contains the logic for choosing new validators at the beginning of each staking epoch. The logic uses random seed generated and stored by `RandomAuRa` contract. Also, ValidatorSetAuRa along with [modified Parity client](https://github.com/poanetwork/parity-ethereum/tree/aura-pos) is responsible for discovering and removing malicious validators. This contract is based on `reporting ValidatorSet` [described in Parity Wiki](https://wiki.parity.io/Validator-Set.html#reporting-contract).

Note that HBBFT contracts implementations are not fully finished, so they are not listed nor described here.

To get a detailed description of each function of the contracts, see the source code.

## Whitepaper and License

Work in progress. Will be published later.
