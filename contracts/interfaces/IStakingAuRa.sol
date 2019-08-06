pragma solidity 0.5.9;


interface IStakingAuRa {
    function initialize(
        address,
        address[] calldata,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256,
        bool
    ) external;
    function setStakingEpochStartBlock(uint256) external;
    function stakeWithdrawDisallowPeriod() external view returns(uint256);
    function stakingEpochDuration() external view returns(uint256);
    function stakingEpochStartBlock() external view returns(uint256);
    function stakingEpochEndBlock() external view returns(uint256);
}
