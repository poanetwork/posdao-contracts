pragma solidity 0.4.25;


interface IReportingValidatorSet {
    function isValidator(address) external view returns(bool);
    function getValidators() external view returns(address[]);
    function stakingEpoch() external view returns(uint256);
}