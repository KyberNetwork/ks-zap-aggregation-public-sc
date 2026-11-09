// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapSettler} from '../IZapSettler.sol';

/// @title IZapCurveSettler
/// @notice Interface of {ZapCurveSettler}
interface IZapCurveSettler is IZapSettler {
  /// @notice Thrown when the pool type is unknown
  error InvalidCurvePoolType();

  /**
   * @notice The list of Curve pool types
   * @param STABLESWAP_NG The StableSwap NG pool type
   * @param TRICRYPTO The Tricrypto pool type
   * @param TWOCYCRYPTO The TwoCrypto pool type
   */
  enum CurvePoolType {
    STABLESWAP_NG,
    TRICRYPTO,
    TWOCYCRYPTO
  }

  /**
   * @notice Parameters of the zap in
   * @param poolType The type of the Curve pool
   * @param pool The pool to add liquidity to
   * @param minLiquidity The minimum liquidity to mint
   * @param recipient The receiver of the LP tokens
   * @param refundRecipient The receiver of the remaining tokens
   */
  struct ZapInParams {
    CurvePoolType poolType;
    address pool;
    uint256 minLiquidity;
    address recipient;
    address refundRecipient;
  }

  /**
   * @notice Result of the zap in
   * @param pool The pool that received the liquidity
   * @param recipient The receiver of the LP tokens
   * @param amounts The amounts of the pool tokens added
   * @param liquidity The amount of liquidity minted
   */
  struct ZapInResult {
    address pool;
    address recipient;
    uint256[] amounts;
    uint256 liquidity;
  }
}
