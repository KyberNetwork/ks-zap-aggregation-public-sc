// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapAdapter} from '../IZapAdapter.sol';
import {IZapUniswapV3HelperTypes} from './IZapUniswapV3HelperTypes.sol';

import {PackedBits} from '../../../types/PackedBits.sol';
import {PackedU128} from '../../../types/PackedU128.sol';

/// @title IZapUniswapV3Adapter
/// @notice Interface of {ZapUniswapV3Adapter}
interface IZapUniswapV3Adapter is IZapAdapter, IZapUniswapV3HelperTypes {
  /// @notice Thrown when the first pass adds no liquidity or the liquidity added by the zap in is
  /// below `minLiquidity`
  error ZapInUniswapV3InsufficientLiquidity();

  /// @notice Thrown when the removed amounts are below the minimums
  error RemoveUniswapV3InsufficientAmounts();

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
   * @param poolSwap The pool swap of the first pass; zero `iterations` skips it
   * @param poolSwapAgain The pool swap of the second pass
   * @param minZapInAmounts The minimum balances of token0 and token1 left after the first addition;
   * the second pass runs when either balance is at least its minimum
   * @param approvalFlags Bit 0 and bit 1 set approve the position manager for the maximum amount of
   * token0 and token1 respectively
   * @param helper The helper that is delegatecalled for the pool swaps; the zero address skips both
   * pool swaps and the second pass
   */
  struct ZapInSolverParams {
    UniswapV3PoolSwapParams poolSwap;
    UniswapV3PoolSwapParams poolSwapAgain;
    PackedU128 minZapInAmounts;
    PackedBits approvalFlags;
    address helper;
  }

  /**
   * @notice Parameters of a pool swap before liquidity is added
   * @param sqrtPriceLimit0X96 The lower sqrt price limit
   * @param sqrtPriceLimit1X96 The upper sqrt price limit
   * @param iterations The number of binary search iterations; zero skips the pool swap of the first
   * pass only
   * @param optimizer The optimizer address
   * @param optimizeFixedParams The fixed parameters of the optimizer
   * @param extraData The off-chain data or the data of the optimizer
   */
  struct UniswapV3PoolSwapParams {
    uint160 sqrtPriceLimit0X96;
    uint160 sqrtPriceLimit1X96;
    uint256 iterations;
    address optimizer;
    bytes optimizeFixedParams;
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
   * @param minRemoveAmounts The minimum amounts of token0 and token1 that the removal collects
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
