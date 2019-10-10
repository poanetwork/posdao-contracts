pragma solidity 0.5.9;


interface IERC677Minting {
    // This function may only be called by BlockReward contract
    function mintReward(uint256 _amount) external;

    // This function may only be called by Staking contract
    function stake(address _staker, uint256 _amount) external;

    // Other ERC677 functions
    function balanceOf(address) external view returns(uint256);
    function transfer(address, uint256) external returns(bool);
}
