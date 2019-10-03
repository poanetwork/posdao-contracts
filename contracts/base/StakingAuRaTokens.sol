pragma solidity 0.5.9;

import "./StakingAuRaBase.sol";


/// @dev Implements staking and withdrawal logic.
contract StakingAuRaTokens is StakingAuRaBase {

    // =============================================== Storage ========================================================

    /// @dev The address of the ERC20/677 staking token contract.
    IERC20Minting public erc20TokenContract;

    // =============================================== Setters ========================================================

    /// @dev Sets the address of the ERC20/ERC677 staking token contract. Can only be called by the `owner`.
    /// Cannot be called if there was at least one stake in staking tokens before.
    /// @param _erc20TokenContract The address of the contract.
    function setErc20TokenContract(IERC20Minting _erc20TokenContract) external onlyOwner onlyInitialized {
        require(_erc20TokenContract != IERC20Minting(0));
        require(erc20TokenContract == IERC20Minting(0));
        require(_erc20TokenContract.balanceOf(address(this)) == 0);
        erc20TokenContract = _erc20TokenContract;
    }

    /// @dev Sends tokens from this contract to the specified address.
    /// @param _to The target address to send amount to.
    /// @param _amount The amount to send.
    function _sendWithdrawnStakeAmount(address payable _to, uint256 _amount) internal {
        require(erc20TokenContract != IERC20Minting(0));
        erc20TokenContract.transfer(_to, _amount);
    }

    /// @dev The internal function used by the `stake` and `addPool` functions.
    /// See the `stake` public function for more details.
    /// @param _toPoolStakingAddress The staking address of the pool where the tokens should be staked.
    /// @param _amount The amount of tokens to be staked.
    function _stake(address _toPoolStakingAddress, uint256 _amount) internal gasPriceIsValid onlyInitialized {
        address staker = msg.sender;
        _stake(_toPoolStakingAddress, staker, _amount);
        require(msg.value == 0);
        require(erc20TokenContract != IERC20Minting(0));
        erc20TokenContract.stake(staker, _amount);
        emit PlacedStake(_toPoolStakingAddress, staker, stakingEpoch, _amount);
    }
}
