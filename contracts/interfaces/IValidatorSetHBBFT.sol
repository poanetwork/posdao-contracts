pragma solidity 0.5.2;
pragma experimental ABIEncoderV2;


interface IValidatorSetHBBFT {
    function clearMaliceReported(address) external;
    function initializePublicKeys(bytes[] calldata) external;
    function savePublicKey(address, bytes calldata) external;
}
