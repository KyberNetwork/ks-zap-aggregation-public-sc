// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapHelper} from '../IZapHelper.sol';

import {PackedU128} from '../../../types/PackedU128.sol';

/// @title IZapALMVaultHelper
/// @notice Interface of {ZapALMVaultHelper}
interface IZapALMVaultHelper is IZapHelper {
  /**
   * @notice Emitted when the helper swaps on the pool towards the ratio of the vault, or deposits
   * the amounts at the pool price when it swaps nothing
   * @param originalAmount0 The amount of token0 before the swap
   * @param originalAmount1 The amount of token1 before the swap
   * @param usedOffchainData Whether the off-chain data was used
   * @param sharesToAdd The shares that the balances after the swap mint at the pool price
   * @param amount0AfterSwap The balance of token0 after the swap, which the adapter passes to the
   * deposit
   * @param amount1AfterSwap The balance of token1 after the swap, which the adapter passes to the
   * deposit
   */
  event PoolSwap(
    uint256 originalAmount0,
    uint256 originalAmount1,
    bool usedOffchainData,
    uint256 sharesToAdd,
    uint256 amount0AfterSwap,
    uint256 amount1AfterSwap
  );

  /**
   * @notice The parameters that the adapter adds to the pool swap and to the preview of a zap
   * into a vault
   * @param amount0 The amount of token0 to swap and deposit
   * @param amount1 The amount of token1 to swap and deposit
   * @param useExtraData Whether the pool swap uses the extra data of the solver; the preview
   * ignores it
   */
  struct PoolSwapAdditionalParams {
    uint256 amount0;
    uint256 amount1;
    bool useExtraData;
  }

  /**
   * @notice The result of previewing a zap into a vault
   * @param sqrtPriceStartX96 The starting sqrt price
   * @param poolLiquidityStart The starting pool liquidity
   * @param sqrtPriceX96 The resulting sqrt price
   * @param amount0Delta The token0 delta of the swap
   * @param amount1Delta The token1 delta of the swap
   * @param shares The shares minted
   * @param addedAmount0 The amount of token0 deposited
   * @param addedAmount1 The amount of token1 deposited
   */
  struct PreviewZapInResult {
    uint160 sqrtPriceStartX96;
    uint128 poolLiquidityStart;
    uint160 sqrtPriceX96;
    int256 amount0Delta;
    int256 amount1Delta;
    uint256 shares;
    uint256 addedAmount0;
    uint256 addedAmount1;
  }

  /**
   * @notice The result of the pool swap of a zap into a vault
   * @param usedOffchainData Whether the off-chain data was used
   * @param sharesToAdd The shares that the balances after the swap mint at the pool price
   * @param amount0AfterSwap The balance of token0 after the swap, which the adapter passes to the
   * deposit
   * @param amount1AfterSwap The balance of token1 after the swap, which the adapter passes to the
   * deposit
   */
  struct PoolSwapResult {
    bool usedOffchainData;
    uint256 sharesToAdd;
    uint256 amount0AfterSwap;
    uint256 amount1AfterSwap;
  }

  /**
   * @notice The result of previewing a removal of shares from a vault
   * @param amount0 The amount of token0 that the removal returns
   * @param amount1 The amount of token1 that the removal returns
   */
  struct PreviewRemoveResult {
    uint256 amount0;
    uint256 amount1;
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
