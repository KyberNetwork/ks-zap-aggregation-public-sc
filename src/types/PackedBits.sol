// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

type PackedBits is uint256;

using PackedBitsLibrary for PackedBits global;

/// @notice Packs the bits into a PackedBits
function toPackedBits(bool[] memory bits) pure returns (PackedBits) {
  uint256 packed = 0;
  for (uint256 i = 0; i < bits.length; i++) {
    packed |= (bits[i] ? uint256(1) : 0) << i;
  }

  return PackedBits.wrap(packed);
}

/// @notice Contains functions for processing PackedBits
library PackedBitsLibrary {
  /// @notice Returns the bit at the given index
  function at(PackedBits self, uint256 index) internal pure returns (bool bit) {
    assembly ('memory-safe') {
      bit := and(shr(index, self), 1)
    }
  }
}
