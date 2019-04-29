pragma solidity 0.5.7;


interface IRandom {
    function getCurrentSeed() external view returns(uint256);
}
