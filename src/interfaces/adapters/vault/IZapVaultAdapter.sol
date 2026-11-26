// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapAdapter} from '../IZapAdapter.sol';

import {PackedBits} from '../../../types/PackedBits.sol';
import {PackedU128} from '../../../types/PackedU128.sol';

/// @title IZapVaultAdapter
/// @notice Interface of {ZapVaultAdapter}
interface IZapVaultAdapter is IZapAdapter {
  /// @notice Thrown when the first pass mints no shares or the shares minted by the zap in are
  /// below `minShares`
  error ZapInVaultInsufficientShares();

  /// @notice Thrown when an amount that the proxy receives from the removal is below its minimum
  error RemoveVaultInsufficientAmounts();

  /**
   * @notice Parameters of the zap in, signed by the owner
   * @param vault The vault to deposit into
   * @param pool The pool of the vault, which the helper swaps on
   * @param router The contract that deposits into the vault, the UniProxy for Gamma; Steer does not
   * read it
   * @param minShares The minimum shares that the zap in mints in total
   * @param recipient The receiver of the shares
   */
  struct ZapInOwnerParams {
    address vault;
    address pool;
    address router;
    uint256 minShares;
    address recipient;
  }

  /**
   * @notice Parameters of a pool swap before the deposit
   * @param sqrtPriceLimit0X96 The lower sqrt price limit
   * @param sqrtPriceLimit1X96 The upper sqrt price limit
   * @param iterations The number of binary search iterations between initialized ticks; zero skips
   * the pool swap
   * @param extraData The off-chain data of the swap
   */
  struct VaultPoolSwapParams {
    uint160 sqrtPriceLimit0X96;
    uint160 sqrtPriceLimit1X96;
    uint256 iterations;
    bytes extraData;
  }

  /**
   * @notice Parameters of the zap in chosen by the solver
   * @param poolSwap The pool swap of both passes; zero `iterations` skips both pool swaps: the
   * first pass deposits the balances at the pool price and the second pass does not run. The second
   * pass uses the same parameters without `extraData`.
   * @param minZapInAmounts The minimum balances of token0 and token1 left after the first deposit;
   * the second pass runs when either balance is at least its minimum
   * @param approvalFlags Bit 0 and bit 1 set approve the approval target of the adapter for the
   * maximum amount of token0 and token1 respectively
   * @param helper The helper that is delegatecalled for the pool swaps of both passes; it is
   * required
   */
  struct ZapInSolverParams {
    VaultPoolSwapParams poolSwap;
    PackedU128 minZapInAmounts;
    PackedBits approvalFlags;
    address helper;
  }

  /**
   * @notice Result of the zap in
   * @param vault The vault that minted the shares
   * @param recipient The receiver of the shares
   * @param originalAmount0 The balance of token0 minus 1, read after the native token is wrapped
   * and before the pool swap of the first pass
   * @param originalAmount1 The balance of token1 minus 1, read after the native token is wrapped
   * and before the pool swap of the first pass
   * @param addedShares The shares minted by both passes
   * @param addedAmount0 The amount of token0 deposited by both passes
   * @param addedAmount1 The amount of token1 deposited by both passes
   */
  struct ZapInResult {
    address vault;
    address recipient;
    uint256 originalAmount0;
    uint256 originalAmount1;
    uint256 addedShares;
    uint256 addedAmount0;
    uint256 addedAmount1;
  }

  /**
   * @notice Parameters of the removal, signed by the owner
   * @param vault The vault whose shares the proxy holds and removes
   * @param pool The pool of the vault, from which the adapter reads the tokens
   * @param shares The shares to remove
   */
  struct RemoveOwnerParams {
    address vault;
    address pool;
    uint256 shares;
  }

  /**
   * @notice Parameters of the removal chosen by the solver
   * @param minRemoveAmounts The minimum amounts of token0 and token1 that the proxy receives from
   * the removal
   */
  struct RemoveSolverParams {
    PackedU128 minRemoveAmounts;
  }

  /**
   * @notice Result of the removal
   * @param vault The vault whose shares were removed
   * @param shares The shares that were removed
   * @param amount0 The amount of token0 that the proxy received
   * @param amount1 The amount of token1 that the proxy received
   */
  struct RemoveResult {
    address vault;
    uint256 shares;
    uint256 amount0;
    uint256 amount1;
  }
}
