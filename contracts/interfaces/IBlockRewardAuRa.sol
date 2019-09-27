pragma solidity 0.5.9;


interface IBlockRewardAuRa {
    function clearBlocksCreated() external;
    function initialize(address) external;
    function transferReward(uint256, uint256, address payable) external;
    function epochsPoolGotRewardFor(address) external view returns(uint256[] memory);
    function getDelegatorRewards(uint256, uint256, address) external view returns(uint256, uint256);
    function getValidatorRewards(uint256, address) external view returns(uint256, uint256);
    function mintedTotally() external view returns(uint256);
    function mintedTotallyByBridge(address) external view returns(uint256);
}
