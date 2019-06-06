pragma solidity 0.5.7;

import "../interfaces/IRandom.sol";
import "../interfaces/IValidatorSet.sol";
import "../eternal-storage/OwnedEternalStorage.sol";
import "../libs/SafeMath.sol";


/// @dev The base contract for the RandomAuRa and RandomHBBFT contracts.
contract RandomBase is OwnedEternalStorage, IRandom {
    using SafeMath for uint256;

    // ============================================== Modifiers =======================================================

    /// @dev Ensures the caller is the ValidatorSet contract address
    /// (EternalStorageProxy proxy contract for ValidatorSet).
    modifier onlyValidatorSetContract() {
        require(msg.sender == address(validatorSetContract()));
        _;
    }

    // =============================================== Getters ========================================================

    /// @dev Returns the current random seed accumulated during RANDAO or another process (depending on
    /// implementation). This getter can only be called by the `ValidatorSet` contract.
    function getCurrentSeed() external onlyValidatorSetContract view returns(uint256) {
        return _getCurrentSeed();
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
        require(_validatorSet != address(0));
        require(addressStorage[VALIDATOR_SET_CONTRACT] == address(0));
        addressStorage[VALIDATOR_SET_CONTRACT] = _validatorSet;
    }

    /// @dev Updates the current random seed.
    /// @param _seed A new random seed.
    function _setCurrentSeed(uint256 _seed) internal {
        uintStorage[CURRENT_SEED] = _seed;
    }

    /// @dev Reads the current random seed from the state.
    function _getCurrentSeed() internal view returns(uint256) {
        return uintStorage[CURRENT_SEED];
    }

}
