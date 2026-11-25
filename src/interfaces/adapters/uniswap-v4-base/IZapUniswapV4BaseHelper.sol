// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PackedU128} from '../../../types/PackedU128.sol';
import {IZapHelper} from '../IZapHelper.sol';

/// @title IZapUniswapV4BaseHelper
/// @notice Interface of {ZapUniswapV4BaseHelper}
interface IZapUniswapV4BaseHelper is IZapHelper {
  /**
   * @notice Emitted when the helper swaps on the pool towards the ratio of the position, or adds
   * the amounts at the pool price when it swaps nothing
   * @param originalAmount0 The amount of currency0 before the swap
   * @param originalAmount1 The amount of currency1 before the swap
   * @param usedOffchainData Whether the off-chain data was used
   * @param liquidityToAdd The liquidity that the amounts to add give at the price after the swap
   * @param amount0ToAdd The amount of currency0 to add to the position after the swap
   * @param amount1ToAdd The amount of currency1 to add to the position after the swap
   */
  event PoolSwap(
    uint256 originalAmount0,
    uint256 originalAmount1,
    bool usedOffchainData,
    uint128 liquidityToAdd,
    uint256 amount0ToAdd,
    uint256 amount1ToAdd
  );

  /**
   * @notice The parameters that the adapter adds to the pool swap and to the preview of a zap
   * into Uniswap V4
   * @param amount0 The amount of currency0 to swap and add
   * @param amount1 The amount of currency1 to swap and add
   * @param useExtraData Whether the pool swap uses the extra data of the solver; the preview
   * ignores it
   */
  struct PoolSwapAdditionalParams {
    uint256 amount0;
    uint256 amount1;
    bool useExtraData;
  }

  /**
   * @notice The result of previewing a zap into Uniswap V4
   * @param sqrtPriceStartX96 The starting sqrt price
   * @param poolLiquidityStart The starting pool liquidity
   * @param sqrtPriceX96 The resulting sqrt price
   * @param amount0Delta The currency0 delta of the swap
   * @param amount1Delta The currency1 delta of the swap
   * @param positionLiquidity The liquidity added
   * @param addedAmount0 The amount of currency0 added
   * @param addedAmount1 The amount of currency1 added
   */
  struct PreviewZapInResult {
    uint160 sqrtPriceStartX96;
    uint128 poolLiquidityStart;
    uint160 sqrtPriceX96;
    int256 amount0Delta;
    int256 amount1Delta;
    uint256 positionLiquidity;
    uint256 addedAmount0;
    uint256 addedAmount1;
  }

  /**
   * @notice The result of the pool swap of a Uniswap V4 zap
   * @param usedOffchainData Whether the off-chain data was used
   * @param liquidityToAdd The liquidity that the amounts to add give at the price after the swap
   * @param amount0ToAdd The amount of currency0 to add to the position after the swap
   * @param amount1ToAdd The amount of currency1 to add to the position after the swap
   */
  struct PoolSwapResult {
    bool usedOffchainData;
    uint128 liquidityToAdd;
    uint256 amount0ToAdd;
    uint256 amount1ToAdd;
  }

  /**
   * @notice The result of previewing liquidity removal from Uniswap V4
   * @param amount0Fee The fee amount in token0
   * @param amount1Fee The fee amount in token1
   * @param amount0Principal The principal amount in token0
   * @param amount1Principal The principal amount in token1
   */
  struct PreviewRemoveResult {
    uint256 amount0Fee;
    uint256 amount1Fee;
    uint256 amount0Principal;
    uint256 amount1Principal;
  }

  /**
   * @notice The off-chain data for the swap
   * @param sqrtPriceStartX96 The starting sqrt price
   * @param poolLiquidityStart The starting pool liquidity
   * @param amount0Range The range of token0
   * @param amount1Range The range of token1
   * @param sqrtPriceX96 The resulting sqrt price
   */
  struct OffchainData {
    uint160 sqrtPriceStartX96;
    uint128 poolLiquidityStart;
    PackedU128 amount0Range;
    PackedU128 amount1Range;
    uint160 sqrtPriceX96;
  }
}
