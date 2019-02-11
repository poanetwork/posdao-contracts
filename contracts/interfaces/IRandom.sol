pragma solidity 0.5.2;


interface IRandom {
    function getCurrentSeed() external view returns(uint256);
}
