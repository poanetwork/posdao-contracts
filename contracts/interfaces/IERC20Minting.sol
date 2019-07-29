pragma solidity 0.5.9;


interface IERC20Minting {
    // This function may only be called by BlockReward contract
    function mintReward(address[] calldata _receivers, uint256[] calldata _rewards) external;

    // This function may only be called by Staking contract
    function stake(address _staker, uint256 _amount) external;

    // Other ERC20 functions
    function balanceOf(address) external view returns(uint256);
    function transfer(address, uint256) external returns(bool);
}
