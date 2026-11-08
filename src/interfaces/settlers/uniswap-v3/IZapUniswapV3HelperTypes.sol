// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IZapUniswapV3HelperTypes
/// @notice Parameters and results of the Uniswap V3 helper's zap in preview
interface IZapUniswapV3HelperTypes {
  /**
   * @notice The fixed parameters for zapping into Uniswap V3
   * @param posManager The address of the position manager
   * @param pool The address of the pool
   * @param tickLower The lower tick
   * @param tickUpper The upper tick
   * @param sqrtPriceLimit0X96 The lower sqrt price limit
   * @param sqrtPriceLimit1X96 The upper sqrt price limit
   * @param iterations The number of iterations to binary search
   * @param optimizer The optimizer address
   * @param optimizeFixedParams The fixed parameters for the optimizer
   */
  struct ZapInFixedParams {
    address posManager;
    address pool;
    int24 tickLower;
    int24 tickUpper;
    uint160 sqrtPriceLimit0X96;
    uint160 sqrtPriceLimit1X96;
    uint256 iterations;
    address optimizer;
    bytes optimizeFixedParams;
  }

  /**
   * @notice The variable parameters for previewing a zap into Uniswap V3
   * @param amount0 The amount of token0 to zap in
   * @param amount1 The amount of token1 to zap in
   */
  struct PreviewZapInVariableParams {
    uint256 amount0;
    uint256 amount1;
  }

  /**
   * @notice The result of previewing a zap into Uniswap V3
   * @param sqrtPriceStartX96 The starting sqrt price
   * @param poolLiquidityStart The starting pool liquidity
   * @param sqrtPriceX96 The resulting sqrt price
   * @param amount0Delta The token0 delta for the swap
   * @param amount1Delta The token1 delta for the swap
   * @param positionLiquidity The amount of liquidity added
   * @param addedAmount0 The amount of token0 added
   * @param addedAmount1 The amount of token1 added
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
}
