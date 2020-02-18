pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

interface IKeyGenHistory {
    function initialize(
        address,
        address[] calldata,
        bytes[] calldata,
        bytes[][] calldata
    ) external;
    function clearPrevKeyGenState(address[] calldata) external;
}
