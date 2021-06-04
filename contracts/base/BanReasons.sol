pragma solidity 0.5.10;


contract BanReasons {

    bytes32 internal constant BAN_REASON_UNREVEALED = "unrevealed";
    bytes32 internal constant BAN_REASON_SPAM = "spam";
    bytes32 internal constant BAN_REASON_MALICIOUS = "malicious";
    bytes32 internal constant BAN_REASON_OFTEN_BLOCK_DELAYS = "often block delays";
    bytes32 internal constant BAN_REASON_OFTEN_BLOCK_SKIPS = "often block skips";
    bytes32 internal constant BAN_REASON_OFTEN_REVEAL_SKIPS = "often reveal skips";

}