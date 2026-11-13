// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title AddLiquidityPreviewRecord
/// @notice Stores in transient storage the add liquidity preview that a pool swap computes for the
/// amounts after the swap
/// @dev The record lives in the transient storage of the contract that runs the pool swap and the
/// mint, the router. A pool swap writes the record and the next mint consumes it. A zero liquidity
/// means no record.
library AddLiquidityPreviewRecord {
  /// @dev Transient slot of the liquidity, followed by the slots of the two added amounts
  bytes32 private constant BASE_SLOT =
    bytes32(uint256(keccak256('ks.zap.add-liquidity-preview-record')) - 1);

  /// @dev Stores the preview, replacing the previous record
  function write(uint256 liquidity, uint256 addedAmount0, uint256 addedAmount1) internal {
    bytes32 slot = BASE_SLOT;
    assembly ('memory-safe') {
      tstore(slot, liquidity)
      tstore(add(slot, 1), addedAmount0)
      tstore(add(slot, 2), addedAmount1)
    }
  }

  /**
   * @dev Returns the preview and clears the record when its liquidity is nonzero
   * @return liquidity The previewed liquidity, zero when no record exists
   * @return addedAmount0 The previewed amount of token0
   * @return addedAmount1 The previewed amount of token1
   */
  function consume()
    internal
    returns (uint256 liquidity, uint256 addedAmount0, uint256 addedAmount1)
  {
    bytes32 slot = BASE_SLOT;
    assembly ('memory-safe') {
      liquidity := tload(slot)
      addedAmount0 := tload(add(slot, 1))
      addedAmount1 := tload(add(slot, 2))
      if liquidity { tstore(slot, 0) }
    }
  }
}
