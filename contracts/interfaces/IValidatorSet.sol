pragma solidity 0.5.2;


interface IValidatorSet {
    function newValidatorSet() external;
    function blockRewardContract() external view returns(address);
    function changeRequestCount() external view returns(uint256);
    function erc20TokenContract() external view returns(address);
    function getPendingValidators() external view returns(address[] memory);
    function getPreviousValidators() external view returns(address[] memory);
    function getValidators() external view returns(address[] memory);
    function isReportValidatorValid(address) external view returns(bool);
    function isValidator(address) external view returns(bool);
    function isValidatorOnPreviousEpoch(address) external view returns(bool);
    function MAX_VALIDATORS() external pure returns(uint256);
    function poolDelegators(address) external view returns(address[] memory);
    function randomContract() external view returns(address);
    function stakeAmount(address, address) external view returns(uint256);
    function stakingEpoch() external view returns(uint256);
    function validatorSetApplyBlock() external view returns(uint256);
}
