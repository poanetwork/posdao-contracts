pragma solidity 0.5.12;


interface IRandomAuRa {
    function initialize(uint256, address) external;
    function onFinishCollectRound() external;
    function commitHashCallable(address, bytes32) external view returns(bool);
    function currentSeed() external view returns(uint256);
    function revealSecretCallable(address, uint256) external view returns(bool);
}
