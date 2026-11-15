// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PackedU128} from '../../../types/PackedU128.sol';

/// @title IZapArrakisV2HelperTypes
/// @notice Parameters and results of the Arrakis V2 helper's zap in preview
interface IZapArrakisV2HelperTypes {
  /**
   * @notice The fixed parameters for zapping into Arrakis V2
   * @param vault The address of the vault
   * @param pool The address of the pool
   * @param router The address of the router
   * @param gauge The address of the gauge
   * @param sqrtPriceLimit0X96 The starting sqrt price limit for token0
   * @param sqrtPriceLimit1X96 The starting sqrt price limit for token1
   * @param iterations The number of iterations for the swap
   */
  struct ZapInFixedParams {
    address vault;
    address pool;
    address router;
    address gauge;
    uint160 sqrtPriceLimit0X96;
    uint160 sqrtPriceLimit1X96;
    uint256 iterations;
  }

  /**
   * @notice The variable parameters for previewing a zap into Arrakis V2
   * @param amount0 The amount of token0 to zap in
   * @param amount1 The amount of token1 to zap in
   */
  struct PreviewZapInVariableParams {
    uint256 amount0;
    uint256 amount1;
  }

  /**
   * @notice The result of previewing a zap into Arrakis V2
   * @param sqrtPriceStartX96 The starting sqrt price
   * @param poolLiquidityStart The starting pool liquidity
   * @param sqrtPriceX96 The resulting sqrt price
   * @param amount0Delta The token0 delta for the swap
   * @param amount1Delta The token1 delta for the swap
   * @param shares The amount of shares added
   * @param addedAmount0 The amount of token0 added
   * @param addedAmount1 The amount of token1 added
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
   * @notice The variable parameters for the pool swap of an Arrakis V2 zap
   * @param offchainData The off-chain data
   * @param zapAgain The ABI-encoded {ArrakisV2ZapAgainParams} that the next owner call uses for the
   * zap again; empty clears the record of the zap again
   */
  struct PoolSwapVariableParams {
    bytes offchainData;
    bytes zapAgain;
  }

  /**
   * @notice The parameters of the zap again of an Arrakis V2 zap
   * @param minZapInAmounts The remaining amounts of token0 and token1 from which the pool swap of
   * the zap again runs; it runs when either remaining amount is at least its minimum
   * @param sqrtPriceLimit0X96 The lower sqrt price limit of the swap preview
   * @param sqrtPriceLimit1X96 The upper sqrt price limit of the swap preview
   * @param iterations The number of binary search iterations of the swap preview
   */
  struct ArrakisV2ZapAgainParams {
    PackedU128 minZapInAmounts;
    uint160 sqrtPriceLimit0X96;
    uint160 sqrtPriceLimit1X96;
    uint256 iterations;
  }

  /**
   * @notice The result of the pool swap of an Arrakis V2 zap
   * @param originalAmount0 The amount of token0 before the swap
   * @param originalAmount1 The amount of token1 before the swap
   * @param usedOffchainData Whether the off-chain data was used
   * @param shares The expected shares at the post-swap price
   * @param amount0 The amount of token0 after the swap
   * @param amount1 The amount of token1 after the swap
   */
  struct PoolSwapResult {
    uint256 originalAmount0;
    uint256 originalAmount1;
    bool usedOffchainData;
    uint256 shares;
    uint256 amount0;
    uint256 amount1;
  }
}
