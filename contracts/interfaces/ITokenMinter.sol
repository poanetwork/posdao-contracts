pragma solidity 0.5.10;


interface ITokenMinter {
    // This function may only be called by BlockReward contract
    function mintReward(uint256 _amount) external;

    function blockRewardContract() external view returns(address);
    function tokenContract() external view returns(address);
}
