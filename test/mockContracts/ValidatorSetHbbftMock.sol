pragma solidity ^0.5.16;

import '../../contracts/ValidatorSetHbbft.sol';


contract ValidatorSetHbbftMock is ValidatorSetHbbft {

    uint256 internal _currentBlockNumber;
    address internal _systemAddress;

    // ============================================== Modifiers =======================================================

    modifier onlySystem() {
        require(msg.sender == _getSystemAddress());
        _;
    }

    // =============================================== Setters ========================================================

    function clearPendingValidators() public {
        delete _pendingValidators;
    }

    function setBannedUntil(address _miningAddress, uint256 _bannedUntil) public {
        bannedUntil[_miningAddress] = _bannedUntil;
        bannedDelegatorsUntil[_miningAddress] = _bannedUntil;
    }
    
    function setBlockRewardContract(address _address) public {
        blockRewardContract = _address;
    }

    function setCurrentBlockNumber(uint256 _blockNumber) public {
        _currentBlockNumber = _blockNumber;
    }

    function setRandomContract(address _address) public {
        randomContract = _address;
    }

    function setStakingContract(address _address) public {
        stakingContract = IStakingHbbft(_address);
    }

    function setSystemAddress(address _address) public {
        _systemAddress = _address;
    }

    function setValidatorSetApplyBlock(uint256 _blockNumber) public {
        validatorSetApplyBlock = _blockNumber;
    }

    // =============================================== Getters ========================================================

    function getRandomIndex(
        uint256[] memory _likelihood,
        uint256 _likelihoodSum,
        uint256 _randomNumber
    ) public pure returns(uint256) {
        return _getRandomIndex(
            _likelihood,
            _likelihoodSum,
            uint256(keccak256(abi.encode(_randomNumber)))
        );
    }

    function getCurrentBlockNumber() external view returns(uint256) {
        return _currentBlockNumber;
    }
    // =============================================== Private ========================================================

    function _getCurrentBlockNumber() internal view returns(uint256) {
        return _currentBlockNumber;
    }

    function _getSystemAddress() internal view returns(address) {
        return _systemAddress;
    }

}
