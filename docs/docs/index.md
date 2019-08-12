---
id: index
title: POSDAO Smart Contracts Docs
---

## Navigation

POSDAO smart contracts are located in the contracts directory, which contains the root contracts as well as upgradeability subdirectory. View the documentation by selecting a contract from the menu. To return to the repo, go to https://github.com/poanetwork/posdao-contracts

- **upgradeability:** upgradeability and contract storage management.
- **root:** POSDAO functional contracts.

## Smart Contract Summaries

- **BlockRewardAuRa:** reward generation and distribution. 

- **Certifier:** allows validators to use a zero gas price for service transactions such as reporting malicious validators and revealing secrets (see [Parity Wiki](https://wiki.parity.io/Permissioning.html#gas-price) for more info). 

- **InitializerAuRa:** Initializes upgradable contracts and is then destroyed. This contract's bytecode is written by the `scripts/make_spec.js` into `spec.json` along with other contracts.

- **RandomAuRa:** generates and stores random numbers in a [RANDAO](https://github.com/randao/randao) manner (and controls when they are revealed by Aura validators). 

- **Registry:** stores human-readable keys associated with addresses (see [Parity Wiki](https://wiki.parity.io/Parity-name-registry.html)). Used primarily to store the address of the `Certifier` contract (see [Parity Wiki](https://wiki.parity.io/Permissioning.html#gas-price) for details).

- **StakingAuRa:** contains the contract staking logic for candidates, delegators and validators.

- **TxPermission:** controls the use of a zero gas price by validators in service transactions, protecting the network against "transaction spamming" by malicious validators. 

- **ValidatorSetAuRa:** stores the current validator set and contains the logic for new validators selection at the beginning of each staking epoch.