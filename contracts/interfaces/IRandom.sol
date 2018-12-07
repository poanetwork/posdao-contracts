pragma solidity 0.4.25;


interface IRandom {
    function currentRandom() external view returns(uint256[]);
}