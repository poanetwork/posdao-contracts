pragma solidity 0.4.25;

import "./abstracts/BlockRewardBase.sol";


contract BlockRewardAuRa is BlockRewardBase {

    function reward(address[] benefactors, uint16[] kind)
        external
        onlySystem
        returns (address[], uint256[])
    {
        require(benefactors.length == kind.length);
        require(benefactors.length == 1);
        require(kind[0] == 0);

        // We don't accrue any block reward in native coins to validator here.
        // We just mint native coins by bridge if needed,
        // including the case of bridge's fee accrual.
        return _mintNativeCoinsByBridge();
    }

}
