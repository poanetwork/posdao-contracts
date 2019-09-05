pragma solidity 0.5.9;


interface IBlockRewardAuRa {
    function initialize(address) external;
    function setSnapshotTotalStakeAmount() external;
    function mintedTotally() external view returns(uint256);
    function mintedTotallyByBridge(address _bridge) external view returns(uint256);
}
