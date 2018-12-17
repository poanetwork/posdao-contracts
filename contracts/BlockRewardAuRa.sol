pragma solidity 0.4.25;

import "./abstracts/BlockRewardBase.sol";


contract BlockRewardAuRa is BlockRewardBase {

    // ============================================== Constants =======================================================

    // ...

    // ================================================ Events ========================================================

    // ...

    // =============================================== Setters ========================================================

    function reward(address[] benefactors, uint16[] kind)
        external
        onlySystem
        returns (address[], uint256[])
    {
        require(benefactors.length == kind.length);
        require(benefactors.length == 1);
        require(kind[0] == 0);

        // ...

        return _mintNativeCoinsByBridge();
    }

    // =============================================== Getters ========================================================

    // ...

    // =============================================== Private ========================================================

    // ...
}
