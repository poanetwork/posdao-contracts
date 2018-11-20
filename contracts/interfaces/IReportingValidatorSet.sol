pragma solidity 0.4.25;


interface IReportingValidatorSet {
    function changeRequestCount() external view returns(uint256);
    function getValidators() external view returns(address[]);
    function isValidator(address) external view returns(bool);
    function stakingEpoch() external view returns(uint256);
}