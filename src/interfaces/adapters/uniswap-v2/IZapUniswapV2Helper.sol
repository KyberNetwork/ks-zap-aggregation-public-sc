// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapHelper} from '../IZapHelper.sol';

/// @title IZapUniswapV2Helper
/// @notice Interface of {ZapUniswapV2Helper}
interface IZapUniswapV2Helper is IZapHelper {
  /**
   * @notice Emitted by each pool swap of a zap in, including one that swaps nothing
   * @param originalAmount0 The amount of token0 before the swap
   * @param originalAmount1 The amount of token1 before the swap
   * @param usedOffchainData Whether the optimizer used the off-chain data
   * @param liquidityToAdd The liquidity that the pair mints for the amounts to add at the reserves
   * after the swap
   * @param amount0ToAdd The amount of token0 to transfer to the pair, rounded up
   * @param amount1ToAdd The amount of token1 to transfer to the pair, rounded up
   */
  event PoolSwap(
    uint256 originalAmount0,
    uint256 originalAmount1,
    bool usedOffchainData,
    uint256 liquidityToAdd,
    uint256 amount0ToAdd,
    uint256 amount1ToAdd
  );

  /**
   * @notice The parameters that the adapter adds to the pool swap and to the preview of a zap
   * into Uniswap V2
   * @param amount0 The amount of token0 to swap and add
   * @param amount1 The amount of token1 to swap and add
   * @param useExtraData Whether the pool swap passes the extra data of the solver to the
   * optimizer; the preview ignores it
   */
  struct PoolSwapAdditionalParams {
    uint256 amount0;
    uint256 amount1;
    bool useExtraData;
  }

  /**
   * @notice The result of previewing a zap into Uniswap V2 without an optimizer
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
   * @notice The result of the pool swap of a Uniswap V2 zap
   * @param usedOffchainData Whether the optimizer used the off-chain data
   * @param liquidityToAdd The liquidity that the pair mints for the amounts to add
   * @param amount0ToAdd The amount of token0 to transfer to the pair
   * @param amount1ToAdd The amount of token1 to transfer to the pair
   */
  struct PoolSwapResult {
    bool usedOffchainData;
    uint256 liquidityToAdd;
    uint256 amount0ToAdd;
    uint256 amount1ToAdd;
  }

  /**
   * @notice The fee parameters of the pair that the preview of a removal reads
   * @param swapFee The swap fee of the pair, in units of `feeDenominator`
   * @param protocolFee The protocol fee parameter of the pair; zero when the protocol fee is off
   * @param feeDenominator The denominator of `swapFee`
   */
  struct PreviewRemoveAdditionalParams {
    uint24 swapFee;
    uint24 protocolFee;
    uint24 feeDenominator;
  }

  /**
   * @notice The result of previewing a removal of liquidity from Uniswap V2
   * @param amount0 The amount of token0 that the burn returns
   * @param amount1 The amount of token1 that the burn returns
   */
  struct PreviewRemoveResult {
    uint256 amount0;
    uint256 amount1;
  }
}
