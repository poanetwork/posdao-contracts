pragma solidity 0.5.10;

import './StakingAuRaBaseMock.sol';
import '../../contracts/base/StakingAuRaTokens.sol';


contract StakingAuRaTokensMock is StakingAuRaTokens, StakingAuRaBaseMock {
    function setErc677TokenContractMock(IERC677Minting _erc677TokenContract) public {
        erc677TokenContract = _erc677TokenContract;
    }
}
