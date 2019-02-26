pragma solidity 0.5.2;

import "./interfaces/ITxPermission.sol";
import "./interfaces/IValidatorSet.sol";
import "./interfaces/IValidatorSetAuRa.sol";
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
     * @param _data Transaction data
     *
     */
    function allowedTxTypes(
        address _sender,
        address _to,
        uint256 /*_value*/, // solhint-disable-line space-after-comma
        uint256 _gasPrice,
        bytes memory _data
    )
        public
        view
        returns(uint32, bool)
    {
        if (isSenderAllowed(_sender)) {
            // Let the `_sender` initiate any transaction if the `_sender` is in the `allowedSenders` list
            return (ALL, false);
        }

        IValidatorSet validatorSet = IValidatorSet(VALIDATOR_SET_CONTRACT);

        // Get called function's signature
        bytes4 signature = bytes4(0);
        uint256 i;
        for (i = 0; _data.length >= 4 && i < 4; i++) {
            signature |= bytes4(_data[i]) >> i*8;
        }

        if (_to == RANDOM_CONTRACT) {
            // The functions of Random contract can only be called by validator's mining address
            return (validatorSet.isValidator(_sender) ? CALL : NONE, false);
        }

        if (_to == VALIDATOR_SET_CONTRACT) {
            // The rules for ValidatorSet contract
            if (signature == bytes4(keccak256("emitInitiateChange()"))) {
                // The `emitInitiateChange()` can be called by anyone
                // if `emitInitiateChangeCallable()` returns `true`
                return (validatorSet.emitInitiateChangeCallable() ? CALL : NONE, false);
            } else if (signature == bytes4(keccak256("reportMalicious(address,uint256,bytes)"))) {
                bytes memory abiParams = new bytes(_data.length - 4 > 64 ? 64 : _data.length - 4);

                for (i = 0; i < abiParams.length; i++) {
                    abiParams[i] = _data[i + 4];
                }

                (
                    address maliciousMiningAddress,
                    uint256 blockNumber
                ) = abi.decode(
                    abiParams,
                    (address, uint256)
                );

                // The `reportMalicious()` can only be called by validator's mining address when the calling is allowed
                (bool callable,) = IValidatorSetAuRa(VALIDATOR_SET_CONTRACT).reportMaliciousCallable(
                    _sender, maliciousMiningAddress, blockNumber
                );

                return (callable ? CALL : NONE, false);
            } else if (_gasPrice > 0) {
                // The other functions of ValidatorSet contract can be called
                // by anyone except validators' mining addresses if gasPrice is not zero
                return (validatorSet.isValidator(_sender) ? NONE : CALL, false);
            }
        }

        if (validatorSet.isValidator(_sender) && _gasPrice > 0) {
            // Let the validator's mining address send their accumulated tx fees to some wallet
            return (_sender.balance > 0 ? BASIC : NONE, false);
        }

        if (validatorSet.isValidator(_to)) {
            // Validator's mining address can't receive any coins
            return (NONE, false);
        }

        // In other cases let the `_sender` create any transaction with non-zero gas price,
        // but don't let them use zero gas price
        return (_gasPrice > 0 ? ALL : NONE, false);
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
