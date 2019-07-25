pragma solidity 0.5.9;


interface IValidatorSetAuRa {
    function removeMaliciousValidators(address[] calldata) external;
    function reportMaliciousCallable(address, address, uint256) external view returns(bool, bool);
}
