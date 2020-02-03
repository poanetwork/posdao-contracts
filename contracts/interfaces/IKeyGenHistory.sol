pragma solidity 0.5.10;


interface IKeyGenHistory {
    function clearPrevKeyGenState(address[] calldata) external;
}
