pragma solidity ^0.5.0;


interface ITxPermission {
    function initialize(address[] calldata, address, address) external;
}
