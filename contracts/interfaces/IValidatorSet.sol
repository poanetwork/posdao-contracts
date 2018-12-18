pragma solidity 0.4.25;


interface IValidatorSet {
    function initialize(address[]) external;
    function changeRequestCount() external view returns(uint256);
    function getValidators() external view returns(address[]);
    function isValidator(address) external view returns(bool);
    function MAX_VALIDATORS() external pure returns(uint256);
    function poolStakers(address) external view returns(address[]);
    function stakeAmount(address, address) external view returns(uint256);
    function stakingEpoch() external view returns(uint256);
    function validatorSetApplyBlock() external view returns(uint256);
}