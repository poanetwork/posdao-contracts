pragma solidity 0.5.2;


interface IBlockReward {
    function DELEGATORS_ALIQUOT() external view returns(uint256); // solhint-disable-line func-name-mixedcase
    function isSnapshotting() external view returns(bool);
}
