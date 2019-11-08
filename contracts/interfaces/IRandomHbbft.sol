pragma solidity 0.5.9;


interface IRandomHbbft {
    function initialize(uint256, address) external;
    function currentSeed() external view returns(uint256);
}
