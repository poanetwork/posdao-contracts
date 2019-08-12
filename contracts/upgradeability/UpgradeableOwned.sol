pragma solidity 0.5.9;

import "./UpgradeabilityAdminSlot.sol";


contract UpgradeableOwned is UpgradeabilityAdminSlot {
    /// @dev Access check: revert unless `msg.sender` is the owner of the contract.
    modifier onlyOwner() {
        bytes32 slot = ADMIN_SLOT;
        address adm;
        assembly {
            adm := sload(slot)
        }
        require(msg.sender == adm);
        _;
    }
}
