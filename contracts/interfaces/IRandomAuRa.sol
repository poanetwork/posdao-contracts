pragma solidity 0.5.7;


interface IRandomAuRa {
    function initialize(uint256, address) external;
    function onFinishCollectRound() external;
    function commitHashCallable(address, bytes32) external view returns(bool);
    function revealSecretCallable(address, uint256) external view returns(bool);
}
