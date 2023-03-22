// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 *  @title  StrategiesPackedSet
 *
 *  @notice Store and manage a set of strategies as a packed bytes32 word containing:
 *          address: 160 bits
 *          last worked: 48 bits (timestamp of 4722366482869645213695 max, roughly 2b years)
 *          required amount: 48 bits
 *
 *  @dev    This library offers O(1) add, remove, contains, and length, based on OpenZeppelin
 *          enumerable set implementation.
 */
library StrategiesPackedSet {
  struct Set {
    // Storage of _set values
    bytes32[] values;
    // Position of the value in the `values` array, plus 1 because index 0
    // means a value is not in the _set.
    mapping(address => uint256) indexes;
  }

  /**
   * @dev Add a value to a _set. O(1).
   *
   * Returns true if the value was added to the _set, that is if it was not
   * already present.
   */
  function add(Set storage _set, address _strategy, uint256 _requiredAmount) internal returns (bool) {
    if (!contains(_set, _strategy)) {
      bytes32 _value = bytes32(
        uint256(uint160(_strategy)) // 160 bits
          // 48 bits skipped for the lastWorkAt (init at 0)
          | (uint256(_requiredAmount) << 208) // 48 bits - no mask as it's the last 48 bits
      );

      _set.values.push(_value);

      // The value is stored at length-1, but we add 1 to all indexes
      // and use 0 as a sentinel value
      _set.indexes[_strategy] = _set.values.length;
      return true;
    } else {
      return false;
    }
  }

  /**
   * @dev Removes a value from a _set. O(1).
   *
   * Returns true if the value was removed from the _set, that is if it was
   * present.
   */
  function remove(Set storage _set, address _strategy) internal returns (bool) {
    uint256 _valueIndex = _set.indexes[_strategy];

    if (_valueIndex != 0) {
      uint256 _toDeleteIndex = _valueIndex - 1;
      uint256 _lastIndex = _set.values.length - 1;

      if (_lastIndex != _toDeleteIndex) {
        bytes32 _lastValue = _set.values[_lastIndex];

        // Move the last value to the index where the value to delete is
        _set.values[_toDeleteIndex] = _lastValue;
        // Update the index for the moved value
        _set.indexes[address(uint160(uint256(_lastValue)))] = _valueIndex; // Replace lastValue's index to valueIndex
      }

      // Delete the slot where the moved value was stored
      _set.values.pop();

      // Delete the index for the deleted slot
      delete _set.indexes[_strategy];

      return true;
    } else {
      return false;
    }
  }

  /**
   * @dev Set the last work at timestamp for a strategy.
   *      Bit mask hardcoded for gas cost.
   */
  function setLastWorkAt(Set storage _set, address _strategy, uint256 _timestamp) internal {
    uint256 _valueIndex = _set.indexes[_strategy];

    bytes32 _elementToUpdate = _set.values[_valueIndex - 1];

    // Update the element itself: indexes and lastWorkedAt
    // Clear the 48 bits of the timestamp then set them to the new value
    bytes32 _updatedElement = bytes32(
      (uint256(_elementToUpdate) & 0xffffffffffff000000000000ffffffffffffffffffffffffffffffffffffffff)
        | ((_timestamp & 0xffffffffffff) << 160)
    );

    // Store the new value
    _set.values[_valueIndex - 1] = _updatedElement;
  }

  /**
   * @dev Set the gas required amount for a strategy.
   *      Bit mask hardcoded for gas cost.
   */
  function setRequiredAmount(Set storage _set, address _strategy, uint256 _requiredAmount) internal {
    uint256 _valueIndex = _set.indexes[_strategy];

    bytes32 _elementToUpdate = _set.values[_valueIndex - 1];

    // Update the element itself: indexes and requiredAmount
    // Clear the 48 bits of the amount then set them to the new value
    bytes32 _updatedElement = bytes32(
      (uint256(_elementToUpdate) & 0x000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffff)
        | ((_requiredAmount) << 208)
    );

    _set.values[_valueIndex - 1] = _updatedElement;
  }

  /**
   * @dev Returns true if the value is in the _set. O(1).
   */
  function contains(Set storage _set, address _value) internal view returns (bool) {
    return _set.indexes[_value] != 0;
  }

  /**
   * @dev Returns the number of values on the _set. O(1).
   */
  function length(Set storage _set) internal view returns (uint256) {
    return _set.values.length;
  }

  /**
   * @dev Returns the value stored at position `index` in the _set. O(1).
   *
   *
   * Requirements:
   *
   * - `index` must be strictly less than {length}.
   */
  function at(Set storage _set, uint256 _index) internal view returns (bytes32) {
    return _set.values[_index];
  }

  /**
   * @dev Returns the value associated with the `_strategy` address. 0(1)
   *      This is a convenience overload
   */
  function at(Set storage _set, address _strategy) internal view returns (bytes32) {
    // Non existing value (0 is the safeguard)?
    if (_set.indexes[_strategy] == 0) return bytes32(0);

    return _set.values[_set.indexes[_strategy] - 1];
  }

  /**
   * @dev Return the entire _set in an array
   *
   * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
   * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
   * this function has an unbounded cost, and using it as part of a state-changing function may render the function
   * uncallable if the _set grows to a point where copying to memory consumes too much gas to fit in a block.
   */
  function values(Set storage _set) internal view returns (bytes32[] memory) {
    return _set.values;
  }

  /**
   * @dev Return the address stored in the first 20 bytes
   *      For use on bytes32 type (use StrategiesPackedSet for bytes32).
   */
  function strategyAddress(bytes32 _value) internal pure returns (address) {
    return address(uint160(uint256(_value)));
  }

  /**
   * @dev Return the lastWorkAt stored after 20 bytes, in the next 48 bits
   *      For use on bytes32 type (use StrategiesPackedSet for bytes32).
   */
  function lastWorkAt(bytes32 _value) internal pure returns (uint256) {
    return uint256(_value >> 160) & 0xFFFFFFFFFFFF;
  }

  /**
   * @dev Return the requiredAmount stored in the last 48 bytes
   *      For use on bytes32 type (use StrategiesPackedSet for bytes32).
   */
  function requiredAmount(bytes32 _value) internal pure returns (uint256) {
    return uint256(_value >> 208) & 0xFFFFFFFFFFFF;
  }
}
