pragma solidity 0.5.7;


interface IStakingAuRa {
    function initialize(
        address,
        address,
        address[] calldata,
        uint256,
        uint256,
        uint256,
        uint256
    ) external;
    function setStakingEpochStartBlock(uint256) external;
    function stakeWithdrawDisallowPeriod() external view returns(uint256);
    function stakingEpochDuration() external view returns(uint256);
    function stakingEpochEndBlock() external view returns(uint256);
}
