pragma solidity 0.5.7;


interface IMetadataRegistry {
    event DataChanged(bytes32 indexed name, string key, string plainKey);

    function getData(bytes32 _name, string calldata _key)
        external
        view
        returns (bytes32);

    function getAddress(bytes32 _name, string calldata _key)
        external
        view
        returns (address);

    function getUint(bytes32 _name, string calldata _key)
        external
        view
        returns (uint);
}
