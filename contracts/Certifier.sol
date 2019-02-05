pragma solidity 0.5.2;

import "./interfaces/ICertifier.sol";
import "./interfaces/IValidatorSet.sol";
import "./eternal-storage/OwnedEternalStorage.sol";


contract Certifier is OwnedEternalStorage, ICertifier {

    // ============================================== Constants =======================================================

    // This address must be set before deploy
    address public constant VALIDATOR_SET_CONTRACT = address(0x1000000000000000000000000000000000000001);

    // ================================================ Events ========================================================

    event Confirmed(address indexed who);
    event Revoked(address indexed who);

    // =============================================== Setters ========================================================

    /// Initializes the contract at the start of the network.
    /// Must be called by the constructor of `Initializer` contract on genesis block.
    /// This is used instead of `constructor()` because this contract is upgradable.
    function initialize(
        address _certifiedAddress
    ) external {
        require(block.number == 0);
        _certify(_certifiedAddress);
    }

    function certify(address _who) external onlyOwner {
        _certify(_who);
        emit Confirmed(_who);
    }

    function revoke(address _who) external onlyOwner {
        boolStorage[keccak256(abi.encode(CERTIFIED, _who))] = false;
        emit Revoked(_who);
    }

    // =============================================== Getters ========================================================

    function certified(address _who) external view returns(bool) {
        if (boolStorage[keccak256(abi.encode(CERTIFIED, _who))]) {
            return true;
        }
        return IValidatorSet(VALIDATOR_SET_CONTRACT).isReportValidatorValid(_who);
    }

    // =============================================== Private ========================================================

    bytes32 internal constant CERTIFIED = "certified";

    function _certify(address _who) internal {
        require(_who != address(0));
        boolStorage[keccak256(abi.encode(CERTIFIED, _who))] = true;
    }
}
