pragma solidity 0.5.10;


interface IStakingAuRa {
    function clearUnremovableValidator(uint256) external;
    function incrementStakingEpoch() external;
    function initialize(
        address,
        uint256[] calldata,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256
    ) external;
    function removePool(uint256) external;
    function removePools() external;
    function setStakingEpochStartBlock(uint256) external;
    function getDelegatorPoolsLength(address) external view returns(uint256);
    function getPoolsLikelihood() external view returns(uint256[] memory, uint256);
    function getPoolsToBeElected() external view returns(uint256[] memory);
    function getPoolsToBeRemoved() external view returns(uint256[] memory);
    function isPoolActive(uint256) external view returns(bool);
    function MAX_CANDIDATES() external pure returns(uint256); // solhint-disable-line func-name-mixedcase
    function orderedWithdrawAmount(uint256, address) external view returns(uint256);
    function poolDelegators(uint256) external view returns(address[] memory);
    function rewardWasTaken(uint256, address, uint256) external view returns(bool);
    function stakeAmount(uint256, address) external view returns(uint256);
    function stakeAmountTotal(uint256) external view returns(uint256);
    function stakeFirstEpoch(uint256, address) external view returns(uint256);
    function stakeLastEpoch(uint256, address) external view returns(uint256);
    function stakeWithdrawDisallowPeriod() external view returns(uint256);
    function stakingEpoch() external view returns(uint256);
    function stakingEpochDuration() external view returns(uint256);
    function stakingEpochEndBlock() external view returns(uint256);
    function stakingEpochStartBlock() external view returns(uint256);
}
