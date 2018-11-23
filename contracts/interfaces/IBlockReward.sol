pragma solidity 0.4.25;


interface IBlockReward {
	function BLOCK_REWARD() external pure returns(uint256);
    function newDistribution() external;
}