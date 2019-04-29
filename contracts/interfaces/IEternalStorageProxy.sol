pragma solidity 0.5.7;


interface IEternalStorageProxy {
    function upgradeTo(address) external returns(bool);
}
