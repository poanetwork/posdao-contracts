pragma solidity 0.5.2;


interface IStakingAuRa {
    function initialize(
        address,
        address[] calldata,
        uint256,
        uint256,
        uint256,
        uint256
    ) external;
    function setStakingEpochStartBlock(uint256) external;
    function stakeWithdrawDisallowPeriod() external view returns(uint256);
    function stakingEpochEndBlock() external view returns(uint256);
}
