// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapLegacyPoolSwapHelper} from './IZapLegacyPoolSwapHelper.sol';

import {PackedU128} from '../../types/PackedU128.sol';

/// @title IZapPoolSwapAgainHelper
/// @notice Interface of the helper that an adapter delegatecalls for the pool swap of a zap again
interface IZapPoolSwapAgainHelper is IZapLegacyPoolSwapHelper {
  /**
   * @notice Result of the pool swap of a zap again
   * @param swapped Whether a balance reached its minimum and the pool swap ran
   * @param amount0 The balance of token0 after the pool swap, minus one
   * @param amount1 The balance of token1 after the pool swap, minus one
   * @param liquidity The liquidity, the pair liquidity tokens or the vault shares to add at the
   * state after the pool swap; zero when nothing is to be added
   * @param addedAmount0 The amount of token0, rounded up, that the liquidity requires; zero for
   * vaults, whose deposit computes it
   * @param addedAmount1 The amount of token1, rounded up, that the liquidity requires; zero for
   * vaults, whose deposit computes it
   */
  struct PoolSwapAgainResult {
    bool swapped;
    uint256 amount0;
    uint256 amount1;
    uint256 liquidity;
    uint256 addedAmount0;
    uint256 addedAmount1;
  }

  /**
   * @notice Swaps the balances of the pool tokens towards the ratio of the position when either
   * balance is at least its minimum, and computes the liquidity to add at the state after the swap
   * @param fixedParams ABI-encoded fixed parameters specific to the liquidity source
   * @param minZapInAmounts The balances of token0 and token1 from which the pool swap runs
   * @return result The balances after the pool swap and the liquidity to add
   */
  function poolSwapAgain(bytes calldata fixedParams, PackedU128 minZapInAmounts)
    external
    payable
    returns (PoolSwapAgainResult memory result);
}
