// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
}
