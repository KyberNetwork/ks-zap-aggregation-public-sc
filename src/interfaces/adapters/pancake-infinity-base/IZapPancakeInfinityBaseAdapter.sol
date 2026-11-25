// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapAdapter} from '../IZapAdapter.sol';

import {PackedBits} from '../../../types/PackedBits.sol';
import {PackedU128} from '../../../types/PackedU128.sol';
import {PoolKey} from '../../../vendors/pancake-infinity/PoolKey.sol';

/// @title IZapPancakeInfinityBaseAdapter
/// @notice Interface of {ZapPancakeInfinityBaseAdapter}
interface IZapPancakeInfinityBaseAdapter is IZapAdapter {
  /// @notice Thrown when the first pass adds no liquidity or the liquidity added by the zap in is
  /// below `minLiquidity`
  error ZapInPancakeInfinityInsufficientLiquidity();

  /**
   * @notice Parameters of the zap in, signed by the owner
   * @param posManager The position manager
   * @param vault The vault of the pool
   * @param poolKey The pool key of the position; its pool manager is the CL pool manager
   * @param tickLower The lower tick of the position
   * @param tickUpper The upper tick of the position
   * @param tokenId The position to add liquidity to; zero mints a new position. A non-zero value
   * must be held by the proxy.
   * @param addLiquidityHookData The data passed to the hook of both liquidity additions
   * @param minLiquidity The minimum liquidity that the zap in adds in total
   * @param recipient The receiver of the position; an existing position that the proxy holds is
   * transferred to it
   */
  struct ZapInOwnerParams {
    address posManager;
    address vault;
    PoolKey poolKey;
    int24 tickLower;
    int24 tickUpper;
    uint256 tokenId;
    bytes addLiquidityHookData;
    uint128 minLiquidity;
    address recipient;
  }

  /**
   * @notice Parameters of a pool swap before liquidity is added
   * @param sqrtPriceLimit0X96 The lower sqrt price limit
   * @param sqrtPriceLimit1X96 The upper sqrt price limit
   * @param iterations The number of binary search iterations between initialized ticks; zero skips
   * the pool swap
   * @param swapHookData The data passed to the hook of the swap
   * @param optimizer The optimizer address
   * @param optimizeSolverParams The solver parameters of the optimizer
   * @param extraData The off-chain data or the data of the optimizer
   */
  struct PancakeInfinityPoolSwapParams {
    uint160 sqrtPriceLimit0X96;
    uint160 sqrtPriceLimit1X96;
    uint256 iterations;
    bytes swapHookData;
    address optimizer;
    bytes optimizeSolverParams;
    bytes extraData;
  }

  /**
   * @notice Parameters of the zap in chosen by the solver
   * @param poolSwap The pool swap of both passes; zero `iterations` skips both pool swaps: the
   * first pass adds the balances at the pool price and the second pass does not run. The second
   * pass uses the same parameters without `extraData`.
   * @param minZapInAmounts The minimum balances of currency0 and currency1 left after the first
   * addition; the second pass runs when either balance is at least its minimum
   * @param approvalFlags Bit 0 and bit 1 set approve Permit2 for the maximum amount of currency0
   * and currency1 and approve the position manager on Permit2
   * @param readBalanceFlag Settles the amounts to the vault before adding and reads the
   * resulting deltas and balances, for fee-on-transfer tokens
   * @param helper The helper that is delegatecalled for the pool swaps of both passes; it is
   * required
   */
  struct ZapInSolverParams {
    PancakeInfinityPoolSwapParams poolSwap;
    PackedU128 minZapInAmounts;
    PackedBits approvalFlags;
    bool readBalanceFlag;
    address helper;
  }

  /**
   * @notice Result of the zap in
   * @param posManager The position manager
   * @param tokenId The position that received the liquidity
   * @param recipient The receiver of the position
   * @param originalAmount0 The balance of currency0 minus 1 before the pool swap of the first pass
   * @param originalAmount1 The balance of currency1 minus 1 before the pool swap of the first pass
   * @param addedLiquidity The liquidity added by both passes
   * @param addedAmount0 The amount of currency0 added by both passes
   * @param addedAmount1 The amount of currency1 added by both passes
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
   * @param hookData The data passed to the hook of the liquidity decrease
   * @param recipient The receiver of the position after the removal; the zero address keeps the
   * position in the proxy
   */
  struct RemoveOwnerParams {
    address posManager;
    uint256 tokenId;
    uint128 liquidity;
    bytes hookData;
    address recipient;
  }

  /**
   * @notice Parameters of the removal chosen by the solver
   * @param minRemoveAmounts The minimum amounts of currency0 and currency1 that the decrease of
   * liquidity returns, checked by the position manager on the principal without the fees
   */
  struct RemoveSolverParams {
    PackedU128 minRemoveAmounts;
  }

  /**
   * @notice Result of the removal
   * @param posManager The position manager
   * @param tokenId The position that liquidity was removed from
   * @param liquidity The liquidity that was removed
   * @param amount0 The amount of currency0 taken
   * @param amount1 The amount of currency1 taken
   */
  struct RemoveResult {
    address posManager;
    uint256 tokenId;
    uint128 liquidity;
    uint256 amount0;
    uint256 amount1;
  }

  /**
   * @notice Adds the liquidity inside the lock of the vault, with both pool swaps
   * @param data ABI-encoded owner data and solver data of the zap in
   * @return result ABI-encoded zap in result
   */
  function lockAcquired(bytes calldata data) external returns (bytes memory result);
}
