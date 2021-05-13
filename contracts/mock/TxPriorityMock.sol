pragma solidity 0.5.10;
pragma experimental ABIEncoderV2;

import '../../contracts/TxPriority.sol';


contract TxPriorityMock is TxPriority {

    // solhint-disable
    constructor(address _owner, bool _applyInitTestRules) public TxPriority(_owner) {
        if (_applyInitTestRules) {
            // Apply initial test rules for posdao-test-setup

            // target = StakingAuRa.address, fnSignature = 0x00000000, weight = 4
            _weightsTree.insert(4);
            destinationByWeight[4] = Destination(0x1100000000000000000000000000000000000001, 0x00000000, 4);
            weightByDestination[0x1100000000000000000000000000000000000001][0x00000000] = 4;
            weightsCount++;

            // The next two rules should be overlapped by the local rules, see
            // https://github.com/poanetwork/posdao-test-setup/blob/4bf316133f3ab108d542ec587af918f48cc45621/config/TxPriority1.json#L3-L14

            // target = BlockRewardAuRa.address, fnSignature = 0x00000000, weight = 3
            _weightsTree.insert(3);
            destinationByWeight[3] = Destination(0x2000000000000000000000000000000000000001, 0x00000000, 3);
            weightByDestination[0x2000000000000000000000000000000000000001][0x00000000] = 3;
            weightsCount++;

            // target = ValidatorSetAuRa.address, fnSignature = 0x00000000, weight = 2
            _weightsTree.insert(2);
            destinationByWeight[2] = Destination(0x1000000000000000000000000000000000000001, 0x00000000, 2);
            weightByDestination[0x1000000000000000000000000000000000000001][0x00000000] = 2;
            weightsCount++;

            // sendersWhitelist = ["0x32E4E4c7c5d1CEa5db5F9202a9E4D99E56c91a24"]
            _sendersWhitelist.push(address(0x32E4E4c7c5d1CEa5db5F9202a9E4D99E56c91a24));

            // target = StakingAuRa.address, fnSignature = 0x48aaa4a2, minGasPrice = 100 gwei
            _minGasPriceIndex[0x1100000000000000000000000000000000000001][0x48aaa4a2] = _minGasPrices.length;
            _minGasPrices.push(Destination(0x1100000000000000000000000000000000000001, 0x48aaa4a2, 100000000000));

            // target = account.address, fnSignature = 0x00000000, minGasPrice = 1 gwei
            // this rule should be overlapped by the local rule, see
            // https://github.com/poanetwork/posdao-test-setup/blob/4bf316133f3ab108d542ec587af918f48cc45621/config/TxPriority1.json#L16-L20
            _minGasPriceIndex[0x15B5c5A3D4bF2F2Dfc356A442f72Df372743d7cB][0x00000000] = _minGasPrices.length;
            _minGasPrices.push(Destination(0x15B5c5A3D4bF2F2Dfc356A442f72Df372743d7cB, 0x00000000, 1000000000));
        }
    }
    // solhint-enable

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
