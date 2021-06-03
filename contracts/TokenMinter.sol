pragma solidity 0.5.10;


interface IToken {
    function claimTokens(address _token, address payable _to) external;
    function mint(address _to, uint256 _amount) external returns (bool);
    function setBridgeContract(address _bridgeContract) external;
    function transferOwnership(address _newOwner) external;
}


/// @dev Used when we need to have an ability to mint POSDAO tokens not only by the bridge,
/// but also by the BlockRewardAuRa contract if the staking token contract doesn't support
/// the `mintReward` function. Particularly, it is used for the PermittableToken contract:
/// https://blockscout.com/poa/xdai/address/0xf8D1677c8a0c961938bf2f9aDc3F3CFDA759A9d9/contracts
/// The PermittableToken contract is a reduced version of the full ERC677BridgeTokenRewardable contract.
contract TokenMinter {

    address public owner;
    address public blockRewardContract;
    IToken public tokenContract;

    address public constant F_ADDR = 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF;
    uint256 internal constant MAX_MINTERS = 50;

    mapping(address => address) public minterPointers;
    uint256 public minterCount;

    event BlockRewardContractSet(address blockRewardContractAddress);
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyBlockRewardContract() {
        require(msg.sender == blockRewardContract);
        _;
    }

    modifier onlyMinter() {
        require(isMinter(msg.sender));
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor(
        address _owner,
        address _blockRewardContract,
        address _bridgeContract,
        IToken _tokenContract
    ) public {
        _transferOwnership(_owner);
        _setBlockRewardContract(_blockRewardContract);

        minterPointers[F_ADDR] = F_ADDR; // initially empty minter list
        _addMinter(_bridgeContract);

        require(_isContract(address(_tokenContract)));
        tokenContract = _tokenContract;
    }

    function addMinter(address _minter) external onlyOwner {
        _addMinter(_minter);
    }

    function removeMinter(address _minter) external onlyOwner {
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

    function claimTokens(address _token, address payable _to) external onlyOwner {
        tokenContract.claimTokens(_token, _to);
    }

    function mint(address _to, uint256 _amount) external onlyMinter returns (bool) {
        return tokenContract.mint(_to, _amount);
    }

    function mintReward(uint256 _amount) external onlyBlockRewardContract {
        if (_amount == 0) return;
        tokenContract.mint(blockRewardContract, _amount);
    }

    function setBlockRewardContract(address _blockRewardContract) external onlyOwner {
        _setBlockRewardContract(_blockRewardContract);
    }

    function setBridgeContract(address _bridgeContract) external onlyOwner {
        tokenContract.setBridgeContract(_bridgeContract);
    }

    function transferOwnership(address _newOwner) external onlyOwner {
        _transferOwnership(_newOwner);
    }

    function transferTokenOwnership(address _newOwner) external onlyOwner {
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

    function _transferOwnership(address _newOwner) private {
        require(_newOwner != address(0));
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    function _isContract(address _account) private view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(_account) }
        return size > 0;
    }

}
