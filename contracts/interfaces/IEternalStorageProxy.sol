pragma solidity 0.4.25;


interface IEternalStorageProxy {
    function upgradeTo(address) external returns(bool);
}