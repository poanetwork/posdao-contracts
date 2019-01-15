pragma solidity 0.5.2;


interface IValidatorSetHBBFT {
    function initialize(address, address, address, address[] calldata, uint256, uint256) external;
}