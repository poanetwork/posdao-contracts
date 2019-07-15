pragma solidity 0.5.9;

import "../interfaces/IRandom.sol";
import "../interfaces/IValidatorSet.sol";
import "../eternal-storage/OwnedEternalStorage.sol";
import "../libs/SafeMath.sol";


/// @dev The base contract for the RandomAuRa and RandomHBBFT contracts.
contract RandomBase is OwnedEternalStorage, IRandom {
    using SafeMath for uint256;

    // ============================================== Modifiers =======================================================

    /// @dev Ensures the `initialize` function was called before.
    modifier onlyInitialized {
        require(isInitialized());
        _;
    }

    // =============================================== Getters ========================================================

    /// @dev Returns the current random seed accumulated during RANDAO or another process
    /// (depending on implementation).
    function getCurrentSeed() public view returns(uint256) {
        return uintStorage[CURRENT_SEED];
    }

    /// @dev Returns a boolean flag indicating if the `initialize` function has been called.
    function isInitialized() public view returns(bool) {
        return addressStorage[VALIDATOR_SET_CONTRACT] != address(0);
    }

    /// @dev Returns the address of the `ValidatorSet` contract.
    function validatorSetContract() public view returns(IValidatorSet) {
        return IValidatorSet(addressStorage[VALIDATOR_SET_CONTRACT]);
    }

    // =============================================== Private ========================================================

    bytes32 internal constant CURRENT_SEED = keccak256("currentSeed");
    bytes32 internal constant VALIDATOR_SET_CONTRACT = keccak256("validatorSetContract");

    /// @dev Initializes the network parameters. Used by the `initialize` function of a child contract.
    /// @param _validatorSet The address of the `ValidatorSet` contract.
    function _initialize(address _validatorSet) internal {
        require(!isInitialized());
        require(_validatorSet != address(0));
        addressStorage[VALIDATOR_SET_CONTRACT] = _validatorSet;
    }

    /// @dev Updates the current random seed.
    /// @param _seed A new random seed.
    function _setCurrentSeed(uint256 _seed) internal {
        uintStorage[CURRENT_SEED] = _seed;
    }

}
