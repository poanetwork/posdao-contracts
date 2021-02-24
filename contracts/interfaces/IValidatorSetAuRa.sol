pragma solidity 0.5.10;


interface IValidatorSetAuRa {
    function addPool(address, address) external;
    function initialize(
        address,
        address,
        address,
        address[] calldata,
        address[] calldata,
        bool
    ) external;
    function newValidatorSet() external;
    function removeMaliciousValidators(address[] calldata) external;
    function areDelegatorsBanned(address) external view returns(bool);
    function blockRewardContract() external view returns(address);
    function changeRequestCount() external view returns(uint256);
    function emitInitiateChangeCallable() external view returns(bool);
    function getPendingValidators() external view returns(address[] memory);
    function getValidators() external view returns(address[] memory);
    function hasEverBeenMiningAddress(address) external view returns(bool);
    function idByMiningAddress(address) external view returns(uint256);
    function isReportValidatorValid(address) external view returns(bool);
    function isValidator(address) external view returns(bool);
    function isValidatorBanned(address) external view returns(bool);
    function isValidatorOrPending(address) external view returns(bool);
    function MAX_VALIDATORS() external view returns(uint256); // solhint-disable-line func-name-mixedcase
    function miningByStakingAddress(address) external view returns(address);
    function randomContract() external view returns(address);
    function reportMaliciousCallable(address, address, uint256) external view returns(bool, bool);
    function stakingByMiningAddress(address) external view returns(address);
    function stakingContract() external view returns(address);
    function unremovableValidator() external view returns(uint256);
    function validatorSetApplyBlock() external view returns(uint256);
    function validatorsToBeFinalized() external view returns(address[] memory, bool);
}
