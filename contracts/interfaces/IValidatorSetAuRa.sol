pragma solidity 0.5.9;


interface IValidatorSetAuRa {
    function removeMaliciousValidator(address) external;
    function reportMaliciousCallable(address, address, uint256) external view returns(bool, bool);
}
