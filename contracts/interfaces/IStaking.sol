pragma solidity 0.5.2;


interface IStaking {
    function incrementStakingEpoch() external;
    function performOrderedWithdrawals() external;
    function removeFromPools(address) external;
    function removeMaliciousValidator(address) external;
    function erc20TokenContract() external view returns(address);
    function getPools() external view returns(address[] memory);
    function poolDelegators(address) external view returns(address[] memory);
    function stakeAmountMinusOrderedWithdraw(address, address) external view returns(uint256);
    function stakeAmountTotalMinusOrderedWithdraw(address) external view returns(uint256);
    function STAKE_UNIT() external pure returns(uint256); // solhint-disable-line func-name-mixedcase
    function stakingEpoch() external view returns(uint256);
}
