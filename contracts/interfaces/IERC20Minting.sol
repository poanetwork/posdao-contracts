pragma solidity 0.4.25;


interface IERC20Minting {
	// This function may only be called by BlockReward contract
    function mintReward(address[] _receivers, uint256[] _rewards) external;

    // These functions may only be called by ValidatorSet contract
    function stake(address _staker, uint256 _amount) external;
    function withdraw(address _staker, uint256 _amount) external;
}