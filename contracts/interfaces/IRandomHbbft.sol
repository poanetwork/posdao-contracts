pragma solidity 0.5.10;


interface IRandomHbbft {
    function initialize(address) external;
    function currentSeed() external view returns(uint256);
}
