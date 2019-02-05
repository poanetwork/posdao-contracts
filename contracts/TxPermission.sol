pragma solidity 0.5.2;

import "./interfaces/ITxPermission.sol";
import "./interfaces/IValidatorSet.sol";
import "./eternal-storage/OwnedEternalStorage.sol";


contract TxPermission is OwnedEternalStorage, ITxPermission {

    // ============================================== Constants =======================================================

    /// Addresses of `Random` and `ValidatorSet` contracts.
    /// Must be set before deploy.
    address public constant RANDOM_CONTRACT = address(0x3000000000000000000000000000000000000001);
    address public constant VALIDATOR_SET_CONTRACT = address(0x1000000000000000000000000000000000000001);

    // =============================================== Setters ========================================================

    /// Initializes the contract at the start of the network.
    /// Must be called by the constructor of `Initializer` contract on genesis block.
    /// This is used instead of `constructor()` because this contract is upgradable.
    function initialize(
        address _allowedSender
    ) external {
        require(block.number == 0);
        _addAllowedSender(_allowedSender);
    }

    function addAllowedSender(address _sender) public onlyOwner {
        _addAllowedSender(_sender);
    }

    function removeAllowedSender(address _sender) public onlyOwner {
        uint256 allowedSendersLength = addressArrayStorage[ALLOWED_SENDERS].length;

        for (uint256 i = 0; i < allowedSendersLength; i++) {
            if (_sender == addressArrayStorage[ALLOWED_SENDERS][i]) {
                addressArrayStorage[ALLOWED_SENDERS][i] = addressArrayStorage[ALLOWED_SENDERS][allowedSendersLength-1];
                addressArrayStorage[ALLOWED_SENDERS].length--;
                break;
            }
        }
    }

    // =============================================== Getters ========================================================

    /// Contract name
    function contractName() public pure returns(string memory) {
        return "TX_PERMISSION_CONTRACT";
    }

    /// Contract name hash
    function contractNameHash() public pure returns(bytes32) {
        return keccak256(abi.encodePacked(contractName()));
    }

    /// Contract version
    function contractVersion() public pure returns(uint256) {
        return 0xfffffffffffffffe;
    }

    function allowedSenders() public view returns(address[] memory) {
        return addressArrayStorage[ALLOWED_SENDERS];
    }

    /*
     * Allowed transaction types
     *
     * Returns:
     *  - uint32 - set of allowed transactions for #'sender' depending on tx #'to' address
     *    and value in wei.
     *  - bool - if true is returned the same permissions will be applied from the same #'sender'
     *    without calling this contract again.
     *
     * In case of contract creation #'to' address equals to zero-address
     *
     * Result is represented as set of flags:
     *  - 0x01 - basic transaction (e.g. ether transferring to user wallet)
     *  - 0x02 - contract call
     *  - 0x04 - contract creation
     *  - 0x08 - private transaction
     *
     * @param _sender Transaction sender address
     * @param _to Transaction recepient address
     * @param _value Value in wei for transaction
     * @param _gasPrice Gas price in wei for transaction
     *
     */
    function allowedTxTypes(
        address _sender,
        address _to,
        uint256 /*_value*/, // solhint-disable-line space-after-comma
        uint256 _gasPrice
    )
        public
        view
        returns(uint32, bool)
    {
        if (_gasPrice > 0 || isSenderAllowed(_sender)) {
            // Let `_sender` create any transactions with non-zero gas price
            // or if he is in the allowedSenders list
            return (ALL, false);
        }

        if (_to == RANDOM_CONTRACT && IValidatorSet(VALIDATOR_SET_CONTRACT).isValidator(_sender)) {
            // Let the validator call any function of `Random` contract with zero gas price
            return (CALL, false);
        }

        if (_to == VALIDATOR_SET_CONTRACT && IValidatorSet(VALIDATOR_SET_CONTRACT).isReportValidatorValid(_sender)) {
            // Let the validator call any function of `ValidatorSet` contract with zero gas price
            return (CALL, false);
        }

        // Don't let `_sender` use zero gas price for other cases
        return (NONE, false);
    }

    function isSenderAllowed(address _sender) public view returns(bool) {
        uint256 allowedSendersLength = addressArrayStorage[ALLOWED_SENDERS].length;

        for (uint256 i = 0; i < allowedSendersLength; i++) {
            if (_sender == addressArrayStorage[ALLOWED_SENDERS][i]) {
                return true;
            }
        }

        return false;
    }

    // =============================================== Private ========================================================

    bytes32 internal constant ALLOWED_SENDERS = keccak256("allowedSenders");

    /// Allowed transaction types mask
    uint32 internal constant NONE = 0;
    uint32 internal constant ALL = 0xffffffff;
    uint32 internal constant BASIC = 0x01;
    uint32 internal constant CALL = 0x02;
    uint32 internal constant CREATE = 0x04;
    uint32 internal constant PRIVATE = 0x08;

    function _addAllowedSender(address _sender) internal {
        require(!isSenderAllowed(_sender));
        require(_sender != address(0));
        addressArrayStorage[ALLOWED_SENDERS].push(_sender);
    }
}
