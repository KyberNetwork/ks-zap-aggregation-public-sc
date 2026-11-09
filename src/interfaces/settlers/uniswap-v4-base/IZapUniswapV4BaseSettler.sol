// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IZapSettler} from '../IZapSettler.sol';
import {IZapUniswapV4BaseHelperTypes} from './IZapUniswapV4BaseHelperTypes.sol';

import {PackedBits} from '../../../types/PackedBits.sol';
import {PackedU128} from '../../../types/PackedU128.sol';
import {PoolKey} from '../../../vendors/uniswap-v4/PoolKey.sol';

/// @title IZapUniswapV4BaseSettler
/// @notice Interface of {ZapUniswapV4BaseSettler}
interface IZapUniswapV4BaseSettler is IZapSettler, IZapUniswapV4BaseHelperTypes {
  /// @notice Thrown when the added liquidity is below the minimum
  error ZapInUniswapV4InsufficientLiquidity();

  /// @notice Thrown when the unlock callback is not called by the pool manager of the ongoing zap in
  error InvalidUnlockCallbackCaller(address caller);

  /**
   * @notice Parameters of the swap and the second liquidity addition with the remaining tokens
   * @param helper The helper queried for the swap; the zero address disables the zap again
   * @param minZapInAmounts The remaining amounts of token0 and token1 from which the zap again runs;
   * it runs when either remaining amount is at least its minimum
   * @param sqrtPriceLimit0X96 The lower sqrt price limit of the swap preview
   * @param sqrtPriceLimit1X96 The upper sqrt price limit of the swap preview
   * @param iterations The number of binary search iterations of the swap preview
   * @param swapHookData The data passed to the hook of the zap again swap
   */
  struct ZapAgainParams {
    address helper;
    PackedU128 minZapInAmounts;
    uint160 sqrtPriceLimit0X96;
    uint160 sqrtPriceLimit1X96;
    uint256 iterations;
    bytes swapHookData;
  }

  /**
   * @notice Parameters of the zap in
   * @param posManager The position manager
   * @param poolManager The pool manager
   * @param poolKey The pool key of the position
   * @param tickLower The lower tick of the position
   * @param tickUpper The upper tick of the position
   * @param tokenId The position to add liquidity to, 0 mints a new position; an existing position
   * must be held by this contract
   * @param addLiquidityHookData The data passed to the hook of the liquidity addition
   * @param readBalanceFlag Settles the amounts to the pool manager before adding and reads the
   * resulting deltas and balances, for fee-on-transfer tokens
   * @param approvalFlags Bit 0 and bit 1 set approve Permit2 for the maximum amount of currency0 and
   * currency1 and approve the position manager on Permit2
   * @param minLiquidity The minimum liquidity to add
   * @param recipient The receiver of the position
   * @param refundRecipient The receiver of the remaining tokens
   * @param zapAgain Parameters of the zap again
   */
  struct ZapInParams {
    address posManager;
    address poolManager;
    PoolKey poolKey;
    int24 tickLower;
    int24 tickUpper;
    uint256 tokenId;
    bytes addLiquidityHookData;
    bool readBalanceFlag;
    PackedBits approvalFlags;
    uint128 minLiquidity;
    address recipient;
    address refundRecipient;
    ZapAgainParams zapAgain;
  }

  /**
   * @notice Result of the zap in
   * @param posManager The position manager
   * @param tokenId The position that received the liquidity
   * @param recipient The receiver of the position
   * @param originalAmount0 The amount of currency0 held before adding liquidity
   * @param originalAmount1 The amount of currency1 held before adding liquidity
   * @param positionLiquidity The liquidity added
   * @param addedAmount0 The amount of currency0 added
   * @param addedAmount1 The amount of currency1 added
   * @param remainingAmount0 The amount of currency0 transferred to the refund recipient
   * @param remainingAmount1 The amount of currency1 transferred to the refund recipient
   */
  struct ZapInResult {
    address posManager;
    uint256 tokenId;
    address recipient;
    uint256 originalAmount0;
    uint256 originalAmount1;
    uint128 positionLiquidity;
    uint256 addedAmount0;
    uint256 addedAmount1;
    uint256 remainingAmount0;
    uint256 remainingAmount1;
  }

  /**
   * @notice Adds the liquidity and runs the zap again inside the unlock of the pool manager
   * @param data ABI-encoded zap in parameters
   * @return result ABI-encoded zap in result
   */
  function unlockCallback(bytes calldata data) external returns (bytes memory result);
}
