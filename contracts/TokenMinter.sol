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

    address public constant F_ADDR = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
    uint256 internal constant MAX_MINTERS = 50;

    mapping(address => address) public minterPointers;
    uint256 public minterCount;

    event BlockRewardContractSet(address blockRewardContractAddress);
    event BridgeContractSet(address bridgeContractAddress);
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);

    modifier onlyBlockRewardContract() {
        require(msg.sender == blockRewardContract);
        _;
    }

    modifier onlyBridgeContract() {
        require(msg.sender == bridgeContract);
        _;
    }

    modifier onlyMinter() {
        require(isMinter(msg.sender));
        _;
    }

    constructor(address _blockRewardContract, address _bridgeContract, IToken _tokenContract) public {
        _setBlockRewardContract(_blockRewardContract);
        _setBridgeContract(_bridgeContract);
        require(_isContract(address(_tokenContract)));
        tokenContract = _tokenContract;
        minterPointers[F_ADDR] = F_ADDR; // initially empty minter list
        _addMinter(_bridgeContract);
    }

    function addMinter(address _minter) external onlyBridgeContract {
        _addMinter(_minter);
    }

    function removeMinter(address _minter) external onlyBridgeContract {
        require(isMinter(_minter));

        address nextMinter = minterPointers[_minter];
        address index = F_ADDR;
        address next = minterPointers[index];
        require(next != address(0));

        while (next != _minter) {
            index = next;
            next = minterPointers[index];
            require(next != F_ADDR && next != address(0));
        }

        minterPointers[index] = nextMinter;
        delete minterPointers[_minter];
        minterCount--;

        emit MinterRemoved(_minter);
    }

    function claimTokens(address _token, address payable _to) external onlyBridgeContract {
        tokenContract.claimTokens(_token, _to);
    }

    function mint(address _to, uint256 _amount) external onlyMinter returns (bool) {
        return tokenContract.mint(_to, _amount);
    }

    function mintReward(uint256 _amount) external onlyBlockRewardContract {
        if (_amount == 0) return;
        tokenContract.mint(blockRewardContract, _amount);
    }

    function setBlockRewardContract(address _blockRewardContract) external onlyBridgeContract {
        _setBlockRewardContract(_blockRewardContract);
    }

    function setBridgeContract(address _bridgeContract) external onlyBridgeContract {
        _setBridgeContract(_bridgeContract);
    }

    function transferOwnership(address _newOwner) external onlyBridgeContract {
        tokenContract.transferOwnership(_newOwner);
    }

    function isMinter(address _address) public view returns (bool) {
        return _address != F_ADDR && minterPointers[_address] != address(0);
    }

    function minterList() external view returns (address[] memory list) {
        list = new address[](minterCount);
        uint256 counter = 0;
        address nextMinter = minterPointers[F_ADDR];
        require(nextMinter != address(0));

        while (nextMinter != F_ADDR) {
            list[counter] = nextMinter;
            nextMinter = minterPointers[nextMinter];
            counter++;
            require(nextMinter != address(0));
        }

        return list;
    }

    function _addMinter(address _minter) private {
        require(minterCount < MAX_MINTERS);
        require(!isMinter(_minter));

        address firstMinter = minterPointers[F_ADDR];
        require(firstMinter != address(0));
        minterPointers[F_ADDR] = _minter;
        minterPointers[_minter] = firstMinter;
        minterCount++;

        emit MinterAdded(_minter);
    }

    function _setBlockRewardContract(address _blockRewardContract) private {
        require(_isContract(_blockRewardContract));
        blockRewardContract = _blockRewardContract;
        emit BlockRewardContractSet(_blockRewardContract);
    }

    function _setBridgeContract(address _bridgeContract) private {
        require(_isContract(_bridgeContract));
        bridgeContract = _bridgeContract;
        emit BridgeContractSet(_bridgeContract);
    }

    function _isContract(address _account) private view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(_account) }
        return size > 0;
    }

}
