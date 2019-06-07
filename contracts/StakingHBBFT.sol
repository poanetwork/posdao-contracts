pragma solidity 0.5.7;

import "./abstracts/StakingBase.sol";
import "./interfaces/IValidatorSetHBBFT.sol";
import "./interfaces/IStakingHBBFT.sol";


contract StakingHBBFT is IStakingHBBFT, StakingBase {

    // TODO: add a description for each function

    // =============================================== Setters ========================================================

    function addPool(
        bytes calldata _publicKey,
        uint256 _amount,
        address _miningAddress
    )
        external
        gasPriceIsValid
        onlyInitialized
    {
        address stakingAddress = msg.sender;
        IValidatorSetHBBFT(address(validatorSetContract())).savePublicKey(_miningAddress, _publicKey);
        validatorSetContract().setStakingAddress(_miningAddress, stakingAddress);
        _stake(stakingAddress, _amount);
    }

    function addPoolNative(
        bytes calldata _publicKey,
        address _miningAddress
    )
        external
        gasPriceIsValid
        onlyInitialized
        payable
    {
        address stakingAddress = msg.sender;
        IValidatorSetHBBFT(address(validatorSetContract())).savePublicKey(_miningAddress, _publicKey);
        validatorSetContract().setStakingAddress(_miningAddress, stakingAddress);
        _stake(stakingAddress, msg.value);
    }

    /// Must be called by the constructor of `InitializerHBBFT` contract.
    /// This is used instead of `constructor()` because this contract is upgradable.
    function initialize(
        address _validatorSetContract,
        address[] calldata _initialStakingAddresses,
        uint256 _delegatorMinStake,
        uint256 _candidateMinStake,
        bool _erc20Restricted
    ) external {
        super._initialize(
            _validatorSetContract,
            _initialStakingAddresses,
            _delegatorMinStake,
            _candidateMinStake,
            _erc20Restricted
        );
    }

    // =============================================== Getters ========================================================

    function areStakeAndWithdrawAllowed() public view returns(bool) {
        return !IBlockReward(validatorSetContract().blockRewardContract()).isSnapshotting();
    }

    // =============================================== Private ========================================================

    // Adds `_stakingAddress` to the array of pools
    function _addPoolActive(address _stakingAddress, bool _toBeElected) internal {
        super._addPoolActive(_stakingAddress, _toBeElected);
        IValidatorSet validatorSetContract = validatorSetContract();
        IValidatorSetHBBFT(address(validatorSetContract)).clearMaliceReported(
            validatorSetContract.miningByStakingAddress(_stakingAddress)
        );
    }
}
