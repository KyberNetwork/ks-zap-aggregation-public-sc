// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from './IPoolManager.sol';
import {Lock} from './Lock.sol';

/// @notice A helper library to provide state getters that use exttload
library TransientStateLibrary {
  /// @notice Get the current delta for a caller in the given currency
  /// @param target The credited account address
  /// @param currency The currency for which to lookup the delta
  function currencyDelta(IPoolManager manager, address target, address currency)
    internal
    view
    returns (int256)
  {
    bytes32 key;
    assembly ('memory-safe') {
      mstore(0, and(target, 0xffffffffffffffffffffffffffffffffffffffff))
      mstore(32, and(currency, 0xffffffffffffffffffffffffffffffffffffffff))
      key := keccak256(0, 64)
    }
    return int256(uint256(manager.exttload(key)));
  }

  /// @notice Returns whether the contract is unlocked or not
  function isUnlocked(IPoolManager manager) internal view returns (bool) {
    return manager.exttload(Lock.IS_UNLOCKED_SLOT) != 0x0;
  }
}
