// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolKey} from '../../../vendors/pancake-infinity/PoolKey.sol';

/// @title IZapPancakeInfinityBaseHelperTypes
/// @notice Parameters and results of the Pancake Infinity base helper's zap in preview
interface IZapPancakeInfinityBaseHelperTypes {
  /**
   * @notice The fixed parameters for zapping into Pancake Infinity
   * @param posManager The address of the position manager
   * @param vault The address of the vault
   * @param poolKey The pool key
   * @param tickLower The lower tick
   * @param tickUpper The upper tick
   * @param sqrtPriceLimit0X96 The lower sqrt price limit
   * @param sqrtPriceLimit1X96 The upper sqrt price limit
   * @param iterations The number of iterations to binary search
   * @param swapHookData The data for the swap hook
   * @param addLiquidityHookData The data for the add liquidity hook
   * @param optimizer The optimizer address
   * @param optimizeFixedParams The fixed parameters for the optimizer
   * @param readBalanceFlag Whether to read the actual vault deltas and token balances,
   * used for fee-on-transfer or rebasing tokens
   */
  struct ZapInFixedParams {
    address posManager;
    address vault;
    PoolKey poolKey;
    int24 tickLower;
    int24 tickUpper;
    uint160 sqrtPriceLimit0X96;
    uint160 sqrtPriceLimit1X96;
    uint256 iterations;
    bytes swapHookData;
    bytes addLiquidityHookData;
    address optimizer;
    bytes optimizeFixedParams;
    bool readBalanceFlag;
  }

  /**
   * @notice The variable parameters for previewing a zap into Pancake Infinity
   * @param amount0 The amount of token0 to zap in
   * @param amount1 The amount of token1 to zap in
   */
  struct PreviewZapInVariableParams {
    uint256 amount0;
    uint256 amount1;
  }

  /**
   * @notice The result of previewing a zap into Pancake Infinity
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
