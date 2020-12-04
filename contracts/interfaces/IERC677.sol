pragma solidity 0.5.10;


interface IERC677 {
    // This function may only be called by Staking contract
    function stake(address _staker, uint256 _amount) external;

    // Other functions (ERC677)
    function balanceOf(address) external view returns(uint256);
    function transfer(address, uint256) external returns(bool);
}
