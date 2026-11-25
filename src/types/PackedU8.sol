// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MASK_8_BITS} from '../libraries/BitMask.sol';

/// @notice Array of uint8 values packed 8 bits each, the first value in the lowest bits
type PackedU8 is uint256;

using PackedU8Library for PackedU8 global;

/// @notice Packs `values` into a {PackedU8}
function toPackedU8(uint8[] memory values) pure returns (PackedU8) {
  uint256 packed = 0;
  for (uint256 i = 0; i < values.length; i++) {
    packed |= uint256(values[i]) << (i * 8);
  }
  return PackedU8.wrap(packed);
}

/// @title PackedU8Library
/// @notice Accessors of {PackedU8}
library PackedU8Library {
  /// @notice Returns the value at `index`
  function at(PackedU8 self, uint256 index) internal pure returns (uint8 value) {
    assembly ('memory-safe') {
      value := and(shr(mul(8, index), self), MASK_8_BITS)
    }
  }
}
