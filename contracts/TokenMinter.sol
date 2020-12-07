pragma solidity 0.5.10;


interface IToken {
    function claimTokens(address _token, address payable _to) external;
    function mint(address _to, uint256 _amount) external returns (bool);
    function transferOwnership(address _newOwner) external;
}


/// @dev Used when we need to have an ability to mint POSDAO tokens not only by the bridge,
/// but also by the BlockRewardAuRa contract if the staking token contract doesn't support
/// the `mintReward` function.
contract TokenMinter {

    address public blockRewardContract;
    address public bridgeContract;
    IToken public tokenContract;

    modifier onlyBlockRewardContract() {
        require(msg.sender == blockRewardContract);
        _;
    }

    modifier onlyBridgeContract() {
        require(msg.sender == bridgeContract);
        _;
    }

    constructor(address _blockRewardContract, address _bridgeContract, IToken _tokenContract) public {
        require(_isContract(_blockRewardContract));
        require(_isContract(_bridgeContract));
        require(_isContract(address(_tokenContract)));
        blockRewardContract = _blockRewardContract;
        bridgeContract = _bridgeContract;
        tokenContract = _tokenContract;
    }

    function claimTokens(address _token, address payable _to) public onlyBridgeContract {
        tokenContract.claimTokens(_token, _to);
    }

    function mint(address _to, uint256 _amount) external onlyBridgeContract returns (bool) {
        return tokenContract.mint(_to, _amount);
    }

    function mintReward(uint256 _amount) external onlyBlockRewardContract {
        if (_amount == 0) return;
        tokenContract.mint(blockRewardContract, _amount);
    }

    function setBlockRewardContract(address _blockRewardContract) external onlyBridgeContract {
        require(_isContract(_blockRewardContract));
        blockRewardContract = _blockRewardContract;
    }

    function setBridgeContract(address _bridgeContract) external onlyBridgeContract {
        require(_isContract(_bridgeContract));
        bridgeContract = _bridgeContract;
    }

    function transferOwnership(address _newOwner) external onlyBridgeContract {
        tokenContract.transferOwnership(_newOwner);
    }

    function _isContract(address _account) private view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(_account) }
        return size > 0;
    }

}
