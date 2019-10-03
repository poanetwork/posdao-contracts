pragma solidity 0.5.9;

import './StakingAuRaBaseMock.sol';
import '../../contracts/base/StakingAuRaTokens.sol';


contract StakingAuRaTokensMock is StakingAuRaTokens, StakingAuRaBaseMock {
    function setErc20TokenContractMock(IERC20Minting _erc20TokenContract) public {
        erc20TokenContract = _erc20TokenContract;
    }
}
