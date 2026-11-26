// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapHelper} from '../IZapHelper.sol';

/// @title IZapSolidlyV2Helper
/// @notice Interface of {ZapSolidlyV2Helper}
interface IZapSolidlyV2Helper is IZapHelper {
  /**
   * @notice Emitted by each pool swap of a zap in, including one that swaps nothing
   * @param originalAmount0 The amount of token0 before the swap
   * @param originalAmount1 The amount of token1 before the swap
   * @param liquidityToAdd The liquidity that the pair mints for the amounts to add at the reserves
   * after the swap
   * @param amount0ToAdd The amount of token0 to transfer to the pair, rounded up
   * @param amount1ToAdd The amount of token1 to transfer to the pair, rounded up
   */
  event PoolSwap(
    uint256 originalAmount0,
    uint256 originalAmount1,
    uint256 liquidityToAdd,
    uint256 amount0ToAdd,
    uint256 amount1ToAdd
  );

  /**
   * @notice The amounts that the adapter adds to the pool swap and to the preview of a zap into
   * Solidly V2
   * @param amount0 The amount of token0 to swap and add
   * @param amount1 The amount of token1 to swap and add
   */
  struct PoolSwapAdditionalParams {
    uint256 amount0;
    uint256 amount1;
  }

  /**
   * @notice The result of previewing a zap into Solidly V2
   * @param amount0Delta The token0 delta of the swap
   * @param amount1Delta The token1 delta of the swap
   * @param liquidity The liquidity added
   * @param addedAmount0 The amount of token0 added
   * @param addedAmount1 The amount of token1 added
   */
  struct PreviewZapInResult {
    int256 amount0Delta;
    int256 amount1Delta;
    uint256 liquidity;
    uint256 addedAmount0;
    uint256 addedAmount1;
  }

  /**
   * @notice The result of the pool swap of a Solidly V2 zap
   * @param liquidityToAdd The liquidity that the pair mints for the amounts to add
   * @param amount0ToAdd The amount of token0 to transfer to the pair
   * @param amount1ToAdd The amount of token1 to transfer to the pair
   */
  struct PoolSwapResult {
    uint256 liquidityToAdd;
    uint256 amount0ToAdd;
    uint256 amount1ToAdd;
  }

  /**
   * @notice The result of previewing a removal of liquidity from Solidly V2
   * @param amount0 The amount of token0 that the burn returns
   * @param amount1 The amount of token1 that the burn returns
   */
  struct PreviewRemoveResult {
    uint256 amount0;
    uint256 amount1;
  }
}
