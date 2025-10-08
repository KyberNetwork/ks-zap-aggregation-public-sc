// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Contains functions for processing bytes
library BytesHelper {
  /// @notice Returns the uint256 value at the given offset
  function mloadUint256(bytes memory self, uint256 offset) internal pure returns (uint256 value) {
    assembly ("memory-safe") {
      value := mload(add(self, add(0x20, offset)))
    }
  }

  /// @notice Returns the bytes32 value at the given offset
  function mloadBytes32(bytes memory self, uint256 offset) internal pure returns (bytes32 value) {
    assembly ("memory-safe") {
      value := mload(add(self, add(0x20, offset)))
    }
  }
}
