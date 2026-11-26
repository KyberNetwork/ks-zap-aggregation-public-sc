// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapAdapter} from '../IZapAdapter.sol';

import {PackedU128} from '../../../types/PackedU128.sol';

/// @title IZapBrownFiV3Adapter
/// @notice Interface of {ZapBrownFiV3Adapter}
interface IZapBrownFiV3Adapter is IZapAdapter {
  /// @notice Thrown when the first pass adds no liquidity or the liquidity added by the zap in is
  /// below `minLiquidity`
  error ZapInBrownFiV3InsufficientLiquidity();

  /// @notice Thrown when an amount that the proxy receives from the removal is below its minimum
  error RemoveBrownFiV3InsufficientAmounts();

  /**
   * @notice Parameters of the zap in, signed by the owner
   * @param pool The pair to add liquidity to
   * @param minLiquidity The minimum liquidity that the zap in adds in total
   * @param recipient The receiver of the liquidity tokens
   */
  struct ZapInOwnerParams {
    address pool;
    uint256 minLiquidity;
    address recipient;
  }

  /**
   * @notice Parameters of the zap in chosen by the solver
   * @param iterations The number of binary search iterations of the pool swap of both passes; zero
   * swaps nothing in either pass: the first pass adds the balances at the state of the pair and the
   * second pass does not run
   * @param minZapInAmounts The minimum balances of token0 and token1 left after the first addition;
   * the second pass runs when either balance is at least its minimum
   * @param helper The helper that is delegatecalled for the pool swaps of both passes; it is
   * required
   */
  struct ZapInSolverParams {
    uint256 iterations;
    PackedU128 minZapInAmounts;
    address helper;
  }

  /**
   * @notice Result of the zap in
   * @param pool The pair that received the liquidity
   * @param recipient The receiver of the liquidity tokens
   * @param originalAmount0 The balance of token0 minus 1, read after the native token is wrapped
   * and before the pool swap of the first pass
   * @param originalAmount1 The balance of token1 minus 1, read after the native token is wrapped
   * and before the pool swap of the first pass
   * @param addedLiquidity The liquidity that the pair minted to the recipient in both passes
   * @param addedAmount0 The amount of token0 transferred to the pair in both passes
   * @param addedAmount1 The amount of token1 transferred to the pair in both passes
   */
  struct ZapInResult {
    address pool;
    address recipient;
    uint256 originalAmount0;
    uint256 originalAmount1;
    uint256 addedLiquidity;
    uint256 addedAmount0;
    uint256 addedAmount1;
  }

  /**
   * @notice Parameters of the removal, signed by the owner
   * @param pool The pair to remove liquidity from
   * @param liquidity The liquidity tokens of the proxy that the pair burns
   */
  struct RemoveOwnerParams {
    address pool;
    uint256 liquidity;
  }

  /**
   * @notice Parameters of the removal chosen by the solver
   * @param minRemoveAmounts The minimum amounts of token0 and token1 that the proxy receives from
   * the burn
   */
  struct RemoveSolverParams {
    PackedU128 minRemoveAmounts;
  }

  /**
   * @notice Result of the removal
   * @param pool The pair that liquidity was removed from
   * @param liquidity The liquidity that was burned
   * @param amount0 The amount of token0 that the proxy received
   * @param amount1 The amount of token1 that the proxy received
   */
  struct RemoveResult {
    address pool;
    uint256 liquidity;
    uint256 amount0;
    uint256 amount1;
  }
}
