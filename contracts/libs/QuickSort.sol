pragma solidity 0.5.10;


library QuickSort {

    function sort(address[] memory _array) internal pure returns(address[] memory) {
        if (_array.length > 1) {
            _sort(_array, 0, int256(_array.length - 1));
        }
        return _array;
    }
    
    function _sort(address[] memory _array, int256 _low, int256 _high) private pure {
        int256 i = _low;
        int256 j = _high;
        if (i == j) return;
        address pivot = _array[uint256(_low + (_high - _low) / 2)];
        while (i <= j) {
            while (_array[uint256(i)] < pivot) i++;
            while (pivot < _array[uint256(j)]) j--;
            if (i <= j) {
                (_array[uint256(i)], _array[uint256(j)]) = (_array[uint256(j)], _array[uint256(i)]);
                i++;
                j--;
            }
        }
        if (_low < j) {
            _sort(_array, _low, j);
        }
        if (i < _high) {
            _sort(_array, i, _high);
        }
    }

}
