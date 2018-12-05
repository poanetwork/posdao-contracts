pragma solidity 0.4.25;


interface IReportingValidatorSet {
    function initialize(address[]) external;
    function changeRequestCount() external view returns(uint256);
    function getValidators() external view returns(address[]);
    function isValidator(address) external view returns(bool);
    function snapshotPoolBlockReward() external view returns(uint256);
    function snapshotStakers(address) external view returns(address[]);
    function snapshotStakeAmount(address, address) external view returns(uint256);
    function stakingEpoch() external view returns(uint256);
}