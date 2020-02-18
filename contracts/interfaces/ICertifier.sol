pragma solidity ^0.5.0;


interface ICertifier {
    function certifiedExplicitly(address) external view returns(bool);
    function initialize(address[] calldata, address) external;
}
