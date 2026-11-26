// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapAdapter} from '../IZapAdapter.sol';

/// @title IZapCurveAdapter
/// @notice Interface of {ZapCurveAdapter}
interface IZapCurveAdapter is IZapAdapter {
  /// @notice Thrown when the zap in adds no liquidity or less than `minLiquidity`
  error ZapInCurveInsufficientLiquidity();

  /// @notice Thrown when an amount that the proxy receives from the removal is below its minimum
  error RemoveCurveInsufficientAmounts();

  /// @notice The interface of a Curve pool, which selects the calls of `add_liquidity` and
  /// `remove_liquidity`
  enum CurvePoolType {
    /// A pool with `N_COINS` and dynamic arrays of amounts, such as a StableSwap NG pool
    STABLESWAP_NG,
    /// A pool of three coins with fixed arrays of amounts, such as a Tricrypto NG pool
    TRICRYPTO,
    /// A pool of two coins with fixed arrays of amounts, such as a Twocrypto pool or a two-coin
    /// stableswap pool; the only type that receives a native coin as call value
    TWOCRYPTO
  }

  /**
   * @notice Parameters of the zap in, signed by the owner
   * @param poolType The type of the pool
   * @param pool The pool to add liquidity to
   * @param minLiquidity The minimum LP tokens that the zap in adds
   * @param recipient The receiver of the LP tokens
   */
  struct ZapInOwnerParams {
    CurvePoolType poolType;
    address pool;
    uint256 minLiquidity;
    address recipient;
  }

  /**
   * @notice Result of the zap in
   * @param pool The pool that received the liquidity
   * @param recipient The receiver of the LP tokens
   * @param addedAmounts The amount of each coin, in the order of the pool, passed to
   * `add_liquidity`: its balance minus 1, read after the native balance is wrapped or the wrapped
   * native token is unwrapped
   * @param addedLiquidity The LP tokens that the pool minted and the recipient received
   */
  struct ZapInResult {
    address pool;
    address recipient;
    uint256[] addedAmounts;
    uint256 addedLiquidity;
  }

  /**
   * @notice Parameters of the removal, signed by the owner
   * @param poolType The type of the pool
   * @param pool The pool to remove liquidity from
   * @param liquidity The LP tokens of the proxy that the pool burns
   */
  struct RemoveOwnerParams {
    CurvePoolType poolType;
    address pool;
    uint256 liquidity;
  }

  /**
   * @notice Parameters of the removal chosen by the solver
   * @param minRemoveAmounts The minimum amount of each coin, in the order of the pool, that the
   * proxy receives from the removal; an array shorter than the number of coins reverts
   */
  struct RemoveSolverParams {
    uint256[] minRemoveAmounts;
  }

  /**
   * @notice Result of the removal
   * @param pool The pool that liquidity was removed from
   * @param liquidity The LP tokens that were burned
   * @param amounts The amount of each coin, in the order of the pool, that the proxy received
   */
  struct RemoveResult {
    address pool;
    uint256 liquidity;
    uint256[] amounts;
  }
}
