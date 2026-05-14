// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from './IPoolManager.sol';
import {Lock} from './Lock.sol';

/// @notice A helper library to provide state getters that use exttload
library TransientStateLibrary {
  /// @notice Returns whether the contract is unlocked or not
  function isUnlocked(IPoolManager manager) internal view returns (bool) {
    return manager.exttload(Lock.IS_UNLOCKED_SLOT) != 0x0;
  }
}
