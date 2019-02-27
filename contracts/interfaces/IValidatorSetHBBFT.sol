pragma solidity 0.5.2;


interface IValidatorSetHBBFT {
    function initialize(
        address,
        address,
        address,
        address[] calldata,
        address[] calldata,
        bool,
        uint256,
        uint256
    ) external;
}
