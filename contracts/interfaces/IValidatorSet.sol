pragma solidity 0.5.9;


interface IValidatorSet {
    function initialize(
        address,
        address,
        address,
        address[] calldata,
        address[] calldata,
        bool
    ) external;
    function newValidatorSet() external returns(bool, uint256);
    function setStakingAddress(address, address) external;
    function blockRewardContract() external view returns(address);
    function changeRequestCount() external view returns(uint256);
    function emitInitiateChangeCallable() external view returns(bool);
    function getPendingValidators() external view returns(address[] memory);
    function getPreviousValidators() external view returns(address[] memory);
    function getValidators() external view returns(address[] memory);
    function isReportValidatorValid(address) external view returns(bool);
    function isValidator(address) external view returns(bool);
    function isValidatorBanned(address) external view returns(bool);
    function MAX_VALIDATORS() external view returns(uint256); // solhint-disable-line func-name-mixedcase
    function miningByStakingAddress(address) external view returns(address);
    function randomContract() external view returns(address);
    function stakingByMiningAddress(address) external view returns(address);
    function stakingContract() external view returns(address);
    function unremovableValidator() external view returns(address);
    function validatorIndex(address) external view returns(uint256);
    function validatorSetApplyBlock() external view returns(uint256);
}
