pragma solidity 0.5.9;


interface IBlockReward {
    function initialize(address) external;
    function DELEGATORS_ALIQUOT() external view returns(uint256); // solhint-disable-line func-name-mixedcase
    function isRewarding() external view returns(bool);
    function isSnapshotting() external view returns(bool);
}
