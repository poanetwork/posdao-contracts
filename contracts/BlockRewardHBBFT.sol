pragma solidity 0.4.25;

import "./abstracts/BlockRewardBase.sol";
import "./interfaces/IERC20Token.sol";


contract BlockRewardHBBFT is BlockRewardBase {

    // ============================================== Constants =======================================================

    // These value must be changed before deploy
    uint256 public constant BLOCK_REWARD = 100 ether; // in ERC20 tokens
    address public constant ERC20_TOKEN_CONTRACT = address(0);

    // ================================================ Events ========================================================

    event RewardedERC20ByBlock(address[] receivers, uint256[] rewards);

    // =============================================== Setters ========================================================

    function reward(address[] benefactors, uint16[] /*kind*/)
        external
        onlySystem
        returns (address[], uint256[])
    {
        _mintTokensForStakers(benefactors);
        return _mintNativeCoinsByBridge();
    }

    // =============================================== Getters ========================================================

    // ...

    // =============================================== Private ========================================================

    // Mint ERC20 tokens for each staker of each active validator
    function _mintTokensForStakers(address[] benefactors) internal {
        IERC20Token erc20Contract = IERC20Token(ERC20_TOKEN_CONTRACT);

        if (erc20Contract == address(0)) {
            return;
        }

        uint256 poolReward = BLOCK_REWARD / snapshotValidators().length;

        for (uint256 i = 0; i < benefactors.length; i++) {
            uint256 s;
            address[] memory stakers = snapshotStakers(benefactors[i]);
            address[] memory erc20Receivers = new address[](stakers.length.add(1));
            uint256[] memory erc20Rewards = new uint256[](erc20Receivers.length);

            uint256 validatorStake = snapshotStakeAmount(benefactors[i], benefactors[i]);
            uint256 stakersAmount = 0;

            for (s = 0; s < stakers.length; s++) {
                stakersAmount += snapshotStakeAmount(benefactors[i], stakers[s]);
            }

            uint256 totalAmount = validatorStake + stakersAmount;

            // Calculate reward for each staker
            for (s = 0; s < stakers.length; s++) {
                uint256 stakerStake = snapshotStakeAmount(benefactors[i], stakers[s]);

                erc20Receivers[s] = stakers[s];
                if (validatorStake > stakersAmount) {
                    erc20Rewards[s] = poolReward.mul(stakerStake).div(totalAmount);
                } else {
                    erc20Rewards[s] = poolReward.mul(stakerStake).mul(7).div(stakersAmount.mul(10));
                }
            }

            // Calculate reward for validator
            erc20Receivers[s] = benefactors[i];
            if (validatorStake > stakersAmount) {
                erc20Rewards[s] = poolReward.mul(validatorStake).div(totalAmount);
            } else {
                erc20Rewards[s] = poolReward.mul(3).div(10);
            }

            erc20Contract.mintReward(erc20Receivers, erc20Rewards);
            
            emit RewardedERC20ByBlock(erc20Receivers, erc20Rewards);
        }
    }
}
