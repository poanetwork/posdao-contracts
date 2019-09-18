pragma solidity 0.5.9;


interface IBlockRewardAuRa {
    function initialize(address) external;
    function setSnapshotTotalStakeAmount() external;
    function transferReward(uint256, uint256, address payable) external;
    function delegatorShare(uint256, uint256, uint256, uint256) external pure returns(uint256);
    function epochPoolNativeReward(uint256, address) external view returns(uint256);
    function epochPoolTokenReward(uint256, address) external view returns(uint256);
    function mintedTotally() external view returns(uint256);
    function mintedTotallyByBridge(address) external view returns(uint256);
    function snapshotPoolTotalStakeAmount(uint256, address) external view returns(uint256);
    function snapshotPoolValidatorStakeAmount(uint256, address) external view returns(uint256);
    function validatorShare(uint256, uint256, uint256) external pure returns(uint256);
}
