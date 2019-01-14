pragma solidity 0.5.2;


interface IValidatorSetAuRa {
    function removeMaliciousValidator(address) external;
    function stakingEpochStartBlock() external view returns(uint256);
    function STAKING_EPOCH_DURATION() external pure returns(uint256);
}