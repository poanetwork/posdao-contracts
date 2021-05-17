pragma solidity 0.5.10;

import '../../contracts/ValidatorSetAuRa.sol';


contract ValidatorSetAuRaMock is ValidatorSetAuRa {

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
        _setPendingValidatorsChanged(true);
    }

    function incrementLastPoolId() public {
        lastPoolId++;
    }

    function setBannedUntil(address _stakingAddress, uint256 _until) public {
        uint256 poolId = idByStakingAddress[_stakingAddress];
        _bannedUntil[poolId] = _until;
        _bannedDelegatorsUntil[poolId] = _until;
    }

    function setBlockRewardContract(address _address) public {
        blockRewardContract = _address;
    }

    function setCurrentBlockNumber(uint256 _blockNumber) public {
        _currentBlockNumber = _blockNumber;
    }

    function addNonValidatorPools(address[] memory _stakingAddresses) public {
        for (uint256 i = 0; i < _stakingAddresses.length; i++) {
            address stakingAddress = _stakingAddresses[i];
            uint256 poolId = uint256(stakingAddress);
            idByStakingAddress[stakingAddress] = poolId;
        }
    }

    // function setPoolAsValidator(uint256 _poolId) public {
    //     isValidatorById[_poolId] = true;
    // }

    function setRandomContract(address _address) public {
        randomContract = _address;
    }

    function setStakingContract(address _address) public {
        stakingContract = IStakingAuRa(_address);
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

    // =============================================== Private ========================================================

    function _getCurrentBlockNumber() internal view returns(uint256) {
        return _currentBlockNumber;
    }

    function _getSystemAddress() internal view returns(address) {
        return _systemAddress;
    }

    // To keep the unit tests unbroken, rewrite the `_removeMaliciousValidators` internal function
    // since the original one is temporarily turned off in the production contract.
    function _removeMaliciousValidators(address[] memory _miningAddresses, bytes32 _reason) internal {
        bool removed = false;

        for (uint256 i = 0; i < _miningAddresses.length; i++) {
            if (_removeMaliciousValidator(_miningAddresses[i], _reason)) {
                // From this moment `getPendingValidators()` returns the new validator set
                _clearReportingCounter(_miningAddresses[i]);
                removed = true;
            }
        }

        if (removed) {
            _setPendingValidatorsChanged(false);
        }

        lastChangeBlock = _getCurrentBlockNumber();
    }

}
