pragma solidity 0.5.2;


interface IValidatorSetAuRa {
    function enqueuePendingValidators() external;
    function removeMaliciousValidator(address) external;
    function reportMaliciousCallable(address, address, uint256) external view returns(bool, bool);
}
