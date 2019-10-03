pragma solidity 0.5.9;

import "./StakingAuRaBase.sol";


contract Sacrifice {
    constructor(address payable _recipient) public payable {
        selfdestruct(_recipient);
    }
}


/// @dev Implements staking and withdrawal logic.
contract StakingAuRaCoins is StakingAuRaBase {

    // =============================================== Getters ========================================================

    function erc20TokenContract() public view returns(address) {
        return address(0);
    }

    // =============================================== Setters ========================================================

    /// @dev Sends coins from this contract to the specified address.
    /// @param _to The target address to send amount to.
    /// @param _amount The amount to send.
    function _sendWithdrawnStakeAmount(address payable _to, uint256 _amount) internal {
        if (!_to.send(_amount)) {
            // We use the `Sacrifice` trick to be sure the coins can be 100% sent to the receiver.
            // Otherwise, if the receiver is a contract which has a revert in its fallback function,
            // the sending will fail.
            (new Sacrifice).value(_amount)(_to);
        }
    }

    /// @dev The internal function used by the `stake` and `addPool` functions.
    /// See the `stake` public function for more details.
    /// @param _toPoolStakingAddress The staking address of the pool where the coins should be staked.
    /// @param _amount The amount of coins to be staked.
    function _stake(address _toPoolStakingAddress, uint256 _amount) internal gasPriceIsValid onlyInitialized {
        address staker = msg.sender;
        _amount = msg.value;
        _stake(_toPoolStakingAddress, staker, _amount);
        emit PlacedStake(_toPoolStakingAddress, staker, stakingEpoch, _amount);
    }
    
}
