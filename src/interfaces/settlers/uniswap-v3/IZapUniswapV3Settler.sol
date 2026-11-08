// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapSettler} from '../IZapSettler.sol';
import {IZapUniswapV3HelperTypes} from './IZapUniswapV3HelperTypes.sol';

import {PackedBits} from '../../../types/PackedBits.sol';
import {PackedU128} from '../../../types/PackedU128.sol';

/// @title IZapUniswapV3Settler
/// @notice Interface of {ZapUniswapV3Settler}
interface IZapUniswapV3Settler is IZapSettler, IZapUniswapV3HelperTypes {
  /// @notice Thrown when the added liquidity is below the minimum
  error ZapInUniswapV3InsufficientLiquidity();

  /// @notice Thrown when the swap callback is not called by the pool of the ongoing swap
  error InvalidSwapCallbackCaller(address caller);

  /**
   * @notice Parameters of the swap and the second liquidity addition with the remaining tokens
   * @param helper The helper queried for the swap; the zero address disables the zap again
   * @param minZapInAmounts The remaining amounts of token0 and token1 from which the zap again runs;
   * it runs when either remaining amount is at least its minimum
   * @param sqrtPriceLimit0X96 The lower sqrt price limit of the swap preview
   * @param sqrtPriceLimit1X96 The upper sqrt price limit of the swap preview
   * @param iterations The number of binary search iterations of the swap preview
   */
  struct ZapAgainParams {
    address helper;
    PackedU128 minZapInAmounts;
    uint160 sqrtPriceLimit0X96;
    uint160 sqrtPriceLimit1X96;
    uint256 iterations;
  }

  /**
   * @notice Parameters of the zap in
   * @param posManager The position manager
   * @param pool The pool of the position
   * @param tickLower The lower tick of the position
   * @param tickUpper The upper tick of the position
   * @param tokenId The position to add liquidity to, 0 mints a new position
   * @param extraData Data passed to the position manager calls of forks that require it
   * @param approvalFlags Bit 0 and bit 1 set approve the position manager for the maximum amount of
   * token0 and token1
   * @param minLiquidity The minimum liquidity to add
   * @param recipient The receiver of the position; a position held by this contract is transferred
   * to it
   * @param refundRecipient The receiver of the remaining tokens
   * @param zapAgain Parameters of the zap again
   */
  struct ZapInParams {
    address posManager;
    address pool;
    int24 tickLower;
    int24 tickUpper;
    uint256 tokenId;
    bytes extraData;
    PackedBits approvalFlags;
    uint128 minLiquidity;
    address recipient;
    address refundRecipient;
    ZapAgainParams zapAgain;
  }

  /**
   * @notice Result of the zap in
   * @param posManager The position manager
   * @param tokenId The position that received the liquidity
   * @param recipient The receiver of the position
   * @param originalAmount0 The amount of token0 held before adding liquidity
   * @param originalAmount1 The amount of token1 held before adding liquidity
   * @param positionLiquidity The liquidity added
   * @param addedAmount0 The amount of token0 added
   * @param addedAmount1 The amount of token1 added
   * @param remainingAmount0 The amount of token0 transferred to the refund recipient
   * @param remainingAmount1 The amount of token1 transferred to the refund recipient
   */
  struct ZapInResult {
    address posManager;
    uint256 tokenId;
    address recipient;
    uint256 originalAmount0;
    uint256 originalAmount1;
    uint256 positionLiquidity;
    uint256 addedAmount0;
    uint256 addedAmount1;
    uint256 remainingAmount0;
    uint256 remainingAmount1;
  }

  /**
   * @notice Pays the pool the token owed for the swap of the zap again
   * @param amount0Delta The token0 amount owed to the pool when positive
   * @param amount1Delta The token1 amount owed to the pool when positive
   * @param data ABI-encoded token0 and token1 of the pool
   */
  function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data)
    external;
}
