pragma solidity 0.5.2;


interface IStaking {
    function incrementStakingEpoch() external;
    function removePool(address) external;
    function erc20TokenContract() external view returns(address);
    function getPoolsLikelihood() external view returns(int256[] memory, int256);
    function getPoolsToBeElected() external view returns(address[] memory);
    function getPoolsToBeRemoved() external view returns(address[] memory);
    function poolDelegators(address) external view returns(address[] memory);
    function stakeAmountMinusOrderedWithdraw(address, address) external view returns(uint256);
    function stakeAmountTotalMinusOrderedWithdraw(address) external view returns(uint256);
    function stakingEpoch() external view returns(uint256);
}
