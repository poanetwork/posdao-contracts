pragma solidity 0.4.25;


interface IValidatorSet {
    function initialize(address, address, address, address[], uint256, uint256) external;
    function blockRewardContract() external view returns(address);
    function changeRequestCount() external view returns(uint256);
    function erc20TokenContract() external view returns(address);
    function getPendingValidators() external view returns(address[]);
    function getPreviousValidators() external view returns(address[]);
    function getValidators() external view returns(address[]);
    function isValidator(address) external view returns(bool);
    function MAX_VALIDATORS() external pure returns(uint256);
    function poolStakers(address) external view returns(address[]);
    function randomContract() external view returns(address);
    function stakeAmount(address, address) external view returns(uint256);
    function stakingEpoch() external view returns(uint256);
    function validatorSetApplyBlock() external view returns(uint256);
}