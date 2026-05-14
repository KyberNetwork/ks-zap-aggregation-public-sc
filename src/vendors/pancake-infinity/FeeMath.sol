// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {FixedPoint128} from '../uniswap-v4/FixedPoint128.sol';
import {FullMath} from '../uniswap-v4/FullMath.sol';

import {ICLPoolManager} from './ICLPoolManager.sol';
import {PoolKey} from './PoolKey.sol';
import {Tick} from './Tick.sol';

import {ICLPositionManager} from './ICLPositionManager.sol';

library FeeMath {
  /// @notice Calculates the fees accrued to a position. Used for testing purposes.
  function getFeesOwed(ICLPositionManager posm, ICLPoolManager manager, uint256 tokenId)
    internal
    view
    returns (uint256 token0Owed, uint256 token1Owed)
  {
    (
      PoolKey memory poolKey,
      int24 tickLower,
      int24 tickUpper,
      uint128 liquidity,
      uint256 feeGrowthInside0LastX128,
      uint256 feeGrowthInside1LastX128,
    ) = posm.positions(tokenId);
    bytes32 poolId = poolKey.toId();

    (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) =
      _getFeeGrowthInside(manager, poolId, tickLower, tickUpper);

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

  // TODO: should we consider migrating this into core repo ?
  function _getFeeGrowthInside(
    ICLPoolManager manager,
    bytes32 poolId,
    int24 tickLower,
    int24 tickUpper
  ) internal view returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) {
    (uint256 feeGrowthGlobal0X128, uint256 feeGrowthGlobal1X128) =
      manager.getFeeGrowthGlobals(poolId);

    Tick.Info memory lowerTickInfo = manager.getPoolTickInfo(poolId, tickLower);
    Tick.Info memory upperTickInfo = manager.getPoolTickInfo(poolId, tickUpper);
    uint256 lowerFeeGrowthOutside0X128 = lowerTickInfo.feeGrowthOutside0X128;
    uint256 lowerFeeGrowthOutside1X128 = lowerTickInfo.feeGrowthOutside1X128;
    uint256 upperFeeGrowthOutside0X128 = upperTickInfo.feeGrowthOutside0X128;
    uint256 upperFeeGrowthOutside1X128 = upperTickInfo.feeGrowthOutside1X128;
    (, int24 tickCurrent,,) = manager.getSlot0(poolId);
    unchecked {
      if (tickCurrent < tickLower) {
        feeGrowthInside0X128 = lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
        feeGrowthInside1X128 = lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
      } else if (tickCurrent >= tickUpper) {
        feeGrowthInside0X128 = upperFeeGrowthOutside0X128 - lowerFeeGrowthOutside0X128;
        feeGrowthInside1X128 = upperFeeGrowthOutside1X128 - lowerFeeGrowthOutside1X128;
      } else {
        feeGrowthInside0X128 =
          feeGrowthGlobal0X128 - lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
        feeGrowthInside1X128 =
          feeGrowthGlobal1X128 - lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
      }
    }
  }
}
