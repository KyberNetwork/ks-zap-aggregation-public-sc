// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ZapAgainRecord
/// @notice Stores in transient storage the parameters of the zap again that the solver passes to a
/// pool swap, for the settler of the owner call that follows
/// @dev The record lives in the transient storage of the contract that runs the pool swap and the
/// settler, the router. A pool swap writes or clears the record and the settler consumes it. A
/// zero length means no record.
library ZapAgainRecord {
  /// @dev Transient slot of the byte length of the parameters, followed by the slots of the words
  /// of the parameters
  bytes32 private constant BASE_SLOT = bytes32(uint256(keccak256('ks.zap.zap-again-record')) - 1);

  /**
   * @dev Stores the parameters, replacing the previous record
   * @param params The ABI-encoded parameters of the zap again
   */
  function write(bytes calldata params) internal {
    bytes32 slot = BASE_SLOT;
    assembly ('memory-safe') {
      tstore(slot, params.length)
      let words := shr(5, add(params.length, 31))
      for { let i := 0 } lt(i, words) { i := add(i, 1) } {
        tstore(add(slot, add(1, i)), calldataload(add(params.offset, shl(5, i))))
      }
    }
  }

  /// @dev Clears the record
  function clear() internal {
    bytes32 slot = BASE_SLOT;
    assembly ('memory-safe') {
      tstore(slot, 0)
    }
  }

  /**
   * @dev Clears the record and returns its parameters
   * @return params The ABI-encoded parameters, empty when no record exists
   */
  function consume() internal returns (bytes memory params) {
    bytes32 slot = BASE_SLOT;
    uint256 length;
    assembly ('memory-safe') {
      length := tload(slot)
    }
    if (length == 0) return params;

    clear();

    assembly ('memory-safe') {
      let words := shr(5, add(length, 31))
      params := mload(0x40)
      mstore(params, length)
      for { let i := 0 } lt(i, words) { i := add(i, 1) } {
        mstore(add(params, add(0x20, shl(5, i))), tload(add(slot, add(1, i))))
      }
      mstore(0x40, add(params, add(0x20, shl(5, words))))
    }
  }
}
