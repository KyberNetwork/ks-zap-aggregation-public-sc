// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MASK_128_BITS} from '../libraries/BitMask.sol';

/// @notice Two 128-bit values packed into a 256-bit value, the first value in the upper 128 bits
type PackedU128 is uint256;

using PackedU128Library for PackedU128 global;

/**
 * @notice Packs two values into a {PackedU128}
 * @param value0 The value stored in the upper 128 bits
 * @param value1 The value stored in the lower 128 bits
 * @return packedU128 The packed value
 */
function toPackedU128(uint256 value0, uint256 value1) pure returns (PackedU128 packedU128) {
  assembly ('memory-safe') {
    packedU128 := or(shl(128, value0), value1)
  }
}

/// @title PackedU128Library
/// @notice Reads the values of a {PackedU128}
library PackedU128Library {
  /// @dev Returns the value stored in the upper 128 bits
  function value0(PackedU128 packedU128) internal pure returns (uint128 _value0) {
    assembly ('memory-safe') {
      _value0 := shr(128, packedU128)
    }
  }

  /// @dev Returns the value stored in the lower 128 bits
  function value1(PackedU128 packedU128) internal pure returns (uint128 _value1) {
    assembly ('memory-safe') {
      _value1 := and(packedU128, MASK_128_BITS)
    }
  }
}
