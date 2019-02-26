pragma solidity 0.5.2;


interface IRandomAuRa {
    function initialize(uint256) external;
    function onBlockClose() external;
    function commitHashCallable(address, bytes32) external view returns(bool);
    function revealSecretCallable(address, uint256) external view returns(bool);
}
