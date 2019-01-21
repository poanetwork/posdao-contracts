pragma solidity 0.5.2;


interface IRandom {
    function currentRandom() external view returns(uint256[] memory);
}
