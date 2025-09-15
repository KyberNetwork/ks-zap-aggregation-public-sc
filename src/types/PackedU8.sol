// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../libraries/BitMask.sol';

/**
 * @notice PackedU8 is packed version of uint8 array.
 *
 * Layout: 8 bits * length
 */
type PackedU8 is uint256;

using PackedU8Library for PackedU8 global;

function toPackedU8(uint8[] memory values) pure returns (PackedU8) {
  uint256 packed = 0;
  for (uint256 i = 0; i < values.length; i++) {
    packed |= uint256(values[i]) << (i * 8);
  }
  return PackedU8.wrap(packed);
}

library PackedU8Library {
  function at(PackedU8 self, uint256 index) internal pure returns (uint8 value) {
    assembly ("memory-safe") {
      value := and(shr(mul(8, index), self), MASK_8_BITS)
    }
  }
}
