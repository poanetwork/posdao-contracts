pragma solidity 0.5.10;

import "./upgradeability/UpgradeabilityAdmin.sol";
import "./interfaces/IValidatorSetHbbft.sol";

/// @dev Stores and uppdates a random seed that is used to form a new validator set by the
/// `ValidatorSetHbbft.newValidatorSet` function.
contract RandomHbbft is UpgradeabilityAdmin {

    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables and do not change their types!


    /// @dev The current random seed accumulated during RANDAO or another process
    /// (depending on implementation).
    uint256 public currentSeed;


    /// @dev The address of the `ValidatorSetHbbft` contract.
    IValidatorSetHbbft public validatorSetContract;

    // ============================================== Modifiers =======================================================

    /// @dev Ensures the caller is the BlockRewardHbbft contract address.
    modifier onlyBlockReward() {
        require(msg.sender == validatorSetContract.blockRewardContract());
        _;
    }

    /// @dev Ensures the `initialize` function was called before.
    modifier onlyInitialized {
        require(isInitialized());
        _;
    }

    // =============================================== Setters ========================================================


    function setCurrentSeed(uint256 _currentSeed) external onlyInitialized {
        currentSeed = _currentSeed;
    }

    /// @dev Initializes the contract at network startup.
    /// Can only be called by the constructor of the `InitializerHbbft` contract or owner.
    /// @param _validatorSet The address of the `ValidatorSet` contract.
    function initialize(
        address _validatorSet
    ) external {
        _initialize(_validatorSet);
    }

    // =============================================== Getters ========================================================

    /// @dev Returns a boolean flag indicating if the `initialize` function has been called.
    function isInitialized() public view returns(bool) {
        return validatorSetContract != IValidatorSetHbbft(0);
    }


    // ============================================== Internal ========================================================

    /// @dev Initializes the network parameters. Used by the `initialize` function.
    /// @param _validatorSet The address of the `ValidatorSetHbbft` contract.
    function _initialize(address _validatorSet) internal {
        require(_getCurrentBlockNumber() == 0 || msg.sender == _admin());
        require(!isInitialized());
        require(_validatorSet != address(0));
        validatorSetContract = IValidatorSetHbbft(_validatorSet);
    }

    /// @dev Returns the current `coinbase` address. Needed mostly for unit tests.
    function _getCoinbase() internal view returns(address) {
        return block.coinbase;
    }

    /// @dev Returns the current block number. Needed mostly for unit tests.
    function _getCurrentBlockNumber() internal view returns(uint256) {
        return block.number;
    }
}
