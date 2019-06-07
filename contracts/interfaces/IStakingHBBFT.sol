pragma solidity 0.5.9;


interface IStakingHBBFT {
    function initialize(
        address,
        address[] calldata,
        uint256,
        uint256,
        bool
    ) external;
}
