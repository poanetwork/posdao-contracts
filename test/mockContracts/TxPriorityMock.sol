pragma solidity 0.5.10;
pragma experimental ABIEncoderV2;

import '../../contracts/TxPriority.sol';


contract TxPriorityMock is TxPriority {

    constructor(address _owner, bool _applyInitTestRules) public TxPriority(_owner) {
        if (_applyInitTestRules) {
            // Apply initial test rules for posdao-test-setup
            _weightsTree.insert(4);
            destinationByWeight[4] = Destination(0x1100000000000000000000000000000000000001, 0x00000000, 4);
            weightByDestination[0x1100000000000000000000000000000000000001][0x00000000] = 4;
            weightsCount = 1;
            _sendersWhitelist.push(address(0x32E4E4c7c5d1CEa5db5F9202a9E4D99E56c91a24));
            _minGasPrices.push(Destination(0x1100000000000000000000000000000000000001, 0x48aaa4a2, 100000000000));
        }
    }

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
