pragma solidity 0.5.2;


interface IEternalStorageProxy {
    function upgradeTo(address) external returns(bool);
}
