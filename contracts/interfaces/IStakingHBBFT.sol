pragma solidity 0.5.2;


interface IStakingHBBFT {
    function initialize(
        address,
        address[] calldata,
        uint256,
        uint256
    ) external;
}
