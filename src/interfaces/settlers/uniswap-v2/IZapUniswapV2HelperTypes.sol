// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IZapUniswapV2HelperTypes
/// @notice Parameters and results of the Uniswap V2 helper's previews
interface IZapUniswapV2HelperTypes {
  /**
   * @notice The fixed parameters for zapping into Uniswap V2
   * @param pool The address of the pool
   * @param swapFee The swap fee
   * @param protocolFee The protocol fee
   * @param feeDenominator The fee denominator
   * @param readBalanceFlag Whether to read the token balances, used for fee-on-transfer or rebasing tokens
   * @param optimizer The optimizer address
   * @param optimizeFixedParams The fixed parameters for the optimizer
   */
  struct ZapInFixedParams {
    address pool;
    uint24 swapFee;
    uint24 protocolFee;
    uint24 feeDenominator;
    bool readBalanceFlag;
    address optimizer;
    bytes optimizeFixedParams;
  }

  /**
   * @notice The variable parameters for previewing a zap into Uniswap V2
   * @param amount0 The amount of token0 to zap in
   * @param amount1 The amount of token1 to zap in
   */
  struct PreviewZapInVariableParams {
    uint256 amount0;
    uint256 amount1;
  }

  /**
   * @notice The result of previewing a zap into Uniswap V2
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
}
