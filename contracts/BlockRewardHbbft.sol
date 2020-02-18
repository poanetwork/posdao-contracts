pragma solidity ^0.5.16;

import "./base/BlockRewardHbbftTokens.sol";
//import "./base/BlockRewardHbbftCoins.sol";


contract BlockRewardHbbft is BlockRewardHbbftTokens {}

// Uncomment this line and comment out the above one
// if staking in native coins is needed instead of staking in tokens:
// contract BlockRewardHbbft is BlockRewardHbbftCoins {}
