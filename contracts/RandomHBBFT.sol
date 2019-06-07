pragma solidity 0.5.9;

import "./abstracts/RandomBase.sol";


contract RandomHBBFT is RandomBase {

    modifier onlySystem() {
        require(msg.sender == 0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE);
        _;
    }

    /// @dev Initializes the contract at network startup.
    /// Must be called by the constructor of the `InitializerHBBFT` contract.
    /// @param _validatorSet The address of the `ValidatorSet` contract.
    function initialize(address _validatorSet) external {
        super._initialize(_validatorSet);
    }

    function storeRandom(uint256[] memory _random) public onlySystem onlyInitialized {
        for (uint256 i = 0; i < _random.length; i++) {
            _setCurrentSeed(_getCurrentSeed() ^ _random[i]);
        }
    }

}
