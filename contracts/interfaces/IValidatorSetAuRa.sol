pragma solidity 0.5.2;


interface IValidatorSetAuRa {
    function initialize(
        address,
        address,
        address,
        address[] calldata,
        address[] calldata,
        uint256,
        uint256,
        uint256,
        uint256
    ) external;
    function removeMaliciousValidator(address) external;
    function reportMaliciousCallable(address, address, uint256) external view returns(bool, bool);
    function stakeWithdrawDisallowPeriod() external view returns(uint256);
    function stakingEpochDuration() external view returns(uint256);
    function stakingEpochStartBlock() external view returns(uint256);
    function stakingEpochEndBlock() external view returns(uint256);
}
