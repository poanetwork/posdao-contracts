pragma solidity 0.5.2;

import "./abstracts/BlockRewardBase.sol";
import "./interfaces/IERC20Minting.sol";


contract BlockRewardHBBFT is BlockRewardBase {

    // ============================================== Constants =======================================================

    // This value must be changed before deploy
    uint256 public constant BLOCK_REWARD = 0 ether; // in ERC20 tokens

    // ================================================ Events ========================================================

    event RewardedERC20ByBlock(address[] receivers, uint256[] rewards);

    // =============================================== Setters ========================================================

    function reward(address[] calldata benefactors, uint16[] calldata/*kind*/)
        external
        onlySystem
        returns (address[] memory, uint256[] memory)
    {
        // Mint ERC20 tokens to validators and their delegators as block reward.
        // This is not bridge's fee distribution.
        // This call makes sense only if `BLOCK_REWARD` and `ERC20_TOKEN_CONTRACT`
        // constants are not equal to zero.
        _mintTokensForDelegators(benefactors);

        // We don't accrue any block reward in native coins to validator here.
        // We just mint native coins by bridge if needed.
        return _mintNativeCoinsByErcToNativeBridge();
    }

    // =============================================== Private ========================================================

    // Mint ERC20 tokens for each delegator of each active validator
    function _mintTokensForDelegators(address[] memory benefactors) internal {
        IERC20Minting erc20Contract = IERC20Minting(IValidatorSet(VALIDATOR_SET_CONTRACT).erc20TokenContract());

        if (BLOCK_REWARD == 0) return;
        if (address(erc20Contract) == address(0)) return;

        uint256 stakingEpoch = _getStakingEpoch();

        if (stakingEpoch == 0) {
            return;
        }

        uint256 poolReward = BLOCK_REWARD / snapshotValidators(stakingEpoch).length;
        uint256 remainder = BLOCK_REWARD % snapshotValidators(stakingEpoch).length;

        for (uint256 i = 0; i < benefactors.length; i++) {
            (
                address[] memory receivers,
                uint256[] memory rewards
            ) = _distributePoolReward(stakingEpoch, benefactors[i], i == 0 ? poolReward + remainder : poolReward);

            erc20Contract.mintReward(receivers, rewards);

            emit RewardedERC20ByBlock(receivers, rewards);
        }
    }
}
