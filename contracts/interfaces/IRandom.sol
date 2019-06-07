pragma solidity 0.5.9;


interface IRandom {
    function getCurrentSeed() external view returns(uint256);
}
