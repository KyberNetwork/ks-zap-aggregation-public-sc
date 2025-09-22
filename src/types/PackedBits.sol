// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

type PackedBits is uint256;

using PackedBitsLibrary for PackedBits global;

function toPackedBits(bool[] memory bits) pure returns (PackedBits) {
  uint256 packed = 0;
  for (uint256 i = 0; i < bits.length; i++) {
    packed |= (bits[i] ? uint256(1) : 0) << i;
  }

  return PackedBits.wrap(packed);
}

library PackedBitsLibrary {
  function at(PackedBits self, uint256 index) internal pure returns (bool bit) {
    assembly ("memory-safe") {
      bit := and(shr(index, self), 1)
    }
  }
}
