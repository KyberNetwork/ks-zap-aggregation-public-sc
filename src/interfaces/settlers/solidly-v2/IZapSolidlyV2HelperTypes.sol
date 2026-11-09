// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IZapSolidlyV2HelperTypes
/// @notice Parameters and results of the Solidly V2 helper's previews
interface IZapSolidlyV2HelperTypes {
  /**
   * @notice The fixed parameters for zapping into Solidly V2
   * @param pool The address of the pool
   * @param readBalanceFlag Whether to read the token balances, for example when using fee-on-transfer (FOT) tokens
   */
  struct ZapInFixedParams {
    address pool;
    bool readBalanceFlag;
  }

  /**
   * @notice The variable parameters for previewing a zap into Solidly V2
   * @param amount0 The amount of token0 to zap in
   * @param amount1 The amount of token1 to zap in
   */
  struct PreviewZapInVariableParams {
    uint256 amount0;
    uint256 amount1;
  }

  /**
   * @notice The result of previewing a zap into Solidly V2
   * @param amount0Delta The token0 delta for the swap
   * @param amount1Delta The token1 delta for the swap
   * @param liquidity The amount of liquidity added
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
   * @param originalAmount0 The amount of token0 before the swap
   * @param originalAmount1 The amount of token1 before the swap
   * @param amount0 The amount of token0 after the swap
   * @param amount1 The amount of token1 after the swap
   */
  struct PoolSwapResult {
    uint256 originalAmount0;
    uint256 originalAmount1;
    uint256 amount0;
    uint256 amount1;
  }
}
