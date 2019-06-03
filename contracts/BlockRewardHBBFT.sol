pragma solidity 0.5.7;

import "./abstracts/BlockRewardBase.sol";
import "./interfaces/IERC20Minting.sol";
import "./interfaces/IStaking.sol";


contract BlockRewardHBBFT is BlockRewardBase {

    // ============================================== Constants =======================================================

    // This value must be changed before deploy
    uint256 public constant BLOCK_REWARD = 0 ether; // in ERC20 tokens

    // ================================================ Events ========================================================

    event RewardedERC20ByBlock(address[] receivers, uint256[] rewards);

    // =============================================== Setters ========================================================

    function reward(address[] calldata, uint16[] calldata)
        external
        onlySystem
        returns (address[] memory, uint256[] memory)
    {
        /*
        // Mint ERC20 tokens to validators and their delegators as block reward.
        // This is not bridge's fee distribution.
        // This call makes sense only if `BLOCK_REWARD` and `ERC20_TOKEN_CONTRACT`
        // constants are not equal to zero.
        _mintTokensForDelegators(benefactors);
        */

        // Mint native coins by bridge if needed.
        return _mintNativeCoins(new address[](0), new uint256[](0), 25);
    }

    // =============================================== Private ========================================================

    /*
    // Mint ERC20 tokens for each delegator of each active validator
    function _mintTokensForDelegators(address[] memory benefactors) internal {
        IStaking stakingContract = IStaking(
            IValidatorSet(VALIDATOR_SET_CONTRACT).stakingContract()
        );
        IERC20Minting erc20Contract = IERC20Minting(
            stakingContract.erc20TokenContract()
        );

        if (BLOCK_REWARD == 0) return;
        if (address(erc20Contract) == address(0)) return;

        uint256 stakingEpoch = _getStakingEpoch();

        if (stakingEpoch == 0) {
            return;
        }

        uint256 poolReward = BLOCK_REWARD / snapshotStakingAddresses().length;
        uint256 remainder = BLOCK_REWARD % snapshotStakingAddresses().length;

        for (uint256 i = 0; i < benefactors.length; i++) {
            (
                address[] memory receivers,
                uint256[] memory rewards
            ) = _distributePoolReward(
                stakingEpoch,
                IValidatorSet(VALIDATOR_SET_CONTRACT).stakingByMiningAddress(benefactors[i]),
                i == 0 ? poolReward + remainder : poolReward
            );

            erc20Contract.mintReward(receivers, rewards);

            emit RewardedERC20ByBlock(receivers, rewards);
        }
    }
    */
}
