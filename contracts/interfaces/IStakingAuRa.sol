pragma solidity 0.5.9;


interface IStakingAuRa {
    function clearUnremovableValidator(address) external;
    function incrementStakingEpoch() external;
    function initialize(
        address,
        address[] calldata,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256,
        bool
    ) external;
    function removePool(address) external;
    function removePools() external;
    function setStakingEpochStartBlock(uint256) external;
    function erc20TokenContract() external view returns(address);
    function getPoolsLikelihood() external view returns(uint256[] memory, uint256);
    function getPoolsToBeElected() external view returns(address[] memory);
    function getPoolsToBeRemoved() external view returns(address[] memory);
    function MAX_CANDIDATES() external pure returns(uint256); // solhint-disable-line func-name-mixedcase
    function poolDelegators(address) external view returns(address[] memory);
    function stakeAmountMinusOrderedWithdraw(address, address) external view returns(uint256);
    function stakeAmountTotalMinusOrderedWithdraw(address) external view returns(uint256);
    function stakeWithdrawDisallowPeriod() external view returns(uint256);
    function stakingEpoch() external view returns(uint256);
    function stakingEpochDuration() external view returns(uint256);
    function stakingEpochEndBlock() external view returns(uint256);
    function stakingEpochStartBlock() external view returns(uint256);
}
