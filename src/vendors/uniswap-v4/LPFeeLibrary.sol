// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Library of helper functions for a pools LP fee
library LPFeeLibrary {
  /// @notice Thrown when the static or dynamic fee on a pool exceeds 100%.
  error LPFeeTooLarge(uint24 fee);

  /// @notice An lp fee of exactly 0b1000000... signals a dynamic fee pool. This isn't a valid static fee as it is > MAX_LP_FEE
  uint24 public constant DYNAMIC_FEE_FLAG = 0x800000;

  /// @notice the second bit of the fee returned by beforeSwap is used to signal if the stored LP fee should be overridden in this swap
  // only dynamic-fee pools can return a fee via the beforeSwap hook
  uint24 public constant OVERRIDE_FEE_FLAG = 0x400000;

  /// @notice mask to remove the override fee flag from a fee returned by the beforeSwaphook
  uint24 public constant REMOVE_OVERRIDE_MASK = 0xBFFFFF;

  /// @notice the lp fee is represented in hundredths of a bip, so the max is 100%
  uint24 public constant MAX_LP_FEE = 1_000_000;

  /// @notice returns true if a pool's LP fee signals that the pool has a dynamic fee
  /// @param self The fee to check
  /// @return bool True of the fee is dynamic
  function isDynamicFee(uint24 self) internal pure returns (bool) {
    return self == DYNAMIC_FEE_FLAG;
  }

  /// @notice returns true if the fee has the override flag set (2nd highest bit of the uint24)
  /// @param self The fee to check
  /// @return bool True of the fee has the override flag set
  function isOverride(uint24 self) internal pure returns (bool) {
    return self & OVERRIDE_FEE_FLAG != 0;
  }

  /// @notice returns a fee with the override flag removed
  /// @param self The fee to remove the override flag from
  /// @return fee The fee without the override flag set
  function removeOverrideFlag(uint24 self) internal pure returns (uint24) {
    return self & REMOVE_OVERRIDE_MASK;
  }
}
