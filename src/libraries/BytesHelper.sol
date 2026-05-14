// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Contains functions for processing bytes
library BytesHelper {
  /// @notice equivalent to SliceOutOfBounds.selector, stored in least-significant bits
  uint256 internal constant SLICE_ERROR_SELECTOR = 0x3b99b53d;

  /// @notice Returns the uint256 value at the given offset
  function mloadUint256(bytes memory self, uint256 offset)
    internal
    pure
    checkOffset(self, offset)
    returns (uint256 value)
  {
    assembly ('memory-safe') {
      value := mload(add(self, add(0x20, offset)))
    }
  }

  /// @notice Returns the bytes32 value at the given offset
  function mloadBytes32(bytes memory self, uint256 offset)
    internal
    pure
    checkOffset(self, offset)
    returns (bytes32 value)
  {
    assembly ('memory-safe') {
      value := mload(add(self, add(0x20, offset)))
    }
  }

  /// @notice Stores the uint256 value at the given offset
  function mstoreUint256(bytes memory self, uint256 offset, uint256 value)
    internal
    pure
    checkOffset(self, offset)
  {
    assembly ('memory-safe') {
      mstore(add(self, add(0x20, offset)), value)
    }
  }

  /// @notice Stores the bytes32 value at the given offset
  function mstoreBytes32(bytes memory self, uint256 offset, bytes32 value)
    internal
    pure
    checkOffset(self, offset)
  {
    assembly ('memory-safe') {
      mstore(add(self, add(0x20, offset)), value)
    }
  }

  modifier checkOffset(bytes memory self, uint256 offset) {
    assembly ('memory-safe') {
      if gt(add(offset, 0x20), mload(self)) {
        mstore(0, SLICE_ERROR_SELECTOR)
        revert(0x1c, 4)
      }
    }
    _;
  }
}
