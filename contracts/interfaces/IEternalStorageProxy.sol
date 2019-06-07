pragma solidity 0.5.9;


interface IEternalStorageProxy {
    function upgradeTo(address) external returns(bool);
}
