// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapAdapter} from '../IZapAdapter.sol';

import {PackedBits} from '../../../types/PackedBits.sol';
import {PackedU128} from '../../../types/PackedU128.sol';

/// @title IZapUniswapV3Adapter
/// @notice Interface of {ZapUniswapV3Adapter}
interface IZapUniswapV3Adapter is IZapAdapter {
  /// @notice Thrown when the first pass adds no liquidity or the liquidity added by the zap in is
  /// below `minLiquidity`
  error ZapInUniswapV3InsufficientLiquidity();

  /**
   * @notice Parameters of the zap in, signed by the owner
   * @param posManager The position manager
   * @param pool The pool of the position
   * @param tickLower The lower tick of the position
   * @param tickUpper The upper tick of the position
   * @param tokenId The position to add liquidity to; zero mints a new position
   * @param extraData Data for the position manager calls of the forks that require it
   * @param minLiquidity The minimum liquidity that the zap in adds in total
   * @param recipient The receiver of the position; an existing position that the proxy holds is
   * transferred to it
   */
  struct ZapInOwnerParams {
    address posManager;
    address pool;
    int24 tickLower;
    int24 tickUpper;
    uint256 tokenId;
    bytes extraData;
    uint128 minLiquidity;
    address recipient;
  }

  /**
   * @notice Parameters of the zap in chosen by the solver
   * @param poolSwap The pool swap of both passes; zero `iterations` skips both pool swaps: the
   * first pass adds the balances at the pool price and the second pass does not run. The second
   * pass uses the same parameters without `extraData`.
   * @param minZapInAmounts The minimum balances of token0 and token1 left after the first addition;
   * the second pass runs when either balance is at least its minimum
   * @param approvalFlags Bit 0 and bit 1 set approve the position manager for the maximum amount of
   * token0 and token1 respectively
   * @param helper The helper that is delegatecalled for the pool swaps of both passes; it is
   * required
   */
  struct ZapInSolverParams {
    UniswapV3PoolSwapParams poolSwap;
    PackedU128 minZapInAmounts;
    PackedBits approvalFlags;
    address helper;
  }

  /**
   * @notice Parameters of a pool swap before liquidity is added
   * @param sqrtPriceLimit0X96 The lower sqrt price limit
   * @param sqrtPriceLimit1X96 The upper sqrt price limit
   * @param iterations The number of binary search iterations between initialized ticks; zero skips
   * the pool swap
   * @param optimizer The optimizer address
   * @param optimizeSolverParams The solver parameters of the optimizer
   * @param extraData The off-chain data or the data of the optimizer
   */
  struct UniswapV3PoolSwapParams {
    uint160 sqrtPriceLimit0X96;
    uint160 sqrtPriceLimit1X96;
    uint256 iterations;
    address optimizer;
    bytes optimizeSolverParams;
    bytes extraData;
  }

  /**
   * @notice Result of the zap in
   * @param posManager The position manager
   * @param tokenId The position that received the liquidity
   * @param recipient The receiver of the position
   * @param originalAmount0 The balance of token0 minus 1, read after the native token is wrapped
   * and before the pool swap of the first pass
   * @param originalAmount1 The balance of token1 minus 1, read after the native token is wrapped
   * and before the pool swap of the first pass
   * @param addedLiquidity The liquidity added by both passes
   * @param addedAmount0 The amount of token0 added by both passes
   * @param addedAmount1 The amount of token1 added by both passes
   * @param remainingAmount0 The amount of token0 after the pool swap of the last pass less the
   * amount added in that pass
   * @param remainingAmount1 The amount of token1 after the pool swap of the last pass less the
   * amount added in that pass
   */
  struct ZapInResult {
    address posManager;
    uint256 tokenId;
    address recipient;
    uint256 originalAmount0;
    uint256 originalAmount1;
    uint256 addedLiquidity;
    uint256 addedAmount0;
    uint256 addedAmount1;
    uint256 remainingAmount0;
    uint256 remainingAmount1;
  }

  /**
   * @notice Parameters of the removal, signed by the owner
   * @param posManager The position manager
   * @param tokenId The position that the proxy holds and removes liquidity from
   * @param liquidity The liquidity to remove; 0 only collects the fees
   * @param recipient The receiver of the position after the collection; the zero address keeps the
   * position in the proxy
   */
  struct RemoveOwnerParams {
    address posManager;
    uint256 tokenId;
    uint128 liquidity;
    address recipient;
  }

  /**
   * @notice Parameters of the removal chosen by the solver
   * @param minRemoveAmounts The minimum amounts of token0 and token1 that the decrease of
   * liquidity returns, checked by the position manager on the principal without the fees; they
   * are not checked when the liquidity to remove is zero
   */
  struct RemoveSolverParams {
    PackedU128 minRemoveAmounts;
  }

  /**
   * @notice Result of the removal
   * @param posManager The position manager
   * @param tokenId The position that liquidity was removed from
   * @param liquidity The liquidity that was removed
   * @param amount0 The amount of token0 collected
   * @param amount1 The amount of token1 collected
   */
  struct RemoveResult {
    address posManager;
    uint256 tokenId;
    uint128 liquidity;
    uint256 amount0;
    uint256 amount1;
  }
}
