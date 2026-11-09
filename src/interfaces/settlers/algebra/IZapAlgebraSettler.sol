// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapUniswapV3Settler} from '../uniswap-v3/IZapUniswapV3Settler.sol';

/// @title IZapAlgebraSettler
/// @notice Interface of {ZapAlgebraSettler}
interface IZapAlgebraSettler is IZapUniswapV3Settler {
  /**
   * @notice Pays the pool the token owed for the swap of the zap again
   * @param amount0Delta The token0 amount owed to the pool when positive
   * @param amount1Delta The token1 amount owed to the pool when positive
   * @param data ABI-encoded token0 and token1 of the pool
   */
  function algebraSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data)
    external;
}
