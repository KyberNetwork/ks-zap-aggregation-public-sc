//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolKey} from './PoolKey.sol';

/// @notice Library for computing the ID of a pool
library PoolIdLibrary {
  function toId(PoolKey memory poolKey) internal pure returns (bytes32 poolId) {
    assembly ('memory-safe') {
      // 0xc0 represents the total size of the poolKey struct (6 slots of 32 bytes)
      poolId := keccak256(poolKey, 0xc0)
    }
  }
}
