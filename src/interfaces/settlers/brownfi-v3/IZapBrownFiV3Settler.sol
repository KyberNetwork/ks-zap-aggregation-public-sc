// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapSettler} from '../IZapSettler.sol';
import {IZapBrownFiV3HelperTypes} from './IZapBrownFiV3HelperTypes.sol';

/// @title IZapBrownFiV3Settler
/// @notice Interface of {ZapBrownFiV3Settler}
interface IZapBrownFiV3Settler is IZapSettler, IZapBrownFiV3HelperTypes {
  /// @notice Thrown when the added liquidity is below the minimum
  error ZapInBrownFiV3InsufficientLiquidity();

  /**
   * @notice Parameters of the zap in
   * @param pool The pair to add liquidity to
   * @param helper The helper queried for the amounts of the first mint when the pool swap recorded
   * none, and delegatecalled for the pool swap of the zap again; the zap again does not run when it
   * is the zero address
   * @param minLiquidity The minimum liquidity to add
   * @param recipient The receiver of the liquidity tokens
   * @param refundRecipient The receiver of the remaining tokens
   */
  struct ZapInParams {
    address pool;
    address helper;
    uint128 minLiquidity;
    address recipient;
    address refundRecipient;
  }

  /**
   * @notice Result of the zap in
   * @param pool The pair that received the liquidity
   * @param recipient The receiver of the liquidity tokens
   * @param originalAmount0 The amount of token0 held before adding liquidity
   * @param originalAmount1 The amount of token1 held before adding liquidity
   * @param liquidity The liquidity added
   * @param addedAmount0 The amount of token0 added
   * @param addedAmount1 The amount of token1 added
   * @param remainingAmount0 The amount of token0 transferred to the refund recipient
   * @param remainingAmount1 The amount of token1 transferred to the refund recipient
   */
  struct ZapInResult {
    address pool;
    address recipient;
    uint256 originalAmount0;
    uint256 originalAmount1;
    uint256 liquidity;
    uint256 addedAmount0;
    uint256 addedAmount1;
    uint256 remainingAmount0;
    uint256 remainingAmount1;
  }
}
