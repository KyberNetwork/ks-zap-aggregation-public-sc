// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapSettler} from '../IZapSettler.sol';
import {IZapSolidlyV2HelperTypes} from './IZapSolidlyV2HelperTypes.sol';

import {PackedU128} from '../../../types/PackedU128.sol';

/// @title IZapSolidlyV2Settler
/// @notice Interface of {ZapSolidlyV2Settler}
interface IZapSolidlyV2Settler is IZapSettler, IZapSolidlyV2HelperTypes {
  /// @notice Thrown when the added liquidity is below the minimum
  error ZapInSolidlyV2InsufficientLiquidity();

  /**
   * @notice Parameters of the zap in
   * @param pool The pair to add liquidity to
   * @param readBalanceFlag Whether to read the token balances, for example when using fee-on-transfer (FOT) tokens
   * @param helper The helper delegatecalled for the pool swap of the zap again and queried for the
   * mint
   * @param minZapInAmounts The remaining amounts of token0 and token1 from which the zap again runs;
   * it runs when either remaining amount is at least its minimum
   * @param minLiquidity The minimum liquidity to add
   * @param recipient The receiver of the liquidity tokens
   * @param refundRecipient The receiver of the remaining tokens
   */
  struct ZapInParams {
    address pool;
    bool readBalanceFlag;
    address helper;
    PackedU128 minZapInAmounts;
    uint256 minLiquidity;
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
