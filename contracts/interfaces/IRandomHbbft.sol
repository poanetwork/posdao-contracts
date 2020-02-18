pragma solidity ^0.5.16;


interface IRandomHbbft {
    function initialize(address) external;
    function currentSeed() external view returns(uint256);
}
