pragma solidity ^0.5.16;

import './StakingHbbftBaseMock.sol';
import '../../contracts/base/StakingHbbftTokens.sol';


contract StakingHbbftTokensMock is StakingHbbftTokens, StakingHbbftBaseMock {
    function setErc677TokenContractMock(IERC677Minting _erc677TokenContract) public {
        erc677TokenContract = _erc677TokenContract;
    }
}
