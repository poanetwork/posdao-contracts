pragma solidity 0.5.2;

import "./abstracts/StakingBase.sol";
import "./interfaces/IValidatorSetHBBFT.sol";
import "./interfaces/IStakingHBBFT.sol";


contract StakingHBBFT is IStakingHBBFT, StakingBase {

    // TODO: add a description for each function

    // =============================================== Setters ========================================================

    function addPool(bytes calldata _publicKey, uint256 _amount, address _miningAddress) external {
        address stakingAddress = msg.sender;
        IValidatorSetHBBFT(address(validatorSetContract())).savePublicKey(_miningAddress, _publicKey);
        validatorSetContract().setStakingAddress(_miningAddress, stakingAddress);
        stake(stakingAddress, _amount);
    }

    /// Must be called by the constructor of `InitializerHBBFT` contract on genesis block.
    /// This is used instead of `constructor()` because this contract is upgradable.
    function initialize(
        address _validatorSetContract,
        address _erc20TokenContract,
        address[] calldata _initialStakingAddresses,
        uint256 _delegatorMinStake,
        uint256 _candidateMinStake
    ) external {
        super._initialize(
            _validatorSetContract,
            _erc20TokenContract,
            _initialStakingAddresses,
            _delegatorMinStake,
            _candidateMinStake
        );
    }

    // =============================================== Getters ========================================================

    function areStakeAndWithdrawAllowed() public view returns(bool) {
        return _wasValidatorSetApplied();
    }

    // =============================================== Private ========================================================

    // Adds `_stakingAddress` to the array of pools
    function _addToPools(address _stakingAddress) internal {
        super._addToPools(_stakingAddress);
        IValidatorSet validatorSetContract = validatorSetContract();
        IValidatorSetHBBFT(address(validatorSetContract)).clearMaliceReported(
            validatorSetContract.miningByStakingAddress(_stakingAddress)
        );
    }
}
