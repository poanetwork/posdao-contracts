pragma solidity 0.4.25;


interface IReportingValidatorSet {
    function initialize(address[]) external;
    function changeRequestCount() external view returns(uint256);
    function getValidators() external view returns(address[]);
    function isValidator(address) external view returns(bool);
    function poolReward() external view returns(uint256);
    function rewardDistribution(address, address) external view returns(uint256);
    function rewardDistributionStakers(address) external view returns(address[]);
    function stakingEpoch() external view returns(uint256);
}