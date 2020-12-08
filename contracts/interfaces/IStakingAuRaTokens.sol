pragma solidity 0.5.10;


interface IStakingAuRaTokens {
    function erc677TokenContract() external view returns(address);
    function migrateToBridgedSTAKE(address) external;
}
