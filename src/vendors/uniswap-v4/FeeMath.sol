// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {FixedPoint128} from './FixedPoint128.sol';
import {FullMath} from './FullMath.sol';
import {IPoolManager} from './IPoolManager.sol';

import {PoolKey} from './PoolKey.sol';
import {PositionInfo} from './PositionInfoLibrary.sol';
import {StateLibrary} from './StateLibrary.sol';

import {IPositionManager} from './IPositionManager.sol';

library FeeMath {
  using StateLibrary for IPoolManager;

  /// @notice Calculates the fees accrued to a position. Used for testing purposes.
  function getFeesOwed(IPositionManager posm, IPoolManager manager, uint256 tokenId)
    internal
    view
    returns (uint256 token0Owed, uint256 token1Owed)
  {
    (PoolKey memory poolKey, PositionInfo positionInfo) = posm.getPoolAndPositionInfo(tokenId);

    bytes32 poolId = poolKey.toId();
    (uint128 liquidity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128) = manager.getPositionInfo(
      poolId, address(posm), positionInfo.tickLower(), positionInfo.tickUpper(), bytes32(tokenId)
    );

    (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
      manager.getFeeGrowthInside(poolId, positionInfo.tickLower(), positionInfo.tickUpper());

    (token0Owed, token1Owed) = getFeesOwed(
      feeGrowthInside0X128,
      feeGrowthInside1X128,
      feeGrowthInside0LastX128,
      feeGrowthInside1LastX128,
      liquidity
    );
  }

  function getFeesOwed(
    uint256 feeGrowthInside0X128,
    uint256 feeGrowthInside1X128,
    uint256 feeGrowthInside0LastX128,
    uint256 feeGrowthInside1LastX128,
    uint256 liquidity
  ) internal pure returns (uint256 token0Owed, uint256 token1Owed) {
    token0Owed = getFeeOwed(feeGrowthInside0X128, feeGrowthInside0LastX128, liquidity);
    token1Owed = getFeeOwed(feeGrowthInside1X128, feeGrowthInside1LastX128, liquidity);
  }

  function getFeeOwed(
    uint256 feeGrowthInsideX128,
    uint256 feeGrowthInsideLastX128,
    uint256 liquidity
  ) internal pure returns (uint256 tokenOwed) {
    unchecked {
      tokenOwed =
      (FullMath.mulDiv(
          feeGrowthInsideX128 - feeGrowthInsideLastX128, liquidity, FixedPoint128.Q128
        ));
    }
  }
}
