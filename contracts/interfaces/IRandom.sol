pragma solidity 0.5.2;


interface IRandom {
    function getCurrentSecret() external view returns(uint256);
}
