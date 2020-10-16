pragma solidity 0.5.10;


library MerkleTree {

    function getRoot(address[] memory _leaves) internal pure returns(bytes32 root) {
        bytes32[] memory nodes = new bytes32[](_leaves.length);
        for (uint256 i = 0; i < _leaves.length; i++) {
            nodes[i] = _addressToBytes32(_leaves[i]);
        }
        while (nodes.length > 1) {
            nodes = _buildLayer(nodes);
        }
        if (nodes.length != 0) {
            root = nodes[0];
        }
    }

    function _addressToBytes32(address _input) private pure returns(bytes32) {
        return bytes32(uint256(_input)); // compatible with bytes32(_input) in Solidity 0.4
    }

    function _buildLayer(bytes32[] memory _prevLayer) private pure returns(bytes32[] memory layer) {
        layer = new bytes32[](_calcNextLayerLength(_prevLayer.length));
        if (layer.length == 0) {
            return layer;
        }
        for (uint256 i = 0; i < _prevLayer.length; i += 2) {
            uint256 nodeIndex = i / 2;
            if (i == _prevLayer.length - 1) { // it is the last odd node
                layer[nodeIndex] = _prevLayer[i];
                continue;
            }
            bytes32 left = _prevLayer[i];
            bytes32 right = _prevLayer[i + 1];
            layer[nodeIndex] = left > right ? _hashPair(right, left) : _hashPair(left, right);
        }
    }

    function _calcNextLayerLength(uint256 _prevLayerLength) private pure returns(uint256) {
        if (_prevLayerLength == 1) {
            return 0;
        }
        return _prevLayerLength / 2 + _prevLayerLength % 2;
    }

    function _hashPair(bytes32 _left, bytes32 _right) private pure returns(bytes32) {
        return keccak256(abi.encodePacked(_left, _right));
    }

}
