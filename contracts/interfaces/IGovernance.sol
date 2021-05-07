pragma solidity 0.5.10;


interface IGovernance {
    function isValidatorUnderBallot(uint256 _poolId) external view returns(bool);
}
