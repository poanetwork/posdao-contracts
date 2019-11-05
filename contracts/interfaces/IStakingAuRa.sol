pragma solidity 0.5.10;


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
        uint256
    ) external;
    function removePool(address) external;
    function removePools() external;
    function setStakingEpochStartBlock(uint256) external;
    function getPoolsLikelihood() external view returns(uint256[] memory, uint256);
    function getPoolsToBeElected() external view returns(address[] memory);
    function getPoolsToBeRemoved() external view returns(address[] memory);
    function isPoolActive(address) external view returns(bool);
    function MAX_CANDIDATES() external pure returns(uint256); // solhint-disable-line func-name-mixedcase
    function orderedWithdrawAmount(address, address) external view returns(uint256);
    function poolDelegators(address) external view returns(address[] memory);
    function rewardWasTaken(address, address, uint256) external view returns(bool);
    function stakeAmount(address, address) external view returns(uint256);
    function stakeAmountTotal(address) external view returns(uint256);
    function stakeFirstEpoch(address, address) external view returns(uint256);
    function stakeLastEpoch(address, address) external view returns(uint256);
    function stakeWithdrawDisallowPeriod() external view returns(uint256);
    function stakingEpoch() external view returns(uint256);
    function stakingEpochDuration() external view returns(uint256);
    function stakingEpochEndBlock() external view returns(uint256);
    function stakingEpochStartBlock() external view returns(uint256);
}
