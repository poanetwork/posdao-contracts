# POSDAO Smart Contracts

Implementation of POSDAO consensus algorithm in Solidity language.

## About

POSDAO, a Proof-of-Stake (POS) algorithm implemented as a decentralized autonomous organization (DAO). It is designed to provide a decentralized, fair and energy efficient consensus for public chains. The algorithm works as a set of smart contracts written in Solidity. The POSDAO is implemented with a general purpose BFT consensus protocol such as AuthorityRound with a leader and probabilistic finality, or Honeybadger BFT, leaderless and with instant finality. It incentivizes actors to behave in the best interests of a network. The algorithm provides a Sybil control mechanism for reporting malicious validators and adjusting their stake, distributing a block reward, and managing a set of validators. The authors implement the POSDAO for a sidechain based on Ethereum 1.0 protocol.

## POSDAO Repositories and Resources

- Whitepaper https://forum.poa.network/t/posdao-white-paper/2208
- Modified Parity-Ethereum client with changes related to POSDAO https://github.com/poanetwork/parity-ethereum/tree/aura-pos
- Integration tests setup for a POSDAO network https://github.com/poanetwork/posdao-test-setup
- Forum to ask questions and discuss https://forum.poa.network/c/posdao

## Contracts brief description

- `BlockRewardAuRa`: generates and distributes rewards according to the logic and formulas described in Whitepaper. Main features include:
  - distributes the entrance/exit fees from the `erc-to-erc`, `native-to-erc`, and/or `erc-to-native` bridges among validators and their delegators;
  - distributes staking tokens minted by 1%/year inflation among validators and their delegators;
  - mints native coins needed for the `erc-to-native` bridge;
  - makes a snapshot of the validators and their delegators at the beginning of each staking epoch and uses that snapshot during the staking epoch to accrue rewards to validators and their delegators.

- `Certifier`: allows validators to use a zero gas price for their service transactions (see [Parity Wiki](https://wiki.parity.io/Permissioning.html#gas-price) for more info). The following functions are considered service transactions:
  - ValidatorSet.emitInitiateChange
  - ValidatorSet.reportMalicious
  - RandomAura.commitHash
  - RandomAura.revealSecret

- `InitializerAuRa`: used once on network startup and then destroyed on genesis block. This contract is needed for initializing upgradable contracts on the genesis block since an upgradable contract can't have the constructor. The bytecode of this contract is written by the `scripts/make_spec.js` into `spec.json` along with other contracts.

- `KeyGenHistory`: stores the validator’s public keys needed for the HoneyBadger BFT engine and for storing events used by HBBFT nodes.

- `RandomAuRa`: generates and stores random numbers in a [RANDAO](https://github.com/randao/randao) manner (and controls when they are revealed by Aura validators). Random numbers are used to form a new validator set at the beginning of each staking epoch by the `ValidatorSet` contract. Key functions include:
  - `commitHash` and `revealSecret`. Can only be called by the validator's node when generating and revealing their secret number (see [RANDAO](https://github.com/randao/randao) to understand principle). Each validator node must call these functions once per `collection round`. This creates a random seed which is used by `ValidatorSetAuRa` contract. See Whitepaper for more details;
  - `onBlockClose`. This function is automatically called by the `BlockRewardAuRa` contract at the end of each `collection round`. It controls the reveal phase for validator nodes and punishes validators when they don’t reveal (see Whitepaper for more details on the `banning` protocol).

- `Registry`: stores human-readable keys associated with addresses, like DNS information (see [Parity Wiki](https://wiki.parity.io/Parity-name-registry.html)). This contract is needed primarily to store the address of the `TxPermission` contract (see [Parity Wiki](https://wiki.parity.io/Permissioning.html#transaction-type) for details).

- `StakingAuRa`: contains staking logic including:
  - creating, storing, and removing pools by candidates and validators;
  - staking tokens by participants (delegators, candidates, or validators) into the pools;
  - storing participants’ stakes;
  - withdrawing tokens by participants from the pools;
  - moving tokens between pools by participant;
  - performing automatic token withdrawals at the end of a staking epoch if requested by participants.

- `TxPermission`: controls the use of zero gas price by validators in service transactions, protecting the network against "transaction spamming" by malicious validators. The protection logic is declared in the `allowedTxTypes` function.

- `ValidatorSetAuRa`: stores the current validator set and contains the logic for choosing new validators at the beginning of each staking epoch. The logic uses a random seed generated and stored by the `RandomAuRa` contract. Also, ValidatorSetAuRa along with [modified Parity client](https://github.com/poanetwork/parity-ethereum/tree/aura-pos) is responsible for discovering and removing malicious validators. This contract is based on `reporting ValidatorSet` [described in Parity Wiki](https://wiki.parity.io/Validator-Set.html#reporting-contract).

Note that HBBFT contracts implementations are not fully finished, so they are not listed nor described here.

To get a detailed description of each function of the contracts, see the source code.

## License

Will be published later.
