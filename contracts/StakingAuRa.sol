pragma solidity 0.5.10;

import "./base/StakingAuRaTokens.sol";
//import "./base/StakingAuRaCoins.sol";


contract StakingAuRa is StakingAuRaTokens {}

// Uncomment this line and comment out the above one
// if staking in native coins is needed instead of staking in tokens:
// contract StakingAuRa is StakingAuRaCoins {}