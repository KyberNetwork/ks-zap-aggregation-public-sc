// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

library BytesHelper {
  function mloadUint256(bytes memory self, uint256 offset) internal pure returns (uint256 value) {
    assembly ("memory-safe") {
      value := mload(add(self, add(0x20, offset)))
    }
  }

  function mloadBytes32(bytes memory self, uint256 offset) internal pure returns (bytes32 value) {
    assembly ("memory-safe") {
      value := mload(add(self, add(0x20, offset)))
    }
  }
}
