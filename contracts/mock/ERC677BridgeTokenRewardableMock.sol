pragma solidity 0.5.10;

import "../../contracts/ERC677BridgeTokenRewardable.sol";


contract ERC677BridgeTokenRewardableMock is ERC677BridgeTokenRewardable {
    uint256 private _blockTimestamp;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _chainId
    ) public ERC677BridgeTokenRewardable(
        _name,
        _symbol,
        _decimals,
        _chainId
    ) {}

    function setNow(uint256 _timestamp) public {
        _blockTimestamp = _timestamp;
    }

    function _now() internal view returns(uint256) {
        return _blockTimestamp != 0 ? _blockTimestamp : now;
    }

    function () external payable {}
}