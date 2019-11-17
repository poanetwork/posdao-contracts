pragma solidity 0.5.10;

import "./base/StakingAuRaTokens.sol";
//import "./base/StakingAuRaCoins.sol";


contract StakingHbbft is StakingAuRaTokens {

// Uncomment this line and comment out the above one
// if staking in native coins is needed instead of staking in tokens:
// contract StakingAuRa is StakingAuRaCoins {}

    struct PoolInfo {
        bytes publicKey;
        bytes16 internetAddress;
    }

    mapping ( address => PoolInfo ) public poolInfo;

    function getPoolPublicKey(address _poolAddress) public view returns (bytes memory){
        return poolInfo[_poolAddress].publicKey;
    }

    function getPoolInternetAddress(address _poolAddress) public view returns (bytes16){
        return poolInfo[_poolAddress].internetAddress;
    }

}
