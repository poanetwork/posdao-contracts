pragma solidity 0.5.10;


interface IGovernance {
    function initialize(address) external;
    function isValidatorUnderBallot(uint256) external view returns(bool);
}
