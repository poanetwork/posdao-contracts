pragma solidity 0.5.10;
pragma experimental ABIEncoderV2;

import '../../contracts/TxPriority.sol';


contract TxPriorityMock is TxPriority {

    function firstWeightInTree() external view returns(uint256) {
        return _weightsTree.first();
    }

    function lastWeightInTree() external view returns(uint256) {
        return _weightsTree.last();
    }

    function nextWeightInTree(uint256 _afterWeight) external view returns(uint256) {
        return _weightsTree.next(_afterWeight);
    }

    function prevWeightInTree(uint256 _beforeWeight) external view returns(uint256) {
        return _weightsTree.prev(_beforeWeight);
    }

    function weightExistsInTree(uint256 _weight) external view returns(bool) {
        return _weightsTree.exists(_weight);
    }

}
