// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/// @title Position
/// @notice Positions represent an owner address' liquidity between a lower and upper tick boundary
/// @dev Positions store additional state for tracking fees owed to the position
library Position {
  /// @notice Cannot update a position with no liquidity
  error CannotUpdateEmptyPosition();

  // info stored for each user's position
  struct State {
    // the amount of liquidity owned by this position
    uint128 liquidity;
    // fee growth per unit of liquidity as of the last update to liquidity or fees owed
    uint256 feeGrowthInside0LastX128;
    uint256 feeGrowthInside1LastX128;
  }

  /// @notice A helper function to calculate the position key
  /// @param owner The address of the position owner
  /// @param tickLower the lower tick boundary of the position
  /// @param tickUpper the upper tick boundary of the position
  /// @param salt A unique value to differentiate between multiple positions in the same range, by the same owner. Passed in by the caller.
  function calculatePositionKey(address owner, int24 tickLower, int24 tickUpper, bytes32 salt)
    internal
    pure
    returns (bytes32 positionKey)
  {
    // positionKey = keccak256(abi.encodePacked(owner, tickLower, tickUpper, salt))
    assembly ('memory-safe') {
      let fmp := mload(0x40)
      mstore(add(fmp, 0x26), salt) // [0x26, 0x46)
      mstore(add(fmp, 0x06), tickUpper) // [0x23, 0x26)
      mstore(add(fmp, 0x03), tickLower) // [0x20, 0x23)
      mstore(fmp, owner) // [0x0c, 0x20)
      positionKey := keccak256(add(fmp, 0x0c), 0x3a) // len is 58 bytes

      // now clean the memory we used
      mstore(add(fmp, 0x40), 0) // fmp+0x40 held salt
      mstore(add(fmp, 0x20), 0) // fmp+0x20 held tickLower, tickUpper, salt
      mstore(fmp, 0) // fmp held owner
    }
  }
}
