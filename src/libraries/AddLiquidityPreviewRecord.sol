// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title AddLiquidityPreviewRecord
/// @notice Stores in transient storage, per pool, the add liquidity preview that a pool swap
/// computes for the amounts and the reserves after the swap
/// @dev The record lives in the storage of the contract that runs the pool swap and the mint, the
/// router. A record is valid for a mint only when its key equals the key of the helper, the pool,
/// the amounts and the reserves at the mint.
library AddLiquidityPreviewRecord {
  /// @dev Base of the transient slots of the records
  bytes32 private constant BASE_SLOT =
    bytes32(uint256(keccak256('ks.zap.add-liquidity-preview-record')) - 1);

  /// @dev Returns the key of a preview of `helper` for `amount0` and `amount1` on `pool` at
  /// `reserve0` and `reserve1`
  function key(
    address helper,
    address pool,
    uint256 amount0,
    uint256 amount1,
    uint256 reserve0,
    uint256 reserve1
  ) internal pure returns (bytes32 recordKey) {
    assembly ('memory-safe') {
      let ptr := mload(0x40)
      mstore(ptr, and(helper, 0xffffffffffffffffffffffffffffffffffffffff))
      mstore(add(ptr, 0x20), and(pool, 0xffffffffffffffffffffffffffffffffffffffff))
      mstore(add(ptr, 0x40), amount0)
      mstore(add(ptr, 0x60), amount1)
      mstore(add(ptr, 0x80), reserve0)
      mstore(add(ptr, 0xa0), reserve1)
      recordKey := keccak256(ptr, 0xc0)
    }
  }

  /// @dev Stores the preview of `pool` under `recordKey`, replacing the previous record of `pool`
  function write(
    address pool,
    bytes32 recordKey,
    uint256 liquidity,
    uint256 addedAmount0,
    uint256 addedAmount1
  ) internal {
    bytes32 slot = _slot(pool);
    assembly ('memory-safe') {
      tstore(slot, recordKey)
      tstore(add(slot, 1), liquidity)
      tstore(add(slot, 2), addedAmount0)
      tstore(add(slot, 3), addedAmount1)
    }
  }

  /**
   * @dev Returns the preview of `pool` and clears its key when the key of the record equals
   * `recordKey`, or returns `found` false and keeps the record otherwise
   * @param pool The pool of the record
   * @param recordKey The key that the record must hold
   * @return found Whether the record holds `recordKey`
   * @return liquidity The previewed liquidity
   * @return addedAmount0 The previewed amount of token0
   * @return addedAmount1 The previewed amount of token1
   */
  function consume(address pool, bytes32 recordKey)
    internal
    returns (bool found, uint256 liquidity, uint256 addedAmount0, uint256 addedAmount1)
  {
    bytes32 slot = _slot(pool);
    assembly ('memory-safe') {
      found := eq(tload(slot), recordKey)
      if found {
        liquidity := tload(add(slot, 1))
        addedAmount0 := tload(add(slot, 2))
        addedAmount1 := tload(add(slot, 3))
        tstore(slot, 0)
      }
    }
  }

  /// @dev Returns whether `pool` has a record that is not consumed
  function exists(address pool) internal view returns (bool) {
    bytes32 slot = _slot(pool);
    bytes32 recordKey;
    assembly ('memory-safe') {
      recordKey := tload(slot)
    }
    return recordKey != 0;
  }

  /// @dev Returns the first transient slot of the record of `pool`
  function _slot(address pool) private pure returns (bytes32 slot) {
    bytes32 baseSlot = BASE_SLOT;
    assembly ('memory-safe') {
      mstore(0x00, baseSlot)
      mstore(0x20, and(pool, 0xffffffffffffffffffffffffffffffffffffffff))
      slot := keccak256(0x00, 0x40)
    }
  }
}
