pragma solidity 0.5.9;

import '../../contracts/BlockRewardAuRa.sol';


contract BlockRewardAuRaMock is BlockRewardAuRa {

    function setIsSnapshotting(bool _isSnapshotting) public {
        isSnapshotting = _isSnapshotting;
    }

}
