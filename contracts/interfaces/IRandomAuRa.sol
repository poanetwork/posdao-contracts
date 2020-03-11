pragma solidity 0.5.10;


interface IRandomAuRa {
    function initialize(uint256, address, bool) external;
    function onFinishCollectRound() external;
    function commitHashCallable(address, bytes32) external view returns(bool);
    function currentSeed() external view returns(uint256);
    function revealNumberCallable(address, uint256) external view returns(bool);
}
