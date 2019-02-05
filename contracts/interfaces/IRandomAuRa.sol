pragma solidity 0.5.2;


interface IRandomAuRa {
    function initialize(uint256) external;
    function onBlockClose() external;
}
